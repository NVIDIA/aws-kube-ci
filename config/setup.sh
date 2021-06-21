#!/bin/bash

set -xe

CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source ${CONFIG_DIR}/common.sh

wait_cloud_init() {
        echo "waiting 90 seconds for cloud-init to update /etc/apt/sources.list"

        timeout 90 /bin/bash -c \
                  'until stat /var/lib/cloud/instance/boot-finished 2>/dev/null; do echo waiting ...; sleep 1; done'
}

install_docker() {
	${CONFIG_DIR}/install_docker.sh
}

install_kubernetes() {
	${CONFIG_DIR}/install_kubernetes.sh
}

install_container_driver() {
	curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
	curl -s -L https://nvidia.github.io/nvidia-docker/ubuntu18.04/nvidia-docker.list | \
		tee /etc/apt/sources.list.d/nvidia-docker.list
	apt-get update && apt-get install -y nvidia-docker2
	sed -i 's/^#root/root/' /etc/nvidia-container-runtime/config.toml
	modprobe ipmi_msghandler
	modprobe i2c_core
	docker run -d --privileged --pid=host -v /run/nvidia:/run/nvidia:shared nvidia/driver:440.64.00-ubuntu18.04-aws
}

install_nvidia_runtime() {
	curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | apt-key add -
	curl -s -L https://nvidia.github.io/nvidia-docker/ubuntu18.04/nvidia-docker.list | \
		tee /etc/apt/sources.list.d/nvidia-docker.list
	apt-get update
	apt-get install -y nvidia-docker2
	cp ${CONFIG_DIR}/daemon.json /etc/docker/daemon.json
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

wait_cloud_init
install_docker
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
