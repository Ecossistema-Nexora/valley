// Valley Hybrid DB Bootstrap - Field Ops, Security e Agenda v47.
// Este script aprofunda a camada MongoDB para DELIVERY, FLEET, SECURITY e AGENDA.
// Execute com mongosh depois de mongo-001 e mongo-002 para manter o core NoSQL preparado.

// UUID_PATTERN preserva a ponte logica com PostgreSQL usando UUID tecnico em string.
const UUID_PATTERN = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

// HASH_PATTERN valida hashes tecnicos de referencia sem persistir segredo bruto.
const HASH_PATTERN = '^[a-fA-F0-9]{64,128}$';

// applyCollection cria ou atualiza a collection sem apagar dados existentes.
function applyCollection(collectionName, validator) {
  // collectionExists evita erro em reexecucao idempotente.
  const collectionExists = db.getCollectionNames().includes(collectionName);

  // Se a collection ainda nao existe, createCollection cria com validator strict.
  if (!collectionExists) {
    db.createCollection(collectionName, {
      validator,
      validationLevel: 'strict',
      validationAction: 'error',
    });
    return;
  }

  // collMod atualiza o validator da collection quando ela ja existe.
  db.runCommand({
    collMod: collectionName,
    validator,
    validationLevel: 'strict',
    validationAction: 'error',
  });
}

// geoPointSchema reaproveita a validacao GeoJSON Point nos logs com latitude/longitude.
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
  description: 'Localizacao GeoJSON para mapas e tracking.',
};

// deliveryDispatchRunsValidator guarda o ciclo de dispatch e matching de riders.
const deliveryDispatchRunsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['dispatch_id', 'order_id', 'requester_user_id', 'module_code', 'dispatch_status', 'service_level', 'created_at', 'updated_at'],
    additionalProperties: true,
    properties: {
      dispatch_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do dispatch.' },
      order_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'FK logica para orders.order_id.' },
      shipment_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'FK logica para delivery_shipments.shipment_id.' },
      requester_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario solicitante do dispatch.' },
      merchant_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Merchant relacionado ao dispatch.' },
      selected_rider_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Rider selecionado no ciclo.' },
      candidate_rider_user_ids: {
        bsonType: 'array',
        items: { bsonType: 'string', pattern: UUID_PATTERN },
        description: 'Lista de riders candidatos.',
      },
      module_code: { enum: ['DELIVERY', 'FOOD', 'MARKETPLACE', 'PHARMACY', 'MOBILITY'], description: 'Modulo emissor do dispatch.' },
      dispatch_status: { enum: ['QUEUED', 'SEARCHING', 'ASSIGNED', 'REJECTED', 'EXPIRED', 'CANCELLED', 'COMPLETED'], description: 'Status do ciclo de dispatch.' },
      service_level: { enum: ['STANDARD', 'PRIORITY', 'SCHEDULED', 'COLD_CHAIN', 'SECURE'], description: 'Nivel operacional do dispatch.' },
      attempt_count: { bsonType: ['int', 'long'], minimum: 0, description: 'Quantidade de tentativas.' },
      eta_seconds: { bsonType: ['int', 'long', 'null'], minimum: 0, description: 'ETA calculado em segundos.' },
      route_snapshot: { bsonType: ['object', 'null'], description: 'Snapshot resumido da rota e zonas.' },
      optimization_payload: { bsonType: ['object', 'null'], description: 'Payload tecnico do motor de matching.' },
      correlation_id: { bsonType: ['string', 'null'], maxLength: 160, description: 'ID de correlacao com logs e traces.' },
      expires_at: { bsonType: ['date', 'null'], description: 'Data de expiracao do ciclo.' },
      created_at: { bsonType: 'date', description: 'Criacao do dispatch.' },
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao do dispatch.' },
    },
  },
};

// fleetVehicleProfilesValidator guarda cadastro vivo de veiculos e telematica da frota.
const fleetVehicleProfilesValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['vehicle_id', 'owner_user_id', 'module_code', 'vehicle_class', 'vehicle_status', 'identifiers', 'maintenance_policy', 'created_at', 'updated_at'],
    additionalProperties: true,
    properties: {
      vehicle_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do veiculo.' },
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario dono da frota/veiculo.' },
      assigned_rider_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Rider atualmente associado.' },
      module_code: { enum: ['FLEET', 'LOG', 'MOBILITY'], description: 'Modulo principal do veiculo.' },
      vehicle_class: { enum: ['BIKE', 'MOTORBIKE', 'CAR', 'VAN', 'TRUCK', 'DRONE', 'OTHER'], description: 'Classe operacional do veiculo.' },
      vehicle_status: { enum: ['ACTIVE', 'MAINTENANCE', 'BLOCKED', 'RETIRED'], description: 'Status operacional do veiculo.' },
      plate: { bsonType: ['string', 'null'], maxLength: 20, description: 'Placa ou identificador visual.' },
      vin_hash: { bsonType: ['string', 'null'], pattern: HASH_PATTERN, description: 'Hash do VIN ou identificador sensivel.' },
      device_refs: {
        bsonType: 'array',
        items: { bsonType: 'string', maxLength: 160 },
        description: 'IDs tecnicos de rastreadores ou gateways.',
      },
      capabilities: {
        bsonType: 'array',
        items: { bsonType: 'string', maxLength: 80 },
        description: 'Capacidades operacionais como cold_chain ou heavy_load.',
      },
      identifiers: { bsonType: 'object', description: 'Mapa de IDs externos e internos do veiculo.' },
      telematics_config: { bsonType: ['object', 'null'], description: 'Configuracao de telematica e ingestao.' },
      maintenance_policy: { bsonType: 'object', description: 'Politica de manutencao preventiva.' },
      last_seen_at: { bsonType: ['date', 'null'], description: 'Ultima telemetria vista para o veiculo.' },
      created_at: { bsonType: 'date', description: 'Criacao do cadastro.' },
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao do cadastro.' },
    },
  },
};

// fleetMaintenanceEventsValidator guarda manutencao, inspecoes e quebras como trilha imutavel.
const fleetMaintenanceEventsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['maintenance_event_id', 'vehicle_id', 'owner_user_id', 'event_type', 'severity', 'event_status', 'occurred_at', 'created_at'],
    additionalProperties: true,
    properties: {
      maintenance_event_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do evento de manutencao.' },
      vehicle_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'FK logica para fleet_vehicle_profiles.vehicle_id.' },
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Dono do ativo.' },
      assigned_rider_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Rider associado no momento do evento.' },
      event_type: { enum: ['INSPECTION', 'MAINTENANCE', 'REPAIR', 'BREAKDOWN', 'ODOMETER', 'BATTERY', 'TIRE'], description: 'Tipo do evento tecnico.' },
      severity: { enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'], description: 'Severidade do evento.' },
      event_status: { enum: ['OPEN', 'SCHEDULED', 'DONE', 'SKIPPED'], description: 'Status operacional do evento.' },
      odometer_km: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, description: 'Odometro em km.' },
      due_at: { bsonType: ['date', 'null'], description: 'Prazo previsto do evento.' },
      cost_brl: { bsonType: ['double', 'decimal', 'null'], minimum: 0, description: 'Custo do evento em BRL.' },
      document_refs: {
        bsonType: 'array',
        items: { bsonType: 'string', pattern: UUID_PATTERN },
        description: 'Referencias a documentos ou comprovantes.',
      },
      payload: { bsonType: ['object', 'null'], description: 'Payload tecnico complementar.' },
      occurred_at: { bsonType: 'date', description: 'Horario real do evento.' },
      created_at: { bsonType: 'date', description: 'Horario de gravacao do evento.' },
    },
  },
};

// securitySignalLogsValidator guarda sinais de alto volume e resposta rapida.
const securitySignalLogsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['signal_id', 'user_id', 'source_module', 'signal_type', 'severity', 'signal_status', 'event_time', 'ingested_at'],
    additionalProperties: true,
    properties: {
      signal_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do sinal de seguranca.' },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario impactado.' },
      rider_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Rider relacionado ao sinal.' },
      incident_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'FK logica para security_incidents.security_incident_id.' },
      trip_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'FK logica para mobility_trips.trip_id.' },
      shipment_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'FK logica para delivery_shipments.shipment_id.' },
      source_module: { enum: ['SECURITY', 'DELIVERY', 'MOBILITY', 'IOT', 'LOG'], description: 'Modulo de origem do sinal.' },
      signal_type: { enum: ['SOS', 'BIOMETRIC_MISMATCH', 'GEOFENCE_BREACH', 'DEVICE_TAMPER', 'IOT_TRIGGER', 'PANIC_BUTTON'], description: 'Tipo do sinal.' },
      severity: { enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'], description: 'Severidade do sinal.' },
      signal_status: { enum: ['OPEN', 'ACKNOWLEDGED', 'ESCALATED', 'RESOLVED', 'FALSE_POSITIVE'], description: 'Status do tratamento do sinal.' },
      geo: geoPointSchema,
      responder_refs: {
        bsonType: 'array',
        items: { bsonType: 'string', pattern: UUID_PATTERN },
        description: 'Usuarios ou operadores que responderam ao sinal.',
      },
      correlation_id: { bsonType: ['string', 'null'], maxLength: 160, description: 'ID de correlacao operacional.' },
      payload: { bsonType: ['object', 'null'], description: 'Payload tecnico do sinal.' },
      event_time: { bsonType: 'date', description: 'Tempo do evento na origem.' },
      ingested_at: { bsonType: 'date', description: 'Tempo de ingestao no backend.' },
    },
  },
};

// agendaItemsValidator guarda agenda, lembretes e follow-ups da Helena/Advisor.
const agendaItemsValidator = {
  $jsonSchema: {
    bsonType: 'object',
    required: ['agenda_item_id', 'user_id', 'title', 'agenda_kind', 'agenda_status', 'source_module', 'scheduled_for', 'created_at', 'updated_at'],
    additionalProperties: true,
    properties: {
      agenda_item_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do item de agenda.' },
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Dono do item.' },
      owner_persona: { enum: ['PERSONAL', 'PROFESSIONAL'], description: 'Persona que gerencia o item.' },
      title: { bsonType: 'string', minLength: 1, maxLength: 240, description: 'Titulo curto do item.' },
      agenda_kind: { enum: ['REMINDER', 'TASK', 'EVENT', 'HEALTH_ROUTINE', 'PAYMENT', 'FOLLOW_UP'], description: 'Tipo do item.' },
      agenda_status: { enum: ['OPEN', 'SNOOZED', 'DONE', 'CANCELLED', 'ARCHIVED'], description: 'Status do item.' },
      source_module: { enum: ['AGENDA', 'ADVISOR', 'CHAT', 'HEALTH', 'FINANCAS', 'SECURITY'], description: 'Modulo que originou o item.' },
      description: { bsonType: ['string', 'null'], maxLength: 4000, description: 'Descricao longa opcional.' },
      scheduled_for: { bsonType: 'date', description: 'Horario principal do item.' },
      due_at: { bsonType: ['date', 'null'], description: 'Prazo final opcional.' },
      completed_at: { bsonType: ['date', 'null'], description: 'Horario de conclusao.' },
      timezone: { bsonType: ['string', 'null'], maxLength: 80, description: 'Timezone operacional do item.' },
      reminder_offsets_minutes: {
        bsonType: 'array',
        items: { bsonType: ['int', 'long'], minimum: 0 },
        description: 'Offsets de lembrete em minutos.',
      },
      recurrence: { bsonType: ['object', 'null'], description: 'Regra de recorrencia do item.' },
      related_entities: {
        bsonType: 'array',
        items: { bsonType: 'object' },
        description: 'Entidades relacionadas como order, trip, shipment ou insight.',
      },
      ai_context: { bsonType: ['object', 'null'], description: 'Contexto sintetico para IA e priorizacao.' },
      notes: { bsonType: ['string', 'null'], maxLength: 4000, description: 'Observacoes adicionais.' },
      created_at: { bsonType: 'date', description: 'Criacao do item.' },
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao do item.' },
    },
  },
};

// Aplica o contrato de dispatch para orquestracao de entregas.
applyCollection('delivery_dispatch_runs', deliveryDispatchRunsValidator);

// Aplica o cadastro principal de veiculos da frota.
applyCollection('fleet_vehicle_profiles', fleetVehicleProfilesValidator);

// Aplica a trilha append-only de manutencao da frota.
applyCollection('fleet_maintenance_events', fleetMaintenanceEventsValidator);

// Aplica a trilha de sinais de seguranca de alto volume.
applyCollection('security_signal_logs', securitySignalLogsValidator);

// Aplica a agenda inteligente e seus lembretes.
applyCollection('agenda_items', agendaItemsValidator);

// Indice por order e status para retomar dispatch rapidamente.
db.delivery_dispatch_runs.createIndex(
  { order_id: 1, dispatch_status: 1, updated_at: -1 },
  { name: 'ix_delivery_dispatch_runs_order_status_updated_at' },
);

// Indice por rider selecionado e expiracao para matching operacional.
db.delivery_dispatch_runs.createIndex(
  { selected_rider_user_id: 1, dispatch_status: 1, expires_at: 1 },
  { name: 'ix_delivery_dispatch_runs_rider_status_expires', sparse: true },
);

// Indice por owner e status do veiculo para dashboards de frota.
db.fleet_vehicle_profiles.createIndex(
  { owner_user_id: 1, vehicle_status: 1, updated_at: -1 },
  { name: 'ix_fleet_vehicle_profiles_owner_status_updated_at' },
);

// Indice por rider atribuido para achar rapidamente o veiculo atual.
db.fleet_vehicle_profiles.createIndex(
  { assigned_rider_user_id: 1, vehicle_status: 1 },
  { name: 'ix_fleet_vehicle_profiles_rider_status', sparse: true },
);

// Indice por veiculo e data para historico de manutencao.
db.fleet_maintenance_events.createIndex(
  { vehicle_id: 1, occurred_at: -1 },
  { name: 'ix_fleet_maintenance_events_vehicle_occurred_at' },
);

// Indice por status e prazo para manutencao preventiva.
db.fleet_maintenance_events.createIndex(
  { event_status: 1, due_at: 1 },
  { name: 'ix_fleet_maintenance_events_status_due_at', sparse: true },
);

// Indice por incidente e tempo para timeline de seguranca.
db.security_signal_logs.createIndex(
  { incident_id: 1, event_time: -1 },
  { name: 'ix_security_signal_logs_incident_event_time', sparse: true },
);

// Indice por usuario, status e tempo para fila operacional.
db.security_signal_logs.createIndex(
  { user_id: 1, signal_status: 1, event_time: -1 },
  { name: 'ix_security_signal_logs_user_status_event_time' },
);

// Indice geoespacial para heatmap e resposta de proximidade.
db.security_signal_logs.createIndex(
  { geo: '2dsphere' },
  { name: 'ix_security_signal_logs_geo' },
);

// Indice por usuario e agenda para leitura principal da Helena/Agenda.
db.agenda_items.createIndex(
  { user_id: 1, agenda_status: 1, scheduled_for: 1 },
  { name: 'ix_agenda_items_user_status_scheduled_for' },
);

// Indice por modulo de origem e atualizacao para reconcilio entre sistemas.
db.agenda_items.createIndex(
  { source_module: 1, updated_at: -1 },
  { name: 'ix_agenda_items_source_updated_at' },
);

// Indice de prazo para filas e lembretes futuros.
db.agenda_items.createIndex(
  { due_at: 1 },
  { name: 'ix_agenda_items_due_at', sparse: true },
);
