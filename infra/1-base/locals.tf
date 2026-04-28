locals {


  project_tags = merge(
    {
      Environment = var.environment_name
    },
    var.common_tags
  )
}
