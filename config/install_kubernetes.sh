#! /usr/bin/env bash
set -xe

CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${CONFIG_DIR}/common.sh

# Install kubeadm, kubectl, and k8s-cni
: ${K8S_VERSION:=v1.25.11}
: ${CNI_PLUGINS_VERSION:=v1.3.0}
: ${CALICO_VERSION:=v3.26.1}
: ${CRICTL_VERSION:=v1.25.0}

# Configure persistent loading of modules
tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

# Ensure you load modules
modprobe overlay
modprobe br_netfilter

# Set up required sysctl params
tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Reload sysctl
sysctl --system

# Install CNI plugins (required for most pod network):
DEST="/opt/cni/bin"
mkdir -p "$DEST"
curl -L "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-${CNI_PLUGINS_VERSION}.tgz" | tar -C "$DEST" -xz

#Install crictl (required for kubeadm / Kubelet Container Runtime Interface (CRI))
DOWNLOAD_DIR="/usr/local/bin"
mkdir -p "$DOWNLOAD_DIR"

curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRICTL_VERSION}/crictl-${CRICTL_VERSION}-linux-${ARCH}.tar.gz" | tar -C $DOWNLOAD_DIR -xz

# Install kubeadm, kubelet, kubectl
cd $DOWNLOAD_DIR
curl -L --remote-name-all https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/${ARCH}/{kubeadm,kubelet}
chmod +x {kubeadm,kubelet}

# add a kubelet systemd service 
# see https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
RELEASE_VERSION="v0.15.1"
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubelet/lib/systemd/system/kubelet.service" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service
mkdir -p /etc/systemd/system/kubelet.service.d
curl -sSL "https://raw.githubusercontent.com/kubernetes/release/${RELEASE_VERSION}/cmd/kubepkg/templates/latest/deb/kubeadm/10-kubeadm.conf" | sed "s:/usr/bin:${DOWNLOAD_DIR}:g" | tee /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl enable --now kubelet

curl -LO https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl
chmod +x kubectl

# Start kubernetes
KUBEADMIN_OPTIONS="--pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=all --control-plane-endpoint=${K8S_ENDPOINT_HOST:?K8S_ENDPOINT_HOST must be set}:6443"
# If K8S_FEATURE_GATES is set and not empty, add it to the kubeadm init options
if [ -n "${K8S_FEATURE_GATES}" ]; then
  KUBEADMIN_OPTIONS="${KUBEADMIN_OPTIONS} --feature-gates=${K8S_FEATURE_GATES}"
fi
with_retry 2 5s kubeadm init ${KUBEADMIN_OPTIONS} 
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
export KUBECONFIG="/home/ubuntu/.kube/config"

# give it room for all the pods and control plane components to start
apt install -y jq
sleep 5

# Install Calico
# based on https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart
with_retry 2 5s kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml
# Make single-node cluster schedulable
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
kubectl label node --all node-role.kubernetes.io/worker=
