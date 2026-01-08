#!/bin/bash
# scripts/setup_backend.sh
# Descripción: Crea el Backend S3+DynamoDB con seguridad Enterprise.

echo "🏗️  SETUP DE BACKEND ENTERPRISE"
echo "==================================================="

# 1. CALCULAR NOMBRES
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
BUCKET_NAME="eks-gitops-platform-tfstate-${ACCOUNT_ID}"
TABLE_NAME="eks-gitops-platform-tflock"

echo "🎯 Objetivo: $BUCKET_NAME"

# 2. CREAR S3 (Idempotente)
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "📦 S3: Ya existe."
else
    echo "📦 S3: Creando..."
    aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION" >/dev/null 2>&1
    
    echo "   ⚙️  Activando Versionado..."
    aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
    
    echo "   🔒 Activando Cifrado AES256..."
    aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
    
    echo "   🛡️  Bloqueando acceso público..."
    aws s3api put-public-access-block --bucket "$BUCKET_NAME" --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
fi

# 3. CREAR DYNAMODB (Idempotente)
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "🔒 DynamoDB: Ya existe."
else
    echo "🔒 DynamoDB: Creando..."
    aws dynamodb create-table \
        --table-name "$TABLE_NAME" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$REGION" >/dev/null
    aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
fi

echo "✅ Backend listo."
