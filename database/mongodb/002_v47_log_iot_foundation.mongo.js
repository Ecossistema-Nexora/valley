// Valley Hybrid DB Bootstrap - LOG e IoT foundation v47.
// Este arquivo cria collections de alto volume para tracking, devices e sensores sem mover logs brutos para PostgreSQL.
// Execute com mongosh no banco Valley/Nexora alvo depois do script 001 de IA/Social/Telemetria.

// UUID_PATTERN valida referencias logicas ao PostgreSQL public.users.user_id e a IDs relacionais expostos como string.
const UUID_PATTERN = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

// applyCollection cria ou atualiza collection com JSON Schema Validation sem apagar dados existentes.
function applyCollection(collectionName, validator) {
  // collectionExists evita erro quando o ambiente ja possui a collection.
  const collectionExists = db.getCollectionNames().includes(collectionName);

  // createCollection cria o contrato inicial quando a collection ainda nao existe.
  if (!collectionExists) {
    // validationLevel strict aplica o validator a todos os inserts e updates futuros.
    db.createCollection(collectionName, {
      // validator guarda o $jsonSchema da collection.
      validator,
      // validationLevel strict protege dados novos e alterados.
      validationLevel: 'strict',
      // validationAction error rejeita documento invalido.
      validationAction: 'error',
    });
    // return evita collMod redundante no mesmo ciclo.
    return;
  }

  // collMod atualiza validator de collection existente sem recriar dados.
  db.runCommand({
    // collMod escolhe a collection alvo.
    collMod: collectionName,
    // validator aplica o novo contrato versionado.
    validator,
    // validationLevel strict mantem enforcement forte.
    validationLevel: 'strict',
    // validationAction error bloqueia payload invalido.
    validationAction: 'error',
  });
}

// geoPointSchema padroniza GeoJSON Point para tracking, IoT e sensores.
const geoPointSchema = {
  // bsonType object exige objeto GeoJSON quando houver geo.
  bsonType: ['object', 'null'],
  // required exige tipo e coordenadas.
  required: ['type', 'coordinates'],
  // properties define Point e array [longitude, latitude].
  properties: {
    // type precisa ser Point para index 2dsphere.
    type: { enum: ['Point'], description: 'Tipo GeoJSON.' },
    // coordinates guarda longitude e latitude.
    coordinates: { bsonType: 'array', minItems: 2, maxItems: 2, items: { bsonType: ['double', 'int', 'long', 'decimal'] }, description: 'Coordenadas [longitude, latitude].' },
  },
  // description explica uso geoespacial.
  description: 'Localizacao GeoJSON Point.',
};

// logTrackingEventsValidator guarda eventos de tracking da Valley Log.
const logTrackingEventsValidator = {
  // $jsonSchema define o contrato de documento de tracking.
  $jsonSchema: {
    // bsonType object exige documento estruturado.
    bsonType: 'object',
    // required garante rastreabilidade minima por usuario, shipment, status e tempo.
    required: ['tracking_event_id', 'user_id', 'shipment_ref', 'event_type', 'event_status', 'event_time', 'ingested_at'],
    // additionalProperties true permite payloads de carriers diferentes sem quebrar ingestao.
    additionalProperties: true,
    // properties documenta campos de rastreio.
    properties: {
      // tracking_event_id e a chave logica do evento.
      tracking_event_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do evento de tracking.' },
      // user_id referencia users.user_id do dono operacional.
      user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Usuario dono do tracking.' },
      // order_id referencia orders.order_id quando existir pedido relacional.
      order_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Pedido relacional opcional.' },
      // rider_user_id referencia rider quando houver entrega urbana.
      rider_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Rider opcional.' },
      // shipment_ref identifica pacote, corrida, remessa ou tracking externo.
      shipment_ref: { bsonType: 'string', minLength: 1, maxLength: 180, description: 'Referencia da remessa.' },
      // carrier_code identifica transportadora ou integracao.
      carrier_code: { bsonType: ['string', 'null'], maxLength: 80, description: 'Codigo da transportadora.' },
      // event_type classifica o evento logistico.
      event_type: { enum: ['CREATED', 'PICKED_UP', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED_DELIVERY', 'RETURNED', 'EXCEPTION'], description: 'Tipo do evento logistico.' },
      // event_status guarda status tecnico visivel em tracking.
      event_status: { enum: ['OK', 'WARNING', 'BLOCKED', 'FAILED'], description: 'Status do evento.' },
      // geo guarda localizacao do evento quando disponivel.
      geo: geoPointSchema,
      // message guarda descricao curta para operacao e cliente.
      message: { bsonType: ['string', 'null'], maxLength: 1000, description: 'Mensagem do evento.' },
      // raw_payload guarda payload original controlado da transportadora.
      raw_payload: { bsonType: ['object', 'null'], description: 'Payload bruto da integracao.' },
      // correlation_id liga evento a trace, job ou operacao.
      correlation_id: { bsonType: ['string', 'null'], maxLength: 160, description: 'ID de correlacao.' },
      // event_time registra o tempo real do evento.
      event_time: { bsonType: 'date', description: 'Horario real do evento.' },
      // ingested_at registra quando o backend recebeu o evento.
      ingested_at: { bsonType: 'date', description: 'Horario de ingestao.' },
    },
  },
};

// iotDeviceRegistryValidator guarda cadastro flexivel de devices IoT.
const iotDeviceRegistryValidator = {
  // $jsonSchema define o contrato de device.
  $jsonSchema: {
    // bsonType object exige documento estruturado.
    bsonType: 'object',
    // required garante identidade, dono, modulo, tipo, status e auditoria.
    required: ['device_id', 'owner_user_id', 'module_code', 'device_type', 'device_status', 'created_at', 'updated_at'],
    // additionalProperties true permite capabilities novas por fabricante.
    additionalProperties: true,
    // properties documenta o device.
    properties: {
      // device_id e chave tecnica unica do device.
      device_id: { bsonType: 'string', minLength: 1, maxLength: 160, description: 'ID tecnico do device.' },
      // owner_user_id referencia users.user_id do dono.
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Dono do device.' },
      // assigned_user_id referencia usuario que usa o device quando diferente do dono.
      assigned_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Usuario atribuido ao device.' },
      // module_code identifica modulo Valley consumidor.
      module_code: { enum: ['LOG', 'IOT', 'WMS', 'FLEET', 'SECURITY', 'HOME', 'ENERGY'], description: 'Modulo de uso do device.' },
      // device_type classifica hardware ou app.
      device_type: { enum: ['PHONE', 'TRACKER', 'SENSOR', 'GATEWAY', 'WEARABLE', 'VEHICLE_UNIT', 'WAREHOUSE_NODE'], description: 'Tipo do device.' },
      // device_status controla lifecycle do device.
      device_status: { enum: ['PENDING', 'ACTIVE', 'MAINTENANCE', 'SUSPENDED', 'RETIRED'], description: 'Status do device.' },
      // firmware_version guarda versao quando existir.
      firmware_version: { bsonType: ['string', 'null'], maxLength: 80, description: 'Versao de firmware.' },
      // capabilities lista recursos tecnicos do device.
      capabilities: { bsonType: 'array', items: { bsonType: 'string', maxLength: 80 }, description: 'Capacidades do device.' },
      // last_seen_at registra ultimo heartbeat.
      last_seen_at: { bsonType: ['date', 'null'], description: 'Ultima comunicacao.' },
      // metadata guarda dados de fabricante e provisionamento.
      metadata: { bsonType: ['object', 'null'], description: 'Metadados do device.' },
      // created_at registra criacao.
      created_at: { bsonType: 'date', description: 'Criacao do device.' },
      // updated_at registra atualizacao.
      updated_at: { bsonType: 'date', description: 'Ultima atualizacao.' },
    },
  },
};

// iotSensorEventsValidator guarda eventos volumosos de sensores e gateways.
const iotSensorEventsValidator = {
  // $jsonSchema define o contrato de evento de sensor.
  $jsonSchema: {
    // bsonType object exige documento estruturado.
    bsonType: 'object',
    // required garante evento, device, usuario, tipo e tempos.
    required: ['sensor_event_id', 'device_id', 'owner_user_id', 'event_type', 'event_time', 'ingested_at'],
    // additionalProperties true aceita payload variavel por sensor.
    additionalProperties: true,
    // properties descreve evento e leitura.
    properties: {
      // sensor_event_id e chave logica do evento.
      sensor_event_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do evento de sensor.' },
      // device_id referencia iot_device_registry.device_id.
      device_id: { bsonType: 'string', minLength: 1, maxLength: 160, description: 'Device emissor.' },
      // owner_user_id referencia users.user_id do dono.
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Dono operacional.' },
      // related_user_id referencia usuario afetado quando existir.
      related_user_id: { bsonType: ['string', 'null'], pattern: UUID_PATTERN, description: 'Usuario relacionado opcional.' },
      // event_type classifica leitura ou alerta.
      event_type: { enum: ['HEARTBEAT', 'TEMPERATURE', 'HUMIDITY', 'DOOR', 'MOTION', 'BATTERY', 'LOCATION', 'ALERT', 'CUSTOM'], description: 'Tipo do evento.' },
      // severity separa informacao de alerta operacional.
      severity: { enum: ['INFO', 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'], description: 'Severidade.' },
      // geo guarda localizacao quando o sensor tem posicao.
      geo: geoPointSchema,
      // reading guarda valor normalizado simples quando existir.
      reading: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], description: 'Leitura numerica opcional.' },
      // unit guarda unidade tecnica da leitura.
      unit: { bsonType: ['string', 'null'], maxLength: 40, description: 'Unidade da leitura.' },
      // sensor_payload guarda payload especifico do sensor.
      sensor_payload: { bsonType: ['object', 'null'], description: 'Payload especifico do sensor.' },
      // correlation_id liga o evento a incidente, shipment ou trace.
      correlation_id: { bsonType: ['string', 'null'], maxLength: 160, description: 'ID de correlacao.' },
      // event_time registra tempo real do sensor.
      event_time: { bsonType: 'date', description: 'Horario real do evento.' },
      // ingested_at registra chegada no backend.
      ingested_at: { bsonType: 'date', description: 'Horario de ingestao.' },
    },
  },
};

// warehouseSensorSnapshotsValidator guarda snapshots WMS de ambiente e ocupacao.
const warehouseSensorSnapshotsValidator = {
  // $jsonSchema define contrato de snapshot por warehouse.
  $jsonSchema: {
    // bsonType object exige documento estruturado.
    bsonType: 'object',
    // required garante snapshot, warehouse relacional, device e tempo.
    required: ['snapshot_id', 'warehouse_id', 'owner_user_id', 'device_id', 'snapshot_time', 'ingested_at'],
    // additionalProperties true permite novas metricas de armazem.
    additionalProperties: true,
    // properties descreve snapshot WMS.
    properties: {
      // snapshot_id e chave logica do snapshot.
      snapshot_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'UUID do snapshot.' },
      // warehouse_id referencia warehouses.warehouse_id do PostgreSQL.
      warehouse_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Armazem relacional.' },
      // owner_user_id referencia users.user_id do dono do armazem.
      owner_user_id: { bsonType: 'string', pattern: UUID_PATTERN, description: 'Dono do armazem.' },
      // device_id referencia device do snapshot.
      device_id: { bsonType: 'string', minLength: 1, maxLength: 160, description: 'Device emissor.' },
      // temperature_c guarda temperatura quando sensor existir.
      temperature_c: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], description: 'Temperatura em Celsius.' },
      // humidity_pct guarda umidade percentual.
      humidity_pct: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, maximum: 100, description: 'Umidade percentual.' },
      // occupancy_pct guarda ocupacao estimada do armazem.
      occupancy_pct: { bsonType: ['double', 'int', 'long', 'decimal', 'null'], minimum: 0, maximum: 100, description: 'Ocupacao percentual.' },
      // metrics guarda medidas extras do WMS.
      metrics: { bsonType: ['object', 'null'], description: 'Metricas extras.' },
      // snapshot_time registra tempo real da leitura.
      snapshot_time: { bsonType: 'date', description: 'Horario do snapshot.' },
      // ingested_at registra chegada no backend.
      ingested_at: { bsonType: 'date', description: 'Horario de ingestao.' },
    },
  },
};

// Aplica collection de eventos de tracking logistico.
applyCollection('log_tracking_events', logTrackingEventsValidator);

// Aplica collection de registry flexivel de devices IoT.
applyCollection('iot_device_registry', iotDeviceRegistryValidator);

// Aplica collection de eventos volumosos de sensores.
applyCollection('iot_sensor_events', iotSensorEventsValidator);

// Aplica collection de snapshots de sensores de armazem.
applyCollection('warehouse_sensor_snapshots', warehouseSensorSnapshotsValidator);

// Indice de tracking por usuario e tempo.
db.log_tracking_events.createIndex({ user_id: 1, event_time: -1 }, { name: 'ix_log_tracking_events_user_time' });

// Indice de tracking por remessa e tempo.
db.log_tracking_events.createIndex({ shipment_ref: 1, event_time: -1 }, { name: 'ix_log_tracking_events_shipment_time' });

// Indice geoespacial de tracking.
db.log_tracking_events.createIndex({ geo: '2dsphere' }, { name: 'ix_log_tracking_events_geo_2dsphere', sparse: true });

// Indice de devices por dono e status.
db.iot_device_registry.createIndex({ owner_user_id: 1, device_status: 1, updated_at: -1 }, { name: 'ix_iot_device_registry_owner_status' });

// Indice unico de device.
db.iot_device_registry.createIndex({ device_id: 1 }, { name: 'ux_iot_device_registry_device_id', unique: true });

// Indice de eventos de sensor por device e tempo.
db.iot_sensor_events.createIndex({ device_id: 1, event_time: -1 }, { name: 'ix_iot_sensor_events_device_time' });

// Indice de eventos de sensor por dono e tempo.
db.iot_sensor_events.createIndex({ owner_user_id: 1, event_time: -1 }, { name: 'ix_iot_sensor_events_owner_time' });

// Indice geoespacial de sensores.
db.iot_sensor_events.createIndex({ geo: '2dsphere' }, { name: 'ix_iot_sensor_events_geo_2dsphere', sparse: true });

// Indice de snapshots por armazem e tempo.
db.warehouse_sensor_snapshots.createIndex({ warehouse_id: 1, snapshot_time: -1 }, { name: 'ix_warehouse_sensor_snapshots_warehouse_time' });

// Indice de snapshots por device e tempo.
db.warehouse_sensor_snapshots.createIndex({ device_id: 1, snapshot_time: -1 }, { name: 'ix_warehouse_sensor_snapshots_device_time' });
