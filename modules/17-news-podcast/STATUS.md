# Status - Valley News & Podcast

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

- Registry e estado: `database/postgres/007_v47_module_delivery_automation.sql` mantem `NEWS_PODCAST` como `PLANNED`. Esta revisao nao muda esse fato; ela apenas confirma que ja existe base compartilhada suficiente para um MVP sem criar schema paralelo prematuro.
- Suporte base de schema: `database/postgres/005_v47_domain_tables_core_first.sql` ja entrega `creator_uploads`, enquanto `database/postgres/004_v47_control_plane_modules_rules.sql` entrega `document_records`. Na camada NoSQL, `database/mongodb/001_ai_social_telemetry.mongo.js` ja entrega `social_videos`. Em conjunto, esses objetos sustentam upload, distribuicao de conteudo, metadata publica e anexos editoriais de forma parcial.
- Schema PostgreSQL especifico: `NEWS_PODCAST` nao abriu tabela dedicada neste momento. A decisao revisada e manter artigos, roteiros, capas, transcricoes e anexos legais apoiados por `creator_uploads` e `document_records`, descartando por enquanto uma tabela propria de episodios/editoriais para evitar duplicacao da fronteira `MEDIA`.
- Schema MongoDB especifico: `NEWS_PODCAST` tambem nao abriu collection dedicada. A decisao revisada e considerar `social_videos` como base compartilhada para metadados de episodio/clipping/feed, deixando uma collection propria de `news_articles` ou `podcast_episodes` para quando houver workflow editorial, versionamento de pauta ou analytics especifico fora do escopo atual.
- Regras de negocio: nao existe, ate aqui, regra canonica exclusiva do modulo em `business_rule_definitions`. A decisao revisada e considerar isso descartado por enquanto, porque monetizacao, paywall, prioridade editorial e sponsorship ainda nao tem runtime proprio materializado no banco.
- Admin/RBAC/ABAC: o modulo herda governanca por `module_catalog`, `admin_permissions` e `admin_action_audit`, o que ja cobre controle de curadoria, publicacao e operacao administrativa por `module_code`.
- Manual/PDF: `MANUAL_ONLINE/README.md` e `MANUAL_ONLINE/04_ROADMAP_IMPLEMENTACAO_SPRINTS.md` agora deixam explicito que `NEWS_PODCAST` continua planejado, mas pode nascer sobre a pipeline compartilhada de `MEDIA` e `SOCIAL` sem schema novo imediato. O PDF oficial foi regenerado apos esta revisao documental.

Plano minimo de testes de integracao:

1. Criar `creator_upload` com `user_id`, `file_url`, `upload_status` e `checksum_sha256`, validando a esteira basica de ingestao de audio, thumbnail ou clipe editorial.
2. Registrar `document_record` com `module_code = 'NEWS_PODCAST'`, `file_url` e `checksum_sha256`, validando trilha append-only para roteiro, transcricao ou comprovante de licenciamento.
3. Inserir documento em `social_videos` para um episodio/clipping com `creator_user_id`, `owner_user_id`, `caption`, `visibility` e `status`, confirmando a publicacao de metadata compartilhada.
4. Consultar o conteudo por criador e status usando os indices existentes de `creator_uploads` e `social_videos`, validando browse operacional sem collection dedicada.
5. Simular fluxo editorial minimo com upload, registro documental e publicacao social, confirmando que o modulo pode ser testado externamente sem criar schema redundante antes da prova de produto.

Observacao: este status deixou de ser apenas inicial e agora registra a primeira revisao tecnica do modulo, mantendo `NEWS_PODCAST` como planejado no registry, mas com base compartilhada ja identificada.
