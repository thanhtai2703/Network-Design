provider "aws" {
  region = var.aws_region
}

module "vpc_core" {
  source        = "./modules/vpc_core"
  vpc_cidr      = var.vpc_core_cidr
  project_name  = "VietMove"
}
