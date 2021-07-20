provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

variable "access_key" {}

variable "secret_key" {}

variable "region" {}

variable "project" {} 

variable "environment" {}

variable "vpc_id" {}

variable "vpc_sg_id" {}

locals {
  name   = "${var.project}-db"
  tags = {
    Environment = var.environment
  }
}

################################################################################
# Supporting Resources
################################################################################

data "aws_vpc" "db_vpc" {
    id = var.vpc_id
}

data "aws_subnet_ids" "db_subnets" {
  vpc_id = var.vpc_id
}

################################################################################
# RDS Module
################################################################################

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = local.name

  # All available versions: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts
  engine               = "postgres"
  engine_version       = "13.2"
  family               = "postgres13" # DB parameter group
  major_engine_version = "13"         # DB option group
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  name     = "aktion"
  username = "aktionapi"
  password = "aktionapi"
  port     = 5432

  multi_az               = false
  subnet_ids             = data.aws_subnet_ids.db_subnets.ids
  vpc_security_group_ids = [var.vpc_sg_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = true
  monitoring_interval                   = 60

  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    }
  ]

  tags = local.tags
  db_option_group_tags = {
    "Sensitive" = "low"
  }
  db_parameter_group_tags = {
    "Sensitive" = "low"
  }
  db_subnet_group_tags = {
    "Sensitive" = "high"
  }
}