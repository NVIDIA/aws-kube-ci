#!/bin/sh
set -xe
source ../aws-kube-ci/hostname

ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
  "containerd --version"  
ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
  "kubectl version --client"
ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
  "kubectl cluster-info"
ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
  "kubectl get nodes -o json | jq '.items[].status.nodeInfo.containerRuntimeVersion'"  
