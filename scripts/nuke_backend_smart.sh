#!/bin/bash
# scripts/nuke_backend_smart.sh
# Autor: Jose Garagorry & Gemini
# Descripción: Detecta y elimina el Backend REAL basado en tu cuenta AWS.
# Idempotencia: Alta (Detecta ID de cuenta automáticamente)

echo "🔥 INICIANDO PROTOCOLO DE LIMPIEZA DE BACKEND INTELIGENTE..."
echo "=========================================================="

# 1. OBTENER DATOS DE LA CUENTA (Dinámico)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1" # Ajusta si usas otra región

# 2. CONSTRUIR NOMBRES REALES (Patrón estándar de Terragrunt)
# Nota: Terragrunt suele usar patterns como: <proyecto>-<tipo>-<cuenta>
# Basado en tus fotos, tus recursos se llaman:
BUCKET_NAME="eks-gitops-platform-tfstate-${ACCOUNT_ID}"
TABLE_NAME="eks-gitops-platform-tflock"

echo "🎯 Objetivo detectado:"
echo "   - Cuenta AWS: $ACCOUNT_ID"
echo "   - Bucket S3:  $BUCKET_NAME"
echo "   - DynamoDB:   $TABLE_NAME"
echo "=========================================================="

# 3. VERIFICAR SI EXISTEN ANTES DE DISPARAR
BUCKET_EXISTS=$(aws s3api head-bucket --bucket "$BUCKET_NAME" 2>&1 || true)
TABLE_STATUS=$(aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" --query "Table.TableStatus" --output text 2>&1 || true)

if [[ "$BUCKET_EXISTS" == *"Not Found"* ]] && [[ "$TABLE_STATUS" == *"ResourceNotFound"* ]]; then
    echo "✅ AUDITORÍA LIMPIA: No se encontraron residuos del backend. Estás a salvo."
    exit 0
fi

# 4. CONFIRMACIÓN
echo "⚠️  ¡PELIGRO! Se encontraron recursos activos."
echo "   Esto destruirá el historial de tu infraestructura."
read -p "   Escribe 'NUKE' para confirmar la destrucción: " CONFIRM

if [ "$CONFIRM" != "NUKE" ]; then
    echo "❌ Cancelado."
    exit 1
fi

# 5. BORRADO RECURSIVO DEL BUCKET
if [[ "$BUCKET_EXISTS" != *"Not Found"* ]]; then
    echo "📦 Vaciando y borrando S3..."
    # Borrar versiones (necesario si hay versionado)
    aws s3api delete-objects --bucket "$BUCKET_NAME" \
    --delete "$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --output=json --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || true
    
    # Borrar marcadores de borrado
    aws s3api delete-objects --bucket "$BUCKET_NAME" \
    --delete "$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --output=json --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null || true

    # Golpe final
    aws s3 rb "s3://$BUCKET_NAME" --force
    echo "   ✅ Bucket eliminado."
else
    echo "   💨 El bucket ya no estaba."
fi

# 6. BORRADO DE LA TABLA
if [[ "$TABLE_STATUS" != *"ResourceNotFound"* ]]; then
    echo "🔒 Borrando tabla DynamoDB..."
    aws dynamodb delete-table --table-name "$TABLE_NAME" --region "$REGION"
    aws dynamodb wait table-not-exists --table-name "$TABLE_NAME" --region "$REGION"
    echo "   ✅ Tabla eliminada."
else
    echo "   💨 La tabla ya no estaba."
fi

echo "=========================================================="
echo "✨ FINOPS: Cero residuos, cero costos."
