# Declare the data source
data "aws_availability_zones" "available" {}

resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.ifg_proshop_vpc.id}"
  tags {
    Name = "iFG Proshop Internet Gateway"
  }
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.ifg_proshop_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

  tags {
    Name = "Public Route"
  }
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.ifg_proshop_vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.ngw.id}"
  }

  tags {
    Name = "Private Route"
  }
}

resource "aws_eip" "eip" {
  vpc        = true
  depends_on = ["aws_internet_gateway.igw"]
}

resource "aws_nat_gateway" "ngw" {
  depends_on    = ["aws_internet_gateway.igw"]
  allocation_id = "${aws_eip.eip.id}"
  subnet_id     = "${aws_subnet.public_subnet_az_a.id}"

  tags {
    Name = "iFG Proshop NAT Gateway"
  }
}
