include "root" {
  path = find_in_parent_folders("root.hcl")
}

# API Gateway module configuration
terraform {
  source = "../../../../modules/alicloud-apigateway"
}


locals {
  state_bucket_name = "automation-status"
  region = read_terragrunt_config(find_in_parent_folders("terragrunt_region.hcl")).locals.region
}

# Remote state configuration using OSS backend
remote_state {
  backend = "oss"
  config = {
     bucket              = local.state_bucket_name
     prefix              = "dev"
     key                 = "infra/apigateway/terraform.tfstate"
     acl                 = "private"
     region              = local.region
     encrypt             = "true"                                    
    
    # OTS locking configuration
    # tablestore_endpoint = "https://your-instance.cn-shanghai.ots.aliyuncs.com"
    # tablestore_table    = "terraform-state-lock"
  }
}

# Module input variables
inputs = {
__TERRAGRUNT_DYNAMIC_INPUTS__
}
