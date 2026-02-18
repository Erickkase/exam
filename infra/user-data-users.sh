#!/bin/bash
# User Data Script for ms-users
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

# Wait for PostgreSQL to be available
echo "Waiting for PostgreSQL to be ready..."
sleep 45

# Run ms-users container
docker run -d \
  --name ms-users \
  --restart unless-stopped \
  -p 8081:8081 \
  -e SERVER_PORT=8081 \
  -e DATABASE_URL="${db_url}" \
  -e DATABASE_USERNAME="${db_username}" \
  -e DATABASE_PASSWORD="${db_password}" \
  -e JPA_DDL_AUTO=update \
  -e JPA_SHOW_SQL=false \
  -e LOG_LEVEL=INFO \
  ${docker_image}

# Health check log
echo "ms-users container started successfully" >> /var/log/user-data.log
