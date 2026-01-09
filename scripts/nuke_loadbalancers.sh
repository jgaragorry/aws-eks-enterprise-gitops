#!/bin/bash
REGION="us-east-1"
# CAMBIO CLAVE: Buscamos por la etiqueta 'Name' que sí existe en tu Terraform
TAG_KEY="Name"
TAG_VALUE="gitops-platform-dev-vpc"

echo "🔥 NUKE LOAD BALANCERS: Buscando recursos huérfanos..."

# 1. Obtener VPC ID usando la etiqueta Name
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query "Vpcs[0].VpcId" --output text --region $REGION)

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "⚠️  No se detectó la VPC '$TAG_VALUE'. Intentando búsqueda alternativa..."
    # Intento de respaldo por si acaso
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=AWS-EKS-Enterprise-GitOps" --query "Vpcs[0].VpcId" --output text --region $REGION)
fi

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "✅ No se encontró ninguna VPC activa. Nada que limpiar."
    exit 0
fi

echo "🎯 Objetivo detectado: VPC $VPC_ID"

# 2. Borrar Classic ELBs (Los culpables del bloqueo)
CLB_NAMES=$(aws elb describe-load-balancers --region $REGION --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text)
if [ ! -z "$CLB_NAMES" ]; then
    for clb in $CLB_NAMES; do
        echo "💣 Borrando Classic ELB: $clb"
        aws elb delete-load-balancer --load-balancer-name "$clb" --region $REGION
    done
else
    echo "✅ No hay Classic ELBs activos."
fi

# 3. Borrar ELB v2 (ALB/NLB)
ELB_ARNS=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
if [ ! -z "$ELB_ARNS" ]; then
    for arn in $ELB_ARNS; do
        echo "💣 Borrando ELB v2: $arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$arn" --region $REGION
    done
else
    echo "✅ No hay ELB v2 activos."
fi

echo "⏳ Esperando 15s para que AWS libere las interfaces..."
sleep 15
echo "✨ Limpieza de Balanceadores completada."
