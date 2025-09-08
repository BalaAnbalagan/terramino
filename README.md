# Terramino — VM-Native vs Docker-Native (Swarm) via Vagrant

Terramino is a Tetris-like game application with comprehensive monitoring and observability, demonstrating deployment patterns using both VM-native and Docker Swarm approaches via Vagrant.

## 🎮 Application Overview

![Terramino Game Interface](../docs/images/terramino-game.png)
*The Terramino game interface showing both VM-native (left) and Docker-native (right) deployments*

## 🚀 Quick Start

### VM-Native (VirtualBox)
```powershell
vagrant up vm-native --provider=virtualbox
```

### Docker-Native (Swarm via Vagrant Docker provider)
```powershell
# Windows: in Docker Desktop, enable "Expose daemon on tcp://localhost:2375 without TLS"
vagrant up docker-native --provider=docker
```

This launches a helper container `terramino-dc` which runs:
```sh
docker swarm init || true
docker stack deploy -c docker/docker-stack.yml terramino
```

## 🌐 Service Endpoints

- **Frontend:**  http://localhost:8080/
- **Backend:**   http://localhost:8081/api/health
- **Grafana:**   http://localhost:3000 (admin/admin)
- **Prometheus:** http://localhost:9090
- **Node Exporter:** scraped internally via `tasks.node-exporter:9100`
- **cAdvisor:**  http://localhost:8088/

## 📊 Monitoring & Observability

The application includes a comprehensive monitoring stack with Grafana dashboards for real-time insights:

### Application Metrics Dashboard
![Terramino App Overview](../docs/images/terramino-app-overview.png)
*Application-level metrics including games created, backend requests, scores, and Redis operations*

### Redis Performance Monitoring
![Redis Overview](../docs/images/redis-overview.png)
*Redis performance metrics showing operations per second and connected clients*

### Host System Monitoring
![Host Overview](../docs/images/host-overview.png)
*System-level monitoring with CPU usage and memory consumption metrics*

## 🏗️ Architecture

The application demonstrates two deployment approaches:

- **VM-Native**: Traditional virtual machine deployment using VirtualBox
- **Docker-Native**: Modern containerized deployment using Docker Swarm

Both approaches include:
- Frontend service (Terramino game interface)
- Backend API service
- Redis for game state management
- Comprehensive monitoring stack (Prometheus, Grafana, Node Exporter, cAdvisor)

## 📈 Monitoring Stack Features

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and alerting with pre-configured dashboards
- **Node Exporter**: Host system metrics
- **cAdvisor**: Container performance metrics
- **Redis Exporter**: Redis-specific performance metrics

The monitoring setup provides insights into:
- Application performance (request rates, response times)
- Game metrics (games created, scores submitted)
- System resources (CPU, memory usage)
- Container performance
- Redis operations and connectivity

## 🛠️ Tear Down

```bash
docker stack rm terramino
vagrant destroy docker-native -f
```

## 📝 Notes

- Swarm builds backend/frontend from local Dockerfiles the first time (they're referenced as `image: terramino-*-:local` when built). On Docker Desktop this build runs on the same node.
- Node Exporter & cAdvisor run as **global** services and are scraped via Swarm DNS (`tasks.*`).
- If ports are busy, adjust `published:` ports in `docker/docker-stack.yml`.
- All monitoring dashboards are pre-configured and accessible immediately after deployment.

## 🎯 Key Features

- **Dual Deployment Models**: Compare VM vs Container approaches
- **Full Observability**: Complete monitoring stack with visual dashboards
- **Game State Persistence**: Redis integration for game data
- **Production-Ready**: Includes health checks, metrics, and monitoring
- **Easy Setup**: One-command deployment for both approaches