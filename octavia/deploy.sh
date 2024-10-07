# edit globals file
echo "octavia_certs_country: ID" | sudo tee -a /etc/kolla/globals.yml
echo "octavia_certs_state: Jakarta" | sudo tee -a /etc/kolla/globals.yml
echo "octavia_certs_organization: OpenStack" | sudo tee -a /etc/kolla/globals.yml
echo "octavia_certs_organizational_unit: Octavia" | sudo tee -a /etc/kolla/globals.yml

# generate certificate for octavia
kolla-ansible octavia-certificates

OCTAVIA_MGMT_SUBNET=172.16.10.0/24
OCTAVIA_MGMT_SUBNET_START=172.16.10.10
OCTAVIA_MGMT_SUBNET_END=172.16.10.254
OCTAVIA_MGMT_HOST_IP=172.16.10.1
OCTAVIA_MGMT_VLAN_ID=11

# add extra configurations octavia at globals file
sudo tee -a /etc/kolla/globals.yml << EOT
octavia_amp_network:
  name: lb-mgmt-net
  provider_network_type: vlan
  provider_segmentation_id: $OCTAVIA_MGMT_VLAN_ID
  provider_physical_network: physnet1
  external: false
  shared: false
  subnet:
    name: lb-mgmt-subnet
    cidr: "$OCTAVIA_MGMT_SUBNET"
    allocation_pool_start: "$OCTAVIA_MGMT_SUBNET_START"
    allocation_pool_end: "$OCTAVIA_MGMT_SUBNET_END"
    gateway_ip: "$OCTAVIA_MGMT_HOST_IP"
    enable_dhcp: yes
EOT

# Create a new interface with a vlan assigned to octavia at all controller
# ms-ctrl-01
sudo tee /usr/local/bin/veth-lbaas.sh << EOT
#!/bin/bash
sudo ip link add v-lbaas-vlan type veth peer name v-lbaas
sudo ip addr add 172.16.10.2/24 dev v-lbaas
sudo ip link set v-lbaas-vlan up
sudo ip link set v-lbaas up
EOT
sudo chmod 744 /usr/local/bin/veth-lbaas.sh
sudo tee /etc/systemd/system/veth-lbaas.service << EOT
[Unit]
After=network.service

[Service]
ExecStart=/usr/local/bin/veth-lbaas.sh

[Install]
WantedBy=default.target
EOT
sudo chmod 644 /etc/systemd/system/veth-lbaas.service
sudo systemctl daemon-reload
sudo systemctl enable veth-lbaas.service
sudo systemctl start veth-lbaas.service
docker exec openvswitch_vswitchd ovs-vsctl add-port \
br-ex v-lbaas-vlan tag=$OCTAVIA_MGMT_VLAN_ID

# ms-ctrl-02
sudo tee /usr/local/bin/veth-lbaas.sh << EOT
#!/bin/bash
sudo ip link add v-lbaas-vlan type veth peer name v-lbaas
sudo ip addr add 172.16.10.3 dev v-lbaas
sudo ip link set v-lbaas-vlan up
sudo ip link set v-lbaas up
EOT
sudo chmod 744 /usr/local/bin/veth-lbaas.sh
sudo tee /etc/systemd/system/veth-lbaas.service << EOT
[Unit]
After=network.service

[Service]
ExecStart=/usr/local/bin/veth-lbaas.sh

[Install]
WantedBy=default.target
EOT
sudo chmod 644 /etc/systemd/system/veth-lbaas.service
sudo systemctl daemon-reload
sudo systemctl enable veth-lbaas.service
sudo systemctl start veth-lbaas.service
docker exec openvswitch_vswitchd ovs-vsctl add-port \
br-ex v-lbaas-vlan tag=$OCTAVIA_MGMT_VLAN_ID


# ms-ctrl-03
sudo tee /usr/local/bin/veth-lbaas.sh << EOT
#!/bin/bash
sudo ip link add v-lbaas-vlan type veth peer name v-lbaas
sudo ip addr add 172.16.10.4 dev v-lbaas
sudo ip link set v-lbaas-vlan up
sudo ip link set v-lbaas up
EOT
sudo chmod 744 /usr/local/bin/veth-lbaas.sh
sudo tee /etc/systemd/system/veth-lbaas.service << EOT
[Unit]
After=network.service

[Service]
ExecStart=/usr/local/bin/veth-lbaas.sh

[Install]
WantedBy=default.target
EOT
sudo chmod 644 /etc/systemd/system/veth-lbaas.service
sudo systemctl daemon-reload
sudo systemctl enable veth-lbaas.service
sudo systemctl start veth-lbaas.service
docker exec openvswitch_vswitchd ovs-vsctl add-port \
br-ex v-lbaas-vlan tag=$OCTAVIA_MGMT_VLAN_ID

# edd another octavia parameter to globals file
echo "enable_octavia: \"yes\"" | sudo tee -a /etc/kolla/globals.yml
echo "octavia_network_interface: v-lbaas" | sudo tee -a /etc/kolla/globals.yml

sudo tee -a /etc/kolla/globals.yml << EOT
octavia_amp_flavor:
  name: "amphora"
  is_public: no
  vcpus: 1
  ram: 1024
  disk: 5
EOT

sudo mkdir /etc/kolla/config/octavia
# Use a config drive in the Amphorae for cloud-init
sudo tee /etc/kolla/config/octavia/octavia-worker.conf << EOT
[controller_worker]
user_data_config_drive = true
EOT

# deploy octavia
kolla-ansible -i multinode deploy --tags common,horizon,octavia


