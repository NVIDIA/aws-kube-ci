# AWS Kube CI

## Overview

This CI tool aims to create a virtual machine on aws with a GPU enabled Kubernetes
master/node. It uses Terraform, Docker, Kubeadm, the driver container and the device
plugin to setup the VM.

## Getting started

To use this CI tool, you need to:

- Place this directory at the root of your repo, with `aws-kube-ci` as name (you
    may want to use submodules)
- In your `.gitlab-ci.yaml`, define the stages `aws_kube_setup` and `aws_kube_clean`
- In your `.gitlab-ci.yaml`, include the `aws-kube-ci.yaml` file. For example:
```yaml
include:
  - local: 'aws-kube-ci/aws-kube-ci.yaml'
```
- Write a terraform variable file with these variables:
- `instance_type`: The AWS instance type
- `project_name`: The name of your project

For example:
```
instance_type = "g2.2xlarge"
project_name = "my-project"
```
- In your .gitlab-ci.yaml, set the `TF_VAR_FILE` to the path of the previous file.
- Write your ci task. You should write your tasks in a stage which is between `aws_kube_setup` and `aws_kube_clean`.

The `aws_kube_setup` job will expose different files as artifacts:
- The private key to connect to the VM using ssh: `aws-kube-ci/key`
- The associated public key: `aws-kube-ci/key.pub`
- A file to source to get the `user@hostname` in the env: `aws-kube-ci/hostname`. The env
variable is `instance_hostname`.

A docker registry is running on the VM once the setup is done. You can access it
using `127.0.0.1:5000`. It could be useful if you need to build a local image
and use it in the Kubernetes cluster.

A simple `.gitlab-ci.yaml` could be:
```yaml
variables:
  TF_VAR_FILE: "$CI_PROJECT_DIR/variables.tfvars"

stages:
  - aws_kube_setup
  - my_stage
  - aws_kube_clean

job:
  stage: my_stage
  script:
    - source aws-kube-ci/hostname
    - ssh -i aws-kube-ci/key $instance_hostname "echo Hello world!"
    - ssh -i aws-kube-ci/key $instance_hostname "docker push 127.0.0.1:5000/my_image"
  dependencies:
    - aws_kube_setup

include:
  - local: 'aws-kube-ci/aws-kube-ci.yaml'
```
