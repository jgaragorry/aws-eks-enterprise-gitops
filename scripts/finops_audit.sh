#!/bin/bash

# ==============================================================================
# 🕵️‍♂️ FINOPS AUDIT SCRIPT - AWS EKS CLEANUP VERIFICATION
# Autor: Jose Garagorry (Asistido por Gemini)
# Propósito: Verificar que NO queden recursos huérfanos facturables tras el laboratorio.
# Idempotencia: Este script es de solo lectura (READ-ONLY). Ejecútalo las veces que quieras.
# ==============================================================================

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables del Proyecto (Deben coincidir con tu Terragrunt)
PROJECT_TAG="AWS-EKS-Enterprise-GitOps" # Tag 'Project' usado en provider.tf
CLUSTER_NAME="eks-gitops-dev"           # Nombre del clúster
REGION="us-east-1"

echo -e "${YELLOW}================================================================${NC}"
echo -e "${YELLOW}🔍 INICIANDO AUDITORÍA FINOPS: ${PROJECT_TAG}${NC}"
echo -e "${YELLOW}📍 Región: ${REGION}${NC}"
echo -e "${YELLOW}================================================================${NC}"

# Función de ayuda para imprimir estado
check_status() {
    local resource_name=$1
    local count=$2
    local details=$3

    if [ "$count" -gt 0 ]; then
        echo -e "${RED}[PELIGRO] $count $resource_name ENCONTRADO(S)! 💸${NC}"
        echo -e "${RED}Detalles:${NC} $details"
        return 1
    else
        echo -e "${GREEN}[OK] 0 $resource_name encontrados.${NC}"
        return 0
    fi
}

total_warnings=0

# ------------------------------------------------------------------------------
# 1. ☸️  EKS Cluster (Costo Alto)
# ------------------------------------------------------------------------------
echo "Verificando Clústeres EKS..."
CLUSTERS=$(aws eks list-clusters --region $REGION --query "clusters[?(@=='$CLUSTER_NAME')]" --output text)
if [ ! -z "$CLUSTERS" ]; then
    check_status "Clúster EKS" 1 "$CLUSTERS"
    ((total_warnings++))
else
    check_status "Clúster EKS" 0 ""
fi

# ------------------------------------------------------------------------------
# 2. ⚖️  Load Balancers (Costo Alto - El "Huérfano" más común)
# Buscamos LBs creados por Terraform Y LBs creados por K8s (Service type: LoadBalancer)
# ------------------------------------------------------------------------------
echo "Verificando Load Balancers (ALB/NLB/Classic)..."

# CLB (Classic - Usado a veces por defecto en Services viejos)
ELBS=$(aws elb describe-load-balancers --region $REGION --query "LoadBalancerDescriptions[?contains(DNSName, 'elb')].[LoadBalancerName, DNSName]" --output text)
# Filtramos por aquellos que parezcan relacionados o no tengan tags
# Nota: Es difícil filtrar CLBs huérfanos sin tags específicos, pero listaremos todo lo que haya para que tú decidas.
count_elbs=$(echo "$ELBS" | grep -v "^$" | wc -l)
if [ "$count_elbs" -gt 0 ]; then
    echo -e "${YELLOW}[INFO] Se encontraron $count_elbs Classic ELBs en la región. Revisa si pertenecen a ArgoCD:${NC}"
    echo "$ELBS"
    # No sumamos warning automático porque podrías tener otros proyectos, pero ojo aquí.
fi

# ALB/NLB (v2)
ALBS=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?contains(DNSName, 'elb')].[LoadBalancerName, DNSName]" --output text)
count_albs=$(echo "$ALBS" | grep -v "^$" | wc -l)
if [ "$count_albs" -gt 0 ]; then
     echo -e "${YELLOW}[INFO] Se encontraron $count_albs ALB/NLBs. Revisa:${NC}"
     echo "$ALBS"
fi

# ------------------------------------------------------------------------------
# 3. 🌐 NAT Gateways (Costo Alto - Se cobran por hora)
# ------------------------------------------------------------------------------
echo "Verificando NAT Gateways..."
NATS=$(aws ec2 describe-nat-gateways --region $REGION --filter "Name=tag:Project,Values=$PROJECT_TAG" "Name=state,Values=available,pending" --query "NatGateways[*].NatGatewayId" --output text)
count_nats=$(echo "$NATS" | wc -w)
check_status "NAT Gateways activos" $count_nats "$NATS"
((total_warnings+=count_nats))

# ------------------------------------------------------------------------------
# 4. ⚓ Elastic IPs (Costo si no están adjuntas)
# ------------------------------------------------------------------------------
echo "Verificando Elastic IPs..."
EIPS=$(aws ec2 describe-addresses --region $REGION --filter "Name=tag:Project,Values=$PROJECT_TAG" --query "Addresses[*].PublicIp" --output text)
count_eips=$(echo "$EIPS" | wc -w)
check_status "Elastic IPs" $count_eips "$EIPS"
((total_warnings+=count_eips))

# ------------------------------------------------------------------------------
# 5. 💾 EBS Volumes (Discos duros huérfanos de PVCs)
# Buscamos volúmenes "Available" (no en uso) que tengan tags de Kubernetes
# ------------------------------------------------------------------------------
echo "Verificando Volúmenes EBS Huérfanos (PVs)..."
# Filtramos volúmenes creados por el driver de K8s para nuestro cluster
VOLS=$(aws ec2 describe-volumes --region $REGION --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" "Name=status,Values=available" --query "Volumes[*].VolumeId" --output text)
count_vols=$(echo "$VOLS" | wc -w)
check_status "EBS Volumes Huérfanos" $count_vols "$VOLS"
((total_warnings+=count_vols))

# ------------------------------------------------------------------------------
# 6. 🕸️ VPC y Redes
# ------------------------------------------------------------------------------
echo "Verificando VPC..."
VPCS=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Project,Values=$PROJECT_TAG" --query "Vpcs[*].VpcId" --output text)
count_vpcs=$(echo "$VPCS" | wc -w)
check_status "VPCs del Proyecto" $count_vpcs "$VPCS"
((total_warnings+=count_vpcs))

echo -e "${YELLOW}================================================================${NC}"
if [ "$total_warnings" -eq 0 ]; then
    echo -e "${GREEN}✅ AUDITORÍA LIMPIA: No se detectaron recursos activos del proyecto.${NC}"
    echo -e "${GREEN}💰 Tu billetera está a salvo.${NC}"
else
    echo -e "${RED}⚠️  ATENCIÓN: Se detectaron $total_warnings recursos que podrían generar costos.${NC}"
    echo -e "${RED}👉 Ejecuta 'terragrunt destroy' en las carpetas correspondientes o borra manualmente.${NC}"
fi
echo -e "${YELLOW}================================================================${NC}"
