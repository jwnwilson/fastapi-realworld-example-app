output "bastion_ip" {
  value = aws_instance.linux_instance.public_ip
}