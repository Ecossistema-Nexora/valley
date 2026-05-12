# Plano v036 - ERP lojista marketplace operacional

Criado em BRT: 2026-05-12 00:42:57 BRT

## Objetivo

Materializar o ERP do lojista para entrar no ar nos subdominios publicos ja publicados, com schema relacional, integracoes operacionais, mecanicas de painel e frontend baseado nas referencias visuais de ERP em desktop/mobile enviadas pelo Anderson.

## Escopo

- Criar migration PostgreSQL aditiva para workspace ERP do lojista.
- Registrar tabelas de PDV, armazem, metricas, campanhas, relatorios, financeiro, cadastro, perfil, contabil, fiscal, integracoes, equipe, seguranca e auditoria.
- Ligar o frontend do painel lojista aos subdominios oficiais HTTPS custo zero.
- Entregar uma superficie visual real no `admin/` com navegacao superior, cards de metricas, atalhos por modulo, tabelas operacionais e acoes com estado local.
- Gerar um blueprint release unico para Stitch redesenhar os templates web sem ferramentas dev, comandos ou docks laterais.
- Validar sintaxe, manifesto, servidor e links publicos principais.

## Checklist

- [x] Plano persistente criado em `PLANOS/`.
- [x] Migration PostgreSQL do ERP lojista criada e registrada no manifesto.
- [x] Seed operacional do lojista demo criada e aplicada.
- [x] Frontend ERP lojista criado no painel admin/publico.
- [x] Docks, sidebars e abas laterais removidos do admin e do lojista.
- [x] Mecanicas interativas sem botoes mortos implementadas.
- [x] Blueprint release unico para Stitch criado.
- [x] Validacoes locais de sintaxe, manifesto e runtime executadas.
- [x] Links publicos do lojista verificados.

## Decisoes

- O acesso oficial do lojista usa `https://lojista.brasildesconto.com.br/`.
- O centro ERP usa `https://erp-lojista.brasildesconto.com.br/`.
- Os modulos ERP usam subdominios de primeiro nivel, como `pdv-lojista.brasildesconto.com.br`, para manter custo zero com SSL Universal.
- O frontend deve parecer um ERP real, nao landing page: navegacao superior/inline, operacao densa, cards pequenos, tabelas, acoes e status por rotina.
- Admin e lojista nao devem usar docks laterais, sidebars fixas ou abas laterais em nenhum dominio/subdominio.
- O blueprint para Stitch deve ser release: sofisticado, conciso, funcional, sem ferramentas dev, sem comandos e sem seções de bastidor.
- Todo blueprint, label, botao, campo, estado e texto de interface deve permanecer em portugues do Brasil de forma obrigatoria.

## Evidencias

- `database/postgres/037_v47_merchant_erp_marketplace_management.sql` criou 16 relacoes `merchant_erp_*`, enums, triggers e `v_merchant_erp_control_tower`.
- `database/seeds/postgres/004_v47_merchant_erp_seed.sql` aplicou 22 workspaces ERP do lojista, staff owner e 7 conexoes de integracao em estado inicial.
- `python scripts/valley_db_orchestrator.py check` validou manifesto com 37 migrations PostgreSQL e 5 scripts MongoDB.
- `node --check admin/app.js` e `python -m py_compile scripts/serve_valley_admin.py` executados com sucesso.
- Runtime publico validado em `https://admin.brasildesconto.com.br/`, `https://lojista.brasildesconto.com.br/`, `https://erp-lojista.brasildesconto.com.br/` e `https://pdv-lojista.brasildesconto.com.br/` com HTTP 200, sem `control-dock`.
- Shell release validado sem `Runbook`, `Comandos-chave`, `Copiar JSON`, `Healthz`, `Admin data`, `<aside>` ou sidebar visivel no HTML publico e no `app.js` versionado.
- Login lojista QA validado em `https://erp-lojista.brasildesconto.com.br/api/auth/login` com cookie `valley_session` em `.brasildesconto.com.br`.
- Render Playwright validou ERP lojista, modulo PDV, botoes `Salvar rotina`, `Aplicar sync` e `Gerar relatorio`.
- Evidencias visuais sem docks laterais salvas em `output/validation/merchant-erp-release-no-dock-desktop.png` e `output/validation/merchant-erp-release-no-dock-mobile.png`.
- Blueprint release criado em `docs/design/valley-stitch-template-blueprint-release-v036.md`.
- Regra de idioma pt-BR obrigatorio persistida no blueprint release e neste plano.
