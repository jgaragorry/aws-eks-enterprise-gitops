# Security Policy

## Supported Versions

Actualmente, solo la última versión de este laboratorio recibe parches de seguridad y mantenimiento.

| Version | Supported |
| :--- | :--- |
| 3.0.x | ✅ |
| 2.0.x | ❌ |
| 1.0.x | ❌ |

## Reporting a Vulnerability

Este es un repositorio educativo para demostración de GitOps y EKS. Sin embargo, aplicamos buenas prácticas:

1.  **NO** subas credenciales reales de AWS (Access Keys) ni archivos `terraform.tfstate` con datos sensibles al repositorio. Asegúrate de que tu `.gitignore` esté correctamente configurado.
2.  Si encuentras un fallo de seguridad en el código de infraestructura (ej. un Security Group demasiado permisivo `0.0.0.0/0`), por favor abre un **Issue** en GitHub describiendo el hallazgo.
3.  Los secretos de ArgoCD (`admin` password) son generados dinámicamente en cada despliegue por Kubernetes; no están hardcodeados en el repositorio.

### Escaneo de Seguridad Recomendado
Se recomienda usar herramientas como **Trivy** o **Checkov** antes de desplegar este código en un entorno productivo real para verificar el cumplimiento con estándares CIS (Center for Internet Security).

```bash
# Ejemplo de escaneo local
trivy config ./iac
```
