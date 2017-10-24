output "elb_address" {
    value = ["${aws_elb.elb.dns_name}"]
}

output "node_addresses" {
  value = ["${aws_instance.docker_swarm_node.*.private_ip}"]
}

output "master_address" {
  value = "${aws_instance.docker_swarm_master.public_ip}"
}
