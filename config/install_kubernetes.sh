#! /usr/bin/env bash
set -xe

CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${CONFIG_DIR}/common.sh

# Install kubeadm, kubectl, and k8s-cni
: ${K8S_VERSION:=1.23.10}
: ${K8S_CNI_VERSION:=0.8.7}
: ${CALICO_VERSION:=v3.16}

apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubeadm=${K8S_VERSION}\* kubectl=${K8S_VERSION}\* kubelet=${K8S_VERSION}\* kubernetes-cni=${K8S_CNI_VERSION}\*

cat <<EOF >/etc/default/kubelet
KUBELET_EXTRA_ARGS=--feature-gates=KubeletPodResources=true
EOF

KUBEADM_OPTIONS="--pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=all --control-plane-endpoint=${K8S_ENDPOINT_HOST:?K8S_ENDPOINT_HOST must be set}:6443" 

if [[ x"${CONTAINER_RUNTIME}" == x"containerd" ]]; then
# Configure k8s to use containerd
mkdir -p  /etc/systemd/system/kubelet.service.d/
cat << EOF | sudo tee  /etc/systemd/system/kubelet.service.d/0-containerd.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

KUBEADM_OPTIONS="${KUBEADM_OPTIONS} --cri-socket /run/containerd/containerd.sock"
fi

if [[ x"${CONTAINER_RUNTIME}" == x"docker" ]]; then
# Set docker cgroup driver to systemd
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --exec-opt native.cgroupdriver=systemd
EOF
systemctl daemon-reload
systemctl restart docker
fi

systemctl daemon-reload

# Start kubernetes
with_retry 2 5s kubeadm init ${KUBEADM_OPTIONS}

mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
kubectl apply -f https://docs.projectcalico.org/${CALICO_VERSION}/manifests/calico.yaml
kubectl taint nodes --all node-role.kubernetes.io/master-
