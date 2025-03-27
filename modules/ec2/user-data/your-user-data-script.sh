#!/bin/bash

set -euo pipefail
LOG_FILE="/var/log/install_docker.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting setup at $(date) ==="

# Update system and install required packages
dnf update -y
dnf install -y docker unzip awscli cronie logrotate

# Enable and start services
systemctl enable --now docker
systemctl enable --now crond

# Add EC2 user to Docker group
usermod -aG docker ec2-user

# Wait for Docker to be ready
until docker info >/dev/null 2>&1; do
  echo "Waiting for Docker to be ready..."
  sleep 2
done

# Pull and run your container
echo "Pulling latest image..."
docker pull your-dockerhub-username/your-app-image:latest

if docker ps -a --format '{{.Names}}' | grep -q '^your-container-name$'; then
  echo "Container exists, restarting..."
  docker restart your-container-name
else
  echo "Running new container..."
  docker run -d --restart unless-stopped -p 8080:8080 \
    --name your-container-name \
    your-dockerhub-username/your-app-image:latest
fi

# Set up log rotation
cat <<EOF > /etc/logrotate.d/install_docker
$LOG_FILE {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
EOF

echo "Setup complete at $(date)"
echo "Logs: $LOG_FILE"
