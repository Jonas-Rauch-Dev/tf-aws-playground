#region Provider Config
terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }

    backend "s3" {
        bucket         = "d0ej0hn-terraform-state"
        key            = "states/web-app/terraform.tfstate"
        region         = "eu-central-1"
        dynamodb_table = "terraform-state-locking"
        encrypt        = true
    }
}

provider "aws" {
    region = var.region
}
#endregion

#region Locals
locals {
  tags = merge(
    {
      "belongs_to_project": "Web-App"
    }
  )
}
#endregion

#region VPC + Subnets
resource "aws_vpc" "web-app-vpc" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = local.tags
}

resource "aws_subnet" "public_subnet_a" {
  vpc_id = aws_vpc.web-app-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
  tags = local.tags
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id = aws_vpc.web-app-vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
  tags = local.tags
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.web-app-vpc.id
  tags = local.tags
}

resource "aws_route" "public_route" {
  route_table_id = aws_vpc.web-app-vpc.default_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.internet_gateway.id
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name = "db_subnet_group"
  subnet_ids = [ 
    aws_subnet.public_subnet_a.id, 
    aws_subnet.public_subnet_b.id 
  ]
}
#endregion

#region Security Groups

# INSTANCES
resource "aws_security_group" "instances" {
  name = "allow_http_inbound"
  vpc_id = aws_vpc.web-app-vpc.id
  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_inbound" {
  security_group_id = aws_security_group.instances.id
  from_port = 8080
  to_port = 8080
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

# LOAD BALANCER
resource "aws_security_group" "load_balancer" {
  name = "application_load_balancer_security_group"
  vpc_id = aws_vpc.web-app-vpc.id
  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb_http" {
  security_group_id = aws_security_group.load_balancer.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "allow_alb_all_outbound" {
  security_group_id = aws_security_group.load_balancer.id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}
#endregion

#region S3 Bucket
resource "aws_s3_bucket" "bucket" {
  bucket_prefix = var.bucket_prefix
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_crypto_conf" {
  bucket = aws_s3_bucket.bucket.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
#endregion

#region Load Balancer
resource "aws_lb" "application_load_balancer" {
  name = "web-app-lb"
  load_balancer_type = "application"
  subnets = [
    aws_subnet.public_subnet_a.id,
    aws_subnet.public_subnet_b.id
  ]
  security_groups = [
    aws_security_group.load_balancer.id
  ]

  tags = local.tags
}

resource "aws_lb_target_group" "instances" {
  name = "web-app-instance-target-group"
  port = 8080
  protocol = "HTTP"
  target_type = "instance"
  vpc_id = aws_vpc.web-app-vpc.id

  tags = local.tags
}

resource "aws_lb_target_group_attachment" "instance_1" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id = aws_instance.instance_1.id
  port = 8080
}

resource "aws_lb_target_group_attachment" "instance_2" {
  target_group_arn = aws_lb_target_group.instances.arn
  target_id = aws_instance.instance_2.id
  port = 8080
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.application_load_balancer.arn

  port = 80

  protocol = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code = 404
    }
  }

  tags = local.tags
}

resource "aws_lb_listener_rule" "instances" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.instances.arn
  }

  tags = local.tags
}
#endregion

#region Route 53
resource "aws_route53_zone" "primary" {
  name = var.domain
}

resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_lb.application_load_balancer.dns_name
    zone_id                = aws_lb.application_load_balancer.zone_id
    evaluate_target_health = true
  }
}
#endregion

#region RDS
resource "aws_db_instance" "db_instance" {
  allocated_storage = var.db_allocated_storage
  # This allows any minor version within the major engine_version
  # defined below, but will also result in allowing AWS to auto
  # upgrade the minor version of your DB. This may be too risky
  # in a real production environment.
  auto_minor_version_upgrade = true
  storage_type = "standard"
  engine = "postgres"
  engine_version = var.db_instance_version
  instance_class = var.db_instance_class
  db_name = var.db_name
  username = var.db_user
  password = var.db_pass
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  publicly_accessible = false
}
#endregion

#region Instance definition
resource "aws_instance" "instance_1" {
    ami = var.ami // Ubuntu 24.04 Server 64bit-x86
    instance_type = var.instance_type
    subnet_id = aws_subnet.public_subnet_a.id
    security_groups = [
      aws_security_group.instances.id
    ]
    user_data = <<-EOF
        #!/bin/bash
        echo "Hello, World 1" > index.html
        python3 -m http.server 8080 &
        EOF
}

resource "aws_instance" "instance_2" {
    ami = var.ami // Ubuntu 24.04 Server 64bit-x86
    instance_type = var.instance_type
    subnet_id = aws_subnet.public_subnet_b.id
    security_groups = [
      aws_security_group.instances.id
    ]
    user_data = <<-EOF
        #!/bin/bash
        echo "Hello, World 2" > index.html
        python3 -m http.server 8080 &
        EOF
}
#endregion