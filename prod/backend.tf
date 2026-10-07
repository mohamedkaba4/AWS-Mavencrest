terraform {
  backend "s3" {
    bucket       = "mavencrest-terraform-state"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}