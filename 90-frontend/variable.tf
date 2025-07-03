variable "project_name" {
  default = "expense"
}

variable "environment" {
  default = "dev"
}

variable "domain_name" {
  default = "sreeaws.space"
}

variable "common_tags" {
  default = {
    Project     = "expense"
    Environment = "dev"
    Terraform   = "true"
  }
}