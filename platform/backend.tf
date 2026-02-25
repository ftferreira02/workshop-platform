terraform {
  backend "s3" {
    bucket         = "workshop-ua-terraform-state-bucket-ff2"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
