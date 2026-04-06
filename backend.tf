terraform {
  backend "s3" {
    bucket         = "tommykeyapp-tfstate"
    key            = "shared/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
