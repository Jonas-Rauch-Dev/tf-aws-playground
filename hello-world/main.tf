terraform {
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
}

provider "aws" {
    region = "eu-central-1"
}

resource "aws_instance" "tf_hello_world" {
    ami = "ami-07652eda1fbad7432" // Ubuntu 24.04 Server 64bit-x86
    instance_type = "t2.micro"
}