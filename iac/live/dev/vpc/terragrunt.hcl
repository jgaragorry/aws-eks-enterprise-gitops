include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/vpc-network"
}

inputs = {
  project_name = "gitops-platform"
  vpc_name     = "vpc-gitops-dev"
  environment  = "dev"
  
  # 🌐 Red Principal (CIDR)
  vpc_cidr     = "10.100.0.0/16"

  # 👇 CORRECCIÓN: Definimos subnets que SÍ caben en 10.100.0.0/16
  public_subnets  = ["10.100.1.0/24", "10.100.2.0/24"]
  private_subnets = ["10.100.101.0/24", "10.100.102.0/24"]
}
