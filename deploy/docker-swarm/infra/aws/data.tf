data "aws_availability_zones" "available" {}

data "aws_ami" "docker_swarm_ami" {
  most_recent = true
  filter {
    name = "name"
    values = ["docker-swarm"]
  }
}
