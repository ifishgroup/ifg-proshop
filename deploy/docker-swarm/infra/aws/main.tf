provider "aws" {
  region = "${var.aws_region}"
}

data "aws_ami" "docker_swarm_ami" {
  most_recent = true
  filter {
    name = "name"
    values = ["docker-swarm"]
  }
}

# Create a new load balancer
resource "aws_elb" "elb" {
  name               = "ifg-proshop-elb"
  subnets            = ["${aws_subnet.public_subnet_az_a.id}"]
  security_groups    = ["${aws_security_group.elb_sg.id}"]

  listener {
    instance_port     = 30000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:30000/"
    interval            = 60
  }

  instances                   = ["${aws_instance.docker_swarm_master.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags {
    Name = "ifg-proshop-docker-swarm-elb"
  }
}

resource "aws_instance" "docker_swarm_node" {
  depends_on      = [ "aws_instance.docker_swarm_master" ]
  count           = "${var.num_nodes}"
  instance_type   = "${var.instance_type}"
  ami             = "${data.aws_ami.docker_swarm_ami.id}"
  key_name        = "${var.private_key_name}"
  security_groups = ["${aws_security_group.docker_swarm_sg.id}"]
  subnet_id       = "${aws_subnet.private_subnet_az_a.id}"
  associate_public_ip_address = "false"

  tags {
    Name = "ifg-proshop-docker-swarm-node"
  }

  connection {
    user = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    bastion_host = "${aws_instance.docker_swarm_master.public_ip}"
  }

  provisioner "file" {
    source = "join.sh",
    destination = "/tmp/join.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo service docker start",
      "chmod +x /tmp/join.sh",
      "/tmp/join.sh"
    ]
  }
}

resource "aws_instance" "docker_swarm_master" {
  instance_type     = "${var.instance_type}"
  ami               = "${data.aws_ami.docker_swarm_ami.id}"
  key_name          = "${var.private_key_name}"
  security_groups   = ["${aws_security_group.docker_swarm_sg.id}"]
  subnet_id         = "${aws_subnet.public_subnet_az_a.id}"
  associate_public_ip_address = "true"

  tags {
    Name = "ifg-proshop-docker-swarm-master"
  }

  connection {
    user = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
  }

  provisioner "file" {
    source = "deploy/docker-swarm/docker-compose.yml"
    destination = "/tmp/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo service docker start",
      "docker swarm init"
    ]
  }

  provisioner "local-exec" {
    command = "TOKEN=$(ssh -i ${var.private_key_path} -o StrictHostKeyChecking=no ubuntu@${aws_instance.docker_swarm_master.public_ip} docker swarm join-token -q worker); echo \"#!/usr/bin/env bash\ndocker swarm join --token $TOKEN ${aws_instance.docker_swarm_master.public_ip}:2377\" >| join.sh"
  }
}

resource "null_resource" "deploy_docker_stack" {
  depends_on = [ "aws_instance.docker_swarm_node" ]

  connection {
    user = "ubuntu"
    private_key = "${file("${var.private_key_path}")}"
    host = "${aws_instance.docker_swarm_master.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "docker-compose -f /tmp/docker-compose.yml pull",
      "docker-compose -f /tmp/docker-compose.yml bundle -o dockerswarm.dab",
      "docker deploy dockerswarm"
    ]
  }

  provisioner "local-exec" {
    command = "rm join.sh"
  }
}
