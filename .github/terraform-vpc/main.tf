
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

# resource "alicloud_resource_manager_folder" "test" {
#   folder_name = "testb"
# }
