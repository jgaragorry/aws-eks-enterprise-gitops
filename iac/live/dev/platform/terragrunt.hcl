include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  # Apunta a nuestro módulo interno de ArgoCD
  source = "../../../modules/argo-platform"
}

# Dependencia del clúster EKS (necesitamos saber dónde instalarlo)
dependency "eks" {
  config_path = "../eks"
  
  mock_outputs = {
    cluster_name     = "eks-gitops-dev"
    cluster_endpoint = "https://example.com"
    cluster_ca       = "dummymockdata"
  }
}

# Configuración del proveedor Kubernetes usando los datos del EKS real
generate "provider_k8s" {
  path      = "provider_k8s.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
data "aws_eks_cluster" "cluster" {
  name = "${dependency.eks.outputs.cluster_name}"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "${dependency.eks.outputs.cluster_name}"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}
EOF
}

inputs = {
  env          = "dev"
  cluster_name = dependency.eks.outputs.cluster_name
  
  # Valores personalizados para ArgoCD (FinOps: Versión ligera sin HA para Dev)
  argocd_values = [
    <<EOF
server:
  replicas: 1  # Ahorro de recursos en Dev (Prod usaría 2 o 3)
  service:
    type: LoadBalancer # Exponer ArgoCD (Cuidado: Esto crea un CLB/ALB)
repoServer:
  replicas: 1
applicationController:
  replicas: 1
redis:
  ha:
    enabled: false # Redis simple para ahorrar
EOF
  ]
}
