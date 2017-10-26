# terraform plan \
#   -var 'access_key=foo' \
#   -var 'secret_key=bar'

variable "region" {
  default = "us-west-2"
}

variable "additional_manager_nodes" {
  description = "Additional number of manager nodes (swarm always created with at least 1 manager)"
  default = "2"
}

variable "num_nodes" {
  description = "Number of worker nodes"
  default = "6"
}

variable "availability_zones" {
  description = "Name of the availability zones to use"
  default = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "public_subnet_cidr" {
  description = "CIDR blocks to use for public subnets"
  default = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "private_subnet_cidr" {
  description = "CIDR blocks to use for private subnets"
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_key_name" {
    description = "Name of private_key"
    default = "docker-swarm"
}

variable "private_key_path" {
  description = "Path to file containing private key"
  default     = "~/.ssh/docker-swarm.pem"
}

variable "instance_type" {
  description = "AWS Instance size"
  default     = "t2.micro"
}

variable "environment" {
  description = "Environment type"
  default = "staging"
}

variable "weave_cloud_token" {
    description = "Weave Cloud Token for running Weave Scope"
    default = "ajytwqk7czrmmje8fah1m3o97e5nnw97"
}
