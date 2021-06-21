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
	ip_ranges = length(var.ingress_ip_ranges) > 0 ? var.ingress_ip_ranges : flatten([for o in jsondecode(data.http.gcp_cloudips.body).prefixes : (can(o.ipv4Prefix) && length(regexall("^us-east", o.scope)) > 0) ? [o.ipv4Prefix] : [] ])
	key_name = var.key_name == "" ? "${var.project_name}-key-${var.ci_pipeline_id}" : var.key_name
	// define common tags
	common_tags = {
		Name = var.environment == "cicd" ? "${var.project_name}-${var.ci_pipeline_id}" : "dev"
		product = "cloud-native"
		project = var.project_name
		environment = var.environment
	}
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh-${var.project_name}-${var.ci_pipeline_id}"
  description = "Allow ssh traffic on port 22 from the specified IP addresses"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.ip_ranges
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

	root_block_device {
		volume_size = 80
	}

	key_name = local.key_name

	security_groups = ["default", aws_security_group.allow_ssh.name]

	connection {
		host = self.public_ip
		type = "ssh"
		user = "ubuntu"
		private_key = file(var.private_key)
		agent = false
		timeout = "3m"
	}

	provisioner "file" {
		source = "config"
		destination = "~/config"
	}

	provisioner "file" {
		source = "setup.sh"
		destination = "~/setup.sh"
	}

	provisioner "file" {
		source = "config.yml"
		destination = "~/config.yml"
	}

	provisioner "remote-exec" {
		inline = ["cd ~/config && chmod +x ./setup.sh && sudo ./setup.sh ${var.setup_params}"]
	}
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