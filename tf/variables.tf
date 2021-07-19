/* general */
variable "node_count" {
  default = 2
}

variable "environment" {
  default = "develop"
}

variable "project" {
  default = "fast-api-template"
}

variable "domain" {
  default = "fast-api.link"
}

variable "api_subdomain" {
  default = "api"
}

/* aws dns */
variable "aws_access_key" {
  default = ""
}

variable "aws_secret_key" {
  default = ""
}

variable "aws_region" {
  default = "eu-west-1"
}

variable "api_repo" {
  description = "Name of container image repository"
  default     = "fast-api"
}

variable "db_repo" {
  description = "Name of container image repository"
  default     = "fast-api-db"
}