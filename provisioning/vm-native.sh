#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y git curl jq ufw ca-certificates \
  redis-server python3 python3-venv python3-pip \
  nginx prometheus grafana prometheus-node-exporter \
  wget unzip make gcc apache2-utils

# Backend (Flask)
id terramino 2>/dev/null || useradd --system --home /opt/terramino --shell /sbin/nologin terramino
install -d -o terramino -g terramino /opt/terramino/backend
cp -r /vagrant/app/backend/* /opt/terramino/backend/
python3 -m venv /opt/terramino/backend/venv
/opt/terramino/backend/venv/bin/pip install -r /opt/terramino/backend/requirements.txt

# Frontend
install -d /var/www/terramino
cp -r /vagrant/app/frontend/static/* /var/www/terramino/

# Nginx reverse proxy
cat >/etc/nginx/sites-available/terramino <<'NGX'
server {
  listen 80 default_server;
  root /var/www/terramino;
  index index.html;
  location /api/ {
    proxy_pass http://127.0.0.1:8081/;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
NGX
ln -sf /etc/nginx/sites-available/terramino /etc/nginx/sites-enabled/default
systemctl enable --now nginx

# Redis Exporter
RE_EXPORTER_VERSION="1.62.0"
curl -L -o /tmp/redis_exporter.tar.gz \
  https://github.com/oliver006/redis_exporter/releases/download/v${RE_EXPORTER_VERSION}/redis_exporter-v${RE_EXPORTER_VERSION}.linux-amd64.tar.gz
mkdir -p /opt/redis_exporter
tar -xzf /tmp/redis_exporter.tar.gz -C /opt/redis_exporter --strip-components=1
install -m 0755 /opt/redis_exporter/redis_exporter /usr/local/bin/redis_exporter
id redisexp 2>/dev/null || useradd --system --no-create-home --shell /sbin/nologin redisexp
cat >/etc/systemd/system/redis_exporter.service <<'UNIT'
[Unit]
Description=Redis Exporter
After=network-online.target
[Service]
User=redisexp
Group=redisexp
ExecStart=/usr/local/bin/redis_exporter --redis.addr=redis://127.0.0.1:6379
Restart=always
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now redis_exporter

# Prometheus (host)
cat >/etc/prometheus/prometheus.yml <<'PROM'
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'node'
    static_configs: [ { targets: ['localhost:9100'] } ]
  - job_name: 'backend'
    static_configs: [ { targets: ['localhost:8081'] } ]
  - job_name: 'redis'
    static_configs: [ { targets: ['localhost:9121'] } ]
PROM
systemctl enable --now prometheus

# Grafana
# --- Grafana (official APT repo, idempotent) ---
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y curl gnupg ca-certificates apt-transport-https

install -d -m 0755 /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/grafana.gpg ]; then
  curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor -o /etc/apt/keyrings/grafana.gpg
fi

# Write/refresh the repo file (safe to overwrite)
cat >/etc/apt/sources.list.d/grafana.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main
EOF

apt-get update
apt-get install -y grafana

# Provision Grafana content
install -d -m0755 /etc/grafana/provisioning/{dashboards,datasources} /var/lib/grafana/dashboards
cp -f /vagrant/docker/grafana/provisioning/dashboards/dashboards.yml /etc/grafana/provisioning/dashboards/ || true
cp -f /vagrant/docker/grafana/provisioning/datasources/datasource.yml /etc/grafana/provisioning/datasources/ || true
cp -f /vagrant/docker/grafana/dashboards/*.json /var/lib/grafana/dashboards/ || true

systemctl enable grafana-server
systemctl restart grafana-server


# Backend systemd
cat >/etc/systemd/system/terramino-backend.service <<'UNIT'
[Unit] Description=Terramino Backend (Flask) After=network.target redis-server.service
[Service] Type=simple User=terramino Group=terramino WorkingDirectory=/opt/terramino/backend ExecStart=/opt/terramino/backend/venv/bin/python /opt/terramino/backend/server.py Restart=on-failure
[Install] WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now terramino-backend

# Frontend placeholder
cat >/etc/systemd/system/terramino-frontend.service <<'UNIT'
[Unit] Description=Terramino Frontend (served by Nginx) After=nginx.service
[Service] Type=oneshot ExecStart=/bin/true RemainAfterExit=yes
[Install] WantedBy=multi-user.target
UNIT
systemctl daemon-reload && systemctl enable --now terramino-frontend

# Redis tuning
sed -i 's/^#* *maxmemory .*/maxmemory 256mb/' /etc/redis/redis.conf || true
sed -i 's/^#* *maxmemory-policy .*/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf || true
systemctl enable --now redis-server

echo "[vm-native] DONE"
