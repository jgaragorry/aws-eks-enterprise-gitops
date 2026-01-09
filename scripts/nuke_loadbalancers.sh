#!/bin/bash
REGION="us-east-1"
TAG_KEY="Project"
TAG_VALUE="AWS-EKS-Enterprise-GitOps"

echo "🔥 NUKE: Buscando Load Balancers Zombies (Classic & V2)..."

# 1. Obtener VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:$TAG_KEY,Values=$TAG_VALUE" --query "Vpcs[0].VpcId" --output text --region $REGION)

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "✅ No se detectó VPC del proyecto. Nada que limpiar."
    exit 0
fi

echo "   -> Objetivo: VPC $VPC_ID"

# 2. Borrar Classic ELBs (Los culpables habituales)
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

echo "⏳ Esperando 15s para liberación de interfaces..."
sleep 15
echo "✨ Limpieza de Balanceadores completada."
