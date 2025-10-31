include "root" {
  path = find_in_parent_folders("root.hcl")
}

# SLS module configuration
terraform {
  source = "../../../../../modules/alicloud-sls"
}


# Module input variables
inputs = {
  region     = read_terragrunt_config(find_in_parent_folders("terragrunt_region.hcl")).locals.region

  # SLS configuration
  create_project      = true
  project_name        = "accountvending-project"
  project_description = "Account Vending SLS Project"

  create_logstore     = true
  logstore_name       = "accountvending-logstore"
  retention_period    = 30
  shard_count         = 2
}
