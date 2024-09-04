output "instance_1_ip_addr" {
    value = aws_instance.instance_1.public_ip
}

output "instance_2_ip_addr" {
    value = aws_instance.instance_2.public_ip
}

output "db_instance_addr" {
    value = aws_db_instance.db_instance.address
}

output "db_connection_string" {
    value = "psql -h ${aws_db_instance.db_instance.address} -U ${var.db_user} -d ${var.db_name}"
}