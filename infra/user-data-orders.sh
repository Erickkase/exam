#!/bin/bash
# User Data Script for ms-orders
# Redirect all output to log file for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

set -x  # Print commands as they execute

echo "========================================"
echo "Starting ms-orders instance setup..."
echo "Time: $(date)"
echo "========================================"

# Update system
echo "[1/5] Updating system..."
yum update -y || echo "Warning: yum update failed but continuing..."

# Install Docker
echo "[2/5] Installing Docker..."
yum install -y docker
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to install Docker"
  exit 1
fi

# Start and enable Docker
echo "[3/5] Starting Docker service..."
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

# Pull Docker image
echo "[4/5] Pulling Docker image ${docker_image}..."
docker pull ${docker_image}
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to pull Docker image"
  exit 1
fi

# Wait for dependencies (PostgreSQL and ms-users)
echo "[5/5] Waiting for dependencies (PostgreSQL and ms-users)..."
sleep 60

# Run ms-orders container
echo "Starting ms-orders container..."
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

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start ms-orders container"
  docker logs ms-orders
  exit 1
fi

# Wait for container to be healthy
echo "Waiting for container to start..."
sleep 20

# Check container status
echo "Container status:"
docker ps -a | grep ms-orders
docker logs --tail=50 ms-orders

echo "========================================"
echo "ms-orders setup completed successfully!"
echo "Time: $(date)"
echo "========================================"
