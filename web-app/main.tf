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
    region = "eu-central-1"
}

variable "db_pass_1" {
  type = string
  sensitive = true
}


module "web-app-1" {
  source = "./web-app-module"

  bucket_prefix = "web-app-1"
  domain = "zxywu.de"
  app_name = "web-app-1"
  environment_name = "production"
  create_dns_zone = true
  db_name = "webapp1db"
  db_user = "user1"
  db_pass = var.db_pass_1
}