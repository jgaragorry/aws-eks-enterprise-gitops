#!/bin/bash
# scripts/nuke_backend.sh
# Autor: Jose Garagorry
# Descripción: ELIMINA COMPLETAMENTE el Backend Remoto (S3 + DynamoDB)
# Idempotencia: Sí (Verifica existencia antes de borrar)

# --- CONFIGURACIÓN ---
BUCKET_NAME="aws-eks-enterprise-gitops-state"
TABLE_NAME="aws-eks-enterprise-gitops-locks"
REGION="us-east-1"

echo "☢️  ADVERTENCIA: ESTE SCRIPT DESTRUIRÁ EL ESTADO DE TERRAFORM."
echo "   - Bucket S3: $BUCKET_NAME"
echo "   - DynamoDB:  $TABLE_NAME"
echo ""
read -p "⚠️  ¿Estás 100% seguro? Escribe 'NUKE' para continuar: " CONFIRM

if [ "$CONFIRM" != "NUKE" ]; then
    echo "❌ Cancelado."
    exit 1
fi

echo "==================================================="

# 1. ELIMINAR S3 BUCKET (Manejo de Versionado)
echo "📦 Procesando S3 Bucket..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "   Detected: El bucket existe. Iniciando vaciado..."
    
    # Terraform habilita versionado, así que 'rb --force' a veces falla.
    # Debemos borrar versiones y marcadores de borrado explícitamente.
    
    echo "   🗑️  Eliminando versiones de objetos..."
    aws s3api delete-objects \
      --bucket "$BUCKET_NAME" \
      --delete "$(aws s3api list-object-versions \
      --bucket "$BUCKET_NAME" \
      --output=json \
      --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || echo "      (No hay versiones activas)"

    echo "   🗑️  Eliminando marcadores de borrado..."
    aws s3api delete-objects \
      --bucket "$BUCKET_NAME" \
      --delete "$(aws s3api list-object-versions \
      --bucket "$BUCKET_NAME" \
      --output=json \
      --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || echo "      (No hay marcadores)"

    echo "   💣 Borrando Bucket..."
    aws s3 rb "s3://$BUCKET_NAME" --force
    echo "   ✅ Bucket eliminado."
else
    echo "   ✅ El bucket ya no existe (Idempotente)."
fi

# 2. ELIMINAR DYNAMODB TABLE
echo "🔒 Procesando DynamoDB Table..."
if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "   Detected: La tabla existe. Borrando..."
    aws dynamodb delete-table --table-name "$TABLE_NAME" --region "$REGION"
    
    echo "   ⏳ Esperando confirmación de borrado..."
    aws dynamodb wait table-not-exists --table-name "$TABLE_NAME" --region "$REGION"
    echo "   ✅ Tabla eliminada."
else
    echo "   ✅ La tabla ya no existe (Idempotente)."
fi

echo "==================================================="
echo "✨ Limpieza de Backend finalizada."
