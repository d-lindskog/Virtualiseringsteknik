# -*- mode: ruby -*-
# vi: set ft=ruby :

FRONTEND_SUB = "192.168.10."
SERVICE_SUB  = "192.168.20."
BACKEND_SUB  = "192.168.30."

BOX = "ubuntu/jammy64"

VMS = [
  { name: "ansible-control", ip: "#{FRONTEND_SUB}100", net: "frontend-net", memory: 2048, cpus: 2 },
  { name: "firewall",        ip: "#{FRONTEND_SUB}1",   net: "frontend-net", memory: 1024, cpus: 1 },
  { name: "keycloak",        ip: "#{SERVICE_SUB}10",   net: "service-net",  memory: 2048, cpus: 2 },
  { name: "webserver",       ip: "#{SERVICE_SUB}30",   net: "service-net",  memory: 1024, cpus: 1 },
  { name: "vault",           ip: "#{BACKEND_SUB}10",   net: "backend-net",  memory: 1024, cpus: 1 },
  { name: "database",        ip: "#{BACKEND_SUB}20",   net: "backend-net",  memory: 1024, cpus: 1 }
]

Vagrant.configure("2") do |config|
  config.vm.box = BOX

  # Delad mapp via hosten för public key.
  # Detta är fil-delning, inte nätverksrouting.
  config.vm.synced_folder "./shared_keys", "/tmp/shared_keys", create: true

  VMS.each do |machine|
    config.vm.define machine[:name] do |node|
      node.vm.hostname = "#{machine[:name]}.lab.local"

      # Varje VM får sitt interna nät.
      # Vagrants vanliga NAT-adapter finns kvar för apt och nedladdningar.
      node.vm.network "private_network",
        ip: machine[:ip],
        virtualbox__intnet: machine[:net]

      # Tre-bent router/firewall
      if machine[:name] == "firewall"
        node.vm.network "private_network",
          ip: "#{SERVICE_SUB}1",
          virtualbox__intnet: "service-net"

        node.vm.network "private_network",
          ip: "#{BACKEND_SUB}1",
          virtualbox__intnet: "backend-net"

        node.vm.provision "shell", inline: <<-SHELL
          set -e
          echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-forwarding.conf
          sysctl --system
          apt-get update -y
          apt-get install -y python3 vim curl nftables
        SHELL
      end

      # Rutter
      case machine[:name]
      when "ansible-control"
        node.vm.provision "shell", run: "always", inline: <<-SHELL
          ip route replace #{SERVICE_SUB}0/24 via #{FRONTEND_SUB}1
          ip route replace #{BACKEND_SUB}0/24 via #{FRONTEND_SUB}1
        SHELL

      when "keycloak", "webserver"
        node.vm.provision "shell", run: "always", inline: <<-SHELL
          ip route replace #{FRONTEND_SUB}0/24 via #{SERVICE_SUB}1
          ip route replace #{BACKEND_SUB}0/24 via #{SERVICE_SUB}1
        SHELL

      when "vault", "database"
        node.vm.provision "shell", run: "always", inline: <<-SHELL
          ip route replace #{FRONTEND_SUB}0/24 via #{BACKEND_SUB}1
          ip route replace #{SERVICE_SUB}0/24 via #{BACKEND_SUB}1
        SHELL
      end

      # Baspaket på alla noder utom firewall som redan fixas ovan
      unless machine[:name] == "firewall"
        node.vm.provision "shell", inline: <<-SHELL
          set -e
          apt-get update -y
          apt-get install -y python3 vim curl
        SHELL
      end

      # Ansible-control skapar nyckel och lägger public key i delad mapp
      if machine[:name] == "ansible-control"
        node.vm.provision "shell", inline: <<-SHELL
          set -e

          install -d -m 700 -o vagrant -g vagrant /home/vagrant/.ssh

          sudo -u vagrant bash -c '
            if [ ! -f /home/vagrant/.ssh/id_ed25519 ]; then
              ssh-keygen -t ed25519 -N "" -f /home/vagrant/.ssh/id_ed25519
            fi
          '

          cp /home/vagrant/.ssh/id_ed25519.pub /tmp/shared_keys/control.pub
          chmod 644 /tmp/shared_keys/control.pub

          apt-get install -y ansible sshpass git jq
        SHELL
      end

      # Alla maskiner hämtar control-nodens public key
      node.vm.provision "shell", run: "always", inline: <<-SHELL
        set -e

        install -d -m 700 -o vagrant -g vagrant /home/vagrant/.ssh
        touch /home/vagrant/.ssh/authorized_keys
        chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
        chmod 600 /home/vagrant/.ssh/authorized_keys

        echo "Letar efter /tmp/shared_keys/control.pub ..."
        for i in $(seq 1 30); do
          if [ -f /tmp/shared_keys/control.pub ]; then
            if ! grep -q -f /tmp/shared_keys/control.pub /home/vagrant/.ssh/authorized_keys; then
              cat /tmp/shared_keys/control.pub >> /home/vagrant/.ssh/authorized_keys
              chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
              chmod 600 /home/vagrant/.ssh/authorized_keys
              echo "Nyckel installerad."
            else
              echo "Nyckeln finns redan."
            fi
            exit 0
          fi
          echo "Väntar på nyckel, försök $i ..."
          sleep 2
        done

        echo "Ingen public key hittades i /tmp/shared_keys"
        exit 1
      SHELL

      node.vm.provider "virtualbox" do |vb|
        vb.name = machine[:name]
        vb.memory = machine[:memory]
        vb.cpus = machine[:cpus]
      end
    end
  end
end