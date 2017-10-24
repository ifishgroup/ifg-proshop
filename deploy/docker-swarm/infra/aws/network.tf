resource "aws_vpc" "ifg_proshop_vpc" {
    cidr_block           = "${var.base_cidr_block}"
    enable_dns_support   = true
    enable_dns_hostnames = true

    tags {
      Name = "iFG Proshop VPC"
    }
}
