#!/bin/sh

source ../aws-kube-ci/hostname

# Docker
if [ "$CONTAINER_RUNTIME" = "docker" ]; then
ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
  "docker version"
ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
  "docker run hello-world"  
fi
# Containerd
if [ "$CONTAINER_RUNTIME" = "containerd" ]; then
ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
  "containerd --version"  
fi
# CRI-O
if [ "$CONTAINER_RUNTIME" = "crio" ]; then
ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
  "crio --version"  
fi
# Kubernetes
if [ "$KUBERNETES_ENABLED" = "true" ]; then
ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
  "kubectl cluster-info && kubectl version --client"
ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
  "kubectl get nodes -o json | jq '.items[].status.nodeInfo.containerRuntimeVersion'"  
fi
