# ============================================================
# MICROSERVICIOS EXAMEN - INFRAESTRUCTURA AWS
# ============================================================
# 3 Microservicios: ms-users, ms-orders, ms-notifications
# Base de Datos: PostgreSQL RDS
# Cada microservicio: 2 instancias (min: 2, max: 3)
# Load Balancer compartido con Target Groups por servicio
# ============================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.AWS_REGION
}

# ============================================================
# SECURITY GROUPS
# ============================================================

# Security Group para ALB
resource "aws_security_group" "alb_sg" {
  name_prefix = "microservicios-alb-sg"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "microservicios-alb-sg"
  }
}

# Security Group para Microservicios
resource "aws_security_group" "microservices_sg" {
  name_prefix = "microservicios-ec2-sg"
  vpc_id      = var.vpc_id
  description = "Security group for microservices EC2 instances"

  ingress {
    from_port       = 8081
    to_port         = 8083
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow traffic from ALB on ports 8081-8083"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "microservicios-ec2-sg"
  }
}

# Security Group para RDS PostgreSQL
resource "aws_security_group" "rds_sg" {
  name_prefix = "microservicios-rds-sg"
  vpc_id      = var.vpc_id
  description = "Security group for PostgreSQL RDS"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.microservices_sg.id]
    description     = "PostgreSQL from microservices"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "microservicios-rds-sg"
  }
}

# ============================================================
# RDS POSTGRESQL DATABASE
# ============================================================

# DB Subnet Group
resource "aws_db_subnet_group" "postgres_subnet_group" {
  name       = "microservicios-db-subnet-group"
  subnet_ids = [var.subnet1, var.subnet2]

  tags = {
    Name = "microservicios-db-subnet-group"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "postgres" {
  identifier             = "microservicios-db"
  engine                 = "postgres"
  engine_version         = "17.6-R2"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.postgres17"
  db_subnet_group_name   = aws_db_subnet_group.postgres_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  multi_az               = false
  backup_retention_period = 7
  
  tags = {
    Name = "microservicios-postgres-db-test"
    Environment = "test"
  }
}

# ============================================================
# APPLICATION LOAD BALANCER
# ============================================================

resource "aws_lb" "main_alb" {
  name               = "microservicios-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [var.subnet1, var.subnet2]

  tags = {
    Name = "microservicios-alb"
  }
}

# ALB Listener HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Service not found"
      status_code  = "404"
    }
  }
}

# ============================================================
# TARGET GROUPS
# ============================================================

# Target Group - ms-users (port 8081)
resource "aws_lb_target_group" "ms_users_tg" {
  name_prefix = "msu-"
  port     = 8081
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  lifecycle {
    create_before_destroy = true
  }
  
  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8081"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "ms-users-target-group"
  }
}

# Target Group - ms-orders (port 8082)
resource "aws_lb_target_group" "ms_orders_tg" {
  name_prefix = "mso-"
  port     = 8082
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  lifecycle {
    create_before_destroy = true
  }
  
  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8082"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "ms-orders-target-group"
  }
}

# Target Group - ms-notifications (port 8083)
resource "aws_lb_target_group" "ms_notifications_tg" {
  name_prefix = "msn-"
  port     = 8083
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  
  lifecycle {
    create_before_destroy = true
  }
  
  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "8083"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "ms-notifications-target-group"
  }
}

# ============================================================
# ALB LISTENER RULES
# ============================================================

# Rule for ms-users: /api/users/*
resource "aws_lb_listener_rule" "ms_users_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ms_users_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/users*"]
    }
  }
}

# Rule for ms-orders: /api/orders/*
resource "aws_lb_listener_rule" "ms_orders_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 110

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ms_orders_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/orders*"]
    }
  }
}

# Rule for ms-notifications: /api/notifications/*
resource "aws_lb_listener_rule" "ms_notifications_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 120

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ms_notifications_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/notifications*"]
    }
  }
}

# ============================================================
# SSH KEY PAIRS
# ============================================================

resource "tls_private_key" "ms_users_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ms_users" {
  key_name   = "ms-users-key"
  public_key = tls_private_key.ms_users_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "tls_private_key" "ms_orders_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ms_orders" {
  key_name   = "ms-orders-key"
  public_key = tls_private_key.ms_orders_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

resource "tls_private_key" "ms_notifications_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ms_notifications" {
  key_name   = "ms-notifications-key"
  public_key = tls_private_key.ms_notifications_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

# ============================================================
# LAUNCH TEMPLATES
# ============================================================

# Launch Template - ms-users
resource "aws_launch_template" "ms_users_lt" {
  name_prefix   = "ms-users-lt-"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ms_users.key_name

  vpc_security_group_ids = [aws_security_group.microservices_sg.id]

  user_data = base64encode(templatefile("${path.module}/user-data-users.sh", {
    docker_image     = "${var.docker_hub_username}/ms-users:${var.image_tag}"
    db_url           = "jdbc:postgresql://${aws_db_instance.postgres.endpoint}/${var.db_name}?currentSchema=users_schema"
    db_username      = var.db_username
    db_password      = var.db_password
    db_name          = var.db_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ms-users-instance"
      Service = "users"
    }
  }
}

# Launch Template - ms-orders
resource "aws_launch_template" "ms_orders_lt" {
  name_prefix   = "ms-orders-lt-"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ms_orders.key_name

  vpc_security_group_ids = [aws_security_group.microservices_sg.id]

  user_data = base64encode(templatefile("${path.module}/user-data-orders.sh", {
    docker_image     = "${var.docker_hub_username}/ms-orders:${var.image_tag}"
    db_url           = "jdbc:postgresql://${aws_db_instance.postgres.endpoint}/${var.db_name}?currentSchema=orders_schema"
    db_username      = var.db_username
    db_password      = var.db_password
    users_service_url = "http://${aws_lb.main_alb.dns_name}/api/users"
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ms-orders-instance"
      Service = "orders"
    }
  }
}

# Launch Template - ms-notifications
resource "aws_launch_template" "ms_notifications_lt" {
  name_prefix   = "ms-notifications-lt-"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.ms_notifications.key_name

  vpc_security_group_ids = [aws_security_group.microservices_sg.id]

  user_data = base64encode(templatefile("${path.module}/user-data-notifications.sh", {
    docker_image     = "${var.docker_hub_username}/ms-notifications:${var.image_tag}"
    db_url           = "jdbc:postgresql://${aws_db_instance.postgres.endpoint}/${var.db_name}?currentSchema=notifications_schema"
    db_username      = var.db_username
    db_password      = var.db_password
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ms-notifications-instance"
      Service = "notifications"
    }
  }
}

# ============================================================
# AUTO SCALING GROUPS
# ============================================================

# ASG - ms-users (min: 2, max: 3)
resource "aws_autoscaling_group" "ms_users_asg" {
  name                = "ms-users-asg"
  vpc_zone_identifier = [var.subnet1, var.subnet2]
  target_group_arns   = [aws_lb_target_group.ms_users_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.ms_users_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ms-users-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "users"
    propagate_at_launch = true
  }
}

# ASG - ms-orders (min: 2, max: 3)
resource "aws_autoscaling_group" "ms_orders_asg" {
  name                = "ms-orders-asg"
  vpc_zone_identifier = [var.subnet1, var.subnet2]
  target_group_arns   = [aws_lb_target_group.ms_orders_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.ms_orders_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ms-orders-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "orders"
    propagate_at_launch = true
  }
}

# ASG - ms-notifications (min: 2, max: 3)
resource "aws_autoscaling_group" "ms_notifications_asg" {
  name                = "ms-notifications-asg"
  vpc_zone_identifier = [var.subnet1, var.subnet2]
  target_group_arns   = [aws_lb_target_group.ms_notifications_tg.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300
  min_size            = 2
  max_size            = 3
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.ms_notifications_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ms-notifications-asg-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "notifications"
    propagate_at_launch = true
  }
}

# ============================================================
# AUTO SCALING POLICIES (CPU-based)
# ============================================================

# Scale UP policy - ms-users
resource "aws_autoscaling_policy" "ms_users_scale_up" {
  name                   = "ms-users-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ms_users_asg.name
}

resource "aws_cloudwatch_metric_alarm" "ms_users_cpu_high" {
  alarm_name          = "ms-users-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ms_users_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.ms_users_scale_up.arn]
}

# Scale DOWN policy - ms-users
resource "aws_autoscaling_policy" "ms_users_scale_down" {
  name                   = "ms-users-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ms_users_asg.name
}

resource "aws_cloudwatch_metric_alarm" "ms_users_cpu_low" {
  alarm_name          = "ms-users-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ms_users_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.ms_users_scale_down.arn]
}

# Scale UP policy - ms-orders
resource "aws_autoscaling_policy" "ms_orders_scale_up" {
  name                   = "ms-orders-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ms_orders_asg.name
}

resource "aws_cloudwatch_metric_alarm" "ms_orders_cpu_high" {
  alarm_name          = "ms-orders-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ms_orders_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.ms_orders_scale_up.arn]
}

# Scale DOWN policy - ms-orders
resource "aws_autoscaling_policy" "ms_orders_scale_down" {
  name                   = "ms-orders-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ms_orders_asg.name
}

resource "aws_cloudwatch_metric_alarm" "ms_orders_cpu_low" {
  alarm_name          = "ms-orders-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ms_orders_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.ms_orders_scale_down.arn]
}

# Scale UP policy - ms-notifications
resource "aws_autoscaling_policy" "ms_notifications_scale_up" {
  name                   = "ms-notifications-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ms_notifications_asg.name
}

resource "aws_cloudwatch_metric_alarm" "ms_notifications_cpu_high" {
  alarm_name          = "ms-notifications-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "70"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ms_notifications_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.ms_notifications_scale_up.arn]
}

# Scale DOWN policy - ms-notifications
resource "aws_autoscaling_policy" "ms_notifications_scale_down" {
  name                   = "ms-notifications-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.ms_notifications_asg.name
}

resource "aws_cloudwatch_metric_alarm" "ms_notifications_cpu_low" {
  alarm_name          = "ms-notifications-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "30"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.ms_notifications_asg.name
  }

  alarm_actions = [aws_autoscaling_policy.ms_notifications_scale_down.arn]
}
