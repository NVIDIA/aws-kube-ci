provider "aws" {
	region = var.region
}

data "aws_ami" "ubuntu" {
	most_recent = true

	filter {
		name = "name"
		values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
	}

	filter {
		name = "virtualization-type"
		values = ["hvm"]
	}

	owners = ["099720109477"]
}

data "http" "gcp_cloudips" {
	url = "https://www.gstatic.com/ipranges/cloud.json"
	request_headers = {
		Accept = "application/json"
	}
}

locals {
	// get complete list of ip_ranges and split into multiple buckets if the number of ip_ranges exceeds the security group rule limit
	ip_ranges = length(var.ingress_ip_ranges) > 0 ? var.ingress_ip_ranges : flatten([for o in jsondecode(data.http.gcp_cloudips.body).prefixes : (can(o.ipv4Prefix) && length(regexall("^us-east", o.scope)) > 0) ? [o.ipv4Prefix] : [] ])
	ip_ranges_chunks = chunklist(concat(local.ip_ranges, var.additional_ingress_ip_ranges), var.max_ingress_rules)
	ip_ranges_chunks_map = { for i in range(length(local.ip_ranges_chunks)): i => local.ip_ranges_chunks[i] }
	key_name = var.key_name == "" ? "${var.project_name}-key-${var.ci_pipeline_id}" : var.key_name
	// define common tags
	common_tags = {
		Name = var.environment == "cicd" ? "${var.project_name}-${var.ci_pipeline_id}" : "dev"
		product = "cloud-native"
		project = var.project_name
		environment = var.environment
	}
	config_root = "/home/ubuntu/config"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = local.common_tags
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
  tags = local.common_tags
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
  tags = local.common_tags
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

resource "aws_instance" "web" {
	ami = var.ami == "" ? data.aws_ami.ubuntu.id : var.ami

	instance_type = var.instance_type

	tags = {
		Name = "${var.project_name}-${var.ci_pipeline_id}"
		product = "cloud-native"
		project = var.project_name
		environment = "cicd"
	}

	associate_public_ip_address = true
	subnet_id = aws_subnet.subnet.id

	root_block_device {
		volume_size = 80
	}

	key_name = local.key_name

	vpc_security_group_ids = concat([aws_vpc.vpc.default_security_group_id], [for allow_ssh_sg in aws_security_group.allow_ssh : allow_ssh_sg.id ])

	depends_on = [aws_internet_gateway.gw]

	connection {
		host = aws_instance.web.public_ip
		type = "ssh"
		user = "ubuntu"
		private_key = file(var.private_key)
		agent = false
		timeout = "3m"
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
		host = aws_instance.web.public_ip
		type = "ssh"
		user = "ubuntu"
		private_key = file(var.private_key)
		agent = false
		timeout = "3m"
	}

	provisioner "file" {
		source = "config"
		destination = local.config_root
	}

	provisioner "remote-exec" {
		inline = ["chmod +x ${local.config_root}/*.sh"]
	}
}

resource "null_resource" "install_runtime" {
	count = !var.legacy_setup ? 1 : 0

	connection {
		host = aws_instance.web.public_ip
		type = "ssh"
		user = "ubuntu"
		private_key = file(var.private_key)
		agent = false
		timeout = "3m"
	}

	provisioner "remote-exec" {
		inline = ["sudo ${local.config_root}/install_${var.container_runtime}.sh"]
	}

	depends_on = [
		null_resource.copy_config
	]
}


resource "null_resource" "install_kubernetes" {
	count = !var.legacy_setup ? 1 : 0

	connection {
		host = aws_instance.web.public_ip
		type = "ssh"
		user = "ubuntu"
		private_key = file(var.private_key)
		agent = false
		timeout = "3m"
	}

	provisioner "remote-exec" {
		inline = ["sudo CONTAINER_RUNTIME=${var.container_runtime} ${local.config_root}/install_kubernetes.sh"]
	}

	depends_on = [
		null_resource.install_runtime
	]
}

resource "null_resource" "legacy_setup" {
	count = var.legacy_setup ? 1 : 0

	connection {
		host = aws_instance.web.public_ip
		type = "ssh"
		user = "ubuntu"
		private_key = file(var.private_key)
		agent = false
		timeout = "3m"
	}

	provisioner "remote-exec" {
		inline = ["sudo ${local.config_root}/setup.sh ${var.setup_params}"]
	}

	depends_on = [
		null_resource.copy_config
	]
}

resource "aws_key_pair" "sshLogin" {
	// If the public key is supplied, then create the aws_key_pair with the specified name.
	count = var.public_key == "" ? 0 : 1
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
