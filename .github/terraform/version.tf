terraform {
  required_version = ">= 1.0"

  required_providers {
    alicloud = {
      source  = "aliyun/alicloud"
      version = "> 1.259.0"
    }
  }
}

provider "alicloud" {
  region     = "cn-shanghai"
  access_key = var.alicloud_access_key
  secret_key = var.alicloud_secret_key

  assume_role {
    role_arn           = var.alicloud_role_arn
    session_name       = "accountvending"
    session_expiration = 3600
  }
}
