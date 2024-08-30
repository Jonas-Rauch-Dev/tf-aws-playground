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
            "modified_at" = timestamp()
        }
    )
    account_id = data.aws_caller_identity.current
}

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    instance_tenancy = "default"

    tags = local.tags
}

resource "aws_subnet" "public_subnet" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-central-1a"

    tags = local.tags
}

resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.vpc.id

    tags = local.tags
}

resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }

    tags = local.tags
}

resource "aws_route_table_association" "public_rt_association" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.public_rt.id
}