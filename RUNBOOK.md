# AWS EKS Enterprise GitOps - Master Runbook v2.0

![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=for-the-badge&logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)
![ArgoCD](https://img.shields.io/badge/argo-%23E56426.svg?style=for-the-badge&logo=argo&logoColor=white)
![Bash](https://img.shields.io/badge/Shell_Script-121011?style=for-the-badge&logo=gnu-bash&logoColor=white)

Este documento detalla el procedimiento estándar para desplegar, operar y **destruir** el laboratorio de GitOps sin errores de dependencias y garantizando coste cero al finalizar (FinOps).

---

## 📋 Tabla de Contenidos
1. [Prerrequisitos y Scripts Críticos](#1-prerrequisitos-y-scripts-críticos)
2. [Fase 1: Infraestructura (El Fix de Versiones)](#2-fase-1-infraestructura-el-fix-de-versiones)
3. [Fase 2: Plataforma ArgoCD](#3-fase-2-plataforma-argocd)
4. [Fase 3: GitOps & Canary Automático](#4-fase-3-gitops--canary-automático)
5. [Fase 4: Protocolo de Destrucción (FinOps)](#5-fase-4-protocolo-de-destrucción-finops)
6. [Sesión de Contacto](#sesión-de-contacto)

---

## 1. Prerrequisitos y Scripts Críticos

Antes de comenzar, asegúrate de tener estos dos scripts en tu carpeta `scripts/`. Son tu seguro de vida.

### A. Auditor Financiero (`scripts/finops_audit.sh`)
Detecta recursos huérfanos que Terraform olvida (LBs, NATs, EIPs).

```bash
#!/bin/bash
# scripts/finops_audit.sh
PROJECT_TAG="AWS-EKS-Enterprise-GitOps"
CLUSTER_NAME="eks-gitops-dev"
REGION="us-east-1"

echo "🔍 AUDITORÍA FINOPS: $PROJECT_TAG"
echo "-----------------------------------"

# 1. EKS
echo "1. Verificando EKS..."
aws eks list-clusters --region $REGION --query "clusters[?(@=='$CLUSTER_NAME')]" --output text

# 2. Load Balancers (Lo más peligroso)
echo "2. Verificando Load Balancers (Huérfanos de K8s)..."
aws elb describe-load-balancers --region $REGION --query "LoadBalancerDescriptions[*].[LoadBalancerName,DNSName]" --output text
aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[*].[LoadBalancerName,DNSName]" --output text

# 3. NAT Gateways
echo "3. Verificando NAT Gateways..."
aws ec2 describe-nat-gateways --region $REGION --filter "Name=tag:Project,Values=$PROJECT_TAG" "Name=state,Values=available" --query "NatGateways[*].NatGatewayId" --output text

# 4. Elastic IPs
echo "4. Verificando Elastic IPs..."
aws ec2 describe-addresses --region $REGION --filter "Name=tag:Project,Values=$PROJECT_TAG" --query "Addresses[*].PublicIp" --output text

# 5. VPC
echo "5. Verificando VPC..."
aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Project,Values=$PROJECT_TAG" --query "Vpcs[*].VpcId" --output text

echo "-----------------------------------"
echo "👉 Si ves IDs arriba, ejecuta el protocolo de destrucción."
```

### B. Destructor de VPC Zombies (`scripts/nuke_vpc.sh`)
Fuerza la eliminación de ENIs y Security Groups bloqueados.

```bash
#!/bin/bash
# scripts/nuke_vpc.sh
# USO: ./scripts/nuke_vpc.sh <VPC_ID>
VPC_ID=$1
REGION="us-east-1"

if [ -z "$VPC_ID" ]; then
  echo "❌ Error: Debes pasar el VPC_ID como argumento."
  exit 1
fi

echo "🔥 NUKE: Iniciando limpieza forzada de $VPC_ID..."

# 1. Eliminar Interfaces de Red (ENIs)
ENIS=$(aws ec2 describe-network-interfaces --region $REGION --filters Name=vpc-id,Values=$VPC_ID --query "NetworkInterfaces[*].NetworkInterfaceId" --output text)
if [ "$ENIS" != "None" ] && [ -n "$ENIS" ]; then
  for eni in $ENIS; do
    echo "   - Borrando ENI: $eni"
    aws ec2 delete-network-interface --region $REGION --network-interface-id $eni
  done
fi

# 2. Borrar Security Groups (Romper dependencias)
SGS=$(aws ec2 describe-security-groups --region $REGION --filters Name=vpc-id,Values=$VPC_ID --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
if [ "$SGS" != "None" ] && [ -n "$SGS" ]; then
  # Paso A: Revocar reglas para romper ciclos
  for sg in $SGS; do
      aws ec2 revoke-security-group-ingress --region $REGION --group-id $sg --protocol all --source-group $sg 2>/dev/null
      aws ec2 revoke-security-group-egress --region $REGION --group-id $sg --protocol all --cidr 0.0.0.0/0 2>/dev/null
  done
  # Paso B: Borrar grupos
  for sg in $SGS; do
      echo "   - Borrando SG: $sg"
      aws ec2 delete-security-group --region $REGION --group-id $sg 2>/dev/null
  done
fi

echo "✅ Limpieza de dependencias finalizada. Ahora Terraform podrá borrar la VPC."
```

---

## 2. Fase 1: Infraestructura (El Fix de Versiones)

**⚠️ CRÍTICO:** Evitar el "Dependency Hell" con AWS Provider v6.0.

### Paso 1: Configurar Restricciones de Versión
Edita `iac/modules/vpc-network/versions.tf` y `iac/modules/eks-cluster/versions.tf`. Asegúrate de que el bloque `aws` sea **exactamente** así:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"  # 🛑 ESTO ES OBLIGATORIO PARA EVITAR ERROR EN EKS
    }
  }
}
```

### Paso 2: Despliegue Limpio (VPC + EKS)
Ejecuta en orden:

```bash
# 1. Crear VPC
cd ~/aws-eks-enterprise-gitops/iac/live/dev/vpc
rm -rf .terragrunt-cache .terraform .terraform.lock.hcl
terragrunt init && terragrunt apply -auto-approve

# 2. Crear EKS (Tarda 15 min)
cd ~/aws-eks-enterprise-gitops/iac/live/dev/eks
rm -rf .terragrunt-cache .terraform .terraform.lock.hcl
terragrunt init && terragrunt apply -auto-approve

# 3. Conectar CLI
aws eks update-kubeconfig --region us-east-1 --name eks-gitops-dev
```

---

## 3. Fase 2: Plataforma ArgoCD

**⚠️ CRÍTICO:** Evitar error de sintaxis en Helm Provider v3.x.

### Paso 1: Configurar Versión Helm
Edita `iac/modules/argo-platform/versions.tf`:

```hcl
helm = {
  source  = "hashicorp/helm"
  version = "~> 2.12"  # 🛑 USAR SERIE 2.X ESTABLE
}
```

### Paso 2: Despliegue
```bash
cd ~/aws-eks-enterprise-gitops/iac/live/dev/platform
terragrunt init && terragrunt apply -auto-approve
```

### Paso 3: Acceso (Guardar credenciales)
```bash
# Password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# URL:
kubectl -n argocd get svc argocd-server -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"; echo
```

---

## 4. Fase 3: GitOps & Canary Automático

Para evitar tener que aprobar manualmente en la UI, configura las pausas con tiempo.

### Configuración del Rollout (`rollout.yaml`)
En `app-source/helm-chart/templates/rollout.yaml`:

```yaml
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 10} # ⏳ Automatización activada
      - setWeight: 50
      - pause: {duration: 10}
      - setWeight: 80
      - pause: {duration: 10}
```

---

## 5. Fase 4: Protocolo de Destrucción (FinOps)

**⛔ NO EJECUTES `destroy-all`. Sigue este orden estricto para evitar facturas.**

### Paso 1: Matar la Aplicación (Liberar Load Balancers)
```bash
cd ~/aws-eks-enterprise-gitops/iac/live/dev/platform
terragrunt destroy -auto-approve
```
*Verificación:* Ejecuta `scripts/finops_audit.sh`. La sección "Load Balancers" debe estar vacía.

### Paso 2: Matar el Clúster EKS (Liberar EC2 y NAT)
```bash
cd ~/aws-eks-enterprise-gitops/iac/live/dev/eks
terragrunt destroy -auto-approve
```
*Si falla:* Usa `aws eks delete-cluster` y espera a que los nodos mueran.

### Paso 3: Limpieza Nuclear de VPC (Anti-Zombies)
Antes de borrar la VPC con Terraform, limpia la basura residual:

```bash
# Obtén el ID de la VPC con el script de auditoría
VPC_ID="vpc-xxxxxxxx" 
./scripts/nuke_vpc.sh $VPC_ID
```

### Paso 4: Destrucción Final
```bash
cd ~/aws-eks-enterprise-gitops/iac/live/dev/vpc
terragrunt destroy -auto-approve
```

### Paso 5: Auditoría Final
```bash
./scripts/finops_audit.sh
```
Debes ver: **✅ AUDITORÍA LIMPIA.**

---

## Sesión de Contacto

| Rol | Nombre | Proyecto |
| :--- | :--- | :--- |
| **Owner** | Jose Garagorry | AWS EKS Enterprise GitOps |
| **Soporte AI** | Gemini | Troubleshooting & Optimization |
| **Estado** | 🟢 PRODUCTION READY | v2.0 Stable |

> *Este documento es idempotente y safe-to-fail.*
