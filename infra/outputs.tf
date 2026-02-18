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

output "postgres_private_ip" {
  description = "Private IP of the PostgreSQL EC2 instance"
  value       = aws_instance.postgres.private_ip
}

output "postgres_instance_id" {
  description = "Instance ID of the PostgreSQL server"
  value       = aws_instance.postgres.id
}

output "postgres_database_name" {
  description = "Database name"
  value       = var.db_name
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

output "postgres_private_key" {
  description = "Private key for SSH to PostgreSQL instance"
  value       = tls_private_key.postgres_key.private_key_pem
  sensitive   = true
}

# Summary
output "deployment_summary" {
  description = "Deployment summary"
  value = {
    alb_url              = "http://$${aws_lb.main_alb.dns_name}"
    ms_users_url         = "http://$${aws_lb.main_alb.dns_name}/api/users"
    ms_orders_url        = "http://$${aws_lb.main_alb.dns_name}/api/orders"
    ms_notifications_url = "http://$${aws_lb.main_alb.dns_name}/api/notifications"
    database_private_ip  = aws_instance.postgres.private_ip
    database_name        = var.db_name
  }
}
