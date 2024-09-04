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