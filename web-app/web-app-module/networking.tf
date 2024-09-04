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
  name = "${var.app_name}-${var.environment_name}-allow_http_inbound"
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
  name = "${var.app_name}-${var.environment_name}-application_load_balancer_security_group"
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

#region Load Balancer
resource "aws_lb" "application_load_balancer" {
  name = "${var.app_name}-${var.environment_name}-web-app-lb"
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
  name = "${var.app_name}-${var.environment_name}-lb-tg"
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