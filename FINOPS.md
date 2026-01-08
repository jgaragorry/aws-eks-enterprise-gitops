# 💰 FinOps & Cost Management Strategy

Este documento detalla el desglose de costos estimados y las estrategias de mitigación financiera implementadas en el proyecto.

---

## 1. Desglose de Costos (Bill of Materials)

Basado en la región **us-east-1** (N. Virginia), estos son los costos por hora aproximados de mantener el laboratorio encendido:

| Recurso | Tipo | Cantidad | Costo Unitario | Costo Total/Hora |
| :--- | :--- | :--- | :--- | :--- |
| **EKS Control Plane** | Managed Service | 1 | $0.10 | **$0.10** |
| **Worker Nodes** | EC2 t3.medium | 2 | $0.0416 | **$0.0832** |
| **NAT Gateway** | Network | 1 | $0.045 | **$0.045** |
| **Load Balancer** | Classic/ALB | 2 | $0.025 | **$0.050** |
| **EBS Volumes** | gp3 Storage | 2x 20GB | $0.08/GB/mes | *(Marginal)* |
| **TOTAL ESTIMADO** | | | | **~$0.28 / hora** |

> **Costo Mensual (24/7):** Aprox. **$200 USD**.
> **⚠️ Recomendación:** Destruir el laboratorio al finalizar la sesión de estudio siguiendo el RUNBOOK.

---

## 2. Herramientas de Control

### Script de Auditoría (`scripts/finops_audit.sh`)
Script personalizado que utiliza la CLI de AWS para detectar recursos que suelen quedar "huérfanos" y generan costos silenciosos:
* **Elastic IPs (EIPs):** $0.005/hora si no están asociadas.
* **Volúmenes EBS:** Se cobran aunque la instancia esté terminada.
* **Load Balancers:** Cobran por hora aunque no tengan tráfico.

### Tagueo de Recursos
Todos los recursos creados por Terragrunt llevan automáticamente los siguientes tags para facilitar la búsqueda en AWS Cost Explorer:
* `Project: AWS-EKS-Enterprise-GitOps`
* `Environment: Dev`
* `ManagedBy: Terragrunt`

---

## 3. Protocolo de Limpieza

Para garantizar costo cero al finalizar, consulte el **[RUNBOOK.md](./RUNBOOK.md)** fase 4. El protocolo incluye un script `nuke_vpc.sh` para eliminar dependencias de red persistentes.
