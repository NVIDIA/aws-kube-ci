variable "ci_pipeline_id" {
	description = "ID of the CI pipeline"
}

variable "instance_type" {
	description = "Type of instance"
}

variable "project_name" {
	description = "Name of the project"
}

variable "setup_params" {
	description = "Parameters to pass to setup.sh script"
  default = ""
}
