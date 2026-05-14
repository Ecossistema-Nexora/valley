# Stitch Valley ERP Integration Map

<!--
PROPOSITO: Mapear a conversao das telas Stitch para Valley.
CONTEXTO: Este mapa orienta Figma handoff, Flutter e admin web usando Stitch como fonte obrigatoria.
REGRAS: Implementar por ondas, validar em browser/Flutter, manter tokens Valley/Helena/V-Coin e descartar variacoes anteriores como referencia ativa.
-->

## Decisao

- Fonte da verdade mandataria: export Stitch `stitch_valley_erp (1).zip`, versao `20260513_valley_erp`.
- Assets brutos versionados: `docs/design/stitch_exports/20260513_valley_erp/`.
- Staging local ignorado: `tmp/stitch-import/`.
- Handoff de design: promover P0 para Figma quando houver alvo autenticado, sem bloquear a conversao web/APK ja aprovada.
- Implementacao: converter componentes e fluxos a partir do manifesto Stitch; HTML bruto fica como evidencia publica e variacoes antigas ficam descartadas como referencia de produto.

## Onda 1 - P0

| Tela Stitch | Superficie Valley | Alvo tecnico | Criterio de aceite |
| --- | --- | --- | --- |
| `valley_admin_central_1` | admin_web | admin/app.js + admin/styles.css | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_admin_central_2` | admin_web | admin/app.js + admin/styles.css | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_checkout_e_pagamento_mobile` | usuario_publico | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_cadastro_de_sku` | erp_lojista | admin/app.js merchant ERP tabs | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_cadastro_de_sku_mobile` | flutter_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_cadastro_de_sku_mobile_pt_br` | flutter_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_checkout_e_faturas_pt_br` | usuario_publico | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_checkout_lojista_pt_br` | usuario_publico | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_checkout_mobile_pt_br` | usuario_publico | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_do_lojista` | erp_lojista | admin/app.js merchant ERP tabs | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_gest_o_de_estoque_mobile` | flutter_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_gest_o_de_estoque_mobile_pt_br` | flutter_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_gest_o_de_pedidos_pt_br` | erp_lojista | admin/app.js merchant ERP tabs | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_erp_painel_de_controle_lojista` | erp_lojista | admin/app.js merchant ERP tabs | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_gest_o_de_estoque_pt_br` | shared_design | docs/design handoff | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_login` | flutter_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_login_e_cadastro_mobile` | flutter_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_login_lojista` | flutter_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_login_pt_br` | flutter_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_minhas_compras_mobile` | usuario_publico | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_portal_p_blico_pt_br` | usuario_publico | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |

## Onda 2 - P1

- Financeiro, logistica, marketplace, relatorios, configuracoes, suporte e auditoria.
- Depois da Onda 1, aplicar os mesmos componentes base para evitar duplicacao visual.

## Guardrails

- Nao introduzir referencias proibidas de produto; usar Valley, Helena e V-Coin.
- Manter assets brutos versionados e publicados como fonte auditavel do produto.
- Nao quebrar o APK v038 nem o gate Cloudflare validado.
- Rodar Playwright/browser para admin web e build Flutter quando tocar UI executavel.
