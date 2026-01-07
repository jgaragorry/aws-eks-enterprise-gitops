# ------------------------------------------------------------------------------
# CONFIGURACIÓN GLOBAL DE TERRAGRUNT (DRY)
# ------------------------------------------------------------------------------

# 1. Configuración del Backend Remoto (El Búnker que acabamos de crear)
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "eks-gitops-platform-tfstate-533267117128"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "eks-gitops-platform-tflock"
  }
}

# 2. Configuración del Proveedor AWS (Estabilidad)
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "us-east-1"
  
  # Etiquetado Automático (FinOps): Todo recurso creado llevará estos tags
  default_tags {
    tags = {
      Project     = "AWS-EKS-Enterprise-GitOps"
      ManagedBy   = "Terragrunt"
      Owner       = "Jose Garagorry"
    }
  }
}
EOF
}

# 3. Variables Globales (Para herencia)
inputs = {
  account_id = "533267117128"
  aws_region = "us-east-1"
}
