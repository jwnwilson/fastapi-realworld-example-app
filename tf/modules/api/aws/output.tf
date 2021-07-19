output "target_alb_arn" {
  value = aws_alb.application_load_balancer.arn
}

output "target_listener_arn" {
  value = aws_lb_listener.listener_https.arn
}
