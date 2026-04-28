variable "primary_region" {
  description = "AWS region to deploy to"
  type        = string
}

variable "environment_name" {
  description = "Name of the environment to deploy to (e.g.: dev, staging, prod)"
  type        = string
}

variable "environment_type" {
  description = "Type of the environment to deploy to (e.g.: prod, dev, etc.)"
  type        = string
}

variable "common_tags" {
  description = "A map containing the tags to associate to all the resources"
  type        = map(any)
}

variable "destination_vpc" {
  description = "Name of the VPC that will be used for this deployment"
  type        = string
}

variable "destination_account_domain_name" {
  description = "Route53 domain name associated to this account"
  type        = string
}

variable "rds_instance_type" {
  description = "Instance type for the RDS cluster"
  type        = string
}

variable "rds_multi_az_enabled" {
  description = "Instance type for the RDS cluster"
  type        = bool
}

variable "rds_initial_allocated_storage_gib" {
  description = "The initial size of the volume at the time the DB is created the first time in gibibytes"
  type        = number
}

variable "rds_volume_size_max_threshold_gib" {
  description = "Maximum size of the volumes used in the RDS instances in gibibytes"
  type        = number
}

variable "rds_engine_version" {
  description = "PostgreSQL version to deploy"
  type        = number
}

variable "rds_snapshot_identifier" {
  description = "Snapshot to restore the RDS DB from"
  type        = string
  default     = ""
}

variable "rds_backup_retention_in_days" {
  description = "Number of days AWS will keep automatic backups"
  type        = number
}

variable "kubernetes_workers_type" {
  description = "Instance type for the Kubernetes workers"
  type        = string
}
