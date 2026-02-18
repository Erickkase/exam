#!/bin/bash
# User Data Script for ms-notifications
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

# Wait for RDS to be available
sleep 30

# Run ms-notifications container
docker run -d \
  --name ms-notifications \
  --restart unless-stopped \
  -p 8083:8083 \
  -e SERVER_PORT=8083 \
  -e DATABASE_URL="${db_url}" \
  -e DATABASE_USERNAME="${db_username}" \
  -e DATABASE_PASSWORD="${db_password}" \
  -e JPA_DDL_AUTO=update \
  -e JPA_SHOW_SQL=false \
  -e LOG_LEVEL=INFO \
  ${docker_image}

# Health check log
echo "ms-notifications container started successfully" >> /var/log/user-data.log
