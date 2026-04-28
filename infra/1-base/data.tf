data "aws_region" "current" {}
data "aws_vpc" "selected" {
  tags = {
    Name = var.destination_vpc
  }
}

data "aws_subnets" "db" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*-db-*"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }


  filter {
    name   = "tag:Name"
    values = ["*-private-*"]
  }
}

data "aws_ssm_parameter" "rds_access_from_intranet_sg_id" {
  # TODO: Undo this when CLZ is present
  name = var.environment_name == "dev" ? "/clz/sg/bastion_general_dev/id" : "/clz/sg/bastion_general/id"
}

data "aws_ssm_parameter" "clz_kms_id" {
  name = "/clz/kms/account_general/id"
}

data "aws_kms_key" "clz_kms_key" {
  key_id = data.aws_ssm_parameter.clz_kms_id.value
}

data "aws_route53_zone" "destination_account_domain_name" {
  name = var.destination_account_domain_name
}


data "aws_secretsmanager_secret" "client_app_configuration" {
  name = "/${var.environment_name}/3rd_party/client_app/configuration"
}

data "aws_secretsmanager_secret_version" "client_app_configuration" {
  secret_id = data.aws_secretsmanager_secret.client_app_configuration.id
}
