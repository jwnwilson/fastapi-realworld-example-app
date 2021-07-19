provider "aws" {
    access_key = var.access_key 
    secret_key = var.secret_key 
    region     = var.region
}


locals {
  name   = "${var.project}-bastion"
  tags = {
    Environment = var.environment
  }
}

data "aws_subnet_ids" "bastion_subnets" {
  vpc_id = var.vpc_id

  tags = {
    Name = "*public*"
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "bastion_admin" {
  key_name   = "bastion_admin"
  public_key = "REPLACE ME"
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 3"

  name        = local.name
  description = "Bastion security group"
  vpc_id      = var.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port         = 22
      to_port           = 22
      protocol          = "tcp"
      description       = "Inbound access allowed from internet"
      cidr_blocks       =  "0.0.0.0/0"
    },
  ]

  egress_with_cidr_blocks = [
    {
      from_port         = 0
      to_port           = 0
      protocol          = "tcp"
      description       = "Outbound acccess"
      cidr_blocks       = "0.0.0.0/0"
    },
  ]

  tags = local.tags
}

# create an instance
resource "aws_instance" "linux_instance" {
  ami             = data.aws_ami.ubuntu.id
  subnet_id       = sort(data.aws_subnet_ids.bastion_subnets.ids)[0]
  security_groups = concat(var.securityGroups, [module.security_group.security_group_id])
  key_name        = aws_key_pair.bastion_admin.key_name 
  instance_type   = var.instanceType 
  
  # Let's create and attach an ebs volume 
  # when we create the instance
  ebs_block_device {
    device_name = "/dev/xvdb"
    volume_type = "gp2"
    volume_size = 8 
  }
  # Name the instance
  tags = {
    Name = var.instanceName
  }
  # Name the volumes; will name all volumes included in the 
  # ami and the ebs block device from above with this instance.
  volume_tags = {
    Name = var.instanceName
  }
  # Copy in the bash script we want to execute.
  # The source is the location of the bash script
  # on the local linux box you are executing terraform
  # from.  The destination is on the new AWS instance.
  provisioner "file" {
    source      = "${path.module}/setup.sh"
    destination = "/tmp/setup.sh"
  }
  # Change permissions on bash script and execute from ec2-user.
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setup.sh",
      "sudo /tmp/setup.sh",
    ]
  }
  
  # Login to the ec2-user with the aws key.
  connection {
    type        = "ssh"
    user        = "ubuntu"
    password    = ""
    private_key = file(var.keyPath)
    host        = self.public_ip
  }
}