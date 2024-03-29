provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.image_name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

# Find availability zones where the ec2 instance type is available
data "aws_ec2_instance_type_offerings" "available" {
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }

  location_type = "availability-zone"
}

data "http" "gcp_cloudips" {
  url = "https://www.gstatic.com/ipranges/cloud.json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  // get complete list of ip_ranges and split into multiple buckets if the number of ip_ranges exceeds the security group rule limit
  ip_ranges            = length(var.ingress_ip_ranges) > 0 ? var.ingress_ip_ranges : flatten([for o in jsondecode(data.http.gcp_cloudips.response_body).prefixes : (can(o.ipv4Prefix) && length(regexall("^us-east", o.scope)) > 0) ? [o.ipv4Prefix] : []])
  ip_ranges_chunks     = chunklist(concat(local.ip_ranges, var.additional_ingress_ip_ranges), var.max_ingress_rules / 2)
  ip_ranges_chunks_map = { for i in range(length(local.ip_ranges_chunks)) : i => local.ip_ranges_chunks[i] }
  key_name             = var.key_name == "" ? "${var.project_name}-key-${var.ci_pipeline_id}" : var.key_name
  // define common tags
  common_tags = {
    Name        = var.environment == "cicd" ? "${var.project_name}-${var.ci_pipeline_id}" : "dev"
    product     = "cloud-native"
    project     = var.project_name
    environment = var.environment
  }
  config_root = "/home/ubuntu/config"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = local.common_tags
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags   = local.common_tags
}

resource "aws_default_route_table" "rt" {
  default_route_table_id = aws_vpc.vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = local.common_tags
}

resource "aws_subnet" "subnet" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = element(data.aws_ec2_instance_type_offerings.available.locations, 0)
  tags              = local.common_tags
}

resource "aws_security_group" "allow_ssh" {
  for_each    = local.ip_ranges_chunks_map
  name        = "allow_ssh-${var.project_name}-${each.key}-${var.ci_pipeline_id}"
  description = "Allow ssh traffic on port 22 from the specified IP addresses"

  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = each.value
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_k8s_control_plane" {
  for_each    = local.ip_ranges_chunks_map
  name        = "allow_k8s_control_plane-${var.project_name}-${each.key}-${var.ci_pipeline_id}"
  description = "Allow Kubernetes"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "Secure K8S API"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = each.value
  }

  ingress {
    description = "K8S API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = each.value
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name              = "Control Plane Load Balancer"
    KubernetesCluster = var.project_name
  }
}

resource "aws_instance" "web" {
  ami = var.ami == "" ? data.aws_ami.ubuntu.id : var.ami

  instance_type = var.instance_type

  tags = {
    Name        = "${var.project_name}-${var.ci_pipeline_id}"
    product     = "cloud-native"
    project     = var.project_name
    environment = "cicd"
  }

  associate_public_ip_address = true
  subnet_id                   = aws_subnet.subnet.id

  root_block_device {
    volume_size = 80
  }

  key_name = local.key_name

  vpc_security_group_ids = concat([aws_vpc.vpc.default_security_group_id],
    [for allow_ssh_sg in aws_security_group.allow_ssh : allow_ssh_sg.id],
  [for allow_k8s_sg in aws_security_group.allow_k8s_control_plane : allow_k8s_sg.id])

  depends_on = [aws_internet_gateway.gw]
}

resource "null_resource" "boot-finished" {
  // Wait on the instance stanza to be complete
  depends_on = [aws_instance.web]

  connection {
    host        = aws_instance.web.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key)
    agent       = false
    timeout     = "3m"
  }

  // We wait 90 seconds for the instance to complete boot before being ready
  provisioner "remote-exec" {
    inline = [
      "timeout 90 bash -c 'until [ -e /var/lib/cloud/instance/boot-finished ]; do sleep 5; done'",
    ]
  }
}

resource "null_resource" "copy_config" {
  triggers = {
    instance_id = aws_instance.web.id
  }

  connection {
    host        = aws_instance.web.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key)
    agent       = false
    timeout     = "3m"
  }

  provisioner "file" {
    source      = "config"
    destination = local.config_root
  }

  provisioner "remote-exec" {
    inline = ["chmod +x ${local.config_root}/*.sh"]
  }
}

resource "null_resource" "install_runtime" {

  connection {
    host        = aws_instance.web.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key)
    agent       = false
    timeout     = "3m"
  }

  provisioner "remote-exec" {
    inline = ["sudo CONTAINERD_VERSION=${var.containerd_version} DOCKER_VERSION=${var.docker_version} CRIO_VERSION=${var.crio_version} CONTAINER_RUNTIME=${var.container_runtime} ${local.config_root}/install_container_runtime.sh"]
  }

  depends_on = [
    null_resource.copy_config
  ]
}

resource "null_resource" "install_kubernetes" {
  count = var.kubernetes_enabled ? 1 : 0

  connection {
    host        = aws_instance.web.public_ip
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key)
    agent       = false
    timeout     = "3m"
  }

  provisioner "remote-exec" {
    inline = ["sudo K8S_FEATURE_GATES=${var.kubernetes_features} K8S_ENDPOINT_HOST=${aws_instance.web.public_dns} K8S_VERSION=${var.kubernetes_version} ${local.config_root}/install_kubernetes.sh"]
  }

  depends_on = [
    null_resource.install_runtime
  ]
}

resource "aws_key_pair" "sshLogin" {
  // If the public key is supplied, then create the aws_key_pair with the specified name.
  count      = var.public_key == "" ? 0 : 1
  public_key = file(var.public_key)

  key_name = local.key_name

  tags = local.common_tags
}

output "instance_hostname" {
  value = "ubuntu@${aws_instance.web.public_dns}"
}

output "private_key" {
  value = var.private_key
}

output "container_runtime" {
  value = var.container_runtime
}

output "kubernetes_version" {
  value = var.kubernetes_version
}
