#region General Variables
variable "region" {
  description = "Default region for provider"
  type        = string
  default     = "eu-central-1"
}
#endregion

#region EC2
variable "ami" {
  description = "Amazon machine image to use for ec2 instance"
  type        = string
  default     = "ami-07652eda1fbad7432" # Ubuntu 24.04 LTS // eu-central-1
}

variable "instance_type" {
  description = "ec2 instance type"
  type        = string
  default     = "t2.micro"
}
#endregion

#region S3
variable "bucket_prefix" {
  description = "prefix of s3 bucket for app data"
  type        = string
}
#endregion

#region Route 53
variable "domain" {
  description = "Domain for website"
  type        = string
}
#endregion

#region RDS
variable "db_name" {
  description = "Name of DB"
  type        = string
}

variable "db_user" {
  description = "Username for DB"
  type        = string
}

variable "db_pass" {
  description = "Password for DB"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
    description = "The instance type of the DB"
    type        = string
}

variable "db_instance_version" {
    description = "The postgres version to use for the DB"
    type        = string
}

variable "db_allocated_storage" {
    description = "The storage size of the db"
    type        = string
}
#endregion