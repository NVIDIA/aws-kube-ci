variable "region" {
  type = string
  default = "us-west-2"
}

variable "project_name" {
	type = string
	description = "Name of the project"
}

variable "ci_pipeline_id" {
	type = string
	description = "ID of the CI pipeline"
	default = "local"
}

variable "instance_type" {
	type = string
	description = "Type of instance"
	default = "p2.xlarge"
}

variable "environment" {
	type = string
	description = "The environment where the instance is being used. e.g. dev / cicd"
	default = "cicd"
}

variable "setup_params" {
	description = "Parameters to pass to setup.sh script"
  	default = ""
}

variable "key_name" {
	type = string
	description = "The name of the AWS key to use for the created instance(s)"
	default = ""
}

variable "public_key" {
	type = string
	default = "key.pub"
}

variable "private_key" {
  type = string
  description = "The private key associated with the instance key"
  default = "key"
}

variable "ingress_ip_ranges" {
	type = list(string)
	description = "The CIDR blocks to allow SSH access from"
	default = []
}

variable "additional_ingress_ip_ranges" {
	type = list(string)
	description = "CIDR blocks to always append to the CIDR list"
	default = []
}

variable "ami" {
	type = string
	default = ""
}

variable "container_runtime" {
	type = string
	description = "The container runtime to use. [docker | containerd]"
	default = "docker"
}

variable "legacy_setup" {
	type = bool
	description = "Use the legacy setup mechanism when launching a node"
	default = true
}