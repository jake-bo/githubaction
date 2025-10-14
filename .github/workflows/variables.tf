variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "172.16.0.0/16"
}

variable "vpc_description" {
  description = "Description for the VPC"
  type        = string
  default     = "Created by GitHub Actions Terraform"
}

variable "region" {
  description = "Alibaba Cloud region"
  type        = string
  default     = "cn-beijing"
}
