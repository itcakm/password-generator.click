terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "password-generator-click-tfstate"
    key          = "password-generator.click/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}

# Primary provider — eu-central-1 for S3, Route 53 data, etc.
provider "aws" {
  region = "eu-central-1"
}

# ACM certificates for CloudFront MUST be in us-east-1 (AWS hard requirement)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
