#!/bin/bash
# User Data Script for ms-notifications
# Redirect all output to log file for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

set -x  # Print commands as they execute

echo "========================================"
echo "Starting ms-notifications instance setup..."
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

# Wait for PostgreSQL to be available
echo "[5/5] Waiting for PostgreSQL to be ready..."
sleep 60

# Run ms-notifications container
echo "Starting ms-notifications container..."
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

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to start ms-notifications container"
  docker logs ms-notifications
  exit 1
fi

# Wait for container to be healthy
echo "Waiting for container to start..."
sleep 20

# Check container status
echo "Container status:"
docker ps -a | grep ms-notifications
docker logs --tail=50 ms-notifications

echo "========================================"
echo "ms-notifications setup completed successfully!"
echo "Time: $(date)"
echo "========================================"
