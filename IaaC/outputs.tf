output "frontend_url" {
  value = aws_lb.frontend_alb.dns_name
}
