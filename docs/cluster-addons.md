<!--
PROPOSITO: Registrar os addons Kubernetes esperados para o cluster Valley.
CONTEXTO: Este guia orienta instalacao de ingress, DNS, certificados e metricas no ambiente EKS.
REGRAS: Validar dependencias de IAM, OIDC, Route53 e certificados antes de publicar cargas publicas.
-->

# Cluster Addons

Este kit assume os seguintes addons no EKS:

## 1. AWS Load Balancer Controller

Responsável por materializar o `Ingress` do Kubernetes em um Application Load Balancer.

Requisitos:
- OIDC provider habilitado no cluster
- Service Account com IRSA
- subnets públicas tagueadas para ELB

## 2. ExternalDNS

Responsável por criar/atualizar registros DNS a partir das annotations do `Ingress`.

Requisitos:
- Hosted Zone no Route53
- IAM role com permissões em Route53

## 3. cert-manager

Responsável por emitir certificados para endpoints internos ou para cenários fora do ALB/ACM.

Observação:
- Para tráfego público via ALB, você pode preferir certificado ACM anexado no listener HTTPS.
- Para tráfego interno, mTLS ou outros ingress controllers, mantenha o cert-manager.

## 4. Metrics Server

Necessário para HPA.

## 5. External Secrets Operator (opcional, recomendado)

Recomendado para sincronizar segredos do AWS Secrets Manager ou SSM para o cluster.
