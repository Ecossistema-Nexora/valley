// PROPOSITO: Fechar contratos MongoDB de IA, telemetria, rastreio e payloads volumosos do Valley.
// CONTEXTO: Complementa PostgreSQL v041 mantendo MongoDB para dados de alto volume e nao estruturados.
// REGRAS: Nao armazenar segredos brutos, manter tenant_id/branch_id/user_id como escopo logico e usar validacao JSON Schema.

const UUID_PATTERN = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

function applyCollection(collectionName, validator) {
  const collectionExists = db.getCollectionNames().includes(collectionName);
  if (!collectionExists) {
    db.createCollection(collectionName, {
      validator,
      validationLevel: 'strict',
      validationAction: 'error',
    });
    return;
  }

  db.runCommand({
    collMod: collectionName,
    validator,
    validationLevel: 'strict',
    validationAction: 'error',
  });
}

const geoPointSchema = {
  bsonType: ['object', 'null'],
  required: ['type', 'coordinates'],
  properties: {
    type: { enum: ['Point'], description: 'Tipo GeoJSON.' },
    coordinates: {
      bsonType: 'array',
      minItems: 2,
      maxItems: 2,
      items: { bsonType: ['double', 'int', 'long', 'decimal'] },
      description: 'Coordenadas [longitude, latitude].',
    },
  },
  description: 'Ponto geoespacial opcional.',
};

const helenaAiContextEventsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['event_id', 'tenant_id', 'user_id', 'module_key', 'context_mode', 'event_type', 'summary', 'consent_scope', 'created_at'],
    additionalProperties: true,
    properties: {
      event_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do evento de contexto.' },
      tenant_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Escopo obrigatorio do lojista/usuario dono.' },
      branch_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Filial quando aplicavel.' },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'FK logica para users.user_id.' },
      merchant_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Lojista quando aplicavel.' },
      branch_unit_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Alias legado de filial quando aplicavel.' },
      module_key: { bsonType: 'string', minLength: 2, maxLength: 80, description: 'Modulo origem.' },
      context_mode: { enum: ['USER', 'MERCHANT', 'ADMIN', 'SUPPORT', 'SYSTEM'], description: 'Modo de contexto Helena.' },
      event_type: { bsonType: 'string', minLength: 2, maxLength: 120, description: 'Tipo de evento.' },
      summary: { bsonType: 'string', minLength: 1, maxLength: 8000, description: 'Resumo seguro sem segredo bruto.' },
      consent_scope: { enum: ['NONE', 'SESSION', 'PROFILE', 'CROSS_MODULE'], description: 'Escopo de consentimento.' },
      birth_city: { bsonType: ['string', 'null'], maxLength: 120, description: 'Cidade de nascimento para personalizacao regional.' },
      birth_state: { bsonType: ['string', 'null'], maxLength: 2, description: 'UF de nascimento para personalizacao regional.' },
      regional_accent_code: { bsonType: ['string', 'null'], maxLength: 80, description: 'Codigo de sotaque pt-BR da Helena.' },
      tone_profile: { bsonType: ['string', 'null'], maxLength: 120, description: 'Perfil de tom da Helena.' },
      vector_ref: { bsonType: ['string', 'null'], maxLength: 512, description: 'Referencia de embedding externo.' },
      retention_policy: { enum: ['EPHEMERAL', 'STANDARD', 'AUDIT', 'LEGAL_HOLD'], description: 'Politica de retencao.' },
      metadata: { bsonType: ['object', 'null'], description: 'Metadados controlados.' },
      created_at: { bsonType: 'date', description: 'Criacao do evento.' },
    },
  },
};

const merchantIntegrationPayloadLogsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['payload_log_id', 'tenant_id', 'merchant_user_id', 'provider_key', 'direction', 'event_type', 'payload_hash', 'status', 'created_at'],
    additionalProperties: true,
    properties: {
      payload_log_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do log de payload.' },
      tenant_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Escopo obrigatorio do lojista.' },
      branch_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Filial quando aplicavel.' },
      merchant_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Lojista dono da integracao.' },
      branch_unit_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Filial relacionada.' },
      provider_key: { bsonType: 'string', minLength: 2, maxLength: 80, description: 'Marketplace, banco ou provider externo.' },
      direction: { enum: ['INBOUND', 'OUTBOUND'], description: 'Direcao do trafego.' },
      event_type: { bsonType: 'string', minLength: 2, maxLength: 120, description: 'Tipo do evento externo.' },
      payload_hash: { bsonType: 'string', minLength: 16, maxLength: 256, description: 'Hash do payload normalizado.' },
      payload_ref: { bsonType: ['string', 'null'], maxLength: 1024, description: 'Referencia segura para storage externo.' },
      status: { enum: ['RECEIVED', 'VALIDATED', 'REJECTED', 'PROCESSED', 'FAILED'], description: 'Status de processamento.' },
      correlation_id: { bsonType: ['string', 'null'], maxLength: 160, description: 'Correlacao com Postgres ou trace.' },
      error_summary: { bsonType: ['string', 'null'], maxLength: 2000, description: 'Resumo do erro sem segredo.' },
      metadata: { bsonType: ['object', 'null'], description: 'Metadados controlados.' },
      created_at: { bsonType: 'date', description: 'Criacao do log.' },
    },
  },
};

const merchantRealtimeDeliveryStreamValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['tracking_event_id', 'tenant_id', 'merchant_user_id', 'delivery_assignment_id', 'event_type', 'event_time', 'ingested_at'],
    additionalProperties: true,
    properties: {
      tracking_event_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do evento de rastreio.' },
      tenant_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Escopo obrigatorio do lojista.' },
      branch_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Filial quando aplicavel.' },
      merchant_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Lojista dono da entrega.' },
      branch_unit_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Filial de origem.' },
      delivery_assignment_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Entrega relacional no Postgres.' },
      courier_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Entregador vinculado.' },
      order_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Pedido vinculado.' },
      tracking_code: { bsonType: ['string', 'null'], maxLength: 120, description: 'Codigo publico de rastreio.' },
      event_type: { enum: ['GPS_PING', 'STATUS_CHANGE', 'PROOF_CAPTURED', 'ROUTE_RECALCULATED', 'CUSTOMER_NOTIFIED'], description: 'Tipo de evento.' },
      status: { bsonType: ['string', 'null'], maxLength: 80, description: 'Status operacional.' },
      geo: geoPointSchema,
      speed_kph: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, description: 'Velocidade em km/h.' },
      battery_level: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, maximum: 100, description: 'Bateria do aparelho.' },
      event_time: { bsonType: 'date', description: 'Horario do evento na origem.' },
      ingested_at: { bsonType: 'date', description: 'Horario de ingestao.' },
    },
  },
};

const erpOperationalTelemetryEventsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['telemetry_event_id', 'tenant_id', 'module_key', 'user_id', 'event_type', 'severity', 'created_at'],
    additionalProperties: true,
    properties: {
      telemetry_event_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID da telemetria operacional.' },
      tenant_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Escopo obrigatorio para consulta e relatorio.' },
      branch_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Filial quando aplicavel.' },
      module_key: { bsonType: 'string', minLength: 2, maxLength: 80, description: 'Modulo origem.' },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario principal.' },
      merchant_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Lojista relacionado.' },
      branch_unit_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Filial relacionada.' },
      event_type: { bsonType: 'string', minLength: 2, maxLength: 120, description: 'Tipo da telemetria.' },
      severity: { enum: ['INFO', 'WARN', 'ERROR', 'CRITICAL'], description: 'Severidade.' },
      duration_ms: { bsonType: ['int', 'long', 'double', 'null'], minimum: 0, description: 'Duracao em ms.' },
      payload_summary: { bsonType: ['object', 'null'], description: 'Resumo estruturado sem segredo.' },
      correlation_id: { bsonType: ['string', 'null'], maxLength: 160, description: 'Correlacao operacional.' },
      created_at: { bsonType: 'date', description: 'Criacao do evento.' },
    },
  },
};

const mobilityIdleAgentDecisionsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['decision_id', 'tenant_id', 'user_id', 'route_session_id', 'decision_type', 'decision_status', 'created_at'],
    additionalProperties: true,
    properties: {
      decision_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID da decisao autonoma de Mobilidade.' },
      tenant_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Escopo obrigatorio do usuario/lojista.' },
      branch_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Filial quando aplicavel.' },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario dono do trajeto.' },
      route_session_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Sessao relacional em mobility_realtime_route_sessions.' },
      commitment_ref: { bsonType: ['string', 'null'], maxLength: 200, description: 'Referencia do compromisso do usuario.' },
      decision_type: { enum: ['PRICE_SPIKE_REPLAN', 'PUBLIC_TRANSPORT_PLUS_FINAL_RIDE', 'ACCIDENT_RECALCULATION', 'DELAY_ALERT', 'VISIO_AVAILABILITY_CHECK'], description: 'Tipo de decisao.' },
      decision_status: { enum: ['PROPOSED', 'ACCEPTED', 'REJECTED', 'AUTO_APPLIED', 'FAILED'], description: 'Status da decisao.' },
      providers_considered: {
        bsonType: ['array', 'null'],
        items: { bsonType: 'string' },
        description: 'Providers considerados como onibus, metro e transporte por aplicativo.',
      },
      route_mix: { bsonType: ['object', 'null'], description: 'Composicao recomendada da rota.' },
      money_saved_brl: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, description: 'Economia estimada.' },
      time_saved_minutes: { bsonType: ['int', 'long', 'null'], description: 'Tempo economizado ou delta estimado.' },
      incident_summary: { bsonType: ['string', 'null'], maxLength: 2000, description: 'Acidente, atraso ou evento externo.' },
      notification_copy_ptbr: { bsonType: ['string', 'null'], maxLength: 2000, description: 'Mensagem proativa da Helena em pt-BR.' },
      geo: geoPointSchema,
      metadata: { bsonType: ['object', 'null'], description: 'Metadados controlados sem segredo.' },
      created_at: { bsonType: 'date', description: 'Criacao da decisao.' },
    },
  },
};

const marketplaceAndroidLiveTrackingStreamValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['stream_event_id', 'tenant_id', 'live_tracking_session_id', 'order_id', 'origin_module', 'platform_scope', 'event_type', 'event_time', 'ingested_at'],
    additionalProperties: true,
    properties: {
      stream_event_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do evento de live tracking Android.' },
      tenant_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Escopo obrigatorio do lojista Marketplace.' },
      branch_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Filial quando aplicavel.' },
      live_tracking_session_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Sessao relacional em marketplace_android_live_tracking_sessions.' },
      order_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Pedido Marketplace vinculado.' },
      delivery_assignment_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Entrega relacional quando atribuida.' },
      customer_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Cliente final.' },
      courier_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Entregador/veiculo.' },
      origin_module: { enum: ['MARKETPLACE'], description: 'Origem permitida. STOCK e dropshipping nao ativam esta feature.' },
      platform_scope: { enum: ['ANDROID_ONLY'], description: 'Recurso exclusivo do Super APK Android.' },
      event_type: { enum: ['FCM_SILENT_PUSH', 'FOREGROUND_STARTED', 'LIVE_UPDATE_RENDERED', 'MAP_POSITION_UPDATE', 'ETA_UPDATE', 'STATUS_CHANGE', 'DELIVERED_AUDIO_OPTION'], description: 'Tipo de evento Android.' },
      geo: geoPointSchema,
      eta_minutes: { bsonType: ['int', 'long', 'null'], minimum: 0, description: 'ETA da entrega.' },
      notification_state: { bsonType: ['object', 'null'], description: 'Estado da notificacao rica/lockscreen.' },
      map_snapshot_ref: { bsonType: ['string', 'null'], maxLength: 1024, description: 'Referencia segura do snapshot de mapa, quando existir.' },
      event_time: { bsonType: 'date', description: 'Horario do evento no dispositivo/backend.' },
      ingested_at: { bsonType: 'date', description: 'Horario de ingestao.' },
    },
  },
};

const marketplaceChatModerationEventsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['moderation_event_id', 'tenant_id', 'conversation_id', 'message_id', 'user_id', 'event_type', 'created_at'],
    additionalProperties: true,
    properties: {
      moderation_event_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do evento de moderacao.' },
      tenant_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Lojista dono do contexto Marketplace.' },
      branch_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Filial quando aplicavel.' },
      conversation_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Conversa oficial Valley.' },
      message_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Mensagem append-only relacionada.' },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario que acionou a regra.' },
      merchant_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Lojista relacionado.' },
      event_type: { enum: ['EXTERNAL_CONTACT_DETECTED', 'HELENA_WARNING_SENT', 'SEVERE_WARNING_ACK_REQUIRED', 'SUSPENSION_EVENT_CREATED'], description: 'Evento de moderacao.' },
      matched_pattern: { bsonType: ['string', 'null'], maxLength: 120, description: 'Padrao que acionou o evento.' },
      strike_count: { bsonType: ['int', 'long', 'null'], minimum: 1, description: 'Contador de advertencias.' },
      summary: { bsonType: ['string', 'null'], maxLength: 2000, description: 'Resumo sem expor conteudo sensivel bruto.' },
      created_at: { bsonType: 'date', description: 'Criacao do evento.' },
    },
  },
};

applyCollection('helena_ai_context_events', helenaAiContextEventsValidator);
applyCollection('merchant_integration_payload_logs', merchantIntegrationPayloadLogsValidator);
applyCollection('merchant_realtime_delivery_stream', merchantRealtimeDeliveryStreamValidator);
applyCollection('erp_operational_telemetry_events', erpOperationalTelemetryEventsValidator);
applyCollection('mobility_idle_agent_decisions', mobilityIdleAgentDecisionsValidator);
applyCollection('marketplace_android_live_tracking_stream', marketplaceAndroidLiveTrackingStreamValidator);
applyCollection('marketplace_chat_moderation_events', marketplaceChatModerationEventsValidator);

db.helena_ai_context_events.createIndex({ tenant_id: 1, branch_id: 1, user_id: 1, created_at: -1 }, { name: 'ix_helena_context_scope_user_time' });
db.helena_ai_context_events.createIndex({ user_id: 1, created_at: -1 }, { name: 'ix_helena_context_user_time' });
db.helena_ai_context_events.createIndex({ merchant_user_id: 1, module_key: 1, created_at: -1 }, { name: 'ix_helena_context_merchant_module_time', sparse: true });

db.merchant_integration_payload_logs.createIndex({ tenant_id: 1, branch_id: 1, provider_key: 1, created_at: -1 }, { name: 'ix_integration_payload_scope_provider_time' });
db.merchant_integration_payload_logs.createIndex({ merchant_user_id: 1, provider_key: 1, created_at: -1 }, { name: 'ix_integration_payload_merchant_provider_time' });
db.merchant_integration_payload_logs.createIndex({ correlation_id: 1 }, { name: 'ix_integration_payload_correlation', sparse: true });
db.merchant_integration_payload_logs.createIndex({ payload_hash: 1 }, { name: 'ix_integration_payload_hash' });

db.merchant_realtime_delivery_stream.createIndex({ tenant_id: 1, branch_id: 1, event_time: -1 }, { name: 'ix_delivery_stream_scope_time' });
db.merchant_realtime_delivery_stream.createIndex({ delivery_assignment_id: 1, event_time: -1 }, { name: 'ix_delivery_stream_assignment_time' });
db.merchant_realtime_delivery_stream.createIndex({ merchant_user_id: 1, branch_unit_id: 1, event_time: -1 }, { name: 'ix_delivery_stream_merchant_branch_time' });
db.merchant_realtime_delivery_stream.createIndex({ geo: '2dsphere' }, { name: 'ix_delivery_stream_geo', sparse: true });

db.erp_operational_telemetry_events.createIndex({ tenant_id: 1, branch_id: 1, module_key: 1, created_at: -1 }, { name: 'ix_erp_telemetry_scope_module_time' });
db.erp_operational_telemetry_events.createIndex({ module_key: 1, severity: 1, created_at: -1 }, { name: 'ix_erp_telemetry_module_severity_time' });
db.erp_operational_telemetry_events.createIndex({ merchant_user_id: 1, branch_unit_id: 1, created_at: -1 }, { name: 'ix_erp_telemetry_merchant_branch_time', sparse: true });

db.mobility_idle_agent_decisions.createIndex({ tenant_id: 1, branch_id: 1, user_id: 1, created_at: -1 }, { name: 'ix_mobility_decisions_scope_user_time' });
db.mobility_idle_agent_decisions.createIndex({ route_session_id: 1, created_at: -1 }, { name: 'ix_mobility_decisions_route_time' });
db.mobility_idle_agent_decisions.createIndex({ decision_type: 1, decision_status: 1, created_at: -1 }, { name: 'ix_mobility_decisions_type_status_time' });
db.mobility_idle_agent_decisions.createIndex({ geo: '2dsphere' }, { name: 'ix_mobility_decisions_geo', sparse: true });

db.marketplace_android_live_tracking_stream.createIndex({ tenant_id: 1, branch_id: 1, order_id: 1, event_time: -1 }, { name: 'ix_marketplace_android_tracking_scope_order_time' });
db.marketplace_android_live_tracking_stream.createIndex({ live_tracking_session_id: 1, event_time: -1 }, { name: 'ix_marketplace_android_tracking_session_time' });
db.marketplace_android_live_tracking_stream.createIndex({ geo: '2dsphere' }, { name: 'ix_marketplace_android_tracking_geo', sparse: true });

db.marketplace_chat_moderation_events.createIndex({ tenant_id: 1, user_id: 1, created_at: -1 }, { name: 'ix_marketplace_chat_moderation_user_time' });
db.marketplace_chat_moderation_events.createIndex({ conversation_id: 1, message_id: 1 }, { name: 'ix_marketplace_chat_moderation_conversation_message' });
