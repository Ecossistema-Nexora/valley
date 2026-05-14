# Stitch Valley ERP Integration Map

<!--
PROPOSITO: Mapear a conversao das telas Stitch para Valley.
CONTEXTO: Este mapa orienta Figma handoff, Flutter e admin web a partir da fonte Stitch ativa.
REGRAS: Implementar por ondas, validar em browser/Flutter e manter tokens Valley/Helena/V-Coin.
-->

## Decisao

- Fonte primaria de design: export Stitch `stitch_valley_erp (2).zip`.
- Assets brutos versionados: `docs/design/stitch_exports/20260513_valley_erp_v2/`.
- Staging local ignorado: `tmp/stitch-import/`.
- Handoff de design: promover P0 para Figma antes de codificar grandes superficies.
- Implementacao: converter componentes e fluxos, mantendo HTML bruto como galeria de referencia e fonte ativa de inspecao.

## Onda 1 - P0

| Tela Stitch | Superficie Valley | Alvo tecnico | Criterio de aceite |
| --- | --- | --- | --- |
| `valley_admin_central_1` | admin_web | admin/app.js + admin/styles.css | Sem botao morto, responsivo e validado em browser/mobile |
| `valley_admin_central_2` | admin_web | admin/app.js + admin/styles.css | Sem botao morto, responsivo e validado em browser/mobile |
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
| `valley_portal_p_blico_pt_br` | usuario_publico | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado em browser/mobile |

## Onda 2 - P1

- Financeiro, logistica, marketplace, relatorios, configuracoes, suporte e auditoria.
- Depois da Onda 1, aplicar os mesmos componentes base para evitar duplicacao visual.

## Guardrails

- Nao introduzir referencias proibidas de produto; usar Valley, Helena e V-Coin.
- Manter assets brutos versionados e publicados como referencia de handoff e fonte ativa de inspecao.
- Nao quebrar o APK v038 nem o gate Cloudflare validado.
- Rodar Playwright/browser para admin web e build Flutter quando tocar UI executavel.
