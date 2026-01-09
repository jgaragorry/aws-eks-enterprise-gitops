#!/bin/bash
REGION="us-east-1"
echo "================================================================="
echo "💀 AUDITORÍA EXTREMA FINOPS - REGIÓN: $REGION"
echo "   Buscando cualquier recurso activo que genere costos..."
echo "================================================================="

# 1. COMPUTACIÓN (EC2)
echo "🔍 1. Verificando Instancias EC2 (Running/Stopped)..."
aws ec2 describe-instances --region $REGION --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name}' --output table

# 2. ALMACENAMIENTO (EBS & Snapshots)
echo "🔍 2. Verificando Volúmenes EBS (Discos)..."
aws ec2 describe-volumes --region $REGION --query 'Volumes[*].{ID:VolumeId,Size:Size,State:State}' --output table

echo "🔍 3. Verificando Snapshots de EBS..."
# Filtra solo los que son propiedad tuya (self) para no listar los públicos de AWS
aws ec2 describe-snapshots --owner-ids self --region $REGION --query 'Snapshots[*].{ID:SnapshotId,Size:VolumeSize}' --output table

# 3. RED (La parte crítica)
echo "🔍 4. Verificando Load Balancers V2 (ALB/NLB)..."
aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[*].{ARN:LoadBalancerArn,DNS:DNSName}' --output table

echo "🔍 5. Verificando Classic Load Balancers (ELB v1 - ¡Los traicioneros!)..."
aws elb describe-load-balancers --region $REGION --query 'LoadBalancerDescriptions[*].{Name:LoadBalancerName,DNS:DNSName}' --output table

echo "🔍 6. Verificando NAT Gateways (Costo por hora)..."
aws ec2 describe-nat-gateways --region $REGION --filter "Name=state,Values=available,pending" --query 'NatGateways[*].{ID:NatGatewayId,State:State}' --output table

echo "🔍 7. Verificando Elastic IPs (Costo si no se usan)..."
aws ec2 describe-addresses --region $REGION --query 'Addresses[*].{IP:PublicIp,AssocId:AssociationId}' --output table

# 4. BASES DE DATOS & KUBERNETES
echo "🔍 8. Verificando Clusters EKS..."
aws eks list-clusters --region $REGION --output table

echo "🔍 9. Verificando Instancias RDS..."
aws rds describe-db-instances --region $REGION --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}' --output table

echo "================================================================="
echo "✅ Si todas las tablas de arriba están VACÍAS (None/Null), tu cuenta está a salvo."
echo "================================================================="
