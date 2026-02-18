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

# Security Group for PostgreSQL EC2 Instance
resource "aws_security_group" "postgres_sg" {
  name_prefix = "postgres-db-sg"
  vpc_id      = var.vpc_id
  description = "Security group for PostgreSQL EC2 instance"

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.microservices_sg.id]
    description     = "PostgreSQL from microservices"
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
    Name = "postgres-db-sg"
  }
}

# ============================================================
# POSTGRESQL DATABASE EC2 INSTANCE
# ============================================================

# Key Pair for PostgreSQL Instance
resource "tls_private_key" "postgres_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "postgres" {
  key_name   = "postgres-db-key"
  public_key = tls_private_key.postgres_key.public_key_openssh
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

# PostgreSQL EC2 Instance (Single instance for database)
resource "aws_instance" "postgres" {
  ami           = var.ami_id
  instance_type = "t2.small"
  key_name      = aws_key_pair.postgres.key_name
  subnet_id     = var.subnet1
  
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    set -x
    
    echo "=========================================="
    echo "Starting PostgreSQL instance setup..."
    echo "Time: $(date)"
    echo "=========================================="
    
    # Update system
    echo "[1/6] Updating system..."
    apt-get update -y
    
    # Install Docker
    echo "[2/6] Installing Docker..."
    apt-get install -y docker.io
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to install Docker"
      exit 1
    fi
    
    # Start Docker service
    echo "[3/6] Starting Docker service..."
    systemctl start docker
    systemctl enable docker
    sleep 5
    
    # Verify Docker is running
    if ! docker ps > /dev/null 2>&1; then
      echo "ERROR: Docker is not running properly"
      systemctl status docker
      exit 1
    fi
    
    usermod -aG docker ubuntu
    docker --version
    echo "Docker installed and running successfully!"
    
    # Install Docker Compose
    echo "[4/6] Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    /usr/local/bin/docker-compose --version
    
    # Create PostgreSQL directory
    echo "[5/6] Creating PostgreSQL configuration..."
    mkdir -p /opt/postgres
    cd /opt/postgres
    
    # Create init SQL file (using cat without quotes to allow variable expansion)
    cat > init-db.sql << SQLEOF
CREATE SCHEMA IF NOT EXISTS users_schema;
CREATE SCHEMA IF NOT EXISTS orders_schema;
CREATE SCHEMA IF NOT EXISTS notifications_schema;

GRANT ALL PRIVILEGES ON SCHEMA users_schema TO ${var.db_username};
GRANT ALL PRIVILEGES ON SCHEMA orders_schema TO ${var.db_username};
GRANT ALL PRIVILEGES ON SCHEMA notifications_schema TO ${var.db_username};

ALTER DATABASE ${var.db_name} SET search_path TO users_schema, orders_schema, notifications_schema, public;
SQLEOF
    
    # Create docker-compose.yml (using cat without quotes to allow variable expansion)
    cat > docker-compose.yml << COMPOSEEOF
version: '3.8'

services:
  postgres:
    image: postgres:17.2-alpine
    container_name: postgres-db
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: ${var.db_name}
      POSTGRES_USER: ${var.db_username}
      POSTGRES_PASSWORD: ${var.db_password}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${var.db_username} -d ${var.db_name}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
    driver: local
COMPOSEEOF
    
    # Display configuration files for verification
    echo "=== init-db.sql ==="
    cat init-db.sql
    echo "=== docker-compose.yml ==="
    cat docker-compose.yml
    
    # Start PostgreSQL
    echo "[6/6] Starting PostgreSQL with Docker Compose..."
    /usr/local/bin/docker-compose pull
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to pull PostgreSQL image"
      exit 1
    fi
    
    /usr/local/bin/docker-compose up -d
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to start PostgreSQL"
      /usr/local/bin/docker-compose logs
      exit 1
    fi
    
    # Wait and verify
    echo "Waiting for PostgreSQL to be ready..."
    sleep 30
    
    echo "=== Docker containers status ==="
    docker ps -a
    echo "=== Docker Compose status ==="
    /usr/local/bin/docker-compose ps
    echo "=== PostgreSQL logs (last 20 lines) ==="
    /usr/local/bin/docker-compose logs --tail=20
    
    echo "=========================================="
    echo "PostgreSQL setup completed successfully!"
    echo "Database URL: $(hostname -I | awk '{print $1}'):5432"
    echo "Database Name: ${var.db_name}"
    echo "Time: $(date)"
    echo "=========================================="
    EOF
  )
  
  root_block_device {
    volume_type = "gp2"
    volume_size = 20
    encrypted   = false
  }
  
  tags = {
    Name        = "postgres-database"
    Service     = "database"
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

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    set -x
    
    echo "Starting ms-users setup at $(date)"
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    sleep 5
    usermod -aG docker ubuntu
    
    # Pull and run ms-users container
    docker pull ${var.docker_hub_username}/ms-users:${var.image_tag}
    
    # Wait for PostgreSQL
    sleep 60
    
    docker run -d \
      --name ms-users \
      --restart unless-stopped \
      -p 8081:8081 \
      -e SERVER_PORT=8081 \
      -e DATABASE_URL="jdbc:postgresql://${aws_instance.postgres.private_ip}:5432/${var.db_name}?currentSchema=users_schema" \
      -e DATABASE_USERNAME="${var.db_username}" \
      -e DATABASE_PASSWORD="${var.db_password}" \
      -e JPA_DDL_AUTO=update \
      -e JPA_SHOW_SQL=false \
      -e LOG_LEVEL=INFO \
      ${var.docker_hub_username}/ms-users:${var.image_tag}
    
    echo "ms-users started at $(date)"
    docker ps
    EOF
  )

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

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    set -x
    
    echo "Starting ms-orders setup at $(date)"
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    sleep 5
    usermod -aG docker ubuntu
    
    # Pull and run ms-orders container
    docker pull ${var.docker_hub_username}/ms-orders:${var.image_tag}
    
    # Wait for dependencies
    sleep 60
    
    docker run -d \
      --name ms-orders \
      --restart unless-stopped \
      -p 8082:8082 \
      -e SERVER_PORT=8082 \
      -e DATABASE_URL="jdbc:postgresql://${aws_instance.postgres.private_ip}:5432/${var.db_name}?currentSchema=orders_schema" \
      -e DATABASE_USERNAME="${var.db_username}" \
      -e DATABASE_PASSWORD="${var.db_password}" \
      -e USER_SERVICE_URL="http://${aws_lb.main_alb.dns_name}/api/users" \
      -e JPA_DDL_AUTO=update \
      -e JPA_SHOW_SQL=false \
      -e LOG_LEVEL=INFO \
      ${var.docker_hub_username}/ms-orders:${var.image_tag}
    
    echo "ms-orders started at $(date)"
    docker ps
    EOF
  )

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

  user_data = base64encode(<<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    set -x
    
    echo "Starting ms-notifications setup at $(date)"
    
    # Install Docker
    apt-get update -y
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
    sleep 5
    usermod -aG docker ubuntu
    
    # Pull and run ms-notifications container
    docker pull ${var.docker_hub_username}/ms-notifications:${var.image_tag}
    
    # Wait for PostgreSQL
    sleep 60
    
    docker run -d \
      --name ms-notifications \
      --restart unless-stopped \
      -p 8083:8083 \
      -e SERVER_PORT=8083 \
      -e DATABASE_URL="jdbc:postgresql://${aws_instance.postgres.private_ip}:5432/${var.db_name}?currentSchema=notifications_schema" \
      -e DATABASE_USERNAME="${var.db_username}" \
      -e DATABASE_PASSWORD="${var.db_password}" \
      -e JPA_DDL_AUTO=update \
      -e JPA_SHOW_SQL=false \
      -e LOG_LEVEL=INFO \
      ${var.docker_hub_username}/ms-notifications:${var.image_tag}
    
    echo "ms-notifications started at $(date)"
    docker ps
    EOF
  )

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
