variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "assets_domain" {
  type = string
}

variable "acm_certificate_arn" {
  type = string
}
