variable "env" {
  description = "Entorno de despliegue (dev, prod). Se usa para etiquetado y lógica condicional."
  type        = string
}

variable "argocd_chart_version" {
  description = "Versión específica del Helm Chart de ArgoCD a instalar (Security Pinning)."
  type        = string
  default     = "7.3.4" # Versión estable probada (App v2.11.x)
}

variable "argocd_values" {
  description = "Lista de bloques YAML para sobreescribir la configuración por defecto de ArgoCD (Helm values)."
  type        = list(string)
  default     = []
}

variable "cluster_name" {
  description = "Nombre del clúster EKS donde se instalará (para fines de auditoría)."
  type        = string
}
