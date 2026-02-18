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

# Create init-db.sql for schema creation
cat > /tmp/init-db.sql << 'EOF'
CREATE SCHEMA IF NOT EXISTS users_schema;
CREATE SCHEMA IF NOT EXISTS orders_schema;
CREATE SCHEMA IF NOT EXISTS notifications_schema;

GRANT ALL PRIVILEGES ON SCHEMA users_schema TO ${db_username};
GRANT ALL PRIVILEGES ON SCHEMA orders_schema TO ${db_username};
GRANT ALL PRIVILEGES ON SCHEMA notifications_schema TO ${db_username};

ALTER DATABASE ${db_name} SET search_path TO users_schema, orders_schema, notifications_schema, public;
EOF

# Wait for RDS to be available (simple wait)
sleep 30

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
