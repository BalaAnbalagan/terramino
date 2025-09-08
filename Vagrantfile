# Terramino: VM-Native (VirtualBox) + Docker-Native (Swarm via Vagrant Docker provider)
# Usage:
#   vagrant up vm-native --provider=virtualbox
#   vagrant up docker-native --provider=docker
#
# Windows: In Docker Desktop, enable **Expose daemon on tcp://localhost:2375 without TLS**
# so the helper can talk to the host Docker API via TCP.

Vagrant.configure("2") do |config|
  # ---------------- VM-Native ----------------
  config.vm.define "vm-native" do |vm|
    vm.vm.box = "ubuntu/jammy64"
    vm.vm.hostname = "terramino-vm"
    vm.vm.network "private_network", ip: "192.168.56.50"

    vm.vm.provider :virtualbox do |vb|
      vb.memory = 4096
      vb.cpus = 2
    end

    vm.vm.provision "shell", path: "provisioning/vm-native.sh"
  end

  # ------------- Docker-Native (Swarm) -------------
  config.vm.define "docker-native" do |dn|
    dn.vm.hostname = "terramino-dc"
    dn.vm.provider "docker" do |d|
      d.image = "docker:27-cli"
      d.name  = "terramino-dc"
      d.remains_running = true

      if Vagrant::Util::Platform.windows?
        # Use Docker Desktop's TCP daemon
        d.env = { "DOCKER_HOST" => "tcp://host.docker.internal:2375" }
        #d.volumes = [ "/vagrant:/vagrant" ]
      else
        d.volumes = [ "/vagrant:/vagrant", "/var/run/docker.sock:/var/run/docker.sock" ]
      end

      # Build images, init swarm, deploy stack; keep container alive
      d.cmd = ["sh","-lc", <<'SH'
        set -euo pipefail
        echo "==> Docker connectivity"
        docker version

        echo "==> Build images (backend, frontend)"
        docker build -t terramino-backend:local /vagrant/app/backend
        docker build -t terramino-frontend:local /vagrant/app/frontend

        echo "==> Swarm init (idempotent)"
        docker swarm init 2>/dev/null || true

        echo "==> Stack deploy"
        docker stack deploy -c /vagrant/docker/docker-stack.yml terramino

        echo "==> Services"
        docker stack services terramino || true

        echo "==> Ready (keeping helper alive)"
        tail -f /dev/null
SH
      ]
    end
  end
end
