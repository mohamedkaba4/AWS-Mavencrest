terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                   = var.aws_region
  shared_credentials_files = ["./.awscreds/creds"]

  default_tags {
    tags = {
      Project     = "mavencrest-store"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Mo"
      Repository  = "aws-mavencrest"
    }
  }
}

# Network Layer Discovery
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name = "availability-zone"
    values = [
      "us-east-1a",
      "us-east-1b",
      "us-east-1c",
      "us-east-1d",
      "us-east-1f"
    ]
  }
}