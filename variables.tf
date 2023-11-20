variable "region" {
  type    = string
  default = "us-east-2"
}

variable "image_name" {
  type    = string
  default = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
}

variable "ami" {
  type    = string
  default = ""
}

variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "development"
}

variable "ci_pipeline_id" {
  type        = string
  description = "ID of the CI pipeline"
  default     = "local"
}

variable "instance_type" {
  type        = string
  description = "Type of instance"
  default     = "g4dn.xlarge"
}

variable "environment" {
  type        = string
  description = "The environment where the instance is being used. e.g. dev / cicd"
  default     = "cicd"
}

variable "setup_params" {
  description = "Parameters to pass to setup.sh script"
  default     = ""
}

variable "key_name" {
  type        = string
  description = "The name of the AWS key to use for the created instance(s)"
  default     = ""
}

variable "public_key" {
  type    = string
  default = "key.pub"
}

variable "private_key" {
  type        = string
  description = "The private key associated with the instance key"
  default     = "key"
}

variable "max_ingress_rules" {
  type        = number
  description = "The maximum number of ingress rules per security group"
  default     = 60
}

variable "ingress_ip_ranges" {
  type        = list(string)
  description = "The CIDR blocks to allow SSH access from"
  default     = []
}

variable "additional_ingress_ip_ranges" {
  type        = list(string)
  description = "CIDR blocks to always append to the CIDR list"
  default     = []
}

variable "kubernetes_enabled" {
  type        = bool
  description = "install kubernetes components"
  default     = true
}

variable "kubernetes_features" {
  type        = string
  description = "The kubernetes features to enable"
  default     = ""
}

variable "container_runtime" {
  type        = string
  description = "The container runtime and it's version to use [containerd | crio | docker ]"
  default     = "containerd"
}

variable "containerd_version" {
  type        = string
  description = "The version of containerd to install"
  default     = "1.6.24"
}

variable "docker_version" {
  type        = string
  description = "The version of docker to install"
  default     = "latest"
}

variable "crio_version" {
  type        = string
  description = "The version of crio to install"
  default     = "1.26"
}

variable "kubernetes_version" {
  type        = string
  description = "The version of kubernetes to install"
  default     = "v1.27.6"
}
