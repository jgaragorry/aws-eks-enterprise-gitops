# iac/live/root.hcl

locals {
  # ESTA ES LA CLAVE: Terragrunt obtiene tu ID de AWS automáticamente
  account_id = get_aws_account_id()
  region     = "us-east-1"
  
  # Construimos el MISMO nombre que usan los scripts bash
  bucket_name = "eks-gitops-platform-tfstate-${local.account_id}"
  table_name  = "eks-gitops-platform-tflock"
}

remote_state {
  backend = "s3"
  config = {
    bucket         = local.bucket_name
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = local.table_name
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Configuración global de AWS Provider
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"
  allowed_account_ids = ["${local.account_id}"]
}
EOF
}
