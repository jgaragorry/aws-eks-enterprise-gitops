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
