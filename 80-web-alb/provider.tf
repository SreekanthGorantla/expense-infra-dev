terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "6.0.0-beta2"
    }
  }

  backend "s3" {
    bucket = "sreeaws-remote-state-dev"
    key    = "expense-dev-web-alb" # Should be unique
    region = "us-east-1"
    dynamodb_table = "sreeaws-remote-state-dev"
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
}