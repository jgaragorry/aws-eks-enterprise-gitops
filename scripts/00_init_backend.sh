#!/bin/bash
set -e

# ==============================================================================
# 🛡️ BOOTSTRAP DE BACKEND REMOTO (S3 + DYNAMODB) - NIVEL ENTERPRISE
# Autor: Jose Garagorry
# Descripción:
#   Crea los recursos inmutables para alojar el estado de Terraform.
#   Este script es IDEMPOTENTE: Verifica antes de crear.
#   Garantiza: Versionado, Encriptación, Bloqueo y Etiquetado.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. CONFIGURACIÓN (Variables Globales)
# ------------------------------------------------------------------------------
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PROJECT_NAME="eks-gitops-platform" # Nombre único para este lab

# Nombres estandarizados (Naming Convention)
BUCKET_NAME="${PROJECT_NAME}-tfstate-${ACCOUNT_ID}"
DYNAMODB_TABLE="${PROJECT_NAME}-tflock"

echo "----------------------------------------------------------------"
echo "🚀 INICIANDO BOOTSTRAP DEL BACKEND PARA: $PROJECT_NAME"
echo "📍 Región: $REGION"
echo "📦 Bucket Objetivo: $BUCKET_NAME"
echo "🔐 Tabla de Bloqueo: $DYNAMODB_TABLE"
echo "----------------------------------------------------------------"

# ------------------------------------------------------------------------------
# 2. CREACIÓN DEL BUCKET S3 (ALMACENAMIENTO SEGURO)
# ------------------------------------------------------------------------------
echo "🔍 Verificando existencia del Bucket S3..."

if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "✅ El bucket '$BUCKET_NAME' ya existe. Omitiendo creación."
else
    echo "✨ Creando bucket '$BUCKET_NAME'..."
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION"

    # Nota: us-east-1 no requiere LocationConstraint, otras regiones sí.
    echo "✅ Bucket creado."
fi

# 2.1 Configurar Bloqueo de Acceso Público (Seguridad Máxima)
echo "🔒 Aplicando 'Block Public Access'..."
aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 2.2 Activar Versionado (Para recuperación de desastres)
echo "📚 Activando Versionado de objetos..."
aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

# 2.3 Activar Encriptación por Defecto (AES-256)
echo "🔑 Activando Encriptación (SSE-S3)..."
aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

# 2.4 Etiquetado (FinOps)
echo "🏷️ Etiquetando Bucket..."
aws s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --tagging 'TagSet=[{Key=Project,Value=AWS-EKS-GitOps},{Key=Environment,Value=Common},{Key=ManagedBy,Value=Script},{Key=SecurityLevel,Value=Critical}]'

# ------------------------------------------------------------------------------
# 3. CREACIÓN DE TABLA DYNAMODB (LOCKING)
# ------------------------------------------------------------------------------
echo "🔍 Verificando tabla DynamoDB..."

if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" >/dev/null 2>&1; then
    echo "✅ La tabla '$DYNAMODB_TABLE' ya existe. Omitiendo creación."
else
    echo "✨ Creando tabla de bloqueo '$DYNAMODB_TABLE'..."
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region "$REGION" \
        --tags Key=Project,Value=AWS-EKS-GitOps Key=Purpose,Value=TerraformLock

    echo "⏳ Esperando a que la tabla esté activa..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$REGION"
    echo "✅ Tabla DynamoDB activa y lista para recibir bloqueos."
fi

echo "----------------------------------------------------------------"
echo "🏁 BOOTSTRAP FINALIZADO CON ÉXITO"
echo "----------------------------------------------------------------"
echo "📋 IMPORTANTE: Copia estos valores para tu archivo root.hcl:"
echo ""
echo "bucket         = \"$BUCKET_NAME\""
echo "dynamodb_table = \"$DYNAMODB_TABLE\""
echo "region         = \"$REGION\""
echo "----------------------------------------------------------------"
