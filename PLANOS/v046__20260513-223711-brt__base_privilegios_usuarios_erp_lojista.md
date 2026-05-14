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
- [ ] Integrar backend/admin runtime para listar usuarios e privilegios efetivos.
- [ ] Adaptar UI Equipe/Seguranca do ERP Lojista para gerenciar privilegios.
- [ ] Validar migration em compose e view `v_merchant_erp_staff_effective_privileges`.

## Evidencias

- Migration: `database/postgres/038_v47_merchant_erp_privileges_rbac.sql`.
- Manifesto: `database/migrations.json`.
- Spec: `docs/specs/merchant_erp_privileges_rbac.md`.

## Bloqueios

- A validacao em banco real ainda precisa rodar no compose.
- A UI ainda precisa consumir a view efetiva e bloquear botoes por privilegio.

## Proxima Acao

- Rodar validacao SQL/compose e expor payload de privilegios no backend do painel.
