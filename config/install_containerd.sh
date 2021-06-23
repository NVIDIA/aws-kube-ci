#! /usr/bin/env bash
set -xe

CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${CONFIG_DIR}/common.sh

# Install containerd
# https://github.com/containerd/containerd/blob/main/docs/cri/installation.md
: ${CONTAINERD_VERSION:=1.5.2}

RELEASE_URL="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}"
RELEASE_TAR_GZ="cri-containerd-cni-${CONTAINERD_VERSION}-linux-amd64.tar.gz"
apt-get update && apt-get install -y libseccomp2

wget ${RELEASE_URL}/${RELEASE_TAR_GZ}

wget ${RELEASE_URL}/${RELEASE_TAR_GZ}.sha256sum
sha256sum --check ${RELEASE_TAR_GZ}.sha256sum

tar --no-overwrite-dir -C / -xzf ${RELEASE_TAR_GZ}
systemctl daemon-reload
systemctl start containerd
