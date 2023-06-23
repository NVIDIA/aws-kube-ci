#! /usr/bin/env bash
set -xe

CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${CONFIG_DIR}/common.sh

: ${CONTAINERD_VERSION:=1.6.21}

# Install required packages
apt update
apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# Add Docker repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=${ARCH}] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Install containerd
apt update
apt install -y containerd.io=${CONTAINERD_VERSION}-1

# Configure containerd and start service
mkdir -p /etc/containerd
containerd config default>/etc/containerd/config.toml

# restart containerd
systemctl restart containerd
systemctl enable containerd
