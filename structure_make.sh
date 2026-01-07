# ------------------------------------------------------------------------------
# 🛠️ SCRIPT DE INICIALIZACIÓN DE ESTRUCTURA DEL PROYECTO
# Autor: Jose Garagorry | Rol: Enterprise Cloud Architect
# Objetivo: Crear el esqueleto de directorios para el laboratorio GitOps
# ------------------------------------------------------------------------------

# 1. Crear directorio raíz del proyecto
cd ~/aws-eks-enterprise-gitops

# 2. Crear estructura para Infraestructura (IaC - Terraform/Terragrunt)
# Mantenemos la modularidad: 'modules' (moldes) y 'live' (ambientes)
mkdir -p iac/modules/argo-platform  # Módulo para instalar ArgoCD/Rollouts
mkdir -p iac/live/dev/platform      # Instancia para el ambiente DEV
mkdir -p iac/live/prod/platform     # Instancia para el ambiente PROD

# 3. Crear estructura para la Aplicación (El código fuente)
# Aquí vivirá la app de prueba "colorida" para los demos visuales
mkdir -p app-source/src
mkdir -p app-source/helm-chart      # Empaquetado Helm para simular entorno real

# 4. Crear estructura para GitOps Manifests (El Cerebro de Argo)
# Aquí es donde ArgoCD mirará para saber qué desplegar
mkdir -p gitops-manifests/apps
mkdir -p gitops-manifests/infra

# 5. Crear carpeta de Scripts de Automatización y Seguridad
mkdir -p scripts

# 6. Crear archivos de documentación base (Placeholders)
touch README.md
touch ARCHITECTURE.md
touch SECURITY.md  # 🔒 Nuevo: Política de seguridad explícita
touch FINOPS.md    # 💰 Nuevo: Estrategia de costos explícita

# 7. Inicializar Git
git init
echo "# GitOps Lab Logs" > .gitignore
echo ".terragrunt-cache" >> .gitignore
echo ".terraform" >> .gitignore

echo "✅ Estructura Enterprise creada exitosamente."
