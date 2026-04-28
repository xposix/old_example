terraform {
  backend "s3" {
    region         = "eu-west-2"
    dynamodb_table = "tfstate_locks_local_projects"
    encrypt        = true
  }
}
