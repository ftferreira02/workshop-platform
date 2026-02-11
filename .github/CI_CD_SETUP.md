# CI/CD Setup Guide

This repository uses GitHub Actions to automate Terraform deployments for the workshop platform infrastructure.

## Overview

Two workflows manage the infrastructure lifecycle:

1. **Terraform Plan** (`terraform-plan.yml`) - Runs on pull requests
2. **Terraform Apply** (`terraform-apply.yml`) - Runs on pushes to main

## Prerequisites

### 1. AWS Credentials

The workflows require AWS credentials to manage infrastructure. These should be the credentials for the `terraform-ci` IAM user created in the `terraform_init` directory.

#### Get the Credentials

If you haven't already retrieved the credentials:

```bash
cd terraform_init
terraform output -raw ci_access_key_id
terraform output -raw ci_secret_access_key
```

### 2. GitHub Environments Setup

The workflows use **environment-specific secrets**, allowing each environment (dev, stg, prd) to use different AWS accounts.

#### Create Environments

1. Go to **Settings** → **Environments**
2. Create three environments:
   - `dev`
   - `stg`
   - `production` (for prd)

#### Configure Each Environment

For **each environment**, add the following secrets:

**Environment: `dev`**
1. Go to Settings → Environments → `dev` → Add secret
2. Add secrets:
   - `AWS_ACCESS_KEY_ID` - Dev AWS account access key
   - `AWS_SECRET_ACCESS_KEY` - Dev AWS account secret key

**Environment: `stg`**
1. Go to Settings → Environments → `stg` → Add secret
2. Add secrets:
   - `AWS_ACCESS_KEY_ID` - Staging AWS account access key
   - `AWS_SECRET_ACCESS_KEY` - Staging AWS account secret key

**Environment: `production`**
1. Go to Settings → Environments → `production` → Add secret
2. Add secrets:
   - `AWS_ACCESS_KEY_ID` - Production AWS account access key
   - `AWS_SECRET_ACCESS_KEY` - Production AWS account secret key
3. Configure protection rules:
   - ✅ **Required reviewers** (highly recommended)
   - ✅ **Wait timer** (optional, e.g., 5 minutes)
   - ✅ **Deployment branches**: Only `main`

#### Environment-Specific Secrets Benefits

✅ **Account Isolation**: Each environment can use a different AWS account
✅ **Security**: Production credentials never used in dev/staging
✅ **Flexibility**: Different regions, accounts, or permissions per environment
✅ **Compliance**: Separate accounts for regulatory requirements

#### Using Same Account for All Environments

If you're using a single AWS account for all environments:

1. Use the same credentials (`terraform-ci` user) for all three environments
2. State files are still isolated by backend key
3. Resources are isolated by VPC CIDR and cluster names

**Note**: Using separate AWS accounts per environment is recommended for production workloads.

## Workflows

### Terraform Plan (Pull Requests)

**Triggers:** When a PR is opened or updated targeting `main` with changes in:
- `platform/**`
- `.github/workflows/terraform-plan.yml`

**Steps:**
1. ✅ Checkout code
2. ✅ Configure AWS credentials
3. ✅ Setup Terraform
4. ✅ Run `terraform fmt -check` (formatting)
5. ✅ Run `terraform init`
6. ✅ Run `terraform validate`
7. ✅ Run `terraform plan`
8. 💬 Comment plan output on PR
9. ❌ Fail if formatting, validation, or plan fails

**Output:** The plan is automatically posted as a comment on the PR.

### Terraform Apply (Main Branch)

**Triggers:** When code is pushed or merged to `main` with changes in:
- `platform/**`
- `.github/workflows/terraform-apply.yml`

**Steps:**
1. ✅ Checkout code
2. ✅ Configure AWS credentials
3. ✅ Setup Terraform
4. ✅ Run `terraform fmt -check`
5. ✅ Run `terraform init`
6. ✅ Run `terraform validate`
7. ✅ Run `terraform plan`
8. ✅ Run `terraform apply -auto-approve`
9. ✅ Display deployment summary

**Output:** Deployment summary is added to the GitHub Actions summary page.

## Workflow Diagram

```
┌─────────────────┐
│  Pull Request   │
│   Created/      │
│   Updated       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Terraform Plan  │
│   Workflow      │
├─────────────────┤
│ • Format Check  │
│ • Init          │
│ • Validate      │
│ • Plan          │
│ • Comment on PR │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   PR Review &   │
│    Approval     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Merge to Main  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Terraform Apply │
│   Workflow      │
├─────────────────┤
│ • Format Check  │
│ • Init          │
│ • Validate      │
│ • Plan          │
│ • Apply         │
│ • Summary       │
└─────────────────┘
```

## Usage

### Making Infrastructure Changes

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/add-new-namespace
   ```

2. **Make Changes**
   ```bash
   cd platform
   # Edit Terraform files
   terraform fmt -recursive
   ```

3. **Commit and Push**
   ```bash
   git add .
   git commit -m "Add new Fargate namespace for application"
   git push origin feature/add-new-namespace
   ```

4. **Create Pull Request**
   - Go to GitHub and create a PR
   - GitHub Actions will automatically run `terraform plan`
   - Review the plan in the PR comment

5. **Review and Merge**
   - Review the Terraform plan
   - Get PR approval (if required)
   - Merge the PR

6. **Automatic Deployment**
   - GitHub Actions automatically runs `terraform apply`
   - Infrastructure is updated
   - Review the deployment summary

## Terraform State

The workflows use remote state stored in S3:
- **Bucket:** `workshop-ua-terraform-state-bucket`
- **Key:** `platform/terraform.tfstate`
- **Region:** `eu-west-1`
- **Lock Table:** `terraform-state-locks`

This ensures:
- State is shared across workflows
- Concurrent runs are prevented (via DynamoDB locking)
- State is encrypted at rest

## Security Best Practices

### ✅ Do's

- ✅ Use IAM user with minimal permissions (terraform-ci)
- ✅ Store credentials as GitHub secrets (never in code)
- ✅ Use environment protection rules for production
- ✅ Review all Terraform plans before merging
- ✅ Keep Terraform version pinned and up-to-date
- ✅ Use branch protection on `main`

### ❌ Don'ts

- ❌ Never commit AWS credentials
- ❌ Don't skip the plan review
- ❌ Don't push directly to main (use PRs)
- ❌ Don't disable auto-approve without good reason
- ❌ Don't store secrets in Terraform files

## Troubleshooting

### Workflow Fails with "Error: configuring Terraform AWS Provider"

**Cause:** AWS credentials are not set or invalid.

**Solution:**
1. Verify secrets are set in GitHub: Settings → Secrets → Actions
2. Check credentials are still valid
3. Ensure IAM user has necessary permissions

### Workflow Fails with "Error acquiring state lock"

**Cause:** Another workflow run or local terraform is holding the state lock.

**Solution:**
1. Wait for other workflow to complete
2. Check DynamoDB table `terraform-state-locks` for stuck locks
3. Manually remove lock if necessary (use with caution):
   ```bash
   terraform force-unlock <lock-id>
   ```

### Format Check Fails

**Cause:** Terraform files are not properly formatted.

**Solution:**
```bash
cd platform
terraform fmt -recursive
git add .
git commit -m "Fix formatting"
git push
```

### Plan Shows Unexpected Changes

**Cause:** State drift or unintended modifications.

**Solution:**
1. Review the plan carefully
2. Check if someone made manual changes in AWS console
3. Consider using `terraform refresh` to sync state
4. If needed, use `terraform import` to bring existing resources under management

## Monitoring

### View Workflow Runs

1. Go to **Actions** tab in GitHub
2. Select the workflow (Terraform Plan or Terraform Apply)
3. Click on a specific run to see details

### Notifications

Configure notifications for workflow failures:

1. Go to **Settings** → **Notifications**
2. Enable "Actions" notifications
3. Choose notification method (email, Slack, etc.)

## Advanced Configuration

### Customizing Terraform Version

Edit the workflow files:

```yaml
env:
  TF_VERSION: "1.9"  # Change this
```

### Adding Additional Environments

To add staging/dev environments:

1. Create new workflow files (e.g., `terraform-apply-staging.yml`)
2. Change branch triggers and working directory
3. Add environment-specific secrets
4. Update backend configuration for separate state files

### Enabling Terraform Plan on Specific Directories

Modify the `paths` filter in workflows:

```yaml
on:
  pull_request:
    paths:
      - 'platform/**'
      - 'modules/**'  # Add additional paths
```

## Cost Optimization

GitHub Actions usage is free for public repositories. For private repositories:

- **Free tier:** 2,000 minutes/month
- **Cost:** Varies by runner type

Typical workflow run times:
- Terraform Plan: ~2-3 minutes
- Terraform Apply: ~15-20 minutes (EKS cluster creation)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review GitHub Actions logs
3. Check AWS CloudWatch logs for EKS/Terraform issues
4. Consult Terraform AWS provider documentation
