variable "project_name" {
  default = "expense"
}

variable "environment" {
  default = "dev"
}

variable "domain_name" {
  default = "sreeaws.space"
}

variable "zone_id" {
  default = "Z01906078RFKD2Q1AJO6"
}

variable "common_tags" {
  default = {
    Project     = "expense"
    Environment = "dev"
    Terraform   = "true"
  }
}