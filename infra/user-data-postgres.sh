#!/bin/bash
# User Data Script for PostgreSQL Database Instance
set -e

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Create directory for PostgreSQL
mkdir -p /opt/postgres
cd /opt/postgres

# Create init-db.sql for schema creation
cat > init-db.sql << 'EOF'
-- Create schemas for microservices
CREATE SCHEMA IF NOT EXISTS users_schema;
CREATE SCHEMA IF NOT EXISTS orders_schema;
CREATE SCHEMA IF NOT EXISTS notifications_schema;

-- Grant privileges
GRANT ALL PRIVILEGES ON SCHEMA users_schema TO ${db_username};
GRANT ALL PRIVILEGES ON SCHEMA orders_schema TO ${db_username};
GRANT ALL PRIVILEGES ON SCHEMA notifications_schema TO ${db_username};

-- Set default search path
ALTER DATABASE ${db_name} SET search_path TO users_schema, orders_schema, notifications_schema, public;
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:17.2-alpine
    container_name: postgres-db
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: ${db_name}
      POSTGRES_USER: ${db_username}
      POSTGRES_PASSWORD: ${db_password}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sql:/docker-entrypoint-initdb.d/init-db.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${db_username} -d ${db_name}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
    driver: local
EOF

# Create .env file
cat > .env << EOF
DB_NAME=${db_name}
DB_USERNAME=${db_username}
DB_PASSWORD=${db_password}
EOF

# Start PostgreSQL with Docker Compose
docker-compose up -d

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
sleep 30

# Check if PostgreSQL is running
docker-compose ps

# Log success
echo "PostgreSQL database started successfully" >> /var/log/user-data.log
echo "Database accessible at: $(hostname -I | awk '{print $1}'):5432" >> /var/log/user-data.log
