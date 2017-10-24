resource "aws_subnet" "public_subnet_az_a" {
  vpc_id = "${aws_vpc.ifg_proshop_vpc.id}"
  cidr_block = "${var.public_subnet_az_a_cidr}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "${var.public_subnet_az_a_cidr} - ${data.aws_availability_zones.available.names[0]}"
  }
}

resource "aws_subnet" "private_subnet_az_a" {
  vpc_id = "${aws_vpc.ifg_proshop_vpc.id}"
  cidr_block = "${var.private_subnet_az_a_cidr}"
  availability_zone = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "${var.private_subnet_az_a_cidr} - ${data.aws_availability_zones.available.names[0]}"
  }
}

resource "aws_route_table_association" "public_route_table_assoc" {
  subnet_id = "${aws_subnet.public_subnet_az_a.id}"
  route_table_id = "${aws_route_table.public.id}"
}


resource "aws_route_table_association" "private_route_table_assoc" {
  subnet_id = "${aws_subnet.private_subnet_az_a.id}"
  route_table_id = "${aws_route_table.private.id}"
}
