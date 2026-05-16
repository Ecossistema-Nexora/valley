<!--
PROPOSITO: Registrar a entrega ininterrupta do blueprint de banco hibrido Valley.
CONTEXTO: O usuario determinou entrega total sem confirmacoes tecnicas padrao para finalizar o desenho PostgreSQL + MongoDB.
REGRAS: Manter nomenclatura Valley, preservar compatibilidade aditiva e validar manifestos antes de encerrar.
-->

# v059 - Blueprint banco hibrido Valley

## Escopo

Gerar a camada final de governanca de dados do ERP Lojista e do ecossistema Valley, cobrindo Postgres para identidade, dinheiro, contratos, pedidos e auditoria; MongoDB para IA Helena, telemetria, payloads volumosos e eventos operacionais.

## Checklist

- [x] Auditar o manifesto atual e confirmar que as migrations 001-040 ja cobrem identidade, wallets, ledger, pedidos, ERP Lojista, integrações, agenda, rastreio, etiquetas, trocas e financeiro.
- [x] Criar migration PostgreSQL aditiva para contratos institucionais de escopo por usuario, endereco, validacao documental, marketplace, APIs bancarias, modulos e ledger imutavel.
- [x] Criar migration MongoDB aditiva para contexto Helena, logs de integracao, rastreio em tempo real e telemetria operacional.
- [x] Incorporar `Especificacao_Master_Valley_ERP_v1 (1).md` com ACL tenant/filial, BR-PRO-001, Helena PT-BR, Mobilidade, Visio e contratos Stitch.
- [x] Incorporar `valley-marketplace-android-live-tracking.md` com rastreio Android exclusivo para pedidos Marketplace.
- [x] Incorporar `valley-marketplace-chat-rules.md` com chat append-only, moderacao anti-contato externo e regra de tres advertencias.
- [x] Sincronizar o handoff `merchant_erp_modules_operations_stitch_handoff.md` com Home, Stock Dropshipping, Chat Marketplace, Mobilidade, Visio e Rastreio Android.
- [x] Sincronizar o contrato estruturado `merchant_erp_stitch_module_layout_contract.json` para versao v059.
- [x] Atualizar `database/migrations.json` com os novos artefatos.
- [x] Validar JSON/JS/Python e executar o check estatico do orquestrador.
- [x] Acionar a rotina mandatória Valley Module Activity.

## Criterios de aceite

- O Postgres continua sendo o cofre para identidade, transacao, contrato, operacao fiscal, pedidos e auditoria.
- O MongoDB continua sendo a camada de volume para IA, rastreio, telemetria e payloads externos.
- Todo novo contrato operacional possui vinculo explicito a `users.user_id` ou a um usuario lojista.
- Nenhum dado sensivel bruto ou token de API e versionado.
