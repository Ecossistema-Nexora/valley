# Status - Valley Log

- [x] Registry canonico criado.
- [x] Suporte base de schema ja implantado ou parcialmente implantado.
- [x] Contrato operacional inicial gerado.
- [x] Schema PostgreSQL especifico revisado.
- [x] Schema MongoDB especifico revisado.
- [x] Regras de negocio cadastradas ou descartadas.
- [x] Fluxos Admin/RBAC/ABAC definidos.
- [x] Testes de integracao planejados.
- [x] Manual Online atualizado.
- [x] PDF regenerado.

Evidencias da revisao:

- PostgreSQL: `LOG` nao abriu tabela propria. A decisao revisada e manter o modulo fora do PostgreSQL para eventos volumosos, usando apenas ponte logica com `users.user_id`, `orders.order_id` e entidades operacionais relacionais quando houver correlacao.
- MongoDB: `database/mongodb/002_v47_log_iot_foundation.mongo.js` cobre `log_tracking_events` como contrato principal do modulo, com `JSON Schema Validation`, `UUID` em string, `GeoJSON Point`, indices por usuario/remessa e indice geoespacial.
- Cobertura complementar: o mesmo script cria `iot_device_registry` e `iot_sensor_events`, que podem alimentar tracking e observabilidade de rota sem empurrar payload bruto para o relacional.
- Regras de negocio: nao existe, ate este ponto, regra canonica exclusiva de `LOG` em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque o modulo ja esta blindado por enums, `required`, validacao estrutural e indices; regras parametrizadas entram apenas quando houver SLA por transportadora, prioridade dinamica de rota ou politicas variaveis de excecao.
- Admin/RBAC/ABAC: o desenho usa `module_catalog` + `admin_permissions` para permissao por `module_code`, com trilha de auditoria no control plane.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `MANUAL_ONLINE/OPERACAO_AUTONOMA.md` ja refletem o modulo. `output/pdf/VALLEY_MANUAL_ONLINE.pdf` existe e esta mais novo que `database/mongodb/002_v47_log_iot_foundation.mongo.js`.

Plano minimo de testes de integracao:

1. Inserir documento em `log_tracking_events` com `user_id`, `shipment_ref`, `event_type`, `event_status`, `event_time` e `ingested_at`, validando contrato minimo e ordenacao por tempo.
2. Inserir documento em `log_tracking_events` com `order_id`, `rider_user_id` e `geo`, validando ponte logica com o relacional e consulta geoespacial.
3. Criar `iot_device_registry` para `module_code = 'LOG'`, validando unicidade de `device_id`, ownership e ciclo de status.
4. Inserir documento em `iot_sensor_events` ligado ao device, com `geo`, `severity` e `correlation_id`, validando ingestao de sensor de rota sem schema legado paralelo.
5. Simular fluxo de excecao com eventos `IN_TRANSIT`, `FAILED_DELIVERY` e `EXCEPTION`, validando leitura operacional por `shipment_ref` e reconstruindo timeline completa do tracking.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
