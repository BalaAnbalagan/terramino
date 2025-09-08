# Terramino — VM-Native vs Docker-Native (Swarm) via Vagrant

## Start
```powershell
# VM-Native (VirtualBox)
vagrant up vm-native --provider=virtualbox

# Docker-Native (Swarm via Vagrant Docker provider)
# Windows: in Docker Desktop, enable "Expose daemon on tcp://localhost:2375 without TLS"
vagrant up docker-native --provider=docker
```
This launches a helper container `terramino-dc` which runs:
```sh
docker swarm init || true
docker stack deploy -c docker/docker-stack.yml terramino
```

## Endpoints
- Frontend:  http://localhost:8080/
- Backend:   http://localhost:8081/api/health
- Grafana:   http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090
- Node Exporter: scraped internally via `tasks.node-exporter:9100`
- cAdvisor:  http://localhost:8088/

## Tear down
```bash
docker stack rm terramino
vagrant destroy docker-native -f
```

## Notes
- Swarm builds backend/frontend from local Dockerfiles the first time (they're referenced as `image: terramino-*-:local` when built). On Docker Desktop this build runs on the same node.
- Node Exporter & cAdvisor run as **global** services and are scraped via Swarm DNS (`tasks.*`).
- If ports are busy, adjust `published:` ports in `docker/docker-stack.yml`.
