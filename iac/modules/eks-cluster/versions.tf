# ------------------------------------------------------------------------------
# Restricciones de versiones de proveedores
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # LECCIÓN: Prohibimos la v6.0 hasta que el módulo upstream se actualice.
      # Esto permite cualquier versión 5.x (ej: 5.80, 5.83), pero bloquea la 6.0.
      version = ">= 5.0, < 6.0"
    }
    # ... otros proveedores
  }
}
