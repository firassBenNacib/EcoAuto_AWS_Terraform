terraform {
  backend "s3" {
    bucket  = "your-terraform-state-bucket"
    key     = "your/path/to/terraform.tfstate"
    region  = "your-aws-region"
    encrypt = true
  }
}
