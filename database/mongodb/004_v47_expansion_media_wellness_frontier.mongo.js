// Valley Hybrid DB Bootstrap - Expansion media, wellness e frontier v47.
// Este script fecha os modulos ainda planejados com data home primario em MongoDB ou camada volumosa hibrida.
// Ele adiciona contratos para NEWS_PODCAST, FITNESS, GAMING, HOME, SPACE, TOURISM, BIO e ENERGY.
// Execute com mongosh depois de mongo-003 para manter a malha NoSQL consistente com a 014 relacional.

// UUID_PATTERN preserva a ponte logica com o PostgreSQL usando UUID tecnico em string.
const UUID_PATTERN = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

// applyCollection cria ou atualiza a collection sem apagar dados existentes.
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

// geoPointSchema reaproveita a validacao GeoJSON Point para mapas, wayfinding e sinais de campo.
const geoPointSchema = {
  bsonType: ['object', 'null'],
  required: ['type', 'coordinates'],
  properties: {
    type: { enum: ['Point'], description: 'GeoJSON Point.' },
    coordinates: {
      bsonType: 'array',
      minItems: 2,
      maxItems: 2,
      items: { bsonType: ['double', 'int', 'long', 'decimal'] },
      description: 'Longitude e latitude.',
    },
  },
  description: 'Localizacao GeoJSON para consultas geoespaciais.',
};

// newsContentItemsValidator guarda noticias, episodios e boletins editoriais com ponte segura para users.
const newsContentItemsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['content_id', 'owner_user_id', 'creator_user_id', 'module_code', 'content_type', 'title', 'publication_status', 'created_at', 'updated_at'],
    additionalProperties: true,
    properties: {
      content_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do item editorial.' },
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario dono da publicacao.' },
      creator_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Autor, host ou editor responsavel.' },
      module_code: { enum: ['NEWS_PODCAST'], description: 'Modulo emissor do documento.' },
      content_type: { enum: ['ARTICLE', 'PODCAST_EPISODE', 'LIVE_BULLETIN', 'NEWSLETTER'], description: 'Tipo de conteudo.' },
      title: { bsonType: 'string', minLength: 1, maxLength: 240, description: 'Titulo editorial.' },
      slug: { bsonType: ['string', 'null'], maxLength: 240, description: 'Slug publico do item.' },
      summary: { bsonType: ['string', 'null'], maxLength: 5000, description: 'Resumo editorial.' },
      language_code: { bsonType: ['string', 'null'], maxLength: 16, description: 'Idioma principal.' },
      publication_status: { enum: ['DRAFT', 'SCHEDULED', 'PUBLISHED', 'PAUSED', 'ARCHIVED', 'REMOVED'], description: 'Status de publicacao.' },
      published_at: { bsonType: ['date', 'null'], description: 'Data de publicacao.' },
      distribution_channels: {
        bsonType: 'array',
        items: { bsonType: 'string', maxLength: 80 },
        description: 'Canais de distribuicao.',
      },
      media_assets: {
        bsonType: 'array',
        items: { bsonType: 'object' },
        description: 'Assets de audio, imagem e texto.',
      },
      related_video_ids: {
        bsonType: 'array',
        items: { bsonType: 'string', pattern: UUID_PATTERN },
        description: 'Videos sociais relacionados.',
      },
      ad_slot_refs: {
        bsonType: 'array',
        items: { bsonType: 'string', maxLength: 160 },
        description: 'Slots de monetizacao e patrocinios.',
      },
      moderation_tags: {
        bsonType: 'array',
        items: { bsonType: 'string', maxLength: 80 },
        description: 'Tags de moderacao e compliance.',
      },
      metrics: { bsonType: ['object', 'null'], description: 'Metricas agregadas do item.' },
      created_at: { bsonType: 'date', description: 'Criacao do documento.' },
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao.' },
    },
  },
};

// fitnessActivitySessionsValidator guarda sessoes de movimento e a ponte futura com rewards e health.
const fitnessActivitySessionsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['session_id', 'user_id', 'module_code', 'activity_type', 'session_status', 'started_at', 'created_at', 'updated_at'],
    additionalProperties: true,
    properties: {
      session_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID da sessao fitness.' },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario dono da sessao.' },
      coach_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Coach ou profissional associado.' },
      module_code: { enum: ['FITNESS'], description: 'Modulo emissor.' },
      activity_type: { enum: ['WALK', 'RUN', 'CYCLE', 'WORKOUT', 'YOGA', 'HIIT', 'RECOVERY'], description: 'Tipo da atividade.' },
      session_status: { enum: ['PLANNED', 'IN_PROGRESS', 'COMPLETED', 'PAUSED', 'CANCELLED', 'SYNC_ERROR'], description: 'Status operacional da sessao.' },
      source_device_id: { bsonType: ['string', 'null'], maxLength: 160, description: 'Wearable ou app de origem.' },
      started_at: { bsonType: 'date', description: 'Inicio da sessao.' },
      ended_at: { bsonType: ['date', 'null'], description: 'Fim da sessao.' },
      distance_km: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, description: 'Distancia percorrida.' },
      duration_seconds: { bsonType: ['int', 'long', 'null'], minimum: 0, description: 'Duracao em segundos.' },
      calories_burned: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, description: 'Calorias estimadas.' },
      average_heart_rate: { bsonType: ['int', 'long', 'null'], minimum: 0, maximum: 260, description: 'Batimento medio.' },
      max_heart_rate: { bsonType: ['int', 'long', 'null'], minimum: 0, maximum: 260, description: 'Batimento maximo.' },
      reward_candidate_nex: { bsonType: ['double', 'decimal', 'null'], minimum: 0, description: 'Reward tecnico candidato em NEX.' },
      route_snapshot: { bsonType: ['object', 'null'], description: 'Snapshot de rota e checkpoints.' },
      health_links: {
        bsonType: 'array',
        items: { bsonType: 'object' },
        description: 'Pontes para HEALTH e outros dominios.',
      },
      created_at: { bsonType: 'date', description: 'Criacao do documento.' },
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao.' },
    },
  },
};

// gamingPlayerStatesValidator guarda estado do jogador, progressao e inventario resumido.
const gamingPlayerStatesValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['player_state_id', 'user_id', 'module_code', 'player_status', 'progression', 'inventory_summary', 'created_at', 'updated_at'],
    additionalProperties: true,
    properties: {
      player_state_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do estado do jogador.' },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Jogador vinculado ao users.user_id.' },
      module_code: { enum: ['GAMING'], description: 'Modulo emissor.' },
      player_status: { enum: ['ACTIVE', 'COOLDOWN', 'BANNED', 'ARCHIVED'], description: 'Status do jogador.' },
      nickname: { bsonType: ['string', 'null'], maxLength: 80, description: 'Apelido publico.' },
      season_code: { bsonType: ['string', 'null'], maxLength: 80, description: 'Temporada ativa.' },
      level: { bsonType: ['int', 'long', 'null'], minimum: 0, description: 'Nivel atual.' },
      xp_points: { bsonType: ['int', 'long', 'null'], minimum: 0, description: 'Experiencia acumulada.' },
      rank_tier: { bsonType: ['string', 'null'], maxLength: 80, description: 'Tier competitivo.' },
      guild_refs: {
        bsonType: 'array',
        items: { bsonType: 'string', maxLength: 160 },
        description: 'Guildas, squads ou comunidades.',
      },
      achievements: {
        bsonType: 'array',
        items: { bsonType: 'string', maxLength: 120 },
        description: 'Conquistas resumidas.',
      },
      progression: { bsonType: 'object', description: 'Resumo de quests, mapas e checkpoints.' },
      quest_summary: { bsonType: ['object', 'null'], description: 'Resumo das quests ativas.' },
      inventory_summary: { bsonType: 'object', description: 'Inventario resumido e seguro.' },
      wallet_links: { bsonType: ['object', 'null'], description: 'Ponte segura com rewards ou assets.' },
      last_session_at: { bsonType: ['date', 'null'], description: 'Ultima sessao vista.' },
      created_at: { bsonType: 'date', description: 'Criacao do estado.' },
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao.' },
    },
  },
};

// homeAutomationEventsValidator guarda eventos de automacao residencial, seguranca e modos energeticos.
const homeAutomationEventsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['automation_event_id', 'household_id', 'owner_user_id', 'module_code', 'event_type', 'event_status', 'source_device_id', 'occurred_at', 'ingested_at'],
    additionalProperties: true,
    properties: {
      automation_event_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do evento de automacao.' },
      household_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Casa ou household logico.' },
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Dono da residencia.' },
      module_code: { enum: ['HOME'], description: 'Modulo emissor.' },
      room_code: { bsonType: ['string', 'null'], maxLength: 80, description: 'Comodo afetado.' },
      source_device_id: { bsonType: 'string', minLength: 1, maxLength: 160, description: 'Dispositivo de origem.' },
      related_user_ids: {
        bsonType: 'array',
        items: { bsonType: 'string', pattern: UUID_PATTERN },
        description: 'Usuarios relacionados ao evento.',
      },
      event_type: { enum: ['SCENE_TRIGGERED', 'DEVICE_STATE_CHANGE', 'LOCK_EVENT', 'ALARM_EVENT', 'CLIMATE_CHANGE', 'ENERGY_MODE_CHANGE'], description: 'Tipo do evento.' },
      event_status: { enum: ['INFO', 'ACKNOWLEDGED', 'ACTIONED', 'FAILED', 'SUPPRESSED'], description: 'Status do tratamento.' },
      scenario_code: { bsonType: ['string', 'null'], maxLength: 120, description: 'Cena ou automacao disparada.' },
      energy_wh: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, description: 'Energia relacionada ao evento.' },
      security_signal_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Sinal de seguranca relacionado.' },
      geo: geoPointSchema,
      payload: { bsonType: ['object', 'null'], description: 'Payload tecnico do dispositivo.' },
      occurred_at: { bsonType: 'date', description: 'Horario do evento na origem.' },
      ingested_at: { bsonType: 'date', description: 'Horario de ingestao no backend.' },
    },
  },
};

// spaceAnchorMapsValidator guarda ancoras de realidade aumentada e experiencias imersivas.
const spaceAnchorMapsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['anchor_id', 'owner_user_id', 'module_code', 'anchor_type', 'anchor_status', 'title', 'world_ref', 'created_at', 'updated_at'],
    additionalProperties: true,
    properties: {
      anchor_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID da ancora espacial.' },
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario dono da ancora.' },
      tourism_experience_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Experiencia de turismo relacionada.' },
      social_video_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Video social relacionado.' },
      module_code: { enum: ['SPACE'], description: 'Modulo emissor.' },
      anchor_type: { enum: ['AR_PORTAL', 'IMMERSIVE_SCENE', 'WAYFINDING_MARKER', 'TREASURE_POINT', 'INFO_LAYER'], description: 'Tipo da ancora.' },
      anchor_status: { enum: ['DRAFT', 'ACTIVE', 'PAUSED', 'ARCHIVED'], description: 'Status operacional.' },
      title: { bsonType: 'string', minLength: 1, maxLength: 240, description: 'Titulo da ancora.' },
      world_ref: { bsonType: 'string', minLength: 1, maxLength: 160, description: 'Mundo, mapa ou scena alvo.' },
      geo: geoPointSchema,
      pose: { bsonType: ['object', 'null'], description: 'Pose, orientacao ou referencia 3D.' },
      asset_manifest: { bsonType: ['object', 'null'], description: 'Manifesto de assets renderizados.' },
      interaction_rules: { bsonType: ['object', 'null'], description: 'Regras de interacao e desbloqueio.' },
      analytics: { bsonType: ['object', 'null'], description: 'Metrica agregada da experiencia.' },
      created_at: { bsonType: 'date', description: 'Criacao do documento.' },
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao.' },
    },
  },
};

// tourismExperienceFeedsValidator guarda conteudo rico, reviews e wayfinding do modulo Tourism.
const tourismExperienceFeedsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['feed_id', 'experience_id', 'owner_user_id', 'module_code', 'feed_status', 'created_at', 'updated_at'],
    additionalProperties: true,
    properties: {
      feed_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do feed enriquecido.' },
      experience_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'FK logica para tourism_experiences.experience_id.' },
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Dono operacional da experiencia.' },
      guide_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Guide principal quando existir.' },
      module_code: { enum: ['TOURISM'], description: 'Modulo emissor.' },
      feed_status: { enum: ['DRAFT', 'ACTIVE', 'PAUSED', 'ARCHIVED'], description: 'Status do feed.' },
      highlight_text: { bsonType: ['string', 'null'], maxLength: 5000, description: 'Resumo editorial e promocional.' },
      media_gallery: {
        bsonType: 'array',
        items: { bsonType: 'object' },
        description: 'Galeria de midia e assets do passeio.',
      },
      route_waypoints: {
        bsonType: 'array',
        items: { bsonType: 'object' },
        description: 'Waypoints e passos da rota.',
      },
      language_packs: { bsonType: ['object', 'null'], description: 'Pacotes i18n e legendas.' },
      review_summary: { bsonType: ['object', 'null'], description: 'Resumo agregado de reviews.' },
      live_availability: { bsonType: ['object', 'null'], description: 'Disponibilidade e lotacao em tempo quase real.' },
      geo: geoPointSchema,
      created_at: { bsonType: 'date', description: 'Criacao do documento.' },
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao.' },
    },
  },
};

// bioImpactLogsValidator guarda leituras, verificacoes e sensores do modulo de sustentabilidade.
const bioImpactLogsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['impact_log_id', 'user_id', 'module_code', 'impact_type', 'impact_status', 'measured_at', 'ingested_at'],
    additionalProperties: true,
    properties: {
      impact_log_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do log de impacto.' },
      collection_order_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'FK logica para bio_collection_orders.collection_order_id.' },
      program_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'FK logica para bio_material_programs.program_id.' },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario dono do evento.' },
      partner_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Parceiro ou operador externo.' },
      module_code: { enum: ['BIO'], description: 'Modulo emissor.' },
      impact_type: { enum: ['WEIGH_IN', 'QUALITY_SCAN', 'CO2E_ESTIMATE', 'PARTNER_HANDOFF', 'CERTIFICATION'], description: 'Tipo do log de impacto.' },
      impact_status: { enum: ['RAW', 'VERIFIED', 'REJECTED', 'ENRICHED'], description: 'Status de confianca do log.' },
      device_id: { bsonType: ['string', 'null'], maxLength: 160, description: 'Sensor, balanca ou device de origem.' },
      geo: geoPointSchema,
      metrics: { bsonType: ['object', 'null'], description: 'Medidas enriquecidas do evento.' },
      sensor_payload: { bsonType: ['object', 'null'], description: 'Payload cru ou semi-estruturado.' },
      media_refs: {
        bsonType: 'array',
        items: { bsonType: 'string', maxLength: 2048 },
        description: 'Fotos, videos ou comprovantes externos.',
      },
      measured_at: { bsonType: 'date', description: 'Horario real da medicao.' },
      ingested_at: { bsonType: 'date', description: 'Horario de ingestao.' },
    },
  },
};

// energyMeterStreamsValidator guarda leituras de medidor, balanceamento e sinais de precificacao.
const energyMeterStreamsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['stream_event_id', 'energy_asset_id', 'owner_user_id', 'module_code', 'event_type', 'reading_window_start', 'reading_window_end', 'measured_at', 'ingested_at'],
    additionalProperties: true,
    properties: {
      stream_event_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do evento de medidor.' },
      trade_order_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'FK logica para energy_trade_orders.trade_order_id.' },
      energy_asset_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'FK logica para energy_assets.energy_asset_id.' },
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Dono do ativo energetico.' },
      counterparty_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Contraparte do fluxo quando existir.' },
      module_code: { enum: ['ENERGY'], description: 'Modulo emissor.' },
      event_type: { enum: ['CONSUMPTION_READING', 'GENERATION_READING', 'GRID_BALANCE', 'BATTERY_CYCLE', 'PRICE_SIGNAL'], description: 'Tipo do stream.' },
      reading_window_start: { bsonType: 'date', description: 'Inicio da janela de leitura.' },
      reading_window_end: { bsonType: 'date', description: 'Fim da janela de leitura.' },
      measured_at: { bsonType: 'date', description: 'Horario da leitura.' },
      ingested_at: { bsonType: 'date', description: 'Horario de ingestao no backend.' },
      kwh_in: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, description: 'Energia consumida.' },
      kwh_out: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, description: 'Energia gerada ou exportada.' },
      net_kwh: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], description: 'Saldo liquido da janela.' },
      settlement_candidate_brl: { bsonType: ['double', 'decimal', 'null'], minimum: 0, description: 'Valor tecnico candidato para settlement.' },
      carbon_credit_candidate_nex: { bsonType: ['double', 'decimal', 'null'], minimum: 0, description: 'Credito tecnico candidato em NEX.' },
      geo: geoPointSchema,
      device_payload: { bsonType: ['object', 'null'], description: 'Payload detalhado do medidor.' },
    },
  },
};

applyCollection('news_content_items', newsContentItemsValidator);
applyCollection('fitness_activity_sessions', fitnessActivitySessionsValidator);
applyCollection('gaming_player_states', gamingPlayerStatesValidator);
applyCollection('home_automation_events', homeAutomationEventsValidator);
applyCollection('space_anchor_maps', spaceAnchorMapsValidator);
applyCollection('tourism_experience_feeds', tourismExperienceFeedsValidator);
applyCollection('bio_impact_logs', bioImpactLogsValidator);
applyCollection('energy_meter_streams', energyMeterStreamsValidator);

db.news_content_items.createIndex(
  { owner_user_id: 1, publication_status: 1, updated_at: -1 },
  { name: 'ix_news_content_items_owner_status_updated_at' },
);

db.news_content_items.createIndex(
  { creator_user_id: 1, published_at: -1 },
  { name: 'ix_news_content_items_creator_published_at', sparse: true },
);

db.fitness_activity_sessions.createIndex(
  { user_id: 1, session_status: 1, started_at: -1 },
  { name: 'ix_fitness_activity_sessions_user_status_started_at' },
);

db.fitness_activity_sessions.createIndex(
  { source_device_id: 1, started_at: -1 },
  { name: 'ix_fitness_activity_sessions_device_started_at', sparse: true },
);

db.gaming_player_states.createIndex(
  { user_id: 1 },
  { name: 'ux_gaming_player_states_user_id', unique: true },
);

db.gaming_player_states.createIndex(
  { player_status: 1, updated_at: -1 },
  { name: 'ix_gaming_player_states_status_updated_at' },
);

db.home_automation_events.createIndex(
  { owner_user_id: 1, event_status: 1, occurred_at: -1 },
  { name: 'ix_home_automation_events_owner_status_occurred_at' },
);

db.home_automation_events.createIndex(
  { source_device_id: 1, occurred_at: -1 },
  { name: 'ix_home_automation_events_device_occurred_at' },
);

db.space_anchor_maps.createIndex(
  { owner_user_id: 1, anchor_status: 1, updated_at: -1 },
  { name: 'ix_space_anchor_maps_owner_status_updated_at' },
);

db.space_anchor_maps.createIndex(
  { geo: '2dsphere' },
  { name: 'ix_space_anchor_maps_geo', sparse: true },
);

db.tourism_experience_feeds.createIndex(
  { experience_id: 1, updated_at: -1 },
  { name: 'ix_tourism_experience_feeds_experience_updated_at' },
);

db.tourism_experience_feeds.createIndex(
  { owner_user_id: 1, feed_status: 1, updated_at: -1 },
  { name: 'ix_tourism_experience_feeds_owner_status_updated_at' },
);

db.bio_impact_logs.createIndex(
  { collection_order_id: 1, measured_at: -1 },
  { name: 'ix_bio_impact_logs_collection_measured_at', sparse: true },
);

db.bio_impact_logs.createIndex(
  { user_id: 1, impact_status: 1, measured_at: -1 },
  { name: 'ix_bio_impact_logs_user_status_measured_at' },
);

db.bio_impact_logs.createIndex(
  { geo: '2dsphere' },
  { name: 'ix_bio_impact_logs_geo', sparse: true },
);

db.energy_meter_streams.createIndex(
  { energy_asset_id: 1, measured_at: -1 },
  { name: 'ix_energy_meter_streams_asset_measured_at' },
);

db.energy_meter_streams.createIndex(
  { trade_order_id: 1, measured_at: -1 },
  { name: 'ix_energy_meter_streams_trade_measured_at', sparse: true },
);

db.energy_meter_streams.createIndex(
  { geo: '2dsphere' },
  { name: 'ix_energy_meter_streams_geo', sparse: true },
);
