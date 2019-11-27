#!/bin/bash

set -xe


with_retry() {
	local max_attempts="$1"
	local delay="$2"
	local count=0
	local rc
	shift 2

	while true; do
		set +e
		"$@"
		rc="$?"
		set -e

		count="$((count+1))"

		if [[ "${rc}" -eq 0 ]]; then
			return 0
		fi

		if [[ "${max_attempts}" -le 0 ]] || [[ "${count}" -lt "${max_attempts}" ]]; then
			sleep "${delay}"
		else
			break
		fi
	done

	return 1
}

install_docker() {
	curl https://get.docker.com | sh
}

install_kubernetes() {
	apt-get update && apt-get install -y apt-transport-https curl
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
	cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
	apt-get update
	apt-get install -y kubeadm=1.13.12\* kubectl=1.13.12\* kubelet=1.13.12\* kubernetes-cni=0.7\*

	cat <<EOF >/etc/default/kubelet
KUBELET_EXTRA_ARGS=--feature-gates=KubeletPodResources=true
EOF

	with_retry 2 5s kubeadm init --config ./config.yml --ignore-preflight-errors=all

	mkdir -p /home/ubuntu/.kube
	cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
	chown ubuntu:ubuntu /home/ubuntu/.kube/config
	kubectl apply -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml
	kubectl taint nodes --all node-role.kubernetes.io/master-
}

install_container_driver() {
	curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
	curl -s -L https://nvidia.github.io/nvidia-docker/ubuntu18.04/nvidia-docker.list | \
		tee /etc/apt/sources.list.d/nvidia-docker.list
	apt-get update && apt-get install -y nvidia-docker2
	sed -i 's/^#root/root/' /etc/nvidia-container-runtime/config.toml
	modprobe ipmi_msghandler
	modprobe i2c_core
	docker run -d --privileged --pid=host -v /run/nvidia:/run/nvidia:shared nvidia/driver:418.40.04-ubuntu18.04-aws
}

install_nvidia_runtime() {
	curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
	curl -s -L https://nvidia.github.io/nvidia-docker/ubuntu18.04/nvidia-docker.list | \
		tee /etc/apt/sources.list.d/nvidia-docker.list
	apt-get update
	apt-get install -y nvidia-docker2
	cp daemon.json /etc/docker/daemon.json
	pkill -SIGHUP dockerd
}

install_k8s_device_plugin() {
	kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta4/nvidia-device-plugin.yml
}

usage() {
  echo "Usage: $0 -h|--help"
  echo "Usage: $0 [--driver] [--k8s-plugin] [--nvcr]"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --driver)
      AWS_KUBE_CI_DRIVER=y
      shift
      ;;
    --k8s-plugin)
      AWS_KUBE_CI_K8S_PLUGIN=y
      shift
      ;;
    --nvcr)
      AWS_KUBE_CI_NVCR=y
      shift
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

install_docker
usermod -a -G docker ubuntu
docker run -d -p 5000:5000 --name registry registry:2
install_kubernetes

if [ ! -z "${AWS_KUBE_CI_DRIVER}" ] && [ "${AWS_KUBE_CI_DRIVER}" = 'y' ]; then
  install_container_driver
fi

if [ ! -z "${AWS_KUBE_CI_NVCR}" ] && [ "${AWS_KUBE_CI_NVCR}" = 'y' ]; then
  install_nvidia_runtime
fi

if [ ! -z "${AWS_KUBE_CI_K8S_PLUGIN}" ] && [ "${AWS_KUBE_CI_K8S_PLUGIN}" = "y" ]; then
  install_k8s_device_plugin
fi
