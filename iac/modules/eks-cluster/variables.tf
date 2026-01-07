# ------------------------------------------------------------------------------
# Definición de variables de entrada para eks-cluster
# ------------------------------------------------------------------------------

variable "cluster_name" {
  description = "Nombre del cluster EKS"
  type        = string
}

variable "cluster_version" {
  description = "Versión de Kubernetes"
  type        = string
  default     = "1.29"
}

variable "vpc_id" {
  description = "ID de la VPC donde se desplegará"
  type        = string
}

variable "subnet_ids" {
  description = "Lista de Subnets PRIVADAS para los nodos"
  type        = list(string)
}

variable "environment" {
  description = "Entorno (dev, prod)"
  type        = string
}
