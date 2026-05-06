// Enriquecimento aditivo do brain MongoDB para operacao futura.
// Mantem colecoes existentes e amplia contratos de IA, social, influenciador e telemetria.

const UUID_PATTERN = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

function applyValidator(collectionName, validator) {
  db.runCommand({
    collMod: collectionName,
    validator,
    validationLevel: 'moderate',
    validationAction: 'error',
  });
}

applyValidator('ai_memory', {
  $jsonSchema: {
    bsonType: 'object',
    required: ['memory_id', 'user_id', 'memory_scope', 'helena_context_mode', 'source_module', 'content_summary', 'consent_scope', 'created_at', 'updated_at'],
    additionalProperties: true,
    properties: {
      memory_id: { bsonType: 'string', pattern: UUID_PATTERN },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN },
      memory_scope: { enum: ['SHORT_TERM', 'LONG_TERM', 'PREFERENCE', 'SAFETY', 'BUSINESS'] },
      helena_context_mode: { enum: ['PERSONAL', 'PROFESSIONAL', 'RIDER', 'MERCHANT', 'ADMIN'] },
      source_module: { bsonType: 'string' },
      content_summary: { bsonType: 'string' },
      consent_scope: { enum: ['NONE', 'SESSION', 'PROFILE', 'CROSS_MODULE'] },
      memory_status: { enum: ['ACTIVE', 'ARCHIVED', 'REDACTED', 'EXPIRED', 'BLOCKED'] },
      memory_channel: { enum: ['CHAT', 'VOICE', 'FORM', 'SYSTEM', 'IMPORT', 'SUPPORT'] },
      sentiment_label: { bsonType: ['string', 'null'] },
      sentiment_score: { bsonType: ['double', 'decimal', 'int', 'long', 'null'], minimum: -1, maximum: 1 },
      confidence_score: { bsonType: ['double', 'decimal', 'int', 'long', 'null'], minimum: 0, maximum: 1 },
      redaction_status: { bsonType: ['string', 'null'] },
      pii_flags: { bsonType: ['array', 'null'], items: { bsonType: 'string' } },
      source_event_ref: { bsonType: ['string', 'null'] },
      conversation_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN },
      session_id: { bsonType: ['string', 'null'], maxLength: 160 },
      tags: { bsonType: ['array', 'null'], items: { bsonType: 'string' } },
      memory_graph_refs: { bsonType: ['array', 'null'], items: { bsonType: 'string' } },
      policy_snapshot: { bsonType: ['object', 'null'] },
      metadata_json: { bsonType: ['object', 'null'] },
      expires_at: { bsonType: ['date', 'null'] },
      created_at: { bsonType: 'date' },
      updated_at: { bsonType: 'date' },
    },
  },
});

applyValidator('social_videos', {
  $jsonSchema: {
    bsonType: 'object',
    required: ['video_id', 'creator_user_id', 'owner_user_id', 'caption', 'visibility', 'view_count', 'like_count', 'share_count', 'comment_count', 'status', 'created_at', 'updated_at'],
    additionalProperties: true,
    properties: {
      video_id: { bsonType: 'string', pattern: UUID_PATTERN },
      creator_user_id: { bsonType: 'string', pattern: UUID_PATTERN },
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN },
      caption: { bsonType: 'string' },
      visibility: { enum: ['PUBLIC', 'PRIVATE', 'UNLISTED', 'FOLLOWERS', 'MODERATION_HOLD'] },
      view_count: { bsonType: ['int', 'long'], minimum: 0 },
      like_count: { bsonType: ['int', 'long'], minimum: 0 },
      share_count: { bsonType: ['int', 'long'], minimum: 0 },
      comment_count: { bsonType: ['int', 'long'], minimum: 0 },
      status: { enum: ['DRAFT', 'PROCESSING', 'ACTIVE', 'DISABLED', 'REMOVED', 'ARCHIVED'] },
      moderation_status: { enum: ['PENDING', 'APPROVED', 'REJECTED', 'ESCALATED', 'AUTO_BLOCKED'] },
      moderation_reason: { bsonType: ['string', 'null'] },
      moderation_actor_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN },
      audio_language_code: { bsonType: ['string', 'null'], maxLength: 8 },
      transcript_text: { bsonType: ['string', 'null'] },
      transcript_segments: { bsonType: ['array', 'null'], items: { bsonType: 'object' } },
      monetization_status: { enum: ['OFF', 'ELIGIBLE', 'ACTIVE', 'PAUSED', 'BLOCKED'] },
      conversion_count: { bsonType: ['int', 'long', 'null'], minimum: 0 },
      gross_sales_brl: { bsonType: ['double', 'decimal', 'null'], minimum: 0 },
      commission_brl: { bsonType: ['double', 'decimal', 'null'], minimum: 0 },
      ranking_snapshot: { bsonType: ['object', 'null'] },
      metadata_json: { bsonType: ['object', 'null'] },
      created_at: { bsonType: 'date' },
      updated_at: { bsonType: 'date' },
    },
  },
});

applyValidator('influencer_metrics', {
  $jsonSchema: {
    bsonType: 'object',
    required: ['metric_id', 'influencer_user_id', 'campaign_id', 'period_start', 'period_end', 'impressions', 'views', 'clicks', 'ctr', 'conversions', 'gross_sales_brl', 'commission_brl', 'engagement_rate', 'created_at'],
    additionalProperties: true,
    properties: {
      metric_id: { bsonType: 'string', pattern: UUID_PATTERN },
      influencer_user_id: { bsonType: 'string', pattern: UUID_PATTERN },
      campaign_id: { bsonType: 'string' },
      period_start: { bsonType: 'date' },
      period_end: { bsonType: 'date' },
      impressions: { bsonType: ['int', 'long'], minimum: 0 },
      views: { bsonType: ['int', 'long'], minimum: 0 },
      clicks: { bsonType: ['int', 'long'], minimum: 0 },
      ctr: { bsonType: ['double', 'decimal'], minimum: 0 },
      conversions: { bsonType: ['int', 'long'], minimum: 0 },
      gross_sales_brl: { bsonType: ['double', 'decimal'], minimum: 0 },
      commission_brl: { bsonType: ['double', 'decimal'], minimum: 0 },
      engagement_rate: { bsonType: ['double', 'decimal'], minimum: 0 },
      approved_commission_brl: { bsonType: ['double', 'decimal', 'null'], minimum: 0 },
      paid_commission_brl: { bsonType: ['double', 'decimal', 'null'], minimum: 0 },
      refund_impact_brl: { bsonType: ['double', 'decimal', 'null'], minimum: 0 },
      chargeback_impact_brl: { bsonType: ['double', 'decimal', 'null'], minimum: 0 },
      attributed_orders_count: { bsonType: ['int', 'long', 'null'], minimum: 0 },
      top_content_refs: { bsonType: ['array', 'null'], items: { bsonType: 'string' } },
      settlement_status: { enum: ['OPEN', 'READY', 'PAID', 'HELD', 'DISPUTED'] },
      metadata_json: { bsonType: ['object', 'null'] },
      created_at: { bsonType: 'date' },
    },
  },
});

applyValidator('telemetry_logs', {
  $jsonSchema: {
    bsonType: 'object',
    required: ['telemetry_id', 'user_id', 'device_id', 'event_type', 'event_source', 'event_time', 'ingested_at'],
    additionalProperties: true,
    properties: {
      telemetry_id: { bsonType: 'string', pattern: UUID_PATTERN },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN },
      rider_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN },
      device_id: { bsonType: 'string' },
      event_type: { enum: ['GPS_PING', 'ROUTE_UPDATE', 'SENSOR_EVENT', 'SECURITY_ALERT', 'BATTERY_STATUS', 'IOT_HEARTBEAT'] },
      event_source: { enum: ['MOBILE_APP', 'RIDER_APP', 'IOT_DEVICE', 'BACKEND', 'PARTNER_API'] },
      geo: { bsonType: ['object', 'null'] },
      speed_kph: { bsonType: ['double', 'decimal', 'int', 'long', 'null'], minimum: 0 },
      heading_degrees: { bsonType: ['double', 'decimal', 'int', 'long', 'null'], minimum: 0, maximum: 360 },
      altitude_meters: { bsonType: ['double', 'decimal', 'int', 'long', 'null'] },
      horizontal_accuracy_meters: { bsonType: ['double', 'decimal', 'int', 'long', 'null'], minimum: 0 },
      battery_level: { bsonType: ['double', 'decimal', 'int', 'long', 'null'], minimum: 0, maximum: 100 },
      signal_strength_pct: { bsonType: ['double', 'decimal', 'int', 'long', 'null'], minimum: 0, maximum: 100 },
      firmware_version: { bsonType: ['string', 'null'] },
      device_health_status: { bsonType: ['string', 'null'] },
      alert_severity: { bsonType: ['string', 'null'] },
      route_ref: { bsonType: ['string', 'null'], pattern: UUID_PATTERN },
      order_ref: { bsonType: ['string', 'null'], pattern: UUID_PATTERN },
      trip_ref: { bsonType: ['string', 'null'], pattern: UUID_PATTERN },
      raw_payload_checksum: { bsonType: ['string', 'null'] },
      metadata_json: { bsonType: ['object', 'null'] },
      event_time: { bsonType: 'date' },
      ingested_at: { bsonType: 'date' },
    },
  },
});

db.ai_memory.createIndex({ user_id: 1, memory_status: 1, updated_at: -1 }, { name: 'ix_ai_memory_user_status_updated_at' });
db.ai_memory.createIndex({ conversation_id: 1, created_at: -1 }, { name: 'ix_ai_memory_conversation_created_at', sparse: true });
db.social_videos.createIndex({ moderation_status: 1, updated_at: -1 }, { name: 'ix_social_videos_moderation_status_updated_at', sparse: true });
db.social_videos.createIndex({ monetization_status: 1, gross_sales_brl: -1 }, { name: 'ix_social_videos_monetization_sales', sparse: true });
db.influencer_metrics.createIndex({ settlement_status: 1, period_end: -1 }, { name: 'ix_influencer_metrics_settlement_period_end', sparse: true });
db.telemetry_logs.createIndex({ trip_ref: 1, event_time: -1 }, { name: 'ix_telemetry_logs_trip_event_time', sparse: true });
db.telemetry_logs.createIndex({ alert_severity: 1, ingested_at: -1 }, { name: 'ix_telemetry_logs_alert_severity_ingested_at', sparse: true });
