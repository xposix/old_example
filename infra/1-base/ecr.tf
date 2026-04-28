###############################################################################
## Client app ECR repository

resource "aws_ecr_repository" "client_app" {
  # TODO: Remove these references when moving to CLZ
  count               = var.environment_name == "prod" ? 1 : 0
  name                 = "client-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = data.aws_kms_key.clz_kms_key.arn
  }
  tags = local.project_tags
}

resource "aws_ssm_parameter" "client_app" {
  count               = var.environment_name == "prod" ? 1 : 0
  name  = "/${var.environment_name}/ecr/client_app/repository_url"
  type  = "String"
  value = aws_ecr_repository.client_app[0].repository_url

  tags = local.project_tags
}

resource "aws_ecr_repository_policy" "client_app" {
  count      = var.environment_name == "prod" ? 1 : 0
  repository = aws_ecr_repository.client_app[0].name
  policy     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Private_push",
      "Action": [
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Effect": "Allow",
      "Principal": "*"
    }
  ]
}
EOF
}

resource "aws_ecr_lifecycle_policy" "client_app" {
  count      = var.environment_name == "prod" ? 1 : 0
  repository = aws_ecr_repository.client_app[0].name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 14
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

###############################################################################
## Celery ECR repository

resource "aws_ecr_repository" "celery" {
  count      = var.environment_name == "prod" ? 1 : 0
  name                 = "celery"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = data.aws_kms_key.clz_kms_key.arn
  }
  tags = local.project_tags
}

data "aws_ecr_repository" "celery" {
  count = var.environment_name == "prod" ? 0 : 1
  name  = "celery"
}

resource "aws_ssm_parameter" "celery" {
  name  = "/${var.environment_name}/ecr/celery/repository_url"
  type  = "String"
  value = var.environment_name == "prod" ? aws_ecr_repository.celery[0].repository_url : data.aws_ecr_repository.celery[0].repository_url

  tags = local.project_tags
}

resource "aws_ecr_repository_policy" "celery" {
  count      = var.environment_name == "prod" ? 1 : 0
  repository = aws_ecr_repository.celery[0].name
  policy     = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Private_push",
      "Action": [
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:GetDownloadUrlForLayer",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ],
      "Effect": "Allow",
      "Principal": "*"
    }
  ]
}
EOF
}

resource "aws_ecr_lifecycle_policy" "celery" {
  count      = var.environment_name == "prod" ? 1 : 0
  repository = aws_ecr_repository.celery[0].name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 14 days",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 14
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}