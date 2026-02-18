#!/bin/bash
# Script para verificar el estado de las instancias EC2
# Ejecuta este script después de hacer SSH a cualquier instancia

echo "=========================================="
echo "INSTANCE HEALTH CHECK"
echo "=========================================="

# Check system info
echo -e "\n1. SYSTEM INFO:"
echo "Hostname: $(hostname)"
echo "IP: $(hostname -I)"
echo "Uptime: $(uptime)"

# Check Docker
echo -e "\n2. DOCKER STATUS:"
if systemctl is-active --quiet docker; then
    echo "✅ Docker service is running"
    docker --version
else
    echo "❌ Docker service is NOT running"
    echo "Try: sudo systemctl start docker"
fi

# Check Docker containers
echo -e "\n3. DOCKER CONTAINERS:"
if docker ps > /dev/null 2>&1; then
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
else
    echo "❌ Cannot connect to Docker daemon"
fi

# Check container logs
echo -e "\n4. CONTAINER LOGS (Last 20 lines):"
CONTAINER=$(docker ps -a --format "{{.Names}}" | head -n 1)
if [ -n "$CONTAINER" ]; then
    echo "Container: $CONTAINER"
    docker logs --tail=20 $CONTAINER
else
    echo "No containers found"
fi

# Check user-data log
echo -e "\n5. USER-DATA LOG (Last 30 lines):"
if [ -f /var/log/user-data.log ]; then
    tail -30 /var/log/user-data.log
else
    echo "❌ /var/log/user-data.log not found"
fi

# Check network connectivity
echo -e "\n6. NETWORK CONNECTIVITY:"
if timeout 2 bash -c "cat < /dev/null > /dev/tcp/8.8.8.8/53"; then
    echo "✅ Internet connectivity OK"
else
    echo "❌ No internet connectivity"
fi

# Check disk space
echo -e "\n7. DISK SPACE:"
df -h / | tail -1

echo -e "\n=========================================="
echo "Health check completed!"
echo "=========================================="
