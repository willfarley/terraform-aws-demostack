#!/usr/bin/env bash
set -e

echo "==> Nomad (client)"

echo "--> Fetching"
install_from_url "nomad" "${nomad_url}"

echo "--> Installing"
sudo mkdir -p /mnt/nomad
sudo mkdir -p /etc/nomad.d
sudo tee /etc/nomad.d/config.hcl > /dev/null <<EOF
name         = "${node_name}"
data_dir     = "/mnt/nomad"
enable_debug = true

bind_addr = "0.0.0.0"

datacenter = "${region}"

region = "global"



advertise {
  http = "$(public_ip):4646"
  rpc  = "$(public_ip):4647"
  serf = "$(public_ip):4648"
}

client {
  enabled = true
     options = {
    "driver.raw_exec.enable" = "1"
     "docker.privileged.enabled" = "true"
  }

  meta {
    "type" = "worker",
    "name" = "${node_name}"
  }
}

tls {
  rpc  = true
  http = true

  ca_file   = "/usr/local/share/ca-certificates/01-me.crt"
  cert_file = "/etc/ssl/certs/me.crt"
  key_file  = "/etc/ssl/certs/me.key"

  verify_server_hostname = false
}



vault {
  enabled   = true
   address          = "https://vault.query.consul:8200"
  ca_file   = "/usr/local/share/ca-certificates/01-me.crt"
  cert_file = "/etc/ssl/certs/me.crt"
  key_file  = "/etc/ssl/certs/me.key"
}

autopilot {
    cleanup_dead_servers = true
    last_contact_threshold = "200ms"
    max_trailing_logs = 250
    server_stabilization_time = "10s"
    enable_redundancy_zones = false
    disable_upgrade_migration = false
    enable_custom_upgrades = false
}

EOF

echo "--> Writing profile"
sudo tee /etc/profile.d/nomad.sh > /dev/null <<"EOF"
alias noamd="nomad"
alias nomas="nomad"
alias nomda="nomad"
export NOMAD_ADDR="https://${node_name}.node.consul:4646"
export NOMAD_CACERT="/usr/local/share/ca-certificates/01-me.crt"
export NOMAD_CLIENT_CERT="/etc/ssl/certs/me.crt"
export NOMAD_CLIENT_KEY="/etc/ssl/certs/me.key"
EOF
source /etc/profile.d/nomad.sh

echo "--> Generating upstart configuration"
sudo tee /etc/systemd/system/nomad.service > /dev/null <<EOF
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
Requires=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/local/bin/nomad agent -config="/etc/nomad.d"
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGINT
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "--> Installing CNI plugin"
sudo mkdir -p /opt/cni/bin/
wget -O cni.tgz ${cni_plugin_url} 
sudo tar -xf cni.tgz -C /opt/cni/bin/


echo "--> Starting nomad"
sudo systemctl enable nomad
sudo systemctl start nomad

echo "--> Creating workspace"
sudo mkdir -p /workstation/nomad
cd /workstation/nomad
sudo git clone https://github.com/willfarley/nomad_jobs
cd nomad_jobs

if [ ${run_nomad_jobs} == 0 ]
then
echo "--> not running Nomad Jobs"

else

echo "--> Waiting for Vault leader"
while ! host active.vault.service.consul &> /dev/null; do
  sleep 5
done

echo "--> Waiting for Nomad leader"
while [ -z "$(curl -s http://localhost:4646/v1/status/leader)" ]; do
  sleep 5
done  

sleep 180


echo "--> Running  Nomad Job"

 nomad run hashibo.nomad
 nomad run catalogue-with-connect.nomad
 nomad run nginx-pki.nomad

fi

echo "==> Run Nomad is Done!"

