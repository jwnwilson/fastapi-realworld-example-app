
terraform {
  backend "s3" {
    region = "eu-west-1"
  }
}

module "vpc" {
  source          = "./modules/vpc"
  access_key      = var.aws_access_key
  secret_key      = var.aws_secret_key
  region          = var.aws_region
  project         = var.project
  environment     = var.environment
}

module "bastion" {
  source          = "./modules/bastion"
  access_key      = var.aws_access_key
  secret_key      = var.aws_secret_key
  region          = var.aws_region
  project         = var.project
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  securityGroups  = [module.vpc.vpc_sg_id]
}

module "db" {
  source          = "./modules/db/aws"
  access_key      = var.aws_access_key
  secret_key      = var.aws_secret_key
  region          = var.aws_region
  project         = var.project
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_sg_id       = module.vpc.vpc_sg_id
}

module "api" {
  source          = "./modules/api/aws"
  access_key      = var.aws_access_key
  secret_key      = var.aws_secret_key
  region          = var.aws_region
  project         = var.project
  environment     = var.environment
  image_ecr_repo  = module.docker_images.ecr_api_url
  api_cert_arn    = module.dns.api_cert_arn
  vpc_id          = module.vpc.vpc_id
  vpc_sg_id       = module.vpc.vpc_sg_id
}

module "dns" {
  source              = "./modules/dns/aws"
  access_key          = var.aws_access_key
  secret_key          = var.aws_secret_key
  region              = var.aws_region
  domain              = var.domain
  api_subdomain       = var.api_subdomain
  target_alb_arn      = module.api.target_alb_arn
  target_listener_arn = module.api.target_listener_arn
}

module "docker_images" {
  source = "./modules/images/aws"

  db_repo         = var.db_repo
  api_repo        = var.api_repo
  access_key      = var.aws_access_key
  secret_key      = var.aws_secret_key
  region          = var.aws_region
}