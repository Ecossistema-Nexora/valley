# Stitch Valley ERP Integration Map

<!--
PROPOSITO: Mapear a conversao das telas Stitch v060 para Valley.
CONTEXTO: Este mapa orienta Figma handoff, Flutter e admin web a partir da fonte Stitch ativa.
REGRAS: Implementar por superficies reais, validar runtime e manter tokens Valley/Helena/V-Coin.
-->

## Decisao

- Fonte primaria de design: projeto Stitch `projects/12516070127536900621`.
- Assets brutos versionados: `docs/design/stitch_exports/20260516_valley_erp_v060/stitch_valley_erp`.
- Galeria ativa: `/stitch/20260516_valley_erp_v060/`.
- Handoff de design: consumir `docs/design/STITCH_VALLEY_V060_PUBLICATION.md` e `docs/specs/stitch_v060_generated_screens_summary.md` no Figma.
- Implementacao: admin web e Flutter devem consumir `config/design/valley_stitch_source_of_truth.json`.

## P0 v060

| Tela Stitch | Grupo | Superficie Valley | Alvo tecnico | Criterio de aceite |
| --- | --- | --- | --- | --- |
| `admin_god_mode` | admin | admin_web | admin/app.js + admin/styles.css | Sem botao morto, responsivo e validado no runtime local |
| `courier_delivery_flow_green` | entregador | courier_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado no runtime local |
| `courier_home_green` | entregador | courier_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado no runtime local |
| `merchant_dashboard` | lojista | merchant_erp | admin/app.js merchant ERP + Flutter handoff | Sem botao morto, responsivo e validado no runtime local |
| `merchant_finance_agenda_integrations` | lojista | merchant_erp | admin/app.js merchant ERP + Flutter handoff | Sem botao morto, responsivo e validado no runtime local |
| `merchant_login` | lojista | merchant_erp | admin/app.js merchant ERP + Flutter handoff | Sem botao morto, responsivo e validado no runtime local |
| `merchant_onboarding` | lojista | merchant_erp | admin/app.js merchant ERP + Flutter handoff | Sem botao morto, responsivo e validado no runtime local |
| `merchant_operations` | lojista | merchant_erp | admin/app.js merchant ERP + Flutter handoff | Sem botao morto, responsivo e validado no runtime local |
| `customer_checkout_payment` | usuario | customer_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado no runtime local |
| `customer_helena_support` | usuario | customer_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado no runtime local |
| `customer_home` | usuario | customer_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado no runtime local |
| `customer_merchant_chat` | usuario | customer_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado no runtime local |
| `customer_messages` | usuario | customer_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado no runtime local |
| `customer_purchases_tracking` | usuario | customer_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado no runtime local |
| `customer_stock_marketplace` | usuario | customer_mobile | frontend/flutter/lib/src/ui | Sem botao morto, responsivo e validado no runtime local |

## Guardrails

- Nao introduzir referencias proibidas de produto; usar Valley, Helena e V-Coin.
- Manter assets v060 publicados como referencia de handoff e fonte ativa de inspecao.
- Nao reintroduzir pacotes 20260513 como fonte ativa.
- Rodar validacao browser/HTTP para admin web e build Flutter quando tocar UI executavel.
