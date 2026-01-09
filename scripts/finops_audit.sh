#!/bin/bash
REGION="us-east-1"
echo "================================================================="
echo "💀 AUDITORÍA ULTIMATE FINOPS - REGIÓN: $REGION"
echo "   OBJETIVO: Detección de CUALQUIER recurso facturable."
echo "================================================================="

# --- CAPA 1: CÓMPUTO Y RED (Los caros) ---
echo "🔍 1. Instancias EC2 (Running/Stopped)..."
aws ec2 describe-instances --region $REGION --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name}' --output table

echo "🔍 2. NAT Gateways (Costo por hora)..."
aws ec2 describe-nat-gateways --region $REGION --filter "Name=state,Values=available,pending" --query 'NatGateways[*].{ID:NatGatewayId,State:State}' --output table

echo "🔍 3. Load Balancers (Classic & V2)..."
aws elb describe-load-balancers --region $REGION --query 'LoadBalancerDescriptions[*].{Name:LoadBalancerName,DNS:DNSName}' --output table
aws elbv2 describe-load-balancers --region $REGION --query 'LoadBalancers[*].{ARN:LoadBalancerArn,DNS:DNSName}' --output table

echo "🔍 4. Clusters EKS..."
aws eks list-clusters --region $REGION --output table

# --- CAPA 2: ALMACENAMIENTO Y DATOS ---
echo "🔍 5. Volúmenes EBS y Snapshots..."
aws ec2 describe-volumes --region $REGION --query 'Volumes[*].{ID:VolumeId,State:State}' --output table
aws ec2 describe-snapshots --owner-ids self --region $REGION --query 'Snapshots[*].{ID:SnapshotId,Size:VolumeSize}' --output table

echo "🔍 6. Bases de Datos RDS..."
aws rds describe-db-instances --region $REGION --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus}' --output table

# --- CAPA 3: RESIDUOS PERSISTENTES (Lo que faltaba) ---
echo "🔍 7. Buckets S3 (Almacenamiento de estado)..."
aws s3api list-buckets --query 'Buckets[].Name' --output table

echo "🔍 8. Tablas DynamoDB (Locks de Terraform)..."
aws dynamodb list-tables --region $REGION --output table

echo "🔍 9. CloudWatch Log Groups (Logs residuales)..."
aws logs describe-log-groups --region $REGION --query 'logGroups[*].logGroupName' --output table

echo "🔍 10. Elastic IPs (IPs reservadas)..."
aws ec2 describe-addresses --region $REGION --query 'Addresses[*].{IP:PublicIp,AssocId:AssociationId}' --output table

echo "================================================================="
echo "✅ VEREDICTO FINAL:"
echo "   - Si TODO sale vacío/None: Costo $0 garantizado."
echo "   - Si ves Buckets o Tablas: Ejecuta ./scripts/nuke_backend_smart.sh"
echo "   - Si ves Logs: Ejecuta ./scripts/nuke_zombies.sh"
echo "================================================================="
