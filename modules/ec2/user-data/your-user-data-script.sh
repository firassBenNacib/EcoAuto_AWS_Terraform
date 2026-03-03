#!/bin/bash
set -euo pipefail
LOG_FILE="/var/log/install_docker.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting setup at $(date) ==="

BACKEND_PORT="${backend_port}"
ENABLE_ORIGIN_AUTH_HEADER="${enable_origin_auth_header}"
ORIGIN_AUTH_HEADER_NAME="${origin_auth_header_name}"
ORIGIN_AUTH_HEADER_VALUE="${origin_auth_header_value}"
ORIGIN_AUTH_PREV_HEADER_NAME="${origin_auth_previous_header_name}"
ORIGIN_AUTH_PREV_HEADER_VALUE="${origin_auth_previous_header_value}"

# Update system and install required packages
dnf update -y
dnf install -y docker nginx unzip awscli cronie logrotate

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

APP_IMAGE="your-dockerhub-username/your-app-image:latest"
APP_CONTAINER="your-container-name"

echo "Pulling latest image..."
docker pull "$${APP_IMAGE}"

if [ "$${ENABLE_ORIGIN_AUTH_HEADER}" = "true" ] && [ -n "$${ORIGIN_AUTH_HEADER_VALUE}" ]; then
  APP_INTERNAL_PORT=$((BACKEND_PORT + 10000))
  if [ "$${APP_INTERNAL_PORT}" -gt 65535 ]; then
    APP_INTERNAL_PORT=19000
  fi

  if docker ps -a --format '{{.Names}}' | grep -q "^$${APP_CONTAINER}$"; then
    docker rm -f "$${APP_CONTAINER}"
  fi

  docker run -d --restart unless-stopped -p "127.0.0.1:$${APP_INTERNAL_PORT}:$${BACKEND_PORT}" \
    --name "$${APP_CONTAINER}" \
    "$${APP_IMAGE}"

  CUR_HEADER_VAR="http_$${ORIGIN_AUTH_HEADER_NAME,,}"
  CUR_HEADER_VAR="$${CUR_HEADER_VAR//-/_}"
  PREV_HEADER_VAR="http_$${ORIGIN_AUTH_PREV_HEADER_NAME,,}"
  PREV_HEADER_VAR="$${PREV_HEADER_VAR//-/_}"

  cat >/etc/nginx/conf.d/origin-auth.conf <<EOF
server {
    listen $${BACKEND_PORT} default_server;
    server_name _;

    location / {
        set \$origin_auth_ok 0;
        if (\$$CUR_HEADER_VAR = "$${ORIGIN_AUTH_HEADER_VALUE}") { set \$origin_auth_ok 1; }
EOF

  if [ -n "$${ORIGIN_AUTH_PREV_HEADER_VALUE}" ]; then
    cat >>/etc/nginx/conf.d/origin-auth.conf <<EOF
        if (\$$PREV_HEADER_VAR = "$${ORIGIN_AUTH_PREV_HEADER_VALUE}") { set \$origin_auth_ok 1; }
EOF
  fi

  cat >>/etc/nginx/conf.d/origin-auth.conf <<EOF
        if (\$origin_auth_ok = 0) { return 403; }

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_pass http://127.0.0.1:$${APP_INTERNAL_PORT};
    }
}
EOF

  nginx -t
  systemctl enable --now nginx
else
  echo "Origin auth header enforcement disabled or no header value provided."
  if docker ps -a --format '{{.Names}}' | grep -q "^$${APP_CONTAINER}$"; then
    echo "Container exists, restarting..."
    docker restart "$${APP_CONTAINER}"
  else
    echo "Running new container..."
    docker run -d --restart unless-stopped -p "$${BACKEND_PORT}:$${BACKEND_PORT}" \
      --name "$${APP_CONTAINER}" \
      "$${APP_IMAGE}"
  fi
fi

# Set up log rotation
cat <<EOF >/etc/logrotate.d/install_docker
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
