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