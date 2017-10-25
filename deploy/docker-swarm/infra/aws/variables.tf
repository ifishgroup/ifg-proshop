variable "region" {
  default = "us-west-2"
}

variable "additional_manager_nodes" {
  description = "Additional number of manager nodes (swarm always created with at least 1 manager)"
  default = "2"
}

variable "num_nodes" {
  description = "Number of worker nodes"
  default = "2"
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
