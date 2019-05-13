#!/bin/sh

source ../aws-kube-ci/hostname
ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname} \
	"docker run containerdevk8s/cuda:10.0-nbody-ubuntu16.04 nvidia-smi"
ssh -i ../aws-kube-ci/key ${instance_hostname} \
  "docker run containerdevk8s/cuda:10.0-nbody-ubuntu16.04 0_Simple/vectorAdd/vectorAdd"
ssh -i ../aws-kube-ci/key ${instance_hostname} \
  "docker run containerdevk8s/cuda:10.0-nbody-ubuntu16.04 0_Simple/vectorAddDrv/vectorAddDrv"
