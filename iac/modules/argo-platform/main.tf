# ------------------------------------------------------------------------------
# 1. Namespace Dedicado (Aislamiento)
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "name"        = "argocd"
      "environment" = var.env
      "managed-by"  = "terraform"
      "security"    = "critical" # Etiqueta para auditoría de seguridad
    }
  }
}

# ------------------------------------------------------------------------------
# 2. Despliegue de ArgoCD (Helm)
# ------------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  
  # Esperar a que todos los pods estén verdes antes de marcar éxito
  wait          = true
  wait_for_jobs = true

  # Inyección de valores personalizados (aquí entra la optimización FinOps)
  values = var.argocd_values

  # Timeout extendido para evitar fallos en la primera instalación
  timeout = 600
}

# ------------------------------------------------------------------------------
# 3. Argo Rollouts (Para el Progressive Delivery futuro)
# ------------------------------------------------------------------------------
resource "helm_release" "argo_rollouts" {
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  version    = "2.37.0" # Versión compatible con el dashboard
  namespace  = kubernetes_namespace.argocd.metadata[0].name # Mismo namespace para simplificar gestión

  set {
    name  = "dashboard.enabled"
    value = "true"
  }
}
