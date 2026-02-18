#!/bin/bash
# User Data Script for PostgreSQL Database Instance
# Redirect all output to log file for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

set -x  # Print commands as they execute

echo "========================================"
echo "Starting PostgreSQL instance setup..."
echo "Time: $(date)"
echo "========================================"

# Update system
echo "[1/7] Updating system..."
yum update -y || echo "Warning: yum update failed but continuing..."

# Install Docker
echo "[2/7] Installing Docker..."
yum install -y docker
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to install Docker"
  exit 1
fi

# Start and enable Docker
echo "[3/7] Starting Docker service..."
systemctl start docker
systemctl enable docker
systemctl status docker

# Wait for Docker daemon to be ready
echo "Waiting for Docker daemon..."
sleep 5

# Verify Docker is running
if ! docker ps > /dev/null 2>&1; then
  echo "ERROR: Docker is not running properly"
  systemctl status docker
  exit 1
fi

usermod -aG docker ec2-user
echo "Docker installed successfully"

# Install Docker Compose
echo "[4/7] Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
docker-compose --version || echo "Warning: docker-compose version check failed"

# Create directory for PostgreSQL
echo "[5/7] Creating PostgreSQL directory..."
mkdir -p /opt/postgres
cd /opt/postgres

# Create init-db.sql for schema creation (using double quotes for variable expansion)
echo "[6/7] Creating init-db.sql..."
cat > init-db.sql << EOF
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
echo "Creating docker-compose.yml..."
cat > docker-compose.yml << EOF
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

echo "Configuration files created successfully"

# Start PostgreSQL with Docker Compose
echo "[7/7] Starting PostgreSQL with Docker Compose..."
docker-compose pull
docker-compose up -d

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start PostgreSQL"
  docker-compose logs
  exit 1
fi

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
sleep 30

# Check PostgreSQL status
echo "PostgreSQL container status:"
docker-compose ps
docker-compose logs --tail=50

echo "========================================"
echo "PostgreSQL setup completed successfully!"
echo "Database accessible at: $(hostname -I | awk '{print $1}'):5432"
echo "Time: $(date)"
echo "========================================"
sleep 30

# Check if PostgreSQL is running
docker-compose ps

# Log success
echo "PostgreSQL database started successfully" >> /var/log/user-data.log
echo "Database accessible at: $(hostname -I | awk '{print $1}'):5432" >> /var/log/user-data.log
