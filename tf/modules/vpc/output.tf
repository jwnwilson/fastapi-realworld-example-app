output "vpc_arn" {
  value = module.vpc.vpc_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_sg_id" {
    value = module.security_group.security_group_id
}