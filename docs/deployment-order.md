<!--
PROPOSITO: Definir a ordem operacional de deploy do Valley.
CONTEXTO: Este roteiro conecta Terraform, EKS, Helm, banco hibrido, webhooks e validacoes finais.
REGRAS: Seguir a sequencia antes de validar health checks, jobs, admin e migracoes do banco.
-->

# Ordem de Deploy

1. Provisionar base AWS com Terraform.
2. Atualizar kubeconfig do cluster EKS.
3. Instalar addons do cluster:
   - metrics-server
   - aws-load-balancer-controller
   - external-dns
   - cert-manager
4. Criar namespaces e secrets.
5. Publicar o chart Helm do Valley.
6. Aplicar migrations do banco hibrido:
   - `python scripts/valley_db_orchestrator.py apply-postgres`
   - `python scripts/valley_db_orchestrator.py apply-mongo`
   - Windows com bridge Docker quebrado: `.\scripts\apply_valley_db_via_wsl.ps1`
   - Runtime Compose local canonico: `powershell -ExecutionPolicy Bypass -File scripts/run_valley_compose_builder.ps1`
7. Configurar Stripe webhooks.
8. Validar `/healthz`, `/readyz`, jobs e admin.
