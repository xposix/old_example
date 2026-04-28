########################################################################################
## Master user credentials for RDS instance
resource "aws_secretsmanager_secret" "general_rds_master_user" {
  # Using name_prefix instead of name, otherwise secret cannot be recreated and deployment fails
  # Storing it's name in a parameter in SSM
  name_prefix = "/${var.environment_name}/rds/database/properties"
  kms_key_id  = data.aws_kms_key.clz_kms_key.arn

  tags = local.project_tags
}

resource "random_password" "general_rds_master_user" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret_version" "general_rds_master_user" {
  secret_id     = aws_secretsmanager_secret.general_rds_master_user.id
  secret_string = <<EOF
{
  "username": "${aws_db_instance.general.username}",
  "password": "${random_password.general_rds_master_user.result}",
  "engine": "postgres",
  "host": "${aws_db_instance.general.address}",
  "port": ${aws_db_instance.general.port},
  "dbIdentifier": "${aws_db_instance.general.identifier}",
  "name": "${aws_db_instance.general.db_name}"
}
EOF
}

resource "aws_ssm_parameter" "general_rds_credentials_secret_arn" {
  name  = "/${var.environment_name}/secret/rds_database_credentials/arn"
  type  = "String"
  value = aws_secretsmanager_secret.general_rds_master_user.arn

  tags = local.project_tags
}

########################################################################################
## Master user credentials for Redis
resource "aws_ssm_parameter" "general_redis_master_user_name" {
  name  = "/${var.environment_name}/redis/database_credentials/name"
  type  = "String"
  value = "default"

  tags = local.project_tags
}

resource "aws_ssm_parameter" "general_redis_master_user_password" {
  name  = "/${var.environment_name}/redis/database_credentials/password"
  type  = "String"
  value = random_password.general_redis_master_user_password.result

  tags = local.project_tags
}