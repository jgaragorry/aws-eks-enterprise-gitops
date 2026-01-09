# 📘 AWS EKS Enterprise GitOps - Master Runbook v5.0

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![FinOps](https://img.shields.io/badge/FinOps-Extreme%20Audit-success?style=for-the-badge&logo=cash-app&logoColor=white)

Este documento es la **Fuente Única de la Verdad**. Sigue los pasos linealmente para desplegar, operar y destruir el laboratorio sin errores ni costos sorpresa.

---

## 📋 Tabla de Contenidos
1. [Requisitos Previos](#1-requisitos-previos)
2. [Fase 0: Cimientos (Backend Remoto)](#3-fase-0-cimientos-backend-remoto)
3. [Fase 1: Infraestructura (VPC & EKS)](#4-fase-1-infraestructura-vpc--eks)
4. [Fase 2: Plataforma GitOps (ArgoCD)](#5-fase-2-plataforma-gitops-argocd)
5. [Fase 3: Operación (Canary Deployments)](#6-fase-3-operación-canary-deployments)
6. [Fase 4: Destrucción Total (Protocolo FinOps)](#7-fase-4-destrucción-total-protocolo-finops)

---

## 1. Requisitos Previos

Herramientas necesarias en tu terminal:
- `aws` (v2+)
- `terraform` / `terragrunt`
- `kubectl`

**Permisos de ejecución:**
Antes de empezar, asegúrate de que los scripts de automatización sean ejecutables.
```bash
chmod +x scripts/*.sh
```

---

## 3. Fase 0: Cimientos (Backend Remoto)

Creamos el bucket S3 y la tabla DynamoDB para guardar el estado de Terraform de forma segura.

```bash
# 1. Crear Backend
./scripts/setup_backend.sh

# 2. Verificar que existe
./scripts/check_backend.sh
```
*Output esperado: `[EXISTE]` en verde.*

---

## 4. Fase 1: Infraestructura (VPC & EKS)

Provisionamos la red y el clúster de Kubernetes.

### 1. Desplegar Red (VPC)
```bash
cd ~/aws-eks-enterprise-gitops/iac/live/dev/vpc
terragrunt init
terragrunt apply -auto-approve
```

### 2. Desplegar Clúster (EKS)
```bash
cd ~/aws-eks-enterprise-gitops/iac/live/dev/eks
terragrunt init
terragrunt apply -auto-approve
```

### 3. Conectar tu Terminal al Clúster
```bash
aws eks update-kubeconfig --region us-east-1 --name eks-gitops-dev
kubectl get nodes
```
*Output esperado: Lista de nodos en estado `Ready`.*

---

## 5. Fase 2: Plataforma GitOps (ArgoCD)

Instalamos el controlador ArgoCD y registramos la aplicación.

### 1. Instalar ArgoCD
```bash
cd ~/aws-eks-enterprise-gitops/iac/live/dev/platform
terragrunt init
terragrunt apply -auto-approve
```

### 2. Obtener Acceso (URL y Password)
```bash
echo "🌐 URL:" && kubectl -n argocd get svc argocd-server -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"; echo ""
echo "🔑 Pass:" && kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo ""
```
*Ingresa a la URL con usuario `admin` y el password obtenido.*

### 3. Bootstrapping de la App (¡Paso Crítico!)
ArgoCD arranca vacío. Ejecuta esto para conectar el repositorio Git.

```bash
cd ~/aws-eks-enterprise-gitops
kubectl apply -f gitops-manifests/apps/colors-app.yaml
```
*Ve al Dashboard de ArgoCD: Deberías ver la tarjeta "colors-app" sincronizando.*

---

## 6. Fase 3: Operación (Canary Deployments)

Simularemos un despliegue real de software cambiando la versión de la app.

**1. Editar Código:**
Modifica `app-source/helm-chart/values.yaml`. Cambia `tag: blue` por `tag: green`.

**2. Enviar a Git:**
```bash
git add .
git commit -m "feat: release green version"
git push
```

**3. Observar en ArgoCD:**
- Argo detectará el cambio y comenzará el despliegue.
- **Argo Rollouts** detendrá el despliegue al 20% (Estado `Paused`).
- Verifica los nuevos pods y presiona **"Promote-Full"** en la UI para completar la migración.

---

## 7. Fase 4: Destrucción Total (Protocolo FinOps)

**⚠️ IMPORTANTE:** Sigue este orden EXACTO para evitar bloqueos y costos "zombies".

### 1. Destruir Infraestructura (De arriba hacia abajo)
Ignoramos errores de ArgoCD y vamos directo a destruir el clúster para liberar recursos.

```bash
# 1. Destruir EKS (Esto eliminará los Nodos y ArgoCD)
cd ~/aws-eks-enterprise-gitops/iac/live/dev/eks
terragrunt destroy -auto-approve

# 2. LIMPIEZA PREVENTIVA DE BALANCEADORES (Anti-Deadlock)
# Este script elimina los Load Balancers huérfanos que bloquean la VPC.
cd ~/aws-eks-enterprise-gitops
./scripts/nuke_loadbalancers.sh

# 3. Limpieza de Interfaces de Red
# CORRECCIÓN V5.0: Buscamos por etiqueta 'Name' para asegurar que encontramos el ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=gitops-platform-dev-vpc" --query "Vpcs[0].VpcId" --output text)
./scripts/nuke_vpc.sh $VPC_ID

# 4. Destruir VPC (Ahora que está limpia)
cd ~/aws-eks-enterprise-gitops/iac/live/dev/vpc
terragrunt destroy -auto-approve
```

### 2. Limpieza de Residuos (Zombies)
Elimina Logs de CloudWatch y llaves KMS que Terraform no borra.

```bash
cd ~/aws-eks-enterprise-gitops
./scripts/nuke_zombies.sh
```

### 3. Eliminar Backend (El Gran Reset)
Solo ejecuta esto al final. Borra el estado de Terraform.

```bash
./scripts/nuke_backend_smart.sh
```

### 4. Auditoría Final Extrema
Verificación final para garantizar costo $0.

```bash
./scripts/finops_audit.sh
```
*Si todas las tablas están vacías, has completado el laboratorio exitosamente.*
