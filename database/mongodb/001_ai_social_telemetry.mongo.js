// Valley Hybrid DB Bootstrap - PASSO 3: MongoDB NoSQL Brain. Integra IA, Social, Influencer e Telemetria.
// Execute com mongosh no banco Valley/Nexora alvo. This file is idempotent via createCollection/collMod.

// UUID_PATTERN valida referencias vindas do PostgreSQL public.users.user_id em formato UUID tecnico.
const UUID_PATTERN = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

// applyCollection cria ou atualiza uma collection com JSON Schema Validation sem apagar dados existentes.
function applyCollection(collectionName, validator) {
  // collectionExists evita erro quando o script roda novamente em ambientes de dev, staging ou prod.
  const collectionExists = db.getCollectionNames().includes(collectionName);

  // Se a collection nao existe, criamos com validator strict para proteger a entrada de dados.
  if (!collectionExists) {
    // createCollection abre o contrato de dados MongoDB para o modulo correspondente.
    db.createCollection(collectionName, {
      // validator contem o $jsonSchema que bloqueia documentos fora do padrao esperado.
      validator,
      // validationLevel strict aplica a regra a todos os inserts e updates futuros.
      validationLevel: 'strict',
      // validationAction error impede gravacao invalida em vez de apenas registrar aviso.
      validationAction: 'error',
    });
    // Retorno antecipado evita executar collMod logo depois de criar a collection.
    return;
  }

  // collMod atualiza o schema de uma collection existente sem perder documentos.
  db.runCommand({
    // collMod aponta qual collection recebera o novo validator.
    collMod: collectionName,
    // validator substitui a regra antiga pela regra versionada deste arquivo.
    validator,
    // validationLevel strict mantem enforcement forte depois da atualizacao.
    validationLevel: 'strict',
    // validationAction error mantem fail-fast para proteger dados operacionais.
    validationAction: 'error',
  });
}

// aiMemoryValidator guarda memoria de IA por usuario, integrada ao user_id relacional do Postgres.
const aiMemoryValidator = {
  // $jsonSchema e o contrato de documento aceito pela collection ai_memory.
  $jsonSchema: {
    // bsonType object exige que cada documento seja um objeto MongoDB.
    bsonType: 'object',
    // required lista os campos minimos para rastrear memoria, consentimento e auditoria.
    required: ['memory_id', 'user_id', 'memory_scope', 'persona_mode', 'source_module', 'content_summary', 'consent_scope', 'created_at', 'updated_at'],
    // additionalProperties true permite evolucao controlada para novos modulos de IA sem migracao imediata.
    additionalProperties: true,
    // properties descreve campo por campo o contrato tecnico da memoria de IA.
    properties: {
      // memory_id e a chave logica da memoria no MongoDB.
      memory_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID da memoria de IA.' },
      // user_id integra este documento ao PostgreSQL public.users.user_id.
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'FK logica para users.user_id.' },
      // memory_scope separa memoria curta, longa, preferencia e seguranca.
      memory_scope: { enum: ['SHORT_TERM', 'LONG_TERM', 'PREFERENCE', 'SAFETY', 'BUSINESS'], description: 'Escopo funcional da memoria.' },
      // persona_mode identifica a persona tecnica usada pela IA.
      persona_mode: { enum: ['PERSONAL', 'PROFESSIONAL', 'RIDER', 'MERCHANT', 'ADMIN'], description: 'Persona AI ativa.' },
      // source_module registra qual modulo do Omniverse gerou a memoria.
      source_module: { bsonType: 'string', minLength: 2, maxLength: 80, description: 'Modulo de origem.' },
      // content_summary guarda resumo seguro, nao o dump bruto de conversa sensivel.
      content_summary: { bsonType: 'string', minLength: 1, maxLength: 8000, description: 'Resumo contextual da memoria.' },
      // content_vector_ref referencia embedding/vector store externo quando existir.
      content_vector_ref: { bsonType: ['string', 'null'], maxLength: 512, description: 'Referencia tecnica para vector database.' },
      // importance_score ajuda a IA a priorizar memorias relevantes.
      importance_score: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, maximum: 1, description: 'Score de relevancia entre 0 e 1.' },
      // consent_scope amarra uso da memoria ao consentimento do usuario.
      consent_scope: { enum: ['NONE', 'SESSION', 'PROFILE', 'CROSS_MODULE'], description: 'Escopo de consentimento.' },
      // expires_at permite expirar memorias temporarias automaticamente por TTL futuro.
      expires_at: { bsonType: ['date', 'null'], description: 'Data de expiracao opcional.' },
      // created_at registra quando a memoria foi gravada.
      created_at: { bsonType: 'date', description: 'Criacao do documento.' },
      // updated_at registra a ultima atualizacao logica.
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao do documento.' },
    },
  },
};

// socialVideosValidator guarda metadados de videos estilo feed social e commerce links.
const socialVideosValidator = {
  // $jsonSchema define o contrato da collection social_videos.
  $jsonSchema: {
    // bsonType object garante documento JSON/BSON estruturado.
    bsonType: 'object',
    // required exige identidade do video, dono, status e metricas basicas.
    required: ['video_id', 'creator_user_id', 'owner_user_id', 'caption', 'visibility', 'view_count', 'like_count', 'share_count', 'comment_count', 'status', 'created_at', 'updated_at'],
    // additionalProperties true preserva flexibilidade para features sociais futuras.
    additionalProperties: true,
    // properties documenta os campos de conteudo, monetizacao e engajamento.
    properties: {
      // video_id e a chave logica do video no Social Feed.
      video_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do video.' },
      // creator_user_id referencia quem criou o conteudo em users.user_id.
      creator_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Criador do video.' },
      // owner_user_id referencia quem controla monetizacao e administracao do video.
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Dono operacional do video.' },
      // caption guarda a legenda publica ou moderada.
      caption: { bsonType: 'string', maxLength: 2200, description: 'Legenda do video.' },
      // hashtags suporta descoberta social, campanhas e Ads Intelligence.
      hashtags: { bsonType: 'array', items: { bsonType: 'string', maxLength: 80 }, description: 'Lista de hashtags.' },
      // media_url aponta para storage/CDN do arquivo principal.
      media_url: { bsonType: ['string', 'null'], maxLength: 2048, description: 'URL da midia.' },
      // thumbnail_url aponta para imagem de capa em CDN.
      thumbnail_url: { bsonType: ['string', 'null'], maxLength: 2048, description: 'URL da thumbnail.' },
      // visibility controla publicacao, privado e moderation hold.
      visibility: { enum: ['PUBLIC', 'PRIVATE', 'UNLISTED', 'FOLLOWERS', 'MODERATION_HOLD'], description: 'Visibilidade do video.' },
      // commission_link integra Social com Marketplace, Stock, Ads e Influencer.
      commission_link: { bsonType: ['string', 'null'], maxLength: 2048, description: 'Link de comissao.' },
      // product_refs guarda referencias externas ou internas de produtos monetizados.
      product_refs: { bsonType: 'array', items: { bsonType: 'object' }, description: 'Produtos vinculados ao video.' },
      // view_count registra visualizacoes acumuladas.
      view_count: { bsonType: ['int', 'long'], minimum: 0, description: 'Total de views.' },
      // like_count registra curtidas acumuladas.
      like_count: { bsonType: ['int', 'long'], minimum: 0, description: 'Total de likes.' },
      // share_count registra compartilhamentos acumulados.
      share_count: { bsonType: ['int', 'long'], minimum: 0, description: 'Total de shares.' },
      // comment_count registra comentarios acumulados.
      comment_count: { bsonType: ['int', 'long'], minimum: 0, description: 'Total de comments.' },
      // status separa lifecycle de upload, publicacao, bloqueio e arquivamento.
      status: { enum: ['DRAFT', 'PROCESSING', 'ACTIVE', 'DISABLED', 'REMOVED', 'ARCHIVED'], description: 'Status operacional.' },
      // created_at registra criacao do video.
      created_at: { bsonType: 'date', description: 'Criacao do documento.' },
      // updated_at registra ultima atualizacao de metadados.
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao.' },
    },
  },
};

// influencerMetricsValidator guarda snapshots de performance para campanhas e afiliados.
const influencerMetricsValidator = {
  // $jsonSchema define o contrato da collection influencer_metrics.
  $jsonSchema: {
    // bsonType object exige documento estruturado.
    bsonType: 'object',
    // required garante periodo, campanha, funil e monetizacao basica.
    required: ['metric_id', 'influencer_user_id', 'campaign_id', 'period_start', 'period_end', 'impressions', 'views', 'clicks', 'ctr', 'conversions', 'gross_sales_brl', 'commission_brl', 'engagement_rate', 'created_at'],
    // additionalProperties true permite novos canais e breakdowns sem quebrar ingestao.
    additionalProperties: true,
    // properties descreve indicadores de marketing e revenue attribution.
    properties: {
      // metric_id identifica o snapshot de metricas.
      metric_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do snapshot.' },
      // influencer_user_id integra o influenciador ao users.user_id.
      influencer_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Influencer vinculado.' },
      // campaign_id identifica campanha social, Ads ou afiliacao.
      campaign_id: { bsonType: 'string', minLength: 1, maxLength: 160, description: 'Campanha monitorada.' },
      // period_start abre a janela de agregacao.
      period_start: { bsonType: 'date', description: 'Inicio do periodo.' },
      // period_end fecha a janela de agregacao.
      period_end: { bsonType: 'date', description: 'Fim do periodo.' },
      // impressions registra alcance bruto.
      impressions: { bsonType: ['int', 'long'], minimum: 0, description: 'Impressoes.' },
      // views registra visualizacoes qualificadas.
      views: { bsonType: ['int', 'long'], minimum: 0, description: 'Views.' },
      // clicks registra cliques rastreados.
      clicks: { bsonType: ['int', 'long'], minimum: 0, description: 'Cliques.' },
      // ctr guarda click-through rate como decimal tecnico.
      ctr: { bsonType: ['double', 'decimal'], minimum: 0, description: 'Click-through rate.' },
      // conversions registra conversoes atribuidas.
      conversions: { bsonType: ['int', 'long'], minimum: 0, description: 'Conversoes.' },
      // gross_sales_brl guarda GMV em BRL com precisao logica de finops.
      gross_sales_brl: { bsonType: ['double', 'decimal'], minimum: 0, description: 'Vendas brutas em BRL.' },
      // commission_brl guarda comissao calculada para repasse.
      commission_brl: { bsonType: ['double', 'decimal'], minimum: 0, description: 'Comissao em BRL.' },
      // engagement_rate mede engajamento agregado.
      engagement_rate: { bsonType: ['double', 'decimal'], minimum: 0, description: 'Taxa de engajamento.' },
      // source_breakdown detalha origem por canal, video, campanha ou link.
      source_breakdown: { bsonType: ['object', 'null'], description: 'Breakdown por origem.' },
      // created_at registra geracao do snapshot.
      created_at: { bsonType: 'date', description: 'Criacao do snapshot.' },
    },
  },
};

// telemetryLogsValidator guarda eventos de GPS, IoT e sensores de alto volume.
const telemetryLogsValidator = {
  // $jsonSchema define o contrato da collection telemetry_logs.
  $jsonSchema: {
    // bsonType object garante payload estruturado.
    bsonType: 'object',
    // required garante rastreabilidade minima de usuario, dispositivo, evento e tempo.
    required: ['telemetry_id', 'user_id', 'device_id', 'event_type', 'event_source', 'event_time', 'ingested_at'],
    // additionalProperties true suporta novos sensores, devices e eventos sem migracao pesada.
    additionalProperties: true,
    // properties descreve localizacao, sensor payload e correlacao operacional.
    properties: {
      // telemetry_id identifica o evento de telemetria.
      telemetry_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do evento.' },
      // user_id referencia o usuario principal em users.user_id.
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario dono do evento.' },
      // rider_user_id referencia rider quando o evento vem de Move/Logistics.
      rider_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Rider relacionado.' },
      // device_id identifica celular, rastreador, sensor ou gateway IoT.
      device_id: { bsonType: 'string', minLength: 1, maxLength: 160, description: 'Dispositivo de origem.' },
      // event_type categoriza o evento de telemetria.
      event_type: { enum: ['GPS_PING', 'ROUTE_UPDATE', 'SENSOR_EVENT', 'SECURITY_ALERT', 'BATTERY_STATUS', 'IOT_HEARTBEAT'], description: 'Tipo do evento.' },
      // event_source identifica app, device, integration ou backend.
      event_source: { enum: ['MOBILE_APP', 'RIDER_APP', 'IOT_DEVICE', 'BACKEND', 'PARTNER_API'], description: 'Origem tecnica.' },
      // geo armazena GeoJSON Point para consultas 2dsphere.
      geo: {
        // bsonType object obriga formato GeoJSON quando localizacao existe.
        bsonType: ['object', 'null'],
        // required exige type e coordinates dentro do GeoJSON Point.
        required: ['type', 'coordinates'],
        // properties define tipo Point e coordenadas longitude/latitude.
        properties: {
          // type deve ser Point para o indice 2dsphere.
          type: { enum: ['Point'], description: 'GeoJSON Point.' },
          // coordinates guarda [longitude, latitude].
          coordinates: { bsonType: 'array', minItems: 2, maxItems: 2, items: { bsonType: ['double', 'int', 'long', 'decimal'] }, description: 'Longitude e latitude.' },
        },
        // description explica integracao geoespacial.
        description: 'Localizacao GeoJSON para rastreio e mapas.',
      },
      // speed_kph registra velocidade quando o evento envolve mobilidade.
      speed_kph: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, description: 'Velocidade em km/h.' },
      // battery_level registra bateria do dispositivo entre 0 e 100.
      battery_level: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, maximum: 100, description: 'Bateria percentual.' },
      // sensor_payload guarda dados nao estruturados do sensor.
      sensor_payload: { bsonType: ['object', 'null'], description: 'Payload bruto controlado do sensor.' },
      // correlation_id liga o evento a pedido, corrida, alerta ou trace distribuido.
      correlation_id: { bsonType: ['string', 'null'], maxLength: 160, description: 'ID de correlacao operacional.' },
      // event_time e o horario real do evento no dispositivo/origem.
      event_time: { bsonType: 'date', description: 'Tempo do evento.' },
      // ingested_at e o horario em que o backend recebeu o evento.
      ingested_at: { bsonType: 'date', description: 'Tempo de ingestao.' },
    },
  },
};

// Aplica o contrato de memoria de IA no MongoDB.
applyCollection('ai_memory', aiMemoryValidator);

// Aplica o contrato de videos sociais no MongoDB.
applyCollection('social_videos', socialVideosValidator);

// Aplica o contrato de metricas de influenciadores no MongoDB.
applyCollection('influencer_metrics', influencerMetricsValidator);

// Aplica o contrato de logs de telemetria no MongoDB.
applyCollection('telemetry_logs', telemetryLogsValidator);

// Indice de memoria por usuario e atualizacao para leitura rapida pela Persona AI.
db.ai_memory.createIndex({ user_id: 1, updated_at: -1 }, { name: 'ix_ai_memory_user_updated_at' });

// Indice opcional de expiracao para memorias temporarias quando expires_at existir.
db.ai_memory.createIndex({ expires_at: 1 }, { name: 'ix_ai_memory_expires_at', sparse: true });

// Indice de videos por criador e data para feed social.
db.social_videos.createIndex({ creator_user_id: 1, created_at: -1 }, { name: 'ix_social_videos_creator_created_at' });

// Indice de videos por dono operacional e status para moderacao/admin.
db.social_videos.createIndex({ owner_user_id: 1, status: 1, updated_at: -1 }, { name: 'ix_social_videos_owner_status_updated_at' });

// Indice de campanha e periodo para analytics de influencer.
db.influencer_metrics.createIndex({ campaign_id: 1, period_end: -1 }, { name: 'ix_influencer_metrics_campaign_period_end' });

// Indice de influenciador e periodo para dashboards do Web Admin.
db.influencer_metrics.createIndex({ influencer_user_id: 1, period_start: -1, period_end: -1 }, { name: 'ix_influencer_metrics_user_period' });

// Indice de dispositivo e tempo para telemetria de alto volume.
db.telemetry_logs.createIndex({ device_id: 1, event_time: -1 }, { name: 'ix_telemetry_logs_device_event_time' });

// Indice de usuario e tempo para reconstruir rotas e eventos por pessoa.
db.telemetry_logs.createIndex({ user_id: 1, event_time: -1 }, { name: 'ix_telemetry_logs_user_event_time' });

// Indice geoespacial para mapas, corridas, seguranca e IoT.
db.telemetry_logs.createIndex({ geo: '2dsphere' }, { name: 'ix_telemetry_logs_geo_2dsphere', sparse: true });
