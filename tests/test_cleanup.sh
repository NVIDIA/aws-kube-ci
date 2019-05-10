#!/bin/sh

source ../aws-kube-ci/hostname
if ssh -i ../aws-kube-ci/key -o StrictHostKeyChecking=no ${instance_hostname};
then
	exit 1
fi
exit 0
