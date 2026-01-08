#!/bin/bash
# scripts/check_backend.sh
# Descripción: Verifica el estado del Backend calculado dinámicamente.

# 1. CALCULAR NOMBRES (Igual que Terragrunt)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"
BUCKET_NAME="eks-gitops-platform-tfstate-${ACCOUNT_ID}"
TABLE_NAME="eks-gitops-platform-tflock"

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "🔍 AUDITORÍA DE BACKEND (Cuenta: $ACCOUNT_ID)"
echo "==================================================="

# 2. VERIFICAR S3
echo -n "📦 S3 Bucket ($BUCKET_NAME)... "
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}[EXISTE]${NC}"
else
    echo -e "${RED}[NO EXISTE]${NC}"
fi

# 3. VERIFICAR DYNAMODB
echo -n "🔒 DynamoDB ($TABLE_NAME)... "
STATUS=$(aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" --query "Table.TableStatus" --output text 2>/dev/null)
if [ "$?" -eq 0 ]; then
    echo -e "${GREEN}[EXISTE] ($STATUS)${NC}"
else
    echo -e "${RED}[NO EXISTE]${NC}"
fi
echo "==================================================="
