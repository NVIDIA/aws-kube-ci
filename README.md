# AWS Kube CI

## Overview

This CI tool aims to create a virtual machine on AWS with a GPU enabled Kubernetes
master/node. It uses Terraform, Docker, Kubeadm, the driver container and the device
plugin to setup the VM.

**WARNING:** This tool is in alpha version

## Getting started

### Creating a dev instance

This repository can be used to create and configure a development instance that mirrors the configuration used in CI. Run

```bash
terraform init
```

To initialize the local terraform environment the variables for the `plan`, `apply`, and `destroy` commands are explicitly overridden.

This can be done using the command line as shown below, or by creating a `.local-dev.auto.tfvars` file with ther required overrides as terraform automatically includes `*.auto.tfvars` files.

If running outside of the corp VPN, you need to add your IP to the list `ingress_ip_ranges` at the `local-dev.tfvars` file first then, Run `plan` to check that everything is ready:

```bash
terraform plan \
  -var "region=us-east-2" \
  -var "key_name=elezar" \
  -var "private_key=/Users/elezar/.ssh/elezar.pem" \
    -var-file=local-dev.tfvars
```
will preview the changes that will be applied. Note this assumes that valid AWS credentials have been configured. This also assumes that an AWS key has already been created with a name `elezar` using the public key associated with the private key `/Users/elezar/.ssh/elezar.pem`, so please change accordingly, then create the instance by running `apply`:

```bash
terraform apply \
  -auto-approve \
  -var "region=us-east-2" \
  -var "key_name=elezar" \
  -var "private_key=/Users/elezar/.ssh/elezar.pem" \
    -var-file=local-dev.tfvars
```
Will proceed to create the required resources.

Once this is complete, the instance hostname can be obtained using:

```bash
export instance_hostname=$(terraform output -raw instance_hostname)
```
And assuming that the private key specified during creation is added to the ssh agent:

```bash
eval $(ssh-agent)
ssh-add /Users/elezar/.ssh/elezar.pem
```

running:

```bash
ssh ${instance_hostname}
```

should connect to the created instance. Alternatively, the identity can be explicitly specified:

```bash
ssh -i /Users/elezar/.ssh/elezar.pem ${instance_hostname}
```

To start using the Kubernetes cluster first we retrieve the Kubeconfig file:

```bash
scp ${instance_hostname}:/home/ubuntu/.kube kubeconfig
```

Now we can use the kubernetes clusters from our host:

```bash
kubectl --kubeconfig kubeconfig get node
ip-10-0-0-14   Ready    control-plane,master   7m51s   v1.23.10
```

#### Cleaning up

In order to remove the created resources, run:

```bash
terraform destroy \
  -auto-approve \
  -var "region=us-east-2" \
    -var-file=local-dev.tfvars
```

#### Specifying the container runtime

By using the `container_runtime` variable the provisioned node can be set up to run either docker or
containerd as the container runtime. The default is `docker` and can be changed using the `-var "legacy_setup=false" -var "container_runtime=containerd"` command line arguments when running `terraform apply` (or `destroy`).

### Using the CI tool
To use this CI tool, you need to:

- Place this directory at the root of your repo, with `aws-kube-ci` as name (you
    may want to use submodules). For example:

```yaml
git submodule add https://gitlab.com/nvidia/container-infrastructure/aws-kube-ci.git
```

- In your `.gitlab-ci.yml`, define the stages `aws_kube_setup` and `aws_kube_clean`
- In your `.gitlab-ci.yml`, include the `aws-kube-ci.yml` file. It is strongly
  recommended to include a specific version. The version must be a git ref. For example:

```yaml
include:
  project: nvidia/container-infrastructure/aws-kube-ci
  file: aws-kube-ci.yml
  ref: vX.Y
```

- In your `.gitlab-ci.yml`, extends the `.aws_kube_setup` and `.aws_kube_clean`
  jobs. For example:

```yaml
aws_kube_setup:
  extends: .aws_kube_setup

aws_kube_clean:
  extends: .aws_kube_clean
```

_Note that we include project rather than file here because gitlab doesn't support including local files from submodules_

- Write a terraform variable file with these variables:
  - `instance_type`: The AWS instance type
  - `project_name`: The name of your project

For example:

```
instance_type = "g2.2xlarge"
project_name = "my-project"
```
- In your .gitlab-ci.yml, set the `TF_VAR_FILE` to the path of the previous file.
- Write your ci task. You should write your tasks in a stage which is between `aws_kube_setup` and `aws_kube_clean`.
- Set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` variables in CI/CD
  settings of the projet

The `aws_kube_setup` job will expose different files as artifacts:
- The private key to connect to the VM using ssh: `aws-kube-ci/key`
- The associated public key: `aws-kube-ci/key.pub`
- A file to source to get the `user@hostname` in the env: `aws-kube-ci/hostname`. The env
variable is `instance_hostname`.

A docker registry is running on the VM once the setup is done. You can access it
using `127.0.0.1:5000`. It could be useful if you need to build a local image
and use it in the Kubernetes cluster.

A simple `.gitlab-ci.yml` could be:

```yaml
variables:
  GIT_SUBMODULE_STRATEGY: recursive
  TF_VAR_FILE: "$CI_PROJECT_DIR/variables.tfvars"

stages:
  - aws_kube_setup
  - my_stage
  - aws_kube_clean

aws_kube_setup:
  extends: .aws_kube_setup

job:
  stage: my_stage
  script:
    - source aws-kube-ci/hostname
    - ssh -i aws-kube-ci/key $instance_hostname "echo Hello world!"
    - ssh -i aws-kube-ci/key $instance_hostname "docker push 127.0.0.1:5000/my_image"
  dependencies:
    - aws_kube_setup

aws_kube_clean:
  extends: .aws_kube_clean

include:
  project: nvidia/container-infrastructure/aws-kube-ci
  file: aws-kube-ci.yml
  ref: vX.Y
```
