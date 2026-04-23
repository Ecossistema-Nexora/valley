variable "aws_region" { type = string }
variable "project_name" { type = string }
variable "environment" { type = string  default = "prod" }
variable "vpc_cidr" { type = string  default = "10.40.0.0/16" }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }
variable "database_subnets" { type = list(string) }
variable "eks_instance_types" { type = list(string) default = ["t3.large"] }
variable "db_instance_class" { type = string default = "db.t4g.medium" }
variable "db_allocated_storage" { type = number default = 100 }
variable "db_username" { type = string }
variable "db_password" { type = string sensitive = true }
variable "route53_zone_name" { type = string }
variable "enable_nat_gateway" { type = bool default = true }
variable "redis_node_type" { type = string default = "cache.t4g.small" }
variable "redis_engine_version" { type = string default = "7.1" }
