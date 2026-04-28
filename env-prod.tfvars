# General configuration
destination_vpc                 = "prod-vpc1"
destination_account_domain_name = "exampleco.invalid"


# RDS configuration
rds_engine_version                = "16.1"
rds_instance_type                 = "db.t4g.micro"
rds_multi_az_enabled              = true
rds_backup_retention_in_days      = 7
rds_initial_allocated_storage_gib = 20
rds_volume_size_max_threshold_gib = 50
rds_snapshot_identifier           = "" # For disaster recovery purposes in case you ever need to restore from a snapshot. Leave blank if you don't need this.

kubernetes_workers_type  = "t4g.medium"

arango_db_k8s_operator_version = "1.2.35"
