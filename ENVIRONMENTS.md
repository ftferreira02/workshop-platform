# Multi-Environment Configuration

This platform infrastructure is configured to support three environments: **dev**, **stg** (staging), and **prd** (production).

## Multi-Account Architecture

**Each environment runs in a separate AWS account** for complete isolation and security:

```
Development Account (e.g., 111111111111)
  └─ workshop-eks-dev cluster
     └─ VPC 10.0.0.0/16

Staging Account (e.g., 222222222222)
  └─ workshop-eks-stg cluster
     └─ VPC 10.10.0.0/16

Production Account (e.g., 333333333333)
  └─ workshop-eks-prd cluster
     └─ VPC 10.20.0.0/16
```

### Why Separate AWS Accounts?

✅ **Security Isolation**: Compromised dev environment doesn't affect production
✅ **Blast Radius Limitation**: Issues in one account don't impact others
✅ **IAM Boundary**: Complete IAM policy isolation between environments
✅ **Billing Clarity**: Separate cost tracking per environment
✅ **Compliance**: Meet regulatory requirements for environment separation
✅ **Access Control**: Different teams can have different account access levels

## Overview

Each environment has:
- **Separate AWS account** (recommended for production workloads)
- **Separate state files** in S3 (isolated infrastructure)
- **Environment-specific configurations** via tfvars files
- **Different VPC CIDR ranges** (no IP overlap)
- **Optimized settings** based on environment needs
- **Account-specific credentials** via GitHub environment secrets

## Environment Configuration

### Development (dev)

**Purpose**: Development and testing
**AWS Account**: Separate development account
**State Key**: `platform/dev/terraform.tfstate`
**VPC CIDR**: `10.0.0.0/16`
**Cluster Name**: `workshop-eks-dev`

**Characteristics**:
- ✅ Single NAT Gateway (cost optimization)
- ✅ Reduced logging (3-day retention)
- ✅ Minimal control plane logging
- ✅ Ideal for rapid iteration and testing

**Config File**: [environments/dev.tfvars](environments/dev.tfvars)

### Staging (stg)

**Purpose**: Pre-production validation
**AWS Account**: Separate staging account
**State Key**: `platform/stg/terraform.tfstate`
**VPC CIDR**: `10.10.0.0/16`
**Cluster Name**: `workshop-eks-stg`

**Characteristics**:
- ✅ Single NAT Gateway (cost optimization)
- ✅ Moderate logging (7-day retention)
- ✅ Most control plane logs enabled
- ✅ Mirrors production for testing

**Config File**: [environments/stg.tfvars](environments/stg.tfvars)

### Production (prd)

**Purpose**: Production workloads
**AWS Account**: Separate production account (highly recommended)
**State Key**: `platform/prd/terraform.tfstate`
**VPC CIDR**: `10.20.0.0/16`
**Cluster Name**: `workshop-eks-prd`

**Characteristics**:
- ✅ Multiple NAT Gateways (high availability)
- ✅ Full logging (30-day retention)
- ✅ All control plane logs enabled
- ✅ Production-grade configuration

**Config File**: [environments/prd.tfvars](environments/prd.tfvars)

## Environment Comparison

| Feature | Dev | Stg | Prd |
|---------|-----|-----|-----|
| **AWS Account** | Separate | Separate | Separate |
| **VPC CIDR** | 10.0.0.0/16 | 10.10.0.0/16 | 10.20.0.0/16 |
| **NAT Gateways** | 1 | 1 | 3 |
| **Log Retention** | 3 days | 7 days | 30 days |
| **Control Plane Logs** | Minimal | Moderate | Full |
| **Monthly Cost** | ~$155 | ~$160 | ~$260 |
| **Approval Required** | No | Optional | Yes |
| **Account Isolation** | ✅ Yes | ✅ Yes | ✅ Yes |

## CI/CD Pipeline Flow

### Pull Request (Matrix Plan)

When a PR is created, Terraform plans run **in parallel** for all environments:

```
Pull Request Created
        ↓
┌───────┴───────┐
│   Matrix Job  │
├───────────────┤
│ • Plan Dev    │ ← Runs in parallel
│ • Plan Stg    │ ← Runs in parallel
│ • Plan Prd    │ ← Runs in parallel
└───────┬───────┘
        ↓
   PR Comments
(3 separate plan outputs)
```

**Workflow**: [.github/workflows/terraform-plan.yml](../.github/workflows/terraform-plan.yml)

### Merge to Main (Sequential Apply)

When merged to main, deployments run **sequentially**:

```
Merge to Main
      ↓
 Deploy Dev
      ↓
   Success?
      ↓ Yes
 Deploy Stg
      ↓
   Success?
      ↓ Yes
 Deploy Prd
      ↓
    Done!
```

**Workflow**: [.github/workflows/terraform-apply.yml](../.github/workflows/terraform-apply.yml)

**Benefits**:
- Early failure detection (dev fails = no stg/prd deployment)
- Progressive rollout (test in dev before production)
- Easy rollback (only one environment affected at a time)

## Local Development

### Planning for a Specific Environment

```bash
cd platform

# Initialize with environment-specific state
terraform init -backend-config="key=platform/dev/terraform.tfstate"

# Plan for dev
terraform plan -var-file="environments/dev.tfvars"

# Plan for staging
terraform init -backend-config="key=platform/stg/terraform.tfstate" -reconfigure
terraform plan -var-file="environments/stg.tfvars"

# Plan for production
terraform init -backend-config="key=platform/prd/terraform.tfstate" -reconfigure
terraform plan -var-file="environments/prd.tfvars"
```

### Applying Changes Locally

```bash
# Apply to dev (safe for testing)
terraform init -backend-config="key=platform/dev/terraform.tfstate"
terraform apply -var-file="environments/dev.tfvars"

# Apply to staging (use with caution)
terraform init -backend-config="key=platform/stg/terraform.tfstate" -reconfigure
terraform apply -var-file="environments/stg.tfvars"

# Apply to production (only via CI/CD recommended)
# Manual production deploys should be avoided
```

## State Management

### State Files Location

Each AWS account has its own state bucket:

```
Development Account (111111111111):
  s3://dev-terraform-state-bucket/
  └── platform/dev/terraform.tfstate

Staging Account (222222222222):
  s3://stg-terraform-state-bucket/
  └── platform/stg/terraform.tfstate

Production Account (333333333333):
  s3://prd-terraform-state-bucket/
  └── platform/prd/terraform.tfstate
```

**Note**: The state bucket is always in the same AWS account as the infrastructure it manages. You must run the `terraform_init` bootstrap in each account to create the state bucket and DynamoDB table.

### State Isolation

Each environment has:
- **Separate AWS account** (complete account-level isolation)
- **State bucket in the same account** as the infrastructure
- **Separate state file** per environment (no shared state)
- **Independent resources** (dev won't affect prod)
- **DynamoDB locking** per state file (concurrent protection)

**State Bucket Location**: Each AWS account should have its own S3 bucket and DynamoDB table for Terraform state management. The state bucket is always in the same account as the infrastructure it manages.

### Viewing State

```bash
# Dev state
terraform init -backend-config="key=platform/dev/terraform.tfstate"
terraform state list

# Staging state
terraform init -backend-config="key=platform/stg/terraform.tfstate" -reconfigure
terraform state list

# Production state
terraform init -backend-config="key=platform/prd/terraform.tfstate" -reconfigure
terraform state list
```

## Adding a New Environment

To add a new environment (e.g., `test`):

1. **Create AWS Account** (recommended):
   - Create a new AWS account for the environment
   - Deploy `terraform_init` in the new account to create state bucket and DynamoDB table
   - Set up IAM user with Terraform permissions
   - Configure AWS credentials for CI/CD

2. **Create tfvars file**:
   ```bash
   cp platform/environments/dev.tfvars platform/environments/test.tfvars
   # Edit test.tfvars with new values
   ```

3. **Update workflows**:
   - Add `test` to matrix in `terraform-plan.yml`
   - Add new job `deploy-test` in `terraform-apply.yml`

4. **Create GitHub environment**:
   - Go to Settings → Environments
   - Create new environment `test`
   - Add AWS credentials for the new account:
     - `AWS_ACCESS_KEY_ID`
     - `AWS_SECRET_ACCESS_KEY`
   - Configure protection rules

5. **Use unique CIDR**:
   - Ensure VPC CIDR doesn't overlap
   - Example: `10.30.0.0/16`

## Environment Variables

Each environment can override any variable defined in [variables.tf](variables.tf):

Common overrides:
- `cluster_name` - Unique cluster name per environment
- `vpc_cidr` - Non-overlapping CIDR ranges
- `environment` - Environment identifier (dev/stg/prd)
- `single_nat_gateway` - Cost vs HA trade-off
- `cluster_log_retention_days` - Compliance requirements
- `fargate_namespaces` - Environment-specific namespaces

## Cost Optimization Tips

### Development
- Use single NAT gateway
- Reduce log retention to 1-3 days
- Minimal control plane logging
- Consider smaller subnet sizes

### Staging
- Mirror production configuration
- Balance between cost and testing accuracy
- 7-day log retention is usually sufficient

### Production
- Multiple NAT gateways for HA
- 30+ day log retention for compliance
- Full control plane logging for troubleshooting
- Consider Reserved Instances for steady-state workloads

## Troubleshooting

### State File Locked

**Symptom**: Error acquiring state lock

**Solution**:
```bash
# Check DynamoDB for locks
aws dynamodb scan --table-name terraform-state-locks

# Force unlock (use with extreme caution)
terraform force-unlock <lock-id>
```

### Wrong State File

**Symptom**: Terraform shows unexpected resources

**Solution**:
```bash
# Verify backend configuration
terraform init -backend-config="key=platform/<env>/terraform.tfstate" -reconfigure

# Show current backend
terraform show
```

### Environment Drift

**Symptom**: Manual changes in AWS console not reflected in state

**Solution**:
```bash
# Refresh state from AWS
terraform refresh -var-file="environments/<env>.tfvars"

# Or import specific resources
terraform import aws_eks_cluster.main <cluster-name>
```

## Best Practices

### ✅ Do's

- ✅ **Use separate AWS accounts** for each environment
- ✅ Test in dev before promoting to staging/production
- ✅ Use CI/CD for all production deployments
- ✅ Keep environment configs in version control
- ✅ Review all PR plans before merging
- ✅ Use unique VPC CIDRs per environment
- ✅ Apply least privilege for IAM roles
- ✅ Tag all resources with environment identifier
- ✅ Configure different AWS credentials per GitHub environment

### ❌ Don'ts

- ❌ **Don't share AWS accounts** between environments
- ❌ Don't share state files between environments
- ❌ Don't use overlapping VPC CIDRs
- ❌ Don't manually modify production infrastructure
- ❌ Don't skip dev/staging when testing changes
- ❌ Don't commit sensitive values in tfvars files
- ❌ Don't force-unlock state without investigation
- ❌ Don't delete state files manually
- ❌ Don't use production credentials in dev/staging

## Security Considerations

### Multi-Account Security

- ✅ **Separate AWS accounts** provide the strongest security boundary
- ✅ **Account-level isolation** prevents cross-environment access
- ✅ **Different IAM policies** per account for least privilege
- ✅ **Blast radius limitation** - compromised dev doesn't affect prod
- ✅ **Compliance-ready** - meets regulatory requirements for separation

### Secrets Management

- ✅ Use AWS Secrets Manager or Parameter Store
- ✅ Store GitHub environment secrets separately per environment
- ✅ Rotate IAM credentials regularly
- ✅ Never commit credentials to git
- ✅ Use different credentials for each AWS account

### Access Control

- ✅ **Environment-specific credentials** via GitHub environments
- ✅ Separate IAM users/roles per AWS account
- ✅ Use GitHub environment protection rules
- ✅ Require approvals for production deployments
- ✅ Audit all production changes
- ✅ Different teams can have different account access

### Network Security

- ✅ Private subnets for Fargate pods
- ✅ Security groups restrict access
- ✅ VPC Flow Logs for network monitoring (future enhancement)
- ✅ Non-overlapping CIDRs enable VPC peering if needed
- ✅ No network connectivity between accounts by default

## Monitoring

### CloudWatch Dashboards

Create environment-specific dashboards:

```bash
aws cloudwatch put-dashboard \
  --dashboard-name workshop-eks-dev \
  --dashboard-body file://dashboard-dev.json
```

### Alarms

Set up environment-appropriate alarms:

- **Dev**: Basic health checks
- **Stg**: Production-like monitoring
- **Prd**: Comprehensive alerting

## Support

For questions or issues:
1. Check environment-specific logs in CloudWatch
2. Review Terraform state for drift
3. Consult [CI_CD_SETUP.md](../.github/CI_CD_SETUP.md) for pipeline issues
4. Check AWS console for resource status
