resource "aws_iam_role" "rds_monitoring" {
  name = "${var.environment_name}-${var.primary_region}-rds-monitoring-role"
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "monitoring.rds.amazonaws.com"
          }
          Sid = "Terraform3"
        }
      ]
      Version = "2012-10-17"
    }
  )
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]

  tags = local.project_tags
}

resource "aws_db_parameter_group" "general" {
  name   = replace("${var.environment_name}-data-model-general-${var.rds_engine_version}", ".", "-")
  family = "postgres${split(".", var.rds_engine_version)[0]}"

  parameter {
    apply_method = "pending-reboot"
    name         = "rds.force_ssl"
    value        = "1"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.project_tags
}

resource "aws_db_subnet_group" "general" {
  name       = "${var.environment_name}-database"
  subnet_ids = data.aws_subnets.db.ids

  tags = local.project_tags
}

resource "random_string" "final_snapshot_identifier" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_db_instance" "general" {
  identifier            = "${var.environment_name}-database"
  instance_class        = var.rds_instance_type
  port                  = 5432
  allocated_storage     = var.rds_initial_allocated_storage_gib
  max_allocated_storage = var.rds_volume_size_max_threshold_gib

  db_subnet_group_name = aws_db_subnet_group.general.id
  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]
  deletion_protection = false
  enabled_cloudwatch_logs_exports = [
    "postgresql",
    "upgrade"
  ]

  engine                              = "postgres"
  engine_version                      = var.rds_engine_version
  iam_database_authentication_enabled = false
  kms_key_id                          = data.aws_kms_key.clz_kms_key.arn
  storage_encrypted                   = true
  storage_type                        = "gp3"

  maintenance_window = "mon:07:00-mon:09:30"

  monitoring_interval = 60 # in seconds
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  multi_az            = var.rds_multi_az_enabled

  parameter_group_name                  = aws_db_parameter_group.general.name
  performance_insights_enabled          = true
  performance_insights_kms_key_id       = data.aws_kms_key.clz_kms_key.arn
  performance_insights_retention_period = 7

  # skip_final_snapshot       = var.environment_type == "nonlive" ? true : false
  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.environment_name}-database-final-snapshot-${random_string.final_snapshot_identifier.result}"
  backup_retention_period   = var.rds_backup_retention_in_days
  backup_window             = "04:00-05:00"
  copy_tags_to_snapshot     = true
  snapshot_identifier       = var.rds_snapshot_identifier

  username = "postgres"
  password = random_password.general_rds_master_user.result
  db_name  = "main"

  tags = local.project_tags

  lifecycle {
    ignore_changes = [
      allocated_storage
    ]
  }
}

################################################################################
# RDS-related Security Groups

resource "aws_security_group" "rds" {
  name        = "${var.environment_name}_allow_rds_access"
  description = "RDS instance security group"
  vpc_id      = data.aws_vpc.selected.id

  lifecycle {
    create_before_destroy = true
  }

  tags = local.project_tags
}

data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.${data.aws_region.current.name}.s3"
}

resource "aws_security_group_rule" "rds_access_to_https_outbound" { # For dumps to S3 (just in case)
  description = "RDS access to S3 / HTTPS outbound"
  type        = "egress"

  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.rds.id
  prefix_list_ids   = [data.aws_ec2_managed_prefix_list.s3.id]
}

resource "aws_security_group_rule" "bastion_to_rds_access_outbound" {
  description = "Bastion to RDS access inbound"
  type        = "egress"

  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = data.aws_ssm_parameter.rds_access_from_intranet_sg_id.value
  source_security_group_id = aws_security_group.rds.id
}



resource "aws_security_group_rule" "bastion_to_rds_access_inbound" {
  description = "Bastion to RDS access inbound"
  type        = "ingress"

  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = data.aws_ssm_parameter.rds_access_from_intranet_sg_id.value
}





