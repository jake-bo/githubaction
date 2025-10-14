terraform {
  required_providers {
    alicloud = {
      source = "aliyun/alicloud"
      ersion = "~> 1.227.1"
    }
  }
}

provider "alicloud" {
  region = var.region
}

resource "alicloud_vpc" "main" {
  vpc_name    = var.vpc_name
  cidr_block  = var.vpc_cidr
  description = var.vpc_description
}

# 输出信息
output "vpc_id" {
  value = alicloud_vpc.main.id
}

output "vpc_name" {
  value = alicloud_vpc.main.vpc_name
}

output "cidr_block" {
  value = alicloud_vpc.main.cidr_block
}
