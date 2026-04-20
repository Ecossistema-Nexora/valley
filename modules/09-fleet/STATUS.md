# Status - Valley Fleet

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

- PostgreSQL: `FLEET` nao abriu tabela propria. A decisao revisada e manter o modulo fora do PostgreSQL para telemetria, manutencao e cadastro vivo de veiculo, usando apenas ponte logica com `users.user_id`, `trip_id`, `shipment_id` e outras entidades relacionais quando houver correlacao.
- MongoDB: `database/mongodb/003_v47_field_ops_security_agenda.mongo.js` cobre `fleet_vehicle_profiles` e `fleet_maintenance_events` como contrato principal do modulo, com `JSON Schema Validation`, ownership por `owner_user_id`, vinculo opcional a rider e indices por status, prazo e historico.
- Cobertura complementar: o modulo reutiliza `iot_device_registry` e `iot_sensor_events` do `database/mongodb/002_v47_log_iot_foundation.mongo.js` para rastreadores, gateways e sinais de telemetria conectados ao veiculo.
- Regras de negocio: nao existe, ate este ponto, regra canonica exclusiva de `FLEET` em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque o modulo ja esta blindado por enums, `required`, validacao estrutural e indices; regras parametrizadas entram apenas quando houver politica variavel de manutencao, bloqueio por quilometragem, cold chain ou risco operacional.
- Admin/RBAC/ABAC: o desenho usa `module_catalog` + `admin_permissions` para permissao por `module_code`, com trilha de auditoria no control plane.
- Manual/PDF: `MANUAL_ONLINE/README.md`, `MANUAL_ONLINE/01_ARQUITETURA_TECNICA_MICROSSERVICOS_EVENTOS.md`, `MANUAL_ONLINE/02_MODELAGEM_BANCO_DADOS.md`, `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` e `output/pdf/VALLEY_MANUAL_ONLINE.pdf` ja refletem o modulo.

Plano minimo de testes de integracao:

1. Inserir documento em `fleet_vehicle_profiles` com `owner_user_id`, `module_code`, `vehicle_class`, `vehicle_status`, `identifiers` e `maintenance_policy`, validando contrato minimo e status do veiculo.
2. Vincular `assigned_rider_user_id` e `device_refs`, confirmando ponte logica com rider e rastreador sem tabela relacional paralela.
3. Inserir documento em `fleet_maintenance_events` com `vehicle_id`, `event_type`, `severity`, `event_status`, `occurred_at` e `due_at`, validando historico tecnico e fila preventiva.
4. Criar `iot_device_registry` e `iot_sensor_events` ligados ao veiculo, validando ingestao de telemetria distribuida e reconstrucao de timeline por `device_id`.
5. Simular veiculo em `ACTIVE`, depois `MAINTENANCE` e `BLOCKED`, confirmando leitura operacional por owner/status e acoplamento com `LOG` e `SECURITY` por correlacao.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo.
