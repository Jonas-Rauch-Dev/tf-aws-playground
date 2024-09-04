#region General Variables
variable "region" {
  description = "Default region for provider"
  type        = string
  default     = "eu-central-1"
}

variable "app_name" {
  description = "Name of the web application"
  type        = string
  default     = "web-app"
}

variable "environment_name" {
  description = "Deployment environment (dev/staging/production)"
  type        = string
  default     = "dev"
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
variable "create_dns_zone" {
  description = "If true, create new route53 dns zone, if false read existing route53 zone"
  type = bool
  default = false
}

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

  validation {
    condition = length(var.db_pass) >= 8
    error_message = "The password must be at least 8 characters long"
  }
}

variable "db_instance_class" {
    description = "The instance type of the DB"
    type        = string
    default     = "db.t3.micro"
}

variable "db_instance_version" {
    description = "The postgres version to use for the DB"
    type        = string
    default     = "16"
}

variable "db_allocated_storage" {
    description = "The storage size of the db"
    type        = string
    default     = "5"
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