####################################################################################################
## Public certificates for the client-app
## 

data "aws_route53_zone" "zone" {
  name = var.destination_account_domain_name
}

module "acm_client_app" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 5.0"

  domain_name = "app.${var.destination_account_domain_name}"
  zone_id     = data.aws_route53_zone.zone.zone_id

  validation_method = "DNS"

  wait_for_validation = true

  tags = local.project_tags
}

resource "aws_ssm_parameter" "acm_client_app_arn" {
  name  = "/${var.environment_name}/acm/client_app/cert_arn"
  type  = "String"
  value = module.acm_client_app.acm_certificate_arn
}

resource "aws_ssm_parameter" "ca_cert_primary_domain_name" {
  name  = "/${var.environment_name}/route53/client_app/primary_domain_name"
  type  = "String"
  value = module.acm_client_app.distinct_domain_names[0]
}