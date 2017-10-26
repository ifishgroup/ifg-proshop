terraform {
  required_version = "~> 0.10.7"
}

provider "aws" {
  region = "${var.region}"
}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = "ifg-proshop-vpc"
  cidr                 = "10.0.0.0/16"
  # azs                  = ["${data.aws_availability_zones.available.names[0]}", "${data.aws_availability_zones.available.names[1]}", "${data.aws_availability_zones.available.names[2]}"]
  azs                  = "${var.availability_zones}"
  private_subnets      = "${var.private_subnet_cidr}"
  public_subnets       = "${var.public_subnet_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true
  single_nat_gateway   = true

  tags = {
    Owner       = "iFG Labs"
    Environment = "${var.environment}"
  }
}

resource "aws_elb" "elb" {
  name               = "ifg-proshop-elb"
  subnets            = ["${module.vpc.public_subnets}"]
  security_groups    = ["${aws_security_group.elb_sg.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 60
  }

  instances                   = ["${aws_instance.docker_swarm_manager_init.id}", "${aws_instance.docker_swarm_managers.*.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "ifg-proshop-docker-swarm-elb"
    Environment = "${var.environment}"
  }
}

resource "aws_instance" "docker_swarm_manager_init" {
  instance_type          = "${var.instance_type}"
  ami                    = "${data.aws_ami.docker_swarm_ami.id}"
  key_name               = "${var.private_key_name}"
  vpc_security_group_ids = ["${aws_security_group.docker_swarm_sg.id}", "${aws_security_group.docker_swarm_managers_sg.id}"]
  subnet_id              = "${module.vpc.public_subnets[0]}"
  associate_public_ip_address = "true"

  tags {
    Name = "ifg-proshop-docker-swarm-master"
    Environment = "${var.environment}"
  }

  connection {
    user = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo service docker start",
      "docker swarm init"
    ]
  }

  provisioner "local-exec" {
    command = "TOKEN=$(ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_instance.docker_swarm_manager_init.public_ip} docker swarm join-token -q worker); echo \"#!/usr/bin/env bash\ndocker swarm join --token $TOKEN ${aws_instance.docker_swarm_manager_init.public_ip}:2377\" >| join_worker.sh"
  }

  provisioner "local-exec" {
    command = "TOKEN=$(ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_instance.docker_swarm_manager_init.public_ip} docker swarm join-token -q manager); echo \"#!/usr/bin/env bash\ndocker swarm join --token $TOKEN ${aws_instance.docker_swarm_manager_init.public_ip}:2377\" >| join_manager.sh"
  }
}

resource "aws_instance" "docker_swarm_managers" {
  depends_on             = [ "aws_instance.docker_swarm_manager_init" ]
  count                  = "${var.additional_manager_nodes}"
  instance_type          = "${var.instance_type}"
  ami                    = "${data.aws_ami.docker_swarm_ami.id}"
  key_name               = "${var.private_key_name}"
  vpc_security_group_ids = ["${aws_security_group.docker_swarm_sg.id}", "${aws_security_group.docker_swarm_managers_sg.id}"]
  subnet_id              = "${element(module.vpc.public_subnets, count.index + 1)}"
  associate_public_ip_address = "true"

  tags {
    Name = "ifg-proshop-docker-swarm-manager-${count.index}"
    Environment = "${var.environment}"
  }

  connection {
    user = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "file" {
    source = "join_manager.sh",
    destination = "/tmp/join_manager.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo service docker start",
      "chmod +x /tmp/join_manager.sh",
      "/tmp/join_manager.sh"
    ]
  }
}


resource "aws_instance" "docker_swarm_workers" {
  depends_on             = [ "aws_instance.docker_swarm_manager_init" ]
  count                  = "${var.num_nodes}"
  instance_type          = "${var.instance_type}"
  ami                    = "${data.aws_ami.docker_swarm_ami.id}"
  key_name               = "${var.private_key_name}"
  vpc_security_group_ids = ["${aws_security_group.docker_swarm_sg.id}"]
  subnet_id              = "${element(module.vpc.private_subnets, count.index)}"
  associate_public_ip_address = "false"

  tags {
    Name = "ifg-proshop-docker-swarm-node-${count.index}"
    Environment = "${var.environment}"
  }

  connection {
    user = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    bastion_host = "${aws_instance.docker_swarm_manager_init.public_ip}"
  }

  provisioner "file" {
    source = "join_worker.sh",
    destination = "/tmp/join_worker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo service docker start",
      "chmod +x /tmp/join_worker.sh",
      "/tmp/join_worker.sh"
    ]
  }
}

resource "null_resource" "create_docker_networks" {
  depends_on = [ "aws_instance.docker_swarm_manager_init" ]

  connection {
    user = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    host = "${aws_instance.docker_swarm_manager_init.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "docker network create --driver overlay monitoring",
      "docker network create --driver overlay frontend",
      "docker network create --driver overlay services",
      "docker network create --driver overlay backend"
    ]
  }

}

resource "null_resource" "deploy_docker_stack" {
  depends_on = [ "aws_instance.docker_swarm_workers", "null_resource.create_docker_networks" ]

  connection {
    user = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    host = "${aws_instance.docker_swarm_manager_init.public_ip}"
  }

  provisioner "file" {
    source = "deploy/docker-swarm/docker-compose.yml"
    destination = "/tmp/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "docker-compose -f /tmp/docker-compose.yml pull",
      "docker stack deploy -c /tmp/docker-compose.yml ifg-proshop"
    ]
  }
}

resource "null_resource" "deploy_monitoring_stack" {
  depends_on = [ "aws_instance.docker_swarm_workers", "null_resource.create_docker_networks" ]

  connection {
    user = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    host = "${aws_instance.docker_swarm_manager_init.public_ip}"
  }

  provisioner "file" {
    source = "monitoring"
    destination = "/tmp/monitoring"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/monitoring/deploy-monitoring-services.sh",
      "/tmp/monitoring/deploy-monitoring-services.sh $(hostname)"
    ]
  }
}


resource "null_resource" "launch_weave_scope" {
  depends_on = [ "aws_instance.docker_swarm_manager_init" ]

  connection {
    user = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    host = "${aws_instance.docker_swarm_manager_init.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "docker service create --name scope-launcher --mode global --detach --restart-condition none --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock weaveworks/scope-swarm-launcher scope launch --service-token=${var.weave_cloud_token}"
    ]
  }
}

resource "null_resource" "cleanup" {
  depends_on = [ "null_resource.deploy_docker_stack" ]

  provisioner "local-exec" {
    command = "rm join_worker.sh"
  }

  provisioner "local-exec" {
    command = "rm join_manager.sh"
  }
}
