# 🚀 AWS EKS Enterprise GitOps Platform | ArgoCD & Rollouts

![AWS](https://img.shields.io/badge/AWS-EKS-orange?style=for-the-badge&logo=amazon-aws)
![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-blue?style=for-the-badge&logo=argo)
![Terraform](https://img.shields.io/badge/IaC-Terraform-purple?style=for-the-badge&logo=terraform)
![Status](https://img.shields.io/badge/Status-Active_Development-green?style=for-the-badge)

> **"Transformando un clúster de Kubernetes en una Plataforma de Aplicaciones Autónoma."**

Este repositorio implementa una estrategia de **Continuous Deployment (CD)** moderna utilizando la metodología **GitOps**. El objetivo es eliminar el error humano en los despliegues y habilitar estrategias de entrega progresiva (Canary Releases) seguras.

---

## 🏛️ Arquitectura de la Solución

La plataforma se construye sobre 3 pilares fundamentales, diseñados con independencia y seguridad:

### 1. Infraestructura Base (The Foundation)
* **Cómputo:** AWS EKS (Elastic Kubernetes Service).
* **Orquestación IaC:** Terraform & Terragrunt (Siguiendo principios DRY).
* **Red:** VPC Enterprise (Aislamiento de Capas Pública/Privada).

### 2. Motor GitOps (The Brain)
* **ArgoCD:** Controlador de despliegue continuo. Sincroniza el estado deseado en Git con el clúster.
* **Argo Rollouts:** Controlador de entrega progresiva. Permite despliegues **Canary** y **Blue/Green** automatizados con análisis de métricas.

### 3. Capa de Aplicación (The Workload)
* **Ingress Controller:** AWS Load Balancer Controller (ALB) para exposición segura HTTPS.
* **Helm Charts:** Estandarización del empaquetado de aplicaciones.

---

## 📂 Estructura del Repositorio (Organización Meticulosa)

```text
.
├── iac/                    # 🏗️ INFRAESTRUCTURA COMO CÓDIGO
│   ├── modules/            # Módulos reutilizables (Terraform puro)
│   │   └── argo-platform/  # Instalación automatizada de la suite Argo
│   └── live/               # Instanciación por Ambientes (Terragrunt)
│       ├── dev/            # Entorno Low-Cost (Spot Instances)
│       └── prod/           # Entorno High-Availability
├── gitops-manifests/       # 🧠 ESTADO DESEADO (La "Verdad" de ArgoCD)
│   ├── apps/               # Definiciones de Aplicaciones (ApplicationSet)
│   └── infra/              # Definiciones de Componentes base
├── app-source/             # 📦 CÓDIGO FUENTE (Demo App)
│   ├── src/                # Código de la aplicación (Golang/Python)
│   └── helm-chart/         # Chart de Helm para la app
└── scripts/                # 🛠️ AUTOMATIZACIÓN & FINOPS
    ├── security_audit.sh   # Verificación de cumplimiento de seguridad
    └── cost_nuke.sh        # Destrucción segura para ahorro de costos
```

---

## 🔒 Estrategia de Seguridad (Security First)

Este laboratorio implementa **Defensa en Profundidad**:

1.  **Gestión de Secretos:** Ningún secreto (API Keys, Passwords) se sube al repo. Se utilizan referencias a *AWS Secrets Manager* o *Sealed Secrets*.
2.  **Least Privilege:** Los Pods de ArgoCD utilizan **IRSA (IAM Roles for Service Accounts)** para asumir roles de AWS, evitando credenciales estáticas.
3.  **Network Policies:** Aislamiento de tráfico entre namespaces (La App A no puede ver a la App B salvo autorización explícita).

---

## 💰 FinOps & Optimización de Costos

Para garantizar la viabilidad del laboratorio:

* **Spot Instances:** Los entornos no productivos (`dev`) utilizan instancias Spot (hasta 90% de descuento).
* **Apagado Nocturno:** Scripts para escalar los *Node Groups* a 0 fuera de horario laboral.
* **Limpieza de ALBs:** Auditoría estricta de Load Balancers huérfanos.

---

## 🚀 Guía de Inicio Rápido

*(Sección en construcción - Sigue los scripts en la carpeta `scripts/` para el bootstrapping)*.

---

_Desarrollado por **Jose Garagorry** | Enterprise Cloud Architect_
