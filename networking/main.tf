terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }

    backend "s3" {
        bucket         = "d0ej0hn-terraform-state"
        key            = "states/networking/terraform.tfstate"
        region         = "eu-central-1"
        dynamodb_table = "terraform-state-locking"
        encrypt        = true
    }
}

provider "aws" {
    region = "eu-central-1"
}

data "aws_caller_identity" "current" {}

locals {
    tags = merge(
        {
            "belongs_to_project" = "Networking"
        }
    )
    account_id = data.aws_caller_identity.current
}

# The new vpc
resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"

    tags = local.tags
}

# The private subnet
resource "aws_subnet" "private_subnet" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-central-1a"

    tags = local.tags
}

# The public subnet
resource "aws_subnet" "public_subnet" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-central-1a"

    tags = local.tags
}

# create a internet gateway
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.vpc.id

    tags = local.tags
}

# create route table for routes to internet gateway
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = local.tags
}

# route public subnet via public route table with internet gateway
resource "aws_route_table_association" "public_rt_association" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.public_rt.id
}

# Route private subnet via vpc default route table
resource "aws_route_table_association" "private_rt_association" {
    subnet_id = aws_subnet.private_subnet.id
    route_table_id = aws_vpc.vpc.default_route_table_id
}


#region Private Subnet Internet Access

# Create elastic ip for the nat gateway
resource "aws_eip" "elastic_ip" {

    tags = local.tags
}

# Create the nat gateway in the public subnet and associate the public ip to it
resource "aws_nat_gateway" "nat_gateway" {
    allocation_id = aws_eip.elastic_ip.id
    subnet_id = aws_subnet.public_subnet.id

    tags = local.tags
}

# Route traffic from the private subnet to the NAT_GW
resource "aws_route" "private_internet_traffic" {
    route_table_id = aws_vpc.vpc.default_route_table_id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
}

#endregion


#region Security Groups
# Allow SSH from anywhere
resource "aws_security_group" "allow_all_ssh_sec_group" {
    name = "allow_all_ssh"
    description = "allow ssh connections from anywhere"
    vpc_id = aws_vpc.vpc.id

    tags = local.tags
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
    security_group_id = aws_security_group.allow_all_ssh_sec_group.id
    cidr_ipv4 = "0.0.0.0/0"
    from_port = 22
    ip_protocol = "tcp"
    to_port = 22

    tags = local.tags
}

# Allow all outbound traffic
resource "aws_security_group" "allow_all_outbound" {
    name = "allow_all_outbound"
    description = "allow all traffic outwards"
    vpc_id = aws_vpc.vpc.id

    tags = local.tags
}
resource "aws_vpc_security_group_egress_rule" "name" {
    security_group_id = aws_security_group.allow_all_outbound.id
    cidr_ipv4 = "0.0.0.0/0"
    ip_protocol = "-1"
}

# Allow all internal traffic
resource "aws_security_group" "allow_all_internal" {
    name = "allow all internal"
    description = "allow all traffic within the vpc"
    vpc_id = aws_vpc.vpc.id

    tags = local.tags
}
resource "aws_vpc_security_group_egress_rule" "allow_all_outbound_traffic_within_vpc" {
    security_group_id = aws_security_group.allow_all_internal.id
    cidr_ipv4 = aws_vpc.vpc.cidr_block
    ip_protocol = "-1"

    tags = local.tags
}
resource "aws_vpc_security_group_ingress_rule" "allow_all_inbound_traffic_within_vpc" {
    security_group_id = aws_security_group.allow_all_internal.id
    cidr_ipv4 = aws_vpc.vpc.cidr_block
    ip_protocol = "-1"

    tags = local.tags
}
#endregion


#region Instance Creation
resource "aws_instance" "public_instance" {
    ami = "ami-07652eda1fbad7432" # Ubuntu 24.04 Server 64bit-x86
    instance_type = "t2.micro"
    subnet_id = aws_subnet.public_subnet.id
    security_groups = [ 
        aws_security_group.allow_all_internal.id,
        aws_security_group.allow_all_ssh_sec_group.id,
        aws_security_group.allow_all_outbound.id
    ]
    key_name = "AWS_INSTANCE_ACCES_KEY"
    associate_public_ip_address = true
}

resource "aws_instance" "private_instance" {
    ami = "ami-07652eda1fbad7432" # Ubuntu 24.04 Server 64bit-x86
    instance_type = "t2.micro"
    subnet_id = aws_subnet.private_subnet.id
    security_groups = [ 
        aws_security_group.allow_all_internal.id,
        aws_security_group.allow_all_outbound.id,
        aws_security_group.allow_all_ssh_sec_group.id
    ]
    key_name = "AWS_INSTANCE_ACCES_KEY"
}

resource "aws_ec2_instance_connect_endpoint" "private_subnet_connect_endpoint" {
    subnet_id = aws_subnet.private_subnet.id
    security_group_ids = [ 
        aws_security_group.allow_all_internal.id,
        aws_security_group.allow_all_ssh_sec_group.id
    ]
    preserve_client_ip = true
}
#endregion
