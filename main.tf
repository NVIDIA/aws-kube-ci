provider "aws" {
	region = "us-west-1"
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

resource "aws_instance" "web" {
	ami = "${data.aws_ami.ubuntu.id}"
	
	instance_type = "${var.instance_type}"

	tags = {
		Name = "${var.project_name}-${var.ci_pipeline_id}"
	}

	root_block_device {
		volume_size = 80
	}

	key_name = "${var.project_name}-key-${var.ci_pipeline_id}"

	security_groups = ["default", "allow_ssh"]

	connection {
		type = "ssh"
		user = "ubuntu"
		private_key = "${file("key")}"
		agent = false
		timeout = "3m"
	}

	provisioner "file" {
		source = "daemon.json"
		destination = "~/daemon.json"
	}

	provisioner "file" {
		source = "setup.sh"
		destination = "~/setup.sh"
	}

	provisioner "remote-exec" {
		inline = ["cd ~ && chmod +x ./setup.sh && sudo ./setup.sh"]
	}
}

resource "aws_key_pair" "sshLogin" {
	key_name   = "${var.project_name}-key-${var.ci_pipeline_id}"
	public_key = "${file("key.pub")}"
}

output "instance_hostname" {
	value = "ubuntu@${aws_instance.web.public_dns}"
}
