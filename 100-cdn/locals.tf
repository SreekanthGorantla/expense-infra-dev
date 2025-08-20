locals {
  https_certificate_arn = data.aws_ssm_parameter.https_certificate_arn.value
}