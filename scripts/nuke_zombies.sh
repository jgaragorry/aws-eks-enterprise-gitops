#!/bin/bash
# scripts/nuke_zombies.sh
# Descripción: Elimina recursos específicos que Terraform a veces no logra borrar
# y que bloquean futuros despliegues (KMS Aliases, Log Groups).

REGION="us-east-1"
CLUSTER_NAME="eks-gitops-dev" # Asegúrate que coincida con tu variables.tf

echo "🧟  CAZANDO ZOMBIES (Recursos Huérfanos)..."
echo "==================================================="

# 1. Limpieza de CloudWatch Log Groups
# Terraform a veces pierde el rastro de esto si se recrea el clúster
LOG_GROUP_NAME="/aws/eks/$CLUSTER_NAME/cluster"
echo -n "🔍 Buscando Log Group ($LOG_GROUP_NAME)... "

if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP_NAME" --region $REGION | grep -q "logGroupName"; then
    echo "ENCONTRADO. Eliminando..."
    aws logs delete-log-group --log-group-name "$LOG_GROUP_NAME" --region $REGION
    echo "   ✅ Log Group eliminado."
else
    echo "NO EXISTE (Limpio)."
fi

# 2. Limpieza de KMS Alias
# El Alias bloquea la creación de nuevas llaves con el mismo nombre
ALIAS_NAME="alias/eks/$CLUSTER_NAME"
echo -n "🔍 Buscando KMS Alias ($ALIAS_NAME)... "

# Listamos y filtramos porque no hay comando 'describe-alias' directo simple
if aws kms list-aliases --region $REGION | grep -q "$ALIAS_NAME"; then
    echo "ENCONTRADO. Eliminando..."
    aws kms delete-alias --alias-name "$ALIAS_NAME" --region $REGION
    echo "   ✅ KMS Alias eliminado."
else
    echo "NO EXISTE (Limpio)."
fi

echo "==================================================="
echo "✨ Zona libre de zombies. Listo para el siguiente paso."
