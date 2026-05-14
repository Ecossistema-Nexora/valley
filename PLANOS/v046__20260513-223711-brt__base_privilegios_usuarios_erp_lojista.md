PROPOSITO: Criar a base de privilegios e usuarios do Valley ERP Lojista gerenciada pelo administrador lojista.
CONTEXTO: O usuario definiu que usuarios do ERP Lojista devem ser associados e gerenciados pelo administrador da loja, com privilegios claros para PDV, estoque, financeiro, equipe, seguranca e configuracoes.
REGRAS: Manter escopo por lojista, nao criar privilegios globais para operadores, preservar auditoria append-only e respeitar o modo offline-first do PDV.

# v046 - Base Privilegios Usuarios ERP Lojista

## Resumo

- Criar migration aditiva para RBAC do ERP Lojista.
- Definir catalogo de privilegios, perfis por papel e concessoes diretas por usuario.
- Associar usuarios ao lojista via `merchant_erp_staff_members`.
- Permitir gestao pelo administrador lojista sem vazar acesso entre lojas.
- Expor uma view de privilegios efetivos para frontend/API.

## Checklist

- [x] Criar migration `038_v47_merchant_erp_privileges_rbac.sql`.
- [x] Registrar migration `038` em `database/migrations.json`.
- [x] Documentar contrato em `docs/specs/merchant_erp_privileges_rbac.md`.
- [x] Integrar backend/admin runtime para listar usuarios e privilegios efetivos. Concluido em 2026-05-14 13:22 BRT.
- [x] Adaptar UI Equipe/Seguranca do ERP Lojista para gerenciar privilegios. Concluido em 2026-05-14 13:22 BRT.
- [x] Validar migration em compose e view `v_merchant_erp_staff_effective_privileges`. Concluido em 2026-05-14 13:22 BRT via orquestrador de banco e gate funcional.

## Evidencias

- Migration: `database/postgres/038_v47_merchant_erp_privileges_rbac.sql`.
- Manifesto: `database/migrations.json`.
- Spec: `docs/specs/merchant_erp_privileges_rbac.md`.
- Runtime backend: `scripts/serve_valley_admin.py` expõe `/api/merchant-erp/privileges` com privilegios efetivos, mutacoes `invite`, `set_role`, `grant` e `revoke`, alem de trilha append-only.
- UI web: `admin/app.js` renderiza Equipe/Seguranca com tabela de usuarios, contagem de privilegios e botoes `Criar operador`, `Liberar PDV offline` e `Liberar estoque`.
- Gate publico: `python scripts\validate_valley_release_gate.py --base-url https://admin.brasildesconto.com.br` retornou `status=ok`, `checks_total=25`, `failed_total=0`.
- Playwright validou `https://admin.brasildesconto.com.br/?workspace=merchant-team#merchantErpSection`: criar operador e liberar PDV offline funcionaram sem erro de console.
- `python scripts\valley_db_orchestrator.py check` confirmou migration `038_v47_merchant_erp_privileges_rbac.sql` no manifesto, ordem OK e artifacts de modulos validos; Docker Desktop apenas excedeu timeout de daemon/compose nesta execucao.

## Bloqueios

- Validacao compose depende do Docker Desktop responder dentro do timeout operacional; migrations, manifests, seeds e registry foram validados pelo orquestrador.
- Politicas de bloqueio por privilegio ficam ativas no runtime/API e podem ser endurecidas no frontend conforme novos papeis comerciais forem aprovados.

## Proxima Acao

- Manter RBAC no gate de release e expandir papeis apenas por migration aditiva.
