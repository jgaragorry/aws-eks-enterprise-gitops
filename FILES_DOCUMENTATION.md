# 📂 Anatomía del Proyecto: Documentación Técnica de Archivos

Este documento desglosa cada archivo de configuración utilizado en el laboratorio **AWS EKS Enterprise GitOps**. Explica su función, ciclo de vida e interacción dentro de la arquitectura.

---

## 🏗️ Nivel 0: Los Cimientos (Root Configuration)

Antes de crear cualquier recurso, necesitamos definir **dónde** se guardará el estado y **quién** proveerá los recursos.

### 1. `iac/live/terragrunt.hcl` (El Padre)
* **Qué hace:** Es el archivo de configuración global. Define el bloque `remote_state` (S3 + DynamoDB) y genera el bloque `provider "aws"` dinámicamente.
* **Contenido Clave:** Configuración del Bucket S3 `aws-eks-enterprise-gitops-state` y la tabla de bloqueo DynamoDB.
* **Cuándo se usa:** Cada vez que ejecutas `terragrunt` en cualquier subcarpeta. Los hijos "heredan" esta configuración.
* **Quién lo lee:** El binario de **Terragrunt** (antes de llamar a Terraform).
* **Objetivo:** Principio DRY (Don't Repeat Yourself). Evitar copiar/pegar la configuración del backend en 10 sitios distintos.

```mermaid
graph TD
    User[SysAdmin] -->|Ejecuta| TG[Terragrunt CLI]
    TG -->|Lee| RootHCL[iac/live/terragrunt.hcl]
    RootHCL -->|Genera Backend| S3[(S3 State)]
```

---

## 🌐 Nivel 1: La Red (Networking Layer)

Aquí definimos la carretera por donde viajarán nuestros datos.

### 2. `iac/live/dev/vpc/terragrunt.hcl` (El Instanciador)
* **Qué hace:** Invoca al módulo genérico de VPC y le pasa los valores específicos para este entorno (CIDR `10.0.0.0/16`, Nombres, Tags).
* **Quién lo lee:** Terragrunt.
* **Objetivo:** Definir que *esta* ejecución específica es para el entorno "Dev" en "us-east-1".

### 3. `iac/modules/vpc-network/main.tf` (El Plano)
* **Qué hace:** Contiene el código Terraform puro. Define recursos `aws_vpc`, `aws_subnet`, `aws_nat_gateway`.
* **Cuándo se usa:** Durante `terragrunt apply`.
* **Objetivo:** Abstraer la complejidad de crear una red de 3 capas (Pública/Privada/Database).

### 4. `iac/modules/vpc-network/versions.tf` (El Protector)
* **Qué hace:** Bloquea la versión del proveedor AWS (`< 6.0`).
* **Objetivo:** Evitar el "Dependency Hell". Asegura que el código no se rompa si AWS lanza una actualización incompatible mañana.

```mermaid
graph TD
    RootHCL[iac/live/terragrunt.hcl]
    
    subgraph Phase1_Network [Fase 1: Networking]
        style Phase1_Network fill:#e1f5fe
        VPC_HCL[dev/vpc/terragrunt.hcl] -->|Include| RootHCL
        VPC_HCL -->|Instancia| VPC_Mod[module/vpc-network]
        VPC_Mod -->|Crea| AWS_VPC[☁️ AWS VPC]
    end
```

---

## ⚙️ Nivel 2: Cómputo (Compute Layer)

Ahora colocamos el motor (Kubernetes) sobre la carretera (VPC).

### 5. `iac/live/dev/eks/terragrunt.hcl` (El Coordinador)
* **Qué hace:** Define las dependencias explícitas (`dependency "vpc"`). Le dice a Terragrunt: "No crees el EKS hasta que la VPC tenga un ID válido".
* **Contenido Clave:** Bloque `inputs` que lee `dependency.vpc.outputs.vpc_id`.
* **Objetivo:** Orquestación. Manejar el orden de despliegue automáticamente.

### 6. `iac/modules/eks-cluster/main.tf` (El Motor)
* **Qué hace:** Define el Control Plane de EKS y los Node Groups (instancias EC2).
* **Quién lo lee:** Terraform AWS Provider.
* **Objetivo:** Provisionar un clúster Kubernetes listo para producción con roles IAM (IRSA) integrados.

```mermaid
graph TD
    RootHCL[iac/live/terragrunt.hcl]
    AWS_VPC[☁️ AWS VPC]

    subgraph Phase2_Compute [Fase 2: Compute]
        style Phase2_Compute fill:#fff9c4
        EKS_HCL[dev/eks/terragrunt.hcl] -->|Dependency| VPC_HCL[dev/vpc/terragrunt.hcl]
        EKS_HCL -->|Instancia| EKS_Mod[module/eks-cluster]
        EKS_Mod -->|Crea| AWS_EKS[☸️ EKS Cluster]
        AWS_EKS -.->|Se despliega en| AWS_VPC
    end
```

---

## 🐙 Nivel 3: Plataforma (GitOps Engine)

Instalamos el "cerebro" que gestionará las aplicaciones.

### 7. `iac/live/dev/platform/terragrunt.hcl` (El Puente Helm)
* **Qué hace:** Genera la configuración para conectarse al clúster EKS recién creado. Obtiene las credenciales del clúster dinámicamente.
* **Objetivo:** Permitir que Terraform hable con Kubernetes sin configurar `~/.kube/config` manualmente.

### 8. `iac/modules/argo-platform/main.tf` (El Instalador)
* **Qué hace:** Usa el `helm_release` resource para bajar el Chart oficial de ArgoCD e instalarlo.
* **Cuándo se usa:** Fase de bootstrapping de aplicaciones.
* **Objetivo:** Dejar el clúster listo con ArgoCD y Argo Rollouts funcionando.

```mermaid
graph TD
    AWS_EKS[☸️ EKS Cluster]

    subgraph Phase3_Platform [Fase 3: Plataforma]
        style Phase3_Platform fill:#f8bbd0
        Platform_HCL[dev/platform/terragrunt.hcl] -->|Lee Credenciales| AWS_EKS
        Platform_HCL -->|Instancia| Argo_Mod[module/argo-platform]
        Argo_Mod -->|Helm Install| ArgoCD[🐙 ArgoCD Pods]
    end
    
    ArgoCD -.->|Corre dentro de| AWS_EKS
```

---

## 🚀 Nivel 4: Aplicación (GitOps & Rollouts)

Archivos que viven en Git y definen *qué* debe correr, no *dónde*.

### 9. `gitops-manifests/apps/colors-app.yaml` (El Contrato)
* **Qué hace:** Es un CRD (Custom Resource Definition) de tipo `Application`. Le dice a ArgoCD: "Vigila la carpeta `app-source/helm-chart` en este repo".
* **Quién lo lee:** El controlador de ArgoCD dentro del clúster.
* **Objetivo:** Automatización pura. Conectar Git con K8s.

### 10. `app-source/helm-chart/templates/rollout.yaml` (La Estrategia)
* **Qué hace:** Sustituye al `Deployment` tradicional. Define la lógica Canary (`steps`, `setWeight`, `pause`).
* **Quién lo lee:** El controlador de Argo Rollouts.
* **Objetivo:** Progressive Delivery. Permitir actualizaciones seguras (Blue/Green/Canary).

```mermaid
graph TD
    ArgoCD[🐙 ArgoCD Pods]
    Repo[📂 GitHub Repo]

    subgraph Phase4_GitOps [Fase 4: Aplicación]
        style Phase4_GitOps fill:#c8e6c9
        App_Manifest[colors-app.yaml] -->|Define Source| Repo
        Rollout_Yaml[rollout.yaml] -->|Define Strategy| Canary[🚦 Canary Logic]
    end

    ArgoCD -->|Sync/Pull| App_Manifest
    ArgoCD -->|Aplica| Rollout_Yaml
```

---

## 🛡️ Nivel 5: FinOps & Seguridad (Scripts)

Herramientas de mantenimiento y limpieza.

### 11. `scripts/finops_audit.sh` (El Auditor)
* **Qué hace:** Usa AWS CLI para listar recursos costosos (LB, NAT, EIP) filtrando por Tag de proyecto.
* **Cuándo se usa:** Después de `destroy` para asegurar costo cero.
* **Objetivo:** Evitar facturas sorpresa.

### 12. `scripts/nuke_vpc.sh` (El Exterminador)
* **Qué hace:** Rompe dependencias cíclicas. Busca ENIs y Security Groups huérfanos y los fuerza a borrarse.
* **Cuándo se usa:** Cuando Terraform falla al borrar la VPC por error `DependencyViolation`.
* **Objetivo:** Limpieza nuclear cuando la vía diplomática (Terraform) falla.

---

## 🗺️ Diagrama de Flujo Completo

Así interactúan todos los archivos desde el inicio hasta el fin:

```mermaid
graph TD
    %% Estilos
    classDef hcl fill:#f9f,stroke:#333,stroke-width:2px;
    classDef tf fill:#b3e5fc,stroke:#333,stroke-width:2px;
    classDef yaml fill:#c8e6c9,stroke:#333,stroke-width:2px;
    classDef script fill:#ffccbc,stroke:#333,stroke-width:2px;

    %% Nodos
    Root[iac/live/terragrunt.hcl]:::hcl
    
    subgraph Infra
        VPC_TG[vpc/terragrunt.hcl]:::hcl
        EKS_TG[eks/terragrunt.hcl]:::hcl
        VPC_TF[modules/vpc/main.tf]:::tf
        EKS_TF[modules/eks/main.tf]:::tf
    end

    subgraph Platform
        Plat_TG[platform/terragrunt.hcl]:::hcl
        Argo_TF[modules/argo/main.tf]:::tf
    end

    subgraph GitOps
        App_YAML[colors-app.yaml]:::yaml
        Rollout_YAML[rollout.yaml]:::yaml
    end

    subgraph Ops
        Nuke[nuke_vpc.sh]:::script
        Audit[finops_audit.sh]:::script
    end

    %% Relaciones
    VPC_TG -->|Inherit| Root
    EKS_TG -->|Inherit| Root
    Plat_TG -->|Inherit| Root

    VPC_TG -->|Uses| VPC_TF
    EKS_TG -->|Uses| EKS_TF
    EKS_TG -->|Depends on| VPC_TG

    Plat_TG -->|Uses| Argo_TF
    Plat_TG -->|Connects to| EKS_TF

    Argo_TF -->|Installs Controller| App_YAML
    App_YAML -->|Deploys| Rollout_YAML

    Nuke -->|Cleans| VPC_TF
    Audit -->|Verifies| Infra
```

---
**Autor:** Jose Garagorry
**Proyecto:** AWS EKS Enterprise GitOps
