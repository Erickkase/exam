#!/bin/bash
# User Data Script for ms-orders
set -e

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Pull Docker image
docker pull ${docker_image}

# Wait for dependencies (RDS and ms-users)
sleep 30

# Run ms-orders container
docker run -d \
  --name ms-orders \
  --restart unless-stopped \
  -p 8082:8082 \
  -e SERVER_PORT=8082 \
  -e DATABASE_URL="${db_url}" \
  -e DATABASE_USERNAME="${db_username}" \
  -e DATABASE_PASSWORD="${db_password}" \
  -e USER_SERVICE_URL="${users_service_url}" \
  -e JPA_DDL_AUTO=update \
  -e JPA_SHOW_SQL=false \
  -e LOG_LEVEL=INFO \
  ${docker_image}

# Health check log
echo "ms-orders container started successfully" >> /var/log/user-data.log
