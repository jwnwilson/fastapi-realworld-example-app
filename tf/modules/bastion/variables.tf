variable "access_key" {}

variable "secret_key" {}

variable "region" {
   default = "eu-west-1"
}

variable "project" {} 

variable "environment" {} 

variable "availabilityZone" {
   default = "eu-west-1a"
}

variable "instanceType" {
   default = "t2.micro"
}

variable "keyPath" {
   default = "~/.ssh/id_rsa"
}

variable "vpc_id" {}

variable "securityGroups" {
   type = list
}
variable "instanceName" {
   default = "aktion-bastion"
}