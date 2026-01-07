# ------------------------------------------------------------------------------
# Lógica principal del recurso para eks-cluster
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ☸️ AWS EKS MODULE
# Best Practice: Nodos en redes privadas, Endpoint público habilitado pero seguro.
# ------------------------------------------------------------------------------

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.1"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Red
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Seguridad del API Server
  cluster_endpoint_public_access = true
  cluster_endpoint_private_access = true

  # OIDC Provider (Crucial para que los Pods tengan permisos de AWS IAM)
  enable_irsa = true

  # Addons Básicos de EKS
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  #  aws-ebs-csi-driver = {
  #    most_recent = true # Necesario para volúmenes persistentes
  #  }
  }

  # Configuración de Nodos (Managed Node Groups)
  eks_managed_node_groups = {
    general = {
      min_size     = 1
      max_size     = 2
      desired_size = 2

      instance_types = ["t3.medium"] # t3.micro es muy pequeño para EKS
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "general"
      }
      
      # Tagging para FinOps
      tags = {
        Environment = var.environment
        Team        = "DevOps"
      }
    }
  }

  # Permisos de Administrador (TÚ)
  # Esto te da permisos de 'system:masters' automáticamente
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = var.environment
    Project     = "AWS-EKS-Enterprise-Ingress"
  }
}
