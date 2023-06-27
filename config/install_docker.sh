#! /usr/bin/env bash
set -xe

source ${CONFIG_DIR}/common.sh

# Based on https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
: ${DOCKER_VERSION:=latest}

# Add repo and Install packages
apt update
apt install -y curl gnupg software-properties-common apt-transport-https ca-certificates
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update

# if DOCKER_VERSION is latest, then install latest version, else install specific version
if [ "$DOCKER_VERSION" = "latest" ]; then
  apt install -y docker-ce docker-ce-cli containerd.io
else
  apt install -y docker-ce=${DOCKER_VERSION} docker-ce-cli=${DOCKER_VERSION} containerd.io
fi

# Create required directories
mkdir -p /etc/systemd/system/docker.service.d

# Create daemon json config file
tee /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

# Start and enable Services
systemctl daemon-reload 
systemctl enable docker
systemctl restart docker
