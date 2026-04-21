# -*- mode: ruby -*-
# vi: set ft=ruby :

# 1. DEFINIERA VARIABLER
FRONTEND_SUB  = "192.168.10."
SERVICE_SUB   = "192.168.20."
BACKEND_SUB   = "192.168.30."

# 2. LISTA ÖVER MASKINER
vms = [
  { name: "ansible-control", ip: "#{FRONTEND_SUB}100", net: "frontend-net"},
  { name: "firewall",  ip: "#{FRONTEND_SUB}1", net: "frontend-net"},
  { name: "keycloak",  ip: "#{SERVICE_SUB}10", net: "service-net" },
  { name: "webserver", ip: "#{SERVICE_SUB}30", net: "service-net" },
  { name: "vault",     ip: "#{BACKEND_SUB}10", net: "backend-net" },
  { name: "database",  ip: "#{BACKEND_SUB}2",  net: "backend-net" },
]

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  # FIX 1: Denna rad saknades. Den skapar "bryggan" mellan maskinerna via din värddator.
  config.vm.synced_folder "./shared_keys", "/tmp/shared_keys", create: true

  vms.each do |machine|
    config.vm.define machine[:name] do |node|
      node.vm.hostname = machine[:name]

      # Primärt nätverkskort
      node.vm.network "private_network", 
        ip: machine[:ip], 
        virtualbox__intnet: machine[:net]

      # TRIPLE-HOMED FIREWALL
      if machine[:name] == "firewall"
        node.vm.network "private_network", 
          ip: "#{SERVICE_SUB}1", 
          virtualbox__intnet: "service-net"
          
        node.vm.network "private_network", 
          ip: "#{BACKEND_SUB}1", 
          virtualbox__intnet: "backend-net"

          # AKTIVERA ROUTING (IP Forwarding)
        node.vm.provision "shell", inline: "sysctl -w net.ipv4.ip_forward=1"
      end

      # Lägg till rutt baserat på vilket nätverk noden tillhör
      if machine[:name] == "vault" || machine[:name] == "database"
        node.vm.provision "shell", inline: "ip route replace #{FRONTEND_SUB}0/24 via #{BACKEND_SUB}1", run: "always"
      elsif machine[:name] == "webserver" || machine[:name] == "keycloak"
        node.vm.provision "shell", inline: "ip route replace #{FRONTEND_SUB}0/24 via #{SERVICE_SUB}1", run: "always"
      elsif machine[:name] == "ansible-control"
        node.vm.provision "shell", inline: "ip route replace #{SERVICE_SUB}0/24 via #{FRONTEND_SUB}1", run: "always"
        node.vm.provision "shell", inline: "ip route replace #{BACKEND_SUB}0/24 via #{FRONTEND_SUB}1", run: "always" 
      end

      # Provisionering: Ansible-control förbereder nyckeln
      if machine[:name] == "ansible-control"
        node.vm.provision "shell", inline: <<-SHELL
          apt-get update && apt-get install -y ansible
          # FIX 2: Vi rensar gamla nycklar så att vi inte lägger till dubbletter vid omstart
          rm -f /tmp/shared_keys/control.pub
          sudo -u vagrant ssh-keygen -t ed25519 -N "" -f /home/vagrant/.ssh/id_ed25519
          cp /home/vagrant/.ssh/id_ed25519.pub /tmp/shared_keys/control.pub
          # Gör nyckeln läsbar för alla i den delade mappen
          chmod 644 /tmp/shared_keys/control.pub
        SHELL
      end

      # Provisionering: Alla maskiner hämtar nyckeln
      node.vm.provision "shell", run: "always", inline: <<-SHELL
        echo "Letar efter nyckel i /tmp/shared_keys..."
        for i in {1..30}; do
          if [ -f /tmp/shared_keys/control.pub ]; then
            # FIX 3: Använd grep för att inte lägga till samma nyckel flera gånger
            if ! grep -qf /tmp/shared_keys/control.pub /home/vagrant/.ssh/authorized_keys; then
              cat /tmp/shared_keys/control.pub >> /home/vagrant/.ssh/authorized_keys
              echo "Nyckel hämtad och installerad!"
            else
              echo "Nyckeln finns redan i authorized_keys."
            fi
            break
          fi
          echo "Väntar på nyckel (försök $i)..."
          sleep 2
        done
      SHELL

      node.vm.provider "virtualbox" do |vb|
        vb.memory = "1024"
        vb.cpus = 1
      end
    end
  end
end