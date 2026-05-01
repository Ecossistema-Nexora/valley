# Manual de Ambiente - valley (Codex Cloud)

## Objetivo
Este manual explica como manter sincronizadas as variáveis de ambiente e segredos do projeto no ambiente **valley**, com foco em segurança, estabilidade e redução de custo operacional.

## Arquivo de referência
- `tmp/runtime/codex-cloud-secrets.env`

Esse arquivo funciona como **template técnico** e checklist de variáveis obrigatórias para o runtime local e para o painel remoto do Codex Cloud.

## Processo de atualização
1. Atualize o template local com as chaves necessárias (sem segredos reais).
2. Acesse o painel do Codex Cloud em **Ambientes > valley**.
3. Cadastre/atualize os valores reais das variáveis de ambiente e segredos.
4. Reinicie/deploy do ambiente para aplicar as novas variáveis.
5. Valide logs e health-check após o deploy.

## Checklist rápido de validação pós-deploy
- Confirmar conexão com PostgreSQL sem erro de autenticação.
- Confirmar conexão com Redis sem timeout.
- Validar emissão/validação de JWT em rota protegida.
- Verificar ingestão de erros no Sentry.
- Revisar consumo de recursos para evitar custo desnecessário (pool, timeout e flags).

## Plano de rollback (baixo risco)
1. Reaplicar no painel Codex Cloud o último conjunto estável de variáveis.
2. Executar novo deploy/restart do ambiente `valley`.
3. Revalidar os 5 checks do bloco de pós-deploy.
4. Registrar causa raiz e ajuste definitivo neste manual.

## Boas práticas
- Nunca commitar segredos reais.
- Usar valores mínimos necessários por ambiente.
- Rotacionar chaves periodicamente.
- Revisar flags para desligar recursos não usados e reduzir custo.
- Definir dono técnico por integração para acelerar incidentes.

## Integrações impactadas
- API de produtos
- Banco PostgreSQL
- Redis
- Autenticação JWT
- Observabilidade (Sentry/logs)

## Mapa de responsabilidade operacional
- Produto/API: valida `PRODUCT_API_BASE_URL` e contratos de integração.
- Plataforma/Backend: valida `DATABASE_URL`, `DB_POOL_MIN` e `DB_POOL_MAX`.
- Plataforma/Runtime: valida `REDIS_URL`, `RUNTIME_TIMEOUT_MS` e feature flags.
- Segurança: valida `JWT_SECRET`, `JWT_EXPIRES_IN` e `ENCRYPTION_KEY`.
- Observabilidade: valida `SENTRY_DSN` e `LOG_LEVEL`.

## Referência cruzada para manutenção contínua
- Manual operacional de segredos: `tmp/runtime/codex-cloud-secrets.env`.
- Este documento deve ser atualizado sempre que novas integrações exigirem variáveis adicionais.
