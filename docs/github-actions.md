<!--
PROPOSITO: Documentar os secrets e fluxos de GitHub Actions usados pelo Valley.
CONTEXTO: Este guia apoia CI, build de imagem, push no ECR e deploy Helm no EKS.
REGRAS: Manter secrets fora do Git e validar pipeline antes de qualquer publicacao.
-->

# GitHub Actions

## Secrets esperados

- `AWS_ROLE_TO_ASSUME`
- `AWS_REGION`
- `ECR_REPOSITORY`
- `EKS_CLUSTER_NAME`
- `HELM_RELEASE_NAME`
- `K8S_NAMESPACE`
- `VALLEY_DOMAIN`
- `DATABASE_URL`
- `MONGODB_URI`
- `REDIS_URL`
- `RABBITMQ_URL`
- `JWT_SECRET`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`

## Fluxo

- `ci.yml`: valida sintaxe Python/JavaScript e garante build da imagem
- `deploy.yml`: build da imagem, push no ECR e deploy Helm no EKS
