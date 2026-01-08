VPC_ID="vpc-07bb13b9a04b7f1b6"
REGION="us-east-1"

echo "🔥 INICIANDO DESTRUCCIÓN FINAL DE LA VPC: $VPC_ID"

# 1. Obtener todos los Security Groups de la VPC (excluyendo 'default')
SGS=$(aws ec2 describe-security-groups --region $REGION --filters Name=vpc-id,Values=$VPC_ID --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)

# 2. REVOCAR REGLAS (Romper dependencias cíclicas)
if [ -n "$SGS" ] && [ "$SGS" != "None" ]; then
    echo "🔓 Revocando todas las reglas de ingress/egress para romper ciclos..."
    for sg in $SGS; do
        echo "   - Limpiando reglas de SG: $sg"
        # Revocar todas las reglas de entrada
        aws ec2 describe-security-groups --region $REGION --group-ids $sg --query "SecurityGroups[0].IpPermissions" > /tmp/ingress.json
        if [ -s /tmp/ingress.json ] && [ "$(cat /tmp/ingress.json)" != "[]" ]; then
             aws ec2 revoke-security-group-ingress --region $REGION --group-id $sg --ip-permissions file:///tmp/ingress.json 2>/dev/null
        fi
        
        # Revocar todas las reglas de salida
        aws ec2 describe-security-groups --region $REGION --group-ids $sg --query "SecurityGroups[0].IpPermissionsEgress" > /tmp/egress.json
        if [ -s /tmp/egress.json ] && [ "$(cat /tmp/egress.json)" != "[]" ]; then
             aws ec2 revoke-security-group-egress --region $REGION --group-id $sg --ip-permissions file:///tmp/egress.json 2>/dev/null
        fi
    done
    
    # 3. BORRAR LOS SGS (Ahora que están vacíos)
    echo "🗑️  Borrando Security Groups..."
    for sg in $SGS; do
        echo "   - Borrando SG: $sg"
        aws ec2 delete-security-group --region $REGION --group-id $sg
    done
else
    echo "✅ No se encontraron SGs bloqueantes."
fi

# 4. BORRAR LA VPC (Finalmente)
echo "💣 Detonando la VPC..."
aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION

if [ $? -eq 0 ]; then
    echo "✅ ¡VPC ELIMINADA EXITOSAMENTE! 🎉"
else
    echo "❌ Aún falló. Revisa si quedan Subnets o Gateways manuales."
fi
