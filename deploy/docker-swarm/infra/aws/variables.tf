variable "aws_region" {
  default = "us-west-2"
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

variable "base_cidr_block" {
  default = "10.0.0.0/16"
}

variable "public_subnet_az_a_cidr" {
  description = "CIDR of us-west-2a public subnet"
  default     = "10.0.1.0/27"
}

variable "private_subnet_az_a_cidr" {
  description = "CIDR of us-west-2a private subnet"
  default     = "10.0.2.0/25"
}
