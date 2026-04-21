// Valley Hybrid DB Seed - Expansion media, wellness e frontier.
// Este seed e idempotente e cria um conjunto minimo de documentos para demo e smoke check.
// Ele usa os mesmos UUIDs deterministas do seed PostgreSQL para validar a ponte hibrida.

const TOURISM_OWNER_USER_ID = '10000000-0000-4000-8000-000000000001';
const TRAVELER_USER_ID = '10000000-0000-4000-8000-000000000002';
const BIO_OPERATOR_USER_ID = '10000000-0000-4000-8000-000000000003';
const ENERGY_OPERATOR_USER_ID = '10000000-0000-4000-8000-000000000004';
const HOME_COUNTERPARTY_USER_ID = '10000000-0000-4000-8000-000000000006';

const TOURISM_EXPERIENCE_ID = '30000000-0000-4000-8000-000000000001';
const BIO_PROGRAM_ID = '30000000-0000-4000-8000-000000000101';
const BIO_COLLECTION_ORDER_ID = '30000000-0000-4000-8000-000000000102';
const ENERGY_ASSET_ID = '30000000-0000-4000-8000-000000000201';
const ENERGY_TRADE_ORDER_ID = '30000000-0000-4000-8000-000000000203';

const NEWS_CONTENT_ID = '40000000-0000-4000-8000-000000000001';
const FITNESS_SESSION_ID = '40000000-0000-4000-8000-000000000002';
const GAMING_PLAYER_STATE_ID = '40000000-0000-4000-8000-000000000003';
const HOME_AUTOMATION_EVENT_ID = '40000000-0000-4000-8000-000000000004';
const SPACE_ANCHOR_ID = '40000000-0000-4000-8000-000000000005';
const TOURISM_FEED_ID = '40000000-0000-4000-8000-000000000006';
const BIO_IMPACT_LOG_ID = '40000000-0000-4000-8000-000000000007';
const ENERGY_METER_STREAM_ID = '40000000-0000-4000-8000-000000000008';
const HOME_HOUSEHOLD_ID = '50000000-0000-4000-8000-000000000001';

db.news_content_items.replaceOne(
  { content_id: NEWS_CONTENT_ID },
  {
    content_id: NEWS_CONTENT_ID,
    owner_user_id: TOURISM_OWNER_USER_ID,
    creator_user_id: TOURISM_OWNER_USER_ID,
    module_code: 'NEWS_PODCAST',
    content_type: 'ARTICLE',
    title: 'Circuito Historico de Bairro impulsiona turismo local',
    slug: 'circuito-historico-bairro-seed',
    summary: 'Materia seed para validar publicacao editorial multicanal e ponte com Tourism.',
    language_code: 'pt-BR',
    publication_status: 'PUBLISHED',
    published_at: new Date('2026-04-20T13:10:00.000Z'),
    distribution_channels: ['APP', 'NEWSLETTER', 'PODCAST_TEASER'],
    media_assets: [
      { kind: 'cover', url: 'https://cdn.valley.local/news/seed-cover.jpg' },
      { kind: 'audio_teaser', url: 'https://cdn.valley.local/news/seed-teaser.mp3' },
    ],
    related_video_ids: [],
    ad_slot_refs: ['ADS-SEED-NEWS-HEADER'],
    moderation_tags: ['editorial', 'local-news'],
    metrics: {
      views: 180,
      listens: 42,
      avg_completion_rate: 0.71,
    },
    created_at: new Date('2026-04-20T13:05:00.000Z'),
    updated_at: new Date('2026-04-20T13:10:00.000Z'),
  },
  { upsert: true },
);

db.fitness_activity_sessions.replaceOne(
  { session_id: FITNESS_SESSION_ID },
  {
    session_id: FITNESS_SESSION_ID,
    user_id: TRAVELER_USER_ID,
    coach_user_id: null,
    module_code: 'FITNESS',
    activity_type: 'RUN',
    session_status: 'COMPLETED',
    source_device_id: 'wearable-seed-runner-01',
    started_at: new Date('2026-04-21T06:30:00.000Z'),
    ended_at: new Date('2026-04-21T07:18:00.000Z'),
    distance_km: NumberDecimal('8.400'),
    duration_seconds: 2880,
    calories_burned: NumberDecimal('530.5'),
    average_heart_rate: 148,
    max_heart_rate: 173,
    reward_candidate_nex: NumberDecimal('0.18000000'),
    route_snapshot: {
      city: 'Sao Paulo',
      mode: 'RUN',
      checkpoints: 6,
    },
    health_links: [
      { type: 'HEALTH_PROFILE', sensitivity: 'LOW' },
    ],
    created_at: new Date('2026-04-21T07:18:30.000Z'),
    updated_at: new Date('2026-04-21T07:18:30.000Z'),
  },
  { upsert: true },
);

db.gaming_player_states.replaceOne(
  { player_state_id: GAMING_PLAYER_STATE_ID },
  {
    player_state_id: GAMING_PLAYER_STATE_ID,
    user_id: TRAVELER_USER_ID,
    module_code: 'GAMING',
    player_status: 'ACTIVE',
    nickname: 'ClaraRunner',
    season_code: 'SEASON_EXP_01',
    level: 7,
    xp_points: 2450,
    rank_tier: 'BRONZE_PLUS',
    guild_refs: ['guild-neighborhood-runners'],
    achievements: ['FIRST_CITY_ROUTE', 'COMMUNITY_SCOUT'],
    progression: {
      active_world: 'urban-discovery',
      quests_completed: 12,
      weekly_streak_days: 5,
    },
    quest_summary: {
      active_quest: 'discover-historic-waypoints',
      progress_pct: 68,
    },
    inventory_summary: {
      badges: 4,
      collectibles: 9,
      equipped_theme: 'city-discovery',
    },
    wallet_links: {
      reward_mode: 'POINTS_AND_NEX',
    },
    last_session_at: new Date('2026-04-21T07:30:00.000Z'),
    created_at: new Date('2026-04-20T13:20:00.000Z'),
    updated_at: new Date('2026-04-21T07:30:00.000Z'),
  },
  { upsert: true },
);

db.home_automation_events.replaceOne(
  { automation_event_id: HOME_AUTOMATION_EVENT_ID },
  {
    automation_event_id: HOME_AUTOMATION_EVENT_ID,
    household_id: HOME_HOUSEHOLD_ID,
    owner_user_id: HOME_COUNTERPARTY_USER_ID,
    module_code: 'HOME',
    room_code: 'living-room',
    source_device_id: 'home-hub-seed-01',
    related_user_ids: [HOME_COUNTERPARTY_USER_ID],
    event_type: 'ENERGY_MODE_CHANGE',
    event_status: 'ACTIONED',
    scenario_code: 'evening-grid-balance',
    energy_wh: NumberDecimal('860'),
    security_signal_id: null,
    geo: {
      type: 'Point',
      coordinates: [-46.6409, -23.5733],
    },
    payload: {
      previous_mode: 'comfort',
      next_mode: 'grid_balance',
      triggered_by: 'energy-price-signal',
    },
    occurred_at: new Date('2026-04-26T17:00:00.000Z'),
    ingested_at: new Date('2026-04-26T17:00:04.000Z'),
  },
  { upsert: true },
);

db.space_anchor_maps.replaceOne(
  { anchor_id: SPACE_ANCHOR_ID },
  {
    anchor_id: SPACE_ANCHOR_ID,
    owner_user_id: TRAVELER_USER_ID,
    tourism_experience_id: TOURISM_EXPERIENCE_ID,
    social_video_id: null,
    module_code: 'SPACE',
    anchor_type: 'WAYFINDING_MARKER',
    anchor_status: 'ACTIVE',
    title: 'Portal AR do Centro Historico',
    world_ref: 'tourism-city-layer-seed',
    geo: {
      type: 'Point',
      coordinates: [-46.6333, -23.5505],
    },
    pose: {
      yaw: 45,
      pitch: 0,
      roll: 0,
    },
    asset_manifest: {
      marker: 'historic-portal-v1',
      overlays: ['audio-guide', 'timeline-card'],
    },
    interaction_rules: {
      requires_proximity_meters: 20,
      unlock_mode: 'tourism-booking',
    },
    analytics: {
      views: 37,
      average_dwell_seconds: 52,
    },
    created_at: new Date('2026-04-20T13:25:00.000Z'),
    updated_at: new Date('2026-04-20T13:25:00.000Z'),
  },
  { upsert: true },
);

db.tourism_experience_feeds.replaceOne(
  { feed_id: TOURISM_FEED_ID },
  {
    feed_id: TOURISM_FEED_ID,
    experience_id: TOURISM_EXPERIENCE_ID,
    owner_user_id: TOURISM_OWNER_USER_ID,
    guide_user_id: null,
    module_code: 'TOURISM',
    feed_status: 'ACTIVE',
    highlight_text: 'Feed enriquecido do roteiro historico com waypoints, midia e resumo de reviews.',
    media_gallery: [
      { type: 'image', url: 'https://cdn.valley.local/tourism/centro-1.jpg' },
      { type: 'image', url: 'https://cdn.valley.local/tourism/centro-2.jpg' },
    ],
    route_waypoints: [
      { label: 'Se', order: 1 },
      { label: 'Pateo do Collegio', order: 2 },
      { label: 'Solar da Marquesa', order: 3 },
    ],
    language_packs: {
      available: ['pt-BR', 'en-US'],
    },
    review_summary: {
      rating_avg: 4.8,
      review_count: 26,
    },
    live_availability: {
      seats_left: 10,
      next_slot_utc: '2026-04-25T13:00:00.000Z',
    },
    geo: {
      type: 'Point',
      coordinates: [-46.6333, -23.5505],
    },
    created_at: new Date('2026-04-20T13:30:00.000Z'),
    updated_at: new Date('2026-04-20T13:30:00.000Z'),
  },
  { upsert: true },
);

db.bio_impact_logs.replaceOne(
  { impact_log_id: BIO_IMPACT_LOG_ID },
  {
    impact_log_id: BIO_IMPACT_LOG_ID,
    collection_order_id: BIO_COLLECTION_ORDER_ID,
    program_id: BIO_PROGRAM_ID,
    user_id: TRAVELER_USER_ID,
    partner_user_id: BIO_OPERATOR_USER_ID,
    module_code: 'BIO',
    impact_type: 'WEIGH_IN',
    impact_status: 'VERIFIED',
    device_id: 'bio-scale-seed-01',
    geo: {
      type: 'Point',
      coordinates: [-46.644, -23.582],
    },
    metrics: {
      material_weight_kg: NumberDecimal('18.7500'),
      co2e_avoided_kg: NumberDecimal('28.4000'),
      reward_brl: NumberDecimal('12.5000'),
    },
    sensor_payload: {
      scale_vendor: 'Valley Bio Scale',
      quality_scan: 'approved',
    },
    media_refs: [
      'https://cdn.valley.local/bio/proof-001.jpg',
    ],
    measured_at: new Date('2026-04-22T14:55:00.000Z'),
    ingested_at: new Date('2026-04-22T14:55:03.000Z'),
  },
  { upsert: true },
);

db.energy_meter_streams.replaceOne(
  { stream_event_id: ENERGY_METER_STREAM_ID },
  {
    stream_event_id: ENERGY_METER_STREAM_ID,
    trade_order_id: ENERGY_TRADE_ORDER_ID,
    energy_asset_id: ENERGY_ASSET_ID,
    owner_user_id: ENERGY_OPERATOR_USER_ID,
    counterparty_user_id: HOME_COUNTERPARTY_USER_ID,
    module_code: 'ENERGY',
    event_type: 'GENERATION_READING',
    reading_window_start: new Date('2026-04-26T12:00:00.000Z'),
    reading_window_end: new Date('2026-04-26T18:00:00.000Z'),
    measured_at: new Date('2026-04-26T18:00:10.000Z'),
    ingested_at: new Date('2026-04-26T18:00:15.000Z'),
    kwh_in: NumberDecimal('0'),
    kwh_out: NumberDecimal('120.0000'),
    net_kwh: NumberDecimal('120.0000'),
    settlement_candidate_brl: NumberDecimal('108.0000'),
    carbon_credit_candidate_nex: NumberDecimal('1.50000000'),
    geo: {
      type: 'Point',
      coordinates: [-46.6351, -23.5487],
    },
    device_payload: {
      meter_device_ref: 'METER-SEED-ENERGY-01',
      tariff_window: 'peak-afternoon',
    },
  },
  { upsert: true },
);
