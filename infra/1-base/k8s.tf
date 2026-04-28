data "aws_ssm_parameter" "cluster_name" {
  name  = "/${var.environment_name}/eks_cluster/general/name"
}

locals {
  cluster_name = data.aws_ssm_parameter.cluster_name.insecure_value
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name                   = local.cluster_name
  cluster_version                = "1.29"
  cluster_endpoint_public_access = true

  # External encryption key
  create_kms_key = false
  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = data.aws_kms_key.clz_kms_key.arn
  }

  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.aws_ebs_csi_irsa_role.iam_role_arn
    }
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      # configuration_values = jsonencode({ # This is not supported for small instance types.
      #   "env" = {
      #     "ENABLE_PREFIX_DELEGATION"          = "true"
      #     "ENABLE_POD_ENI"                    = "true"
      #     "POD_SECURITY_GROUP_ENFORCING_MODE" = "standard"
      #   }
      # })
    }
    kube-proxy = {
      most_recent = true
    }
    eks-pod-identity-agent = { # TODO: It may need extra IAM permissions
      most_recent = true
    }
  }

  vpc_id                   = data.aws_vpc.selected.id
  subnet_ids               = data.aws_subnets.private.ids
  control_plane_subnet_ids = data.aws_subnets.db.ids

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      self        = true
    }
  }
  
  create_cluster_primary_security_group_tags = false # https://gitlab.com/kubernetes-sigs/aws-load-balancer-controller/issues/1897

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_ARM_64"
    instance_types = [var.kubernetes_workers_type]
    vpc_security_group_ids                = [aws_security_group.additional.id]
  }

  eks_managed_node_groups = {

    "eks-workers-${var.environment_name}" = {
      # Initial node group, from here Karpenter will scale up/down
      min_size     = 1
      max_size     = 3
      desired_size = 2

      update_config = {
        max_unavailable_percentage = 33 # or set `max_unavailable`
      }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            # iops                  = 3000
            # throughput            = 150
            delete_on_termination = true
          }
        }
      }
      tags = merge(local.project_tags, {
        "karpenter.sh/discovery" = local.cluster_name
      })
      labels = {
        intent = "control-apps"
      }
    }
  }

  # aws-auth configmap
  manage_aws_auth_configmap = true

  aws_auth_roles = [ 
    {
      rolearn  = module.eks_blueprints_addons.karpenter.node_iam_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups = [
        "system:bootstrappers",
        "system:nodes",
      ]
    },
    { # TODO: pointing to users for now but should be roles
      rolearn  = data.aws_iam_user.cicd_user.arn
      username = "cicd_user"
      groups   = ["system:masters"]
    },
    {
      rolearn  = data.aws_iam_user.ruben.arn
      username = "ruben"
      groups   = ["system:masters"]
    },
  ]

  tags = merge(local.project_tags, {
    "karpenter.sh/discovery" = local.cluster_name
  })
}

##########################################################################################
## IAM Users to add to K8s users above
data "aws_iam_user" "ruben" {
  user_name = "ruben"
}

data "aws_iam_user" "cicd_user" {
  user_name = "gitlab-ci-pipelines"
}

##########################################################################################
## EBS CSI Driver Permissions & GP3 Storage Class support

module "aws_ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.32.1"

  role_name_prefix      = "${var.environment_name}-aws-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    sts = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role_policy" "ebs_csi_driver_kms_policy" {
  name_prefix = "ebs-csi-driver-kms-policy"
  role        = module.aws_ebs_csi_irsa_role.iam_role_name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant"
      ],
      "Resource": ["${data.aws_kms_key.clz_kms_key.arn}"],
      "Condition": {
        "Bool": {
          "kms:GrantIsForAWSResource": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey"
      ],
      "Resource": ["${data.aws_kms_key.clz_kms_key.arn}"]
    }
  ]
}
EOF
}

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
  }

  storage_provisioner    = "ebs.csi.aws.com"
  allow_volume_expansion = true
  volume_binding_mode    = "WaitForFirstConsumer"

  parameters = {
    type = "gp3"
  }
}

##########################################################################################
## Rest of the addons

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.15.1"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  create_delay_dependencies = [for prof in module.eks.eks_managed_node_groups : prof.node_group_arn]

  enable_aws_load_balancer_controller = true
  enable_aws_efs_csi_driver      = false
  enable_aws_cloudwatch_metrics  = true
  enable_aws_for_fluentbit       = false
  enable_karpenter               = true
  karpenter = {
    chart_version = "v0.34.1"
  }
  karpenter_node = {
    iam_role_use_name_prefix = false
  }
  enable_external_dns            = true
  enable_cert_manager            = false
  enable_external_secrets        = true
  external_dns_route53_zone_arns = [data.aws_route53_zone.destination_account_domain_name.arn]
  external_secrets_kms_key_arns  = [data.aws_kms_key.clz_kms_key.arn]
  cert_manager_route53_hosted_zone_arns = [data.aws_route53_zone.destination_account_domain_name.arn]

  enable_metrics_server = true

  tags = local.project_tags
}

resource "aws_security_group" "additional" {
  name_prefix = "${local.cluster_name}-additional"
  vpc_id      = data.aws_vpc.selected.id

  tags = merge(local.project_tags, {
    "karpenter.sh/discovery" = local.cluster_name
  })
}

resource "aws_security_group_rule" "eks_hosts_ingress" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.additional.id
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "eks_hosts_egress" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
  security_group_id        = aws_security_group.additional.id
}

data "aws_ssm_parameter" "vpce_sg_id" {
  name = "/clz/vpc/${var.destination_vpc}/private_endpoint_sg_id"
}

resource "aws_security_group_rule" "eks_hosts_to_vpce_ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.additional.id
  security_group_id        = data.aws_ssm_parameter.vpce_sg_id.insecure_value
}

resource "aws_security_group_rule" "eks_hosts_to_vpce_egress" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = data.aws_ssm_parameter.vpce_sg_id.insecure_value
  security_group_id        = aws_security_group.additional.id
}

##########################################################################################
## Karpenter configuration

# Karpenter default EC2NodeClass and NodePool

resource "kubectl_manifest" "karpenter_default_ec2_node_class" {
  yaml_body = <<YAML
apiVersion: karpenter.k8s.aws/v1beta1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: "${module.eks_blueprints_addons.karpenter.node_iam_role_name}"
  amiFamily: AL2
  limits:
    cpu: 20 # TOSCALE: 100
    memory: 48 # TOSCALE: 200Gi
  securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${local.cluster_name}
  subnetSelectorTerms:
  - tags:
      karpenter.sh/discovery: ${local.cluster_name}
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 100Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true
  tags:
    Name: eks-application-scalable-${var.environment_name}
    IntentLabel: apps
    KarpenterNodePoolName: default
    NodeType: default
    intent: apps
    karpenter.sh/discovery: ${local.cluster_name}
    project: karpenter-blueprints
YAML
  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
  ]
  force_new = false # Set this to true if you want to recreate the resource
}

resource "kubectl_manifest" "karpenter_default_node_pool" {
  yaml_body = <<YAML
apiVersion: karpenter.sh/v1beta1
kind: NodePool
metadata:
  name: default 
spec:  
  template:
    metadata:
      labels:
        intent: apps
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: "karpenter.k8s.aws/instance-cpu"
          operator: Gt
          values: ["1"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-family
          operator: In
          values: ["m6a"]
      nodeClassRef:
        name: default
      kubelet:
        containerRuntime: containerd
        systemReserved:
          cpu: 100m
          memory: 100Mi
  disruption:
    consolidationPolicy: WhenUnderutilized
    
YAML
  depends_on = [
    module.eks.cluster,
    module.eks_blueprints_addons.karpenter,
    kubectl_manifest.karpenter_default_node_pool,
  ]
  force_new = false # Set this to true if you want to recreate the resource
}
