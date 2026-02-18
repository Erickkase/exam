# ============================================================
# OUTPUTS - INFRAESTRUCTURA MICROSERVICIOS
# ============================================================

output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = aws_lb.main_alb.dns_name
}

output "alb_url" {
  description = "URL del Application Load Balancer"
  value       = "http://${aws_lb.main_alb.dns_name}"
}

output "rds_endpoint" {
  description = "Endpoint de la base de datos PostgreSQL"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_database_name" {
  description = "Nombre de la base de datos"
  value       = aws_db_instance.postgres.db_name
}

# ms-users outputs
output "ms_users_asg_name" {
  description = "Nombre del Auto Scaling Group de ms-users"
  value       = aws_autoscaling_group.ms_users_asg.name
}

output "ms_users_target_group_arn" {
  description = "ARN del Target Group de ms-users"
  value       = aws_lb_target_group.ms_users_tg.arn
}

output "ms_users_endpoint" {
  description = "Endpoint de ms-users"
  value       = "http://${aws_lb.main_alb.dns_name}/api/users"
}

# ms-orders outputs
output "ms_orders_asg_name" {
  description = "Nombre del Auto Scaling Group de ms-orders"
  value       = aws_autoscaling_group.ms_orders_asg.name
}

output "ms_orders_target_group_arn" {
  description = "ARN del Target Group de ms-orders"
  value       = aws_lb_target_group.ms_orders_tg.arn
}

output "ms_orders_endpoint" {
  description = "Endpoint de ms-orders"
  value       = "http://${aws_lb.main_alb.dns_name}/api/orders"
}

# ms-notifications outputs
output "ms_notifications_asg_name" {
  description = "Nombre del Auto Scaling Group de ms-notifications"
  value       = aws_autoscaling_group.ms_notifications_asg.name
}

output "ms_notifications_target_group_arn" {
  description = "ARN del Target Group de ms-notifications"
  value       = aws_lb_target_group.ms_notifications_tg.arn
}

output "ms_notifications_endpoint" {
  description = "Endpoint de ms-notifications"
  value       = "http://${aws_lb.main_alb.dns_name}/api/notifications"
}

# SSH Keys (Private - para debugging)
output "ms_users_private_key" {
  description = "Private key para SSH a ms-users instances"
  value       = tls_private_key.ms_users_key.private_key_pem
  sensitive   = true
}

output "ms_orders_private_key" {
  description = "Private key para SSH a ms-orders instances"
  value       = tls_private_key.ms_orders_key.private_key_pem
  sensitive   = true
}

output "ms_notifications_private_key" {
  description = "Private key para SSH a ms-notifications instances"
  value       = tls_private_key.ms_notifications_key.private_key_pem
  sensitive   = true
}

# Summary
output "deployment_summary" {
  description = "Resumen del deployment"
  value = {
    alb_url              = "http://${aws_lb.main_alb.dns_name}"
    ms_users_url         = "http://${aws_lb.main_alb.dns_name}/api/users"
    ms_orders_url        = "http://${aws_lb.main_alb.dns_name}/api/orders"
    ms_notifications_url = "http://${aws_lb.main_alb.dns_name}/api/notifications"
    database_endpoint    = aws_db_instance.postgres.endpoint
    database_name        = aws_db_instance.postgres.db_name
  }
}
