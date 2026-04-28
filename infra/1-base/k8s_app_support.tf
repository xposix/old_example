locals {
  namespace_name                      = "exampleco"
  k8s_client_app_service_account_name = "client-app-sa"
  k8s_worker_app_service_account_name = "worker-app-sa"
}

####################################################################################################
## Shared Services

# Create the namespace
resource "kubernetes_namespace" "exampleco" {
  metadata {
    name = local.namespace_name
  }
}

resource "aws_ssm_parameter" "app_namespace" {
  name  = "/${var.environment_name}/k8s_namespace/app/name"
  type  = "String"
  value = local.namespace_name

  tags = local.project_tags
}

# Redis
locals {
  redis_username="default"
}

resource "random_password" "general_redis_master_user_password" {
  length  = 16
  special = false
}

resource "kubernetes_secret" "redis_db_conf" {
  metadata {
    name      = "redis-credentials"
    namespace = local.namespace_name
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  data = {
    "REDIS_USERNAME"     = local.redis_username
    "REDIS_PASSWORD"     = random_password.general_redis_master_user_password.result
  }

  type = "Opaque"
  lifecycle {
    ignore_changes = [
      metadata["labels"]
    ]
  }
}

####################################################################################################
## Client APP Service

resource "kubernetes_secret" "client_app_db_conf" {
  metadata {
    name      = "client-app-configuration"
    namespace = local.namespace_name
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  data = {
    "DB_NAME"     = aws_db_instance.general.db_name
    "DB_USER"     = aws_db_instance.general.username
    "DB_PASSWORD" = aws_db_instance.general.password
    "DB_HOST"     = aws_db_instance.general.address
    "DB_PORT"     = aws_db_instance.general.port
  }

  type = "Opaque"
  lifecycle {
    ignore_changes = [
      metadata["labels"]
    ]
  }
}

module "client_app_iam_eks_role" {
  source     = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  depends_on = [module.eks]

  role_name = "${data.aws_region.current.name}-${var.environment_name}-client-app"

  cluster_service_accounts = {
    "${module.eks.cluster_name}" = ["${local.namespace_name}:${local.k8s_client_app_service_account_name}"]
  }
}

data "aws_iam_policy_document" "client_app_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.incoming_requests.arn]
  }
}

resource "aws_iam_policy" "client_app_policy" {
  name        = "${data.aws_region.current.name}-${var.environment_name}-client-app-pod-policy"
  description = "Proxy Server pod policy"
  policy      = data.aws_iam_policy_document.client_app_policy.json
}

resource "aws_iam_role_policy_attachment" "client_app_policy" {
  role       = module.client_app_iam_eks_role.iam_role_name
  policy_arn = aws_iam_policy.client_app_policy.arn
}

resource "aws_ssm_parameter" "client_app_iam_eks_role_arn" {
  name  = "/${var.environment_name}/iam/client_app_role/arn"
  type  = "String"
  value = module.client_app_iam_eks_role.iam_role_arn
}

output "client_app_iam_eks_role_arn" {
  value = module.client_app_iam_eks_role.iam_role_arn
}

# Create a security group with egress rules to the RDS instance
resource "aws_security_group" "client_app" {
  name_prefix = "${local.namespace_name}-client-app"
  vpc_id      = data.aws_vpc.selected.id

  egress {
    description = "Allow traffic to the RDS instance"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
      aws_security_group.rds.id
    ]
  }
  tags = local.project_tags
}

resource "aws_security_group_rule" "client_app_ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.client_app.id
  security_group_id        = aws_security_group.rds.id
}

####################################################################################################
## Worker Service

module "worker_app_iam_eks_role" {
  source     = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  depends_on = [module.eks]
  role_name = "${data.aws_region.current.name}-${var.environment_name}-worker-app"

  cluster_service_accounts = {
    "${module.eks.cluster_name}" = ["${local.namespace_name}:${local.k8s_worker_app_service_account_name}"]
  }
}

# IAM Permissions
data "aws_iam_policy_document" "worker_app_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.incoming_requests.arn]
  }
}

resource "aws_iam_policy" "worker_app_policy" {
  name        = "${data.aws_region.current.name}-${var.environment_name}-worker-app-pod-policy"
  description = "Proxy Server pod policy"
  policy      = data.aws_iam_policy_document.worker_app_policy.json
}

resource "aws_iam_role_policy_attachment" "worker_app_policy" {
  role       = module.worker_app_iam_eks_role.iam_role_name
  policy_arn = aws_iam_policy.worker_app_policy.arn
}

# Exporting data
resource "aws_ssm_parameter" "worker_app_iam_eks_role_arn" {
  name  = "/${var.environment_name}/iam/worker_app_role/arn"
  type  = "String"
  value = module.worker_app_iam_eks_role.iam_role_arn
}

# Network configuration
resource "aws_security_group" "worker_app" {
  name_prefix = "${local.namespace_name}-worker-app"
  vpc_id      = data.aws_vpc.selected.id

  egress {
    description = "Allow traffic to SQS instance"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.project_tags
}
