-- Valley Hybrid DB Bootstrap - City Ops core v47.
-- Este arquivo aprofunda DELIVERY, MOBILITY e SECURITY sobre o nucleo relacional ja implantado.
-- Ele reutiliza users, rider_profiles, wallets, orders, document_records, legal_disputes e module_delivery_registry.
-- Execute depois de 001, 002, 004, 007, 009 e 010 para manter todas as integracoes disponiveis.

BEGIN;

SET search_path = public;

-- delivery_shipment_kind_enum separa food, courier, marketplace e farmacia dentro do mesmo contrato.
CREATE TYPE delivery_shipment_kind_enum AS ENUM ('FOOD', 'COURIER', 'MARKETPLACE', 'PHARMACY', 'DOCUMENT');

-- delivery_shipment_status_enum controla o lifecycle mutavel do embarque ate a entrega final.
CREATE TYPE delivery_shipment_status_enum AS ENUM ('DRAFT', 'DISPATCHING', 'ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'FAILED', 'CANCELLED');

-- delivery_event_type_enum registra a trilha append-only dos eventos operacionais do embarque.
CREATE TYPE delivery_event_type_enum AS ENUM ('CREATED', 'DISPATCH_STARTED', 'RIDER_ASSIGNED', 'PICKED_UP', 'CHECKPOINT', 'DELIVERED', 'FAILED', 'CANCELLED', 'PROOF_ATTACHED');

-- mobility_trip_service_enum diferencia ride tradicional, carpool e variantes assistidas.
CREATE TYPE mobility_trip_service_enum AS ENUM ('RIDE', 'CARPOOL', 'ASSISTED', 'DELIVERY_SUPPORT');

-- mobility_trip_status_enum controla o lifecycle operacional da corrida.
CREATE TYPE mobility_trip_status_enum AS ENUM ('SEARCHING', 'MATCHED', 'RIDER_EN_ROUTE', 'PASSENGER_ONBOARD', 'COMPLETED', 'CANCELLED', 'NO_SHOW', 'INCIDENT');

-- mobility_checkpoint_type_enum cria checkpoints append-only para analytics, suporte e seguranca.
CREATE TYPE mobility_checkpoint_type_enum AS ENUM ('SEARCH_STARTED', 'RIDER_ASSIGNED', 'RIDER_ARRIVED', 'PASSENGER_BOARDED', 'STOP_REACHED', 'TRIP_COMPLETED', 'TRIP_CANCELLED', 'SOS_TRIGGERED');

-- security_contact_kind_enum classifica o papel do contato dentro do fluxo SOS.
CREATE TYPE security_contact_kind_enum AS ENUM ('EMERGENCY', 'FAMILY', 'GUARDIAN', 'WORK', 'LEGAL');

-- biometric_credential_kind_enum registra apenas o tipo tecnico da credencial, nunca o dado bruto.
CREATE TYPE biometric_credential_kind_enum AS ENUM ('FACE', 'FINGERPRINT', 'VOICE', 'PALM', 'DOCUMENT_LIVENESS');

-- biometric_credential_status_enum controla se a credencial ainda pode ser usada.
CREATE TYPE biometric_credential_status_enum AS ENUM ('PENDING', 'ACTIVE', 'REVOKED', 'BLOCKED', 'EXPIRED');

-- security_incident_type_enum identifica a natureza do risco para roteamento operacional e juridico.
CREATE TYPE security_incident_type_enum AS ENUM ('SOS', 'TRIP_ANOMALY', 'DELIVERY_RISK', 'GEOFENCE_BREACH', 'DEVICE_TAMPER', 'IOT_ALERT', 'FRAUD_REVIEW');

-- security_incident_severity_enum prioriza resposta e escalonamento.
CREATE TYPE security_incident_severity_enum AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');

-- security_incident_status_enum descreve o lifecycle do incidente.
CREATE TYPE security_incident_status_enum AS ENUM ('OPEN', 'ACKNOWLEDGED', 'ESCALATED', 'RESOLVED', 'FALSE_POSITIVE', 'ARCHIVED');

-- security_incident_event_type_enum preserva a trilha append-only do incidente.
CREATE TYPE security_incident_event_type_enum AS ENUM ('CREATED', 'ACKNOWLEDGED', 'ESCALATED', 'CONTACT_NOTIFIED', 'EVIDENCE_ATTACHED', 'LEGAL_REFERENCED', 'RESOLVED', 'FALSE_POSITIVE');

-- delivery_shipments guarda o contrato relacional mutavel de cada entrega urbana.
CREATE TABLE delivery_shipments (
    shipment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'DELIVERY',
    requester_user_id UUID NOT NULL,
    merchant_user_id UUID,
    rider_user_id UUID,
    wallet_id UUID NOT NULL,
    source_order_domain order_domain_enum NOT NULL,
    shipment_kind delivery_shipment_kind_enum NOT NULL,
    shipment_status delivery_shipment_status_enum NOT NULL DEFAULT 'DRAFT',
    pickup_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    dropoff_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    pickup_contact_name TEXT,
    pickup_contact_phone TEXT,
    receiver_contact_name TEXT,
    receiver_contact_phone TEXT,
    package_count SMALLINT NOT NULL DEFAULT 1,
    package_weight_kg DECIMAL(10,3) NOT NULL DEFAULT 0,
    declared_value_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    delivery_fee_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    cash_to_collect_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    route_distance_km DECIMAL(12,3),
    route_duration_sec INTEGER,
    proof_code_hash TEXT,
    proof_document_id UUID,
    dispatch_started_at TIMESTAMPTZ,
    assigned_at TIMESTAMPTZ,
    picked_up_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    status_notes TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_delivery_shipments_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_shipments_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_shipments_requester
        FOREIGN KEY (requester_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_shipments_merchant
        FOREIGN KEY (merchant_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_shipments_rider
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_shipments_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_shipments_document
        FOREIGN KEY (proof_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_delivery_shipments_domain CHECK (source_order_domain IN ('FOOD', 'DROPSHIP')),
    CONSTRAINT chk_delivery_shipments_pickup_json CHECK (jsonb_typeof(pickup_address_json) = 'object'),
    CONSTRAINT chk_delivery_shipments_dropoff_json CHECK (jsonb_typeof(dropoff_address_json) = 'object'),
    CONSTRAINT chk_delivery_shipments_pickup_name CHECK (pickup_contact_name IS NULL OR btrim(pickup_contact_name) <> ''),
    CONSTRAINT chk_delivery_shipments_pickup_phone CHECK (
        pickup_contact_phone IS NULL OR pickup_contact_phone ~ '^\+[1-9][0-9]{7,14}$'
    ),
    CONSTRAINT chk_delivery_shipments_receiver_name CHECK (receiver_contact_name IS NULL OR btrim(receiver_contact_name) <> ''),
    CONSTRAINT chk_delivery_shipments_receiver_phone CHECK (
        receiver_contact_phone IS NULL OR receiver_contact_phone ~ '^\+[1-9][0-9]{7,14}$'
    ),
    CONSTRAINT chk_delivery_shipments_package_count CHECK (package_count BETWEEN 1 AND 999),
    CONSTRAINT chk_delivery_shipments_amounts CHECK (
        package_weight_kg >= 0
        AND declared_value_brl >= 0
        AND delivery_fee_brl >= 0
        AND cash_to_collect_brl >= 0
    ),
    CONSTRAINT chk_delivery_shipments_route CHECK (
        (route_distance_km IS NULL OR route_distance_km >= 0)
        AND (route_duration_sec IS NULL OR route_duration_sec >= 0)
    ),
    CONSTRAINT chk_delivery_shipments_proof_hash CHECK (
        proof_code_hash IS NULL OR proof_code_hash ~ '^[a-fA-F0-9]{64}$'
    ),
    CONSTRAINT chk_delivery_shipments_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_delivery_shipments_timeline CHECK (
        (assigned_at IS NULL OR dispatch_started_at IS NULL OR assigned_at >= dispatch_started_at)
        AND (picked_up_at IS NULL OR assigned_at IS NULL OR picked_up_at >= assigned_at)
        AND (delivered_at IS NULL OR picked_up_at IS NULL OR delivered_at >= picked_up_at)
        AND (failed_at IS NULL OR dispatch_started_at IS NULL OR failed_at >= dispatch_started_at)
        AND (cancelled_at IS NULL OR dispatch_started_at IS NULL OR cancelled_at >= dispatch_started_at)
    ),
    CONSTRAINT chk_delivery_shipments_status_dates CHECK (
        (shipment_status <> 'DELIVERED' OR delivered_at IS NOT NULL)
        AND (shipment_status <> 'FAILED' OR failed_at IS NOT NULL)
        AND (shipment_status <> 'CANCELLED' OR cancelled_at IS NOT NULL)
    ),
    CONSTRAINT chk_delivery_shipments_cancellation_reason CHECK (
        cancellation_reason IS NULL OR btrim(cancellation_reason) <> ''
    ),
    CONSTRAINT chk_delivery_shipments_status_notes CHECK (
        status_notes IS NULL OR btrim(status_notes) <> ''
    )
);

-- delivery_shipment_events guarda a trilha append-only da entrega.
CREATE TABLE delivery_shipment_events (
    shipment_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shipment_id UUID NOT NULL,
    order_id UUID NOT NULL,
    actor_user_id UUID,
    event_type delivery_event_type_enum NOT NULL,
    shipment_status delivery_shipment_status_enum NOT NULL,
    geo_json JSONB,
    notes TEXT,
    correlation_id TEXT,
    evidence_document_id UUID,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_delivery_shipment_events_shipment
        FOREIGN KEY (shipment_id) REFERENCES delivery_shipments (shipment_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_shipment_events_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_shipment_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_delivery_shipment_events_document
        FOREIGN KEY (evidence_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_delivery_shipment_events_geo_json CHECK (
        geo_json IS NULL OR jsonb_typeof(geo_json) = 'object'
    ),
    CONSTRAINT chk_delivery_shipment_events_notes CHECK (notes IS NULL OR btrim(notes) <> ''),
    CONSTRAINT chk_delivery_shipment_events_correlation CHECK (
        correlation_id IS NULL OR btrim(correlation_id) <> ''
    ),
    CONSTRAINT chk_delivery_shipment_events_payload CHECK (jsonb_typeof(payload_json) = 'object')
);

-- mobility_trips guarda a corrida consolidada do modulo Mobility ligada ao order MOVE.
CREATE TABLE mobility_trips (
    trip_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE,
    rider_user_id UUID NOT NULL,
    passenger_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'MOBILITY',
    trip_service mobility_trip_service_enum NOT NULL DEFAULT 'RIDE',
    trip_status mobility_trip_status_enum NOT NULL DEFAULT 'SEARCHING',
    pickup_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    dropoff_address_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    pickup_geo_json JSONB,
    dropoff_geo_json JSONB,
    estimated_distance_km DECIMAL(12,3) NOT NULL DEFAULT 0,
    estimated_duration_sec INTEGER NOT NULL DEFAULT 0,
    actual_distance_km DECIMAL(12,3),
    actual_duration_sec INTEGER,
    estimated_fare_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    final_fare_brl DECIMAL(18,4),
    surge_multiplier DECIMAL(8,4) NOT NULL DEFAULT 1,
    passenger_count SMALLINT NOT NULL DEFAULT 1,
    shared_trip BOOLEAN NOT NULL DEFAULT FALSE,
    safety_pin_hash TEXT,
    started_at TIMESTAMPTZ,
    boarded_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_mobility_trips_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_trips_rider
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_trips_passenger
        FOREIGN KEY (passenger_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_trips_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_trips_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_mobility_trips_distinct_users CHECK (rider_user_id <> passenger_user_id),
    CONSTRAINT chk_mobility_trips_pickup_json CHECK (jsonb_typeof(pickup_address_json) = 'object'),
    CONSTRAINT chk_mobility_trips_dropoff_json CHECK (jsonb_typeof(dropoff_address_json) = 'object'),
    CONSTRAINT chk_mobility_trips_pickup_geo CHECK (
        pickup_geo_json IS NULL OR jsonb_typeof(pickup_geo_json) = 'object'
    ),
    CONSTRAINT chk_mobility_trips_dropoff_geo CHECK (
        dropoff_geo_json IS NULL OR jsonb_typeof(dropoff_geo_json) = 'object'
    ),
    CONSTRAINT chk_mobility_trips_metrics CHECK (
        estimated_distance_km >= 0
        AND estimated_duration_sec >= 0
        AND (actual_distance_km IS NULL OR actual_distance_km >= 0)
        AND (actual_duration_sec IS NULL OR actual_duration_sec >= 0)
        AND estimated_fare_brl >= 0
        AND (final_fare_brl IS NULL OR final_fare_brl >= 0)
        AND surge_multiplier >= 1
    ),
    CONSTRAINT chk_mobility_trips_passenger_count CHECK (passenger_count BETWEEN 1 AND 8),
    CONSTRAINT chk_mobility_trips_safety_hash CHECK (
        safety_pin_hash IS NULL OR safety_pin_hash ~ '^[a-fA-F0-9]{64}$'
    ),
    CONSTRAINT chk_mobility_trips_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_mobility_trips_timeline CHECK (
        (boarded_at IS NULL OR started_at IS NULL OR boarded_at >= started_at)
        AND (completed_at IS NULL OR boarded_at IS NULL OR completed_at >= boarded_at)
        AND (cancelled_at IS NULL OR started_at IS NULL OR cancelled_at >= started_at)
    ),
    CONSTRAINT chk_mobility_trips_status_dates CHECK (
        (trip_status <> 'COMPLETED' OR completed_at IS NOT NULL)
        AND (trip_status <> 'CANCELLED' OR cancelled_at IS NOT NULL)
    ),
    CONSTRAINT chk_mobility_trips_cancellation_reason CHECK (
        cancellation_reason IS NULL OR btrim(cancellation_reason) <> ''
    )
);

-- mobility_trip_events preserva os checkpoints append-only da corrida.
CREATE TABLE mobility_trip_events (
    trip_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID NOT NULL,
    order_id UUID NOT NULL,
    actor_user_id UUID,
    checkpoint_type mobility_checkpoint_type_enum NOT NULL,
    geo_json JSONB,
    speed_kph DECIMAL(10,3),
    distance_since_last_km DECIMAL(10,3),
    eta_seconds INTEGER,
    notes TEXT,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_mobility_trip_events_trip
        FOREIGN KEY (trip_id) REFERENCES mobility_trips (trip_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_trip_events_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_trip_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_mobility_trip_events_geo_json CHECK (
        geo_json IS NULL OR jsonb_typeof(geo_json) = 'object'
    ),
    CONSTRAINT chk_mobility_trip_events_metrics CHECK (
        (speed_kph IS NULL OR speed_kph >= 0)
        AND (distance_since_last_km IS NULL OR distance_since_last_km >= 0)
        AND (eta_seconds IS NULL OR eta_seconds >= 0)
    ),
    CONSTRAINT chk_mobility_trip_events_notes CHECK (notes IS NULL OR btrim(notes) <> ''),
    CONSTRAINT chk_mobility_trip_events_payload CHECK (jsonb_typeof(payload_json) = 'object')
);

-- security_trusted_contacts registra contatos acionaveis nos fluxos SOS e escalonamento.
CREATE TABLE security_trusted_contacts (
    security_contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    contact_kind security_contact_kind_enum NOT NULL DEFAULT 'EMERGENCY',
    contact_name TEXT NOT NULL,
    relation_label TEXT,
    phone_e164 TEXT,
    email TEXT,
    priority SMALLINT NOT NULL DEFAULT 1,
    notify_sms BOOLEAN NOT NULL DEFAULT TRUE,
    notify_email BOOLEAN NOT NULL DEFAULT FALSE,
    notify_push BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_security_trusted_contacts_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_security_trusted_contacts_name CHECK (btrim(contact_name) <> ''),
    CONSTRAINT chk_security_trusted_contacts_relation CHECK (
        relation_label IS NULL OR btrim(relation_label) <> ''
    ),
    CONSTRAINT chk_security_trusted_contacts_phone CHECK (
        phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{7,14}$'
    ),
    CONSTRAINT chk_security_trusted_contacts_email CHECK (
        email IS NULL OR email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
    ),
    CONSTRAINT chk_security_trusted_contacts_priority CHECK (priority BETWEEN 1 AND 10),
    CONSTRAINT chk_security_trusted_contacts_channel CHECK (
        phone_e164 IS NOT NULL OR email IS NOT NULL OR notify_push = TRUE
    ),
    CONSTRAINT chk_security_trusted_contacts_notes CHECK (notes IS NULL OR btrim(notes) <> '')
);

-- security_biometric_credentials guarda somente hash e metadados de biometria, nunca o template bruto.
CREATE TABLE security_biometric_credentials (
    biometric_credential_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    credential_kind biometric_credential_kind_enum NOT NULL,
    credential_status biometric_credential_status_enum NOT NULL DEFAULT 'PENDING',
    provider_name TEXT NOT NULL DEFAULT 'LOCAL',
    template_hash TEXT NOT NULL,
    device_reference_hash TEXT,
    liveness_score NUMERIC(5,2),
    enrollment_document_id UUID,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    verified_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_security_biometric_credentials_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_biometric_credentials_document
        FOREIGN KEY (enrollment_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_security_biometric_credentials_provider CHECK (btrim(provider_name) <> ''),
    CONSTRAINT chk_security_biometric_credentials_template_hash CHECK (
        template_hash ~ '^[a-fA-F0-9]{64,128}$'
    ),
    CONSTRAINT chk_security_biometric_credentials_device_hash CHECK (
        device_reference_hash IS NULL OR device_reference_hash ~ '^[a-fA-F0-9]{64,128}$'
    ),
    CONSTRAINT chk_security_biometric_credentials_liveness CHECK (
        liveness_score IS NULL OR (liveness_score >= 0 AND liveness_score <= 100)
    ),
    CONSTRAINT chk_security_biometric_credentials_metadata CHECK (
        jsonb_typeof(metadata_json) = 'object'
    ),
    CONSTRAINT chk_security_biometric_credentials_timeline CHECK (
        (verified_at IS NULL OR verified_at >= enrolled_at)
        AND (revoked_at IS NULL OR revoked_at >= enrolled_at)
    ),
    CONSTRAINT chk_security_biometric_credentials_status_dates CHECK (
        (credential_status <> 'REVOKED' OR revoked_at IS NOT NULL)
        AND (
            revoked_at IS NULL
            OR (revocation_reason IS NOT NULL AND btrim(revocation_reason) <> '')
        )
    )
);

-- security_incidents centraliza o incidente mutavel e deixa a trilha detalhada para a tabela append-only.
CREATE TABLE security_incidents (
    security_incident_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_code TEXT NOT NULL DEFAULT 'SECURITY',
    user_id UUID NOT NULL,
    reporter_user_id UUID,
    rider_user_id UUID,
    order_id UUID,
    trip_id UUID,
    shipment_id UUID,
    legal_dispute_id UUID,
    incident_type security_incident_type_enum NOT NULL,
    severity security_incident_severity_enum NOT NULL DEFAULT 'MEDIUM',
    incident_status security_incident_status_enum NOT NULL DEFAULT 'OPEN',
    title TEXT NOT NULL,
    description TEXT,
    address_json JSONB,
    geo_json JSONB,
    correlation_id TEXT,
    risk_score SMALLINT NOT NULL DEFAULT 0,
    evidence_document_id UUID,
    opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    acknowledged_at TIMESTAMPTZ,
    escalation_deadline_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    resolution_summary TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_security_incidents_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incidents_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incidents_reporter
        FOREIGN KEY (reporter_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incidents_rider
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incidents_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incidents_trip
        FOREIGN KEY (trip_id) REFERENCES mobility_trips (trip_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incidents_shipment
        FOREIGN KEY (shipment_id) REFERENCES delivery_shipments (shipment_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incidents_dispute
        FOREIGN KEY (legal_dispute_id) REFERENCES legal_disputes (legal_dispute_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incidents_document
        FOREIGN KEY (evidence_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_security_incidents_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_security_incidents_description CHECK (
        description IS NULL OR btrim(description) <> ''
    ),
    CONSTRAINT chk_security_incidents_address_json CHECK (
        address_json IS NULL OR jsonb_typeof(address_json) = 'object'
    ),
    CONSTRAINT chk_security_incidents_geo_json CHECK (
        geo_json IS NULL OR jsonb_typeof(geo_json) = 'object'
    ),
    CONSTRAINT chk_security_incidents_correlation CHECK (
        correlation_id IS NULL OR btrim(correlation_id) <> ''
    ),
    CONSTRAINT chk_security_incidents_anchor CHECK (
        order_id IS NOT NULL
        OR trip_id IS NOT NULL
        OR shipment_id IS NOT NULL
        OR legal_dispute_id IS NOT NULL
        OR geo_json IS NOT NULL
        OR correlation_id IS NOT NULL
    ),
    CONSTRAINT chk_security_incidents_risk_score CHECK (risk_score BETWEEN 0 AND 100),
    CONSTRAINT chk_security_incidents_resolution_summary CHECK (
        resolution_summary IS NULL OR btrim(resolution_summary) <> ''
    ),
    CONSTRAINT chk_security_incidents_metadata CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_security_incidents_timeline CHECK (
        (acknowledged_at IS NULL OR acknowledged_at >= opened_at)
        AND (escalation_deadline_at IS NULL OR escalation_deadline_at >= opened_at)
        AND (resolved_at IS NULL OR resolved_at >= opened_at)
    ),
    CONSTRAINT chk_security_incidents_status_dates CHECK (
        incident_status <> 'RESOLVED' OR resolved_at IS NOT NULL
    )
);

-- security_incident_events preserva toda acao critica como trilha append-only imutavel.
CREATE TABLE security_incident_events (
    security_incident_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    security_incident_id UUID NOT NULL,
    actor_user_id UUID,
    event_type security_incident_event_type_enum NOT NULL,
    incident_status security_incident_status_enum NOT NULL,
    notified_contact_id UUID,
    document_id UUID,
    notes TEXT,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_security_incident_events_incident
        FOREIGN KEY (security_incident_id) REFERENCES security_incidents (security_incident_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incident_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incident_events_contact
        FOREIGN KEY (notified_contact_id) REFERENCES security_trusted_contacts (security_contact_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_security_incident_events_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_security_incident_events_notes CHECK (
        notes IS NULL OR btrim(notes) <> ''
    ),
    CONSTRAINT chk_security_incident_events_payload CHECK (
        jsonb_typeof(payload_json) = 'object'
    )
);

CREATE INDEX ix_delivery_shipments_order_status
    ON delivery_shipments (order_id, shipment_status, created_at);

CREATE INDEX ix_delivery_shipments_requester_created_at
    ON delivery_shipments (requester_user_id, created_at);

CREATE INDEX ix_delivery_shipments_rider_active
    ON delivery_shipments (rider_user_id, shipment_status, created_at)
    WHERE rider_user_id IS NOT NULL
      AND shipment_status IN ('DISPATCHING', 'ASSIGNED', 'PICKED_UP', 'IN_TRANSIT');

CREATE INDEX ix_delivery_shipment_events_shipment_time
    ON delivery_shipment_events (shipment_id, occurred_at);

CREATE INDEX ix_delivery_shipment_events_order_time
    ON delivery_shipment_events (order_id, occurred_at);

CREATE INDEX ix_mobility_trips_rider_active
    ON mobility_trips (rider_user_id, trip_status, created_at)
    WHERE trip_status IN ('MATCHED', 'RIDER_EN_ROUTE', 'PASSENGER_ONBOARD', 'INCIDENT');

CREATE INDEX ix_mobility_trips_passenger_created_at
    ON mobility_trips (passenger_user_id, created_at);

CREATE INDEX ix_mobility_trip_events_trip_time
    ON mobility_trip_events (trip_id, occurred_at);

CREATE INDEX ix_security_trusted_contacts_user_active
    ON security_trusted_contacts (user_id, is_active, priority);

CREATE UNIQUE INDEX ux_security_biometric_credentials_active_kind
    ON security_biometric_credentials (user_id, credential_kind)
    WHERE credential_status IN ('PENDING', 'ACTIVE');

CREATE INDEX ix_security_biometric_credentials_user_status
    ON security_biometric_credentials (user_id, credential_status, updated_at);

CREATE INDEX ix_security_incidents_user_status
    ON security_incidents (user_id, incident_status, severity, opened_at);

CREATE INDEX ix_security_incidents_open_severity
    ON security_incidents (severity, opened_at)
    WHERE incident_status IN ('OPEN', 'ACKNOWLEDGED', 'ESCALATED');

CREATE INDEX ix_security_incidents_trip
    ON security_incidents (trip_id)
    WHERE trip_id IS NOT NULL;

CREATE INDEX ix_security_incidents_shipment
    ON security_incidents (shipment_id)
    WHERE shipment_id IS NOT NULL;

CREATE INDEX ix_security_incident_events_incident_time
    ON security_incident_events (security_incident_id, occurred_at);

-- assert_city_ops_rider_user valida user_kind e existencia de rider profile antes de usar o usuario como rider.
CREATE OR REPLACE FUNCTION assert_city_ops_rider_user(p_rider_user_id UUID, p_context TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    actual_kind user_kind_enum;
    has_profile BOOLEAN;
BEGIN
    IF p_rider_user_id IS NULL THEN
        RETURN;
    END IF;

    SELECT user_kind
      INTO actual_kind
      FROM users
     WHERE user_id = p_rider_user_id;

    IF actual_kind IS NULL THEN
        RAISE EXCEPTION 'Rider % does not exist for %', p_rider_user_id, p_context;
    END IF;

    IF actual_kind <> 'RIDER' THEN
        RAISE EXCEPTION 'Context % requires user_kind RIDER. Found % for user %', p_context, actual_kind, p_rider_user_id;
    END IF;

    SELECT EXISTS (
        SELECT 1
          FROM rider_profiles
         WHERE user_id = p_rider_user_id
    )
      INTO has_profile;

    IF NOT has_profile THEN
        RAISE EXCEPTION 'Rider % has no rider_profiles row for %', p_rider_user_id, p_context;
    END IF;
END;
$$;

-- assert_delivery_shipment_coherence alinha shipment com order, wallet, merchant e rider.
CREATE OR REPLACE FUNCTION assert_delivery_shipment_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    order_user_id UUID;
    order_wallet_id UUID;
    order_domain order_domain_enum;
    order_merchant_user_id UUID;
    order_rider_user_id UUID;
BEGIN
    SELECT user_id, wallet_id, order_domain, merchant_user_id, rider_user_id
      INTO order_user_id, order_wallet_id, order_domain, order_merchant_user_id, order_rider_user_id
      FROM orders
     WHERE order_id = NEW.order_id;

    IF order_user_id IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist for shipment %', NEW.order_id, NEW.shipment_id;
    END IF;

    IF order_user_id <> NEW.requester_user_id THEN
        RAISE EXCEPTION 'Shipment requester % differs from order user %', NEW.requester_user_id, order_user_id;
    END IF;

    IF order_wallet_id <> NEW.wallet_id THEN
        RAISE EXCEPTION 'Shipment wallet % differs from order wallet %', NEW.wallet_id, order_wallet_id;
    END IF;

    IF order_domain <> NEW.source_order_domain THEN
        RAISE EXCEPTION 'Shipment domain % differs from order domain %', NEW.source_order_domain, order_domain;
    END IF;

    IF NEW.merchant_user_id IS NULL THEN
        NEW.merchant_user_id := order_merchant_user_id;
    END IF;

    IF order_merchant_user_id IS NOT NULL AND NEW.merchant_user_id <> order_merchant_user_id THEN
        RAISE EXCEPTION 'Shipment merchant % differs from order merchant %', NEW.merchant_user_id, order_merchant_user_id;
    END IF;

    IF NEW.rider_user_id IS NULL AND order_rider_user_id IS NOT NULL THEN
        NEW.rider_user_id := order_rider_user_id;
    END IF;

    PERFORM assert_city_ops_rider_user(NEW.rider_user_id, 'delivery_shipments');

    RETURN NEW;
END;
$$;

-- assert_delivery_shipment_event_coherence garante que o evento aponta para o mesmo order do shipment.
CREATE OR REPLACE FUNCTION assert_delivery_shipment_event_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    expected_order_id UUID;
BEGIN
    SELECT order_id
      INTO expected_order_id
      FROM delivery_shipments
     WHERE shipment_id = NEW.shipment_id;

    IF expected_order_id IS NULL THEN
        RAISE EXCEPTION 'Shipment % does not exist for delivery event %', NEW.shipment_id, NEW.shipment_event_id;
    END IF;

    IF expected_order_id <> NEW.order_id THEN
        RAISE EXCEPTION 'Delivery event order % differs from shipment order %', NEW.order_id, expected_order_id;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_mobility_trip_coherence garante que a corrida usa order MOVE, wallet do passageiro e rider valido.
CREATE OR REPLACE FUNCTION assert_mobility_trip_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    order_user_id UUID;
    order_wallet_id UUID;
    order_domain order_domain_enum;
    order_rider_user_id UUID;
BEGIN
    SELECT user_id, wallet_id, order_domain, rider_user_id
      INTO order_user_id, order_wallet_id, order_domain, order_rider_user_id
      FROM orders
     WHERE order_id = NEW.order_id;

    IF order_user_id IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist for trip %', NEW.order_id, NEW.trip_id;
    END IF;

    IF order_domain <> 'MOVE' THEN
        RAISE EXCEPTION 'Mobility trip requires MOVE order. Found % for order %', order_domain, NEW.order_id;
    END IF;

    IF order_user_id <> NEW.passenger_user_id THEN
        RAISE EXCEPTION 'Trip passenger % differs from order user %', NEW.passenger_user_id, order_user_id;
    END IF;

    IF order_wallet_id <> NEW.wallet_id THEN
        RAISE EXCEPTION 'Trip wallet % differs from order wallet %', NEW.wallet_id, order_wallet_id;
    END IF;

    IF order_rider_user_id IS NOT NULL AND NEW.rider_user_id <> order_rider_user_id THEN
        RAISE EXCEPTION 'Trip rider % differs from order rider %', NEW.rider_user_id, order_rider_user_id;
    END IF;

    PERFORM assert_city_ops_rider_user(NEW.rider_user_id, 'mobility_trips');

    RETURN NEW;
END;
$$;

-- assert_mobility_trip_event_coherence garante que o checkpoint usa o mesmo order da corrida.
CREATE OR REPLACE FUNCTION assert_mobility_trip_event_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    expected_order_id UUID;
BEGIN
    SELECT order_id
      INTO expected_order_id
      FROM mobility_trips
     WHERE trip_id = NEW.trip_id;

    IF expected_order_id IS NULL THEN
        RAISE EXCEPTION 'Trip % does not exist for trip event %', NEW.trip_id, NEW.trip_event_id;
    END IF;

    IF expected_order_id <> NEW.order_id THEN
        RAISE EXCEPTION 'Trip event order % differs from trip order %', NEW.order_id, expected_order_id;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_security_incident_coherence preenche e valida anchors tecnicos do incidente.
CREATE OR REPLACE FUNCTION assert_security_incident_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    trip_order_id UUID;
    trip_rider_user_id UUID;
    shipment_order_id UUID;
    shipment_rider_user_id UUID;
BEGIN
    IF NEW.trip_id IS NOT NULL THEN
        SELECT order_id, rider_user_id
          INTO trip_order_id, trip_rider_user_id
          FROM mobility_trips
         WHERE trip_id = NEW.trip_id;

        IF trip_order_id IS NULL THEN
            RAISE EXCEPTION 'Trip % does not exist for security incident %', NEW.trip_id, NEW.security_incident_id;
        END IF;

        IF NEW.order_id IS NULL THEN
            NEW.order_id := trip_order_id;
        ELSIF NEW.order_id <> trip_order_id THEN
            RAISE EXCEPTION 'Security incident order % differs from trip order %', NEW.order_id, trip_order_id;
        END IF;

        IF NEW.rider_user_id IS NULL AND trip_rider_user_id IS NOT NULL THEN
            NEW.rider_user_id := trip_rider_user_id;
        ELSIF NEW.rider_user_id IS NOT NULL AND trip_rider_user_id IS NOT NULL AND NEW.rider_user_id <> trip_rider_user_id THEN
            RAISE EXCEPTION 'Security incident rider % differs from trip rider %', NEW.rider_user_id, trip_rider_user_id;
        END IF;
    END IF;

    IF NEW.shipment_id IS NOT NULL THEN
        SELECT order_id, rider_user_id
          INTO shipment_order_id, shipment_rider_user_id
          FROM delivery_shipments
         WHERE shipment_id = NEW.shipment_id;

        IF shipment_order_id IS NULL THEN
            RAISE EXCEPTION 'Shipment % does not exist for security incident %', NEW.shipment_id, NEW.security_incident_id;
        END IF;

        IF NEW.order_id IS NULL THEN
            NEW.order_id := shipment_order_id;
        ELSIF NEW.order_id <> shipment_order_id THEN
            RAISE EXCEPTION 'Security incident order % differs from shipment order %', NEW.order_id, shipment_order_id;
        END IF;

        IF NEW.rider_user_id IS NULL AND shipment_rider_user_id IS NOT NULL THEN
            NEW.rider_user_id := shipment_rider_user_id;
        ELSIF NEW.rider_user_id IS NOT NULL AND shipment_rider_user_id IS NOT NULL AND NEW.rider_user_id <> shipment_rider_user_id THEN
            RAISE EXCEPTION 'Security incident rider % differs from shipment rider %', NEW.rider_user_id, shipment_rider_user_id;
        END IF;
    END IF;

    PERFORM assert_city_ops_rider_user(NEW.rider_user_id, 'security_incidents');

    RETURN NEW;
END;
$$;

-- assert_security_incident_event_coherence impede notificar contato de outro usuario por engano.
CREATE OR REPLACE FUNCTION assert_security_incident_event_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    incident_user_id UUID;
    contact_user_id UUID;
BEGIN
    SELECT user_id
      INTO incident_user_id
      FROM security_incidents
     WHERE security_incident_id = NEW.security_incident_id;

    IF incident_user_id IS NULL THEN
        RAISE EXCEPTION 'Security incident % does not exist for incident event %', NEW.security_incident_id, NEW.security_incident_event_id;
    END IF;

    IF NEW.notified_contact_id IS NOT NULL THEN
        SELECT user_id
          INTO contact_user_id
          FROM security_trusted_contacts
         WHERE security_contact_id = NEW.notified_contact_id;

        IF contact_user_id IS NULL THEN
            RAISE EXCEPTION 'Security contact % does not exist for incident event %', NEW.notified_contact_id, NEW.security_incident_event_id;
        END IF;

        IF contact_user_id <> incident_user_id THEN
            RAISE EXCEPTION 'Security contact % belongs to user % but incident belongs to user %',
                NEW.notified_contact_id, contact_user_id, incident_user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_delivery_shipments_set_updated_at
BEFORE UPDATE ON delivery_shipments
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_delivery_shipments_assert_coherence
BEFORE INSERT OR UPDATE OF order_id, requester_user_id, merchant_user_id, rider_user_id, wallet_id, source_order_domain
ON delivery_shipments
FOR EACH ROW
EXECUTE FUNCTION assert_delivery_shipment_coherence();

CREATE TRIGGER trg_delivery_shipment_events_assert_coherence
BEFORE INSERT ON delivery_shipment_events
FOR EACH ROW
EXECUTE FUNCTION assert_delivery_shipment_event_coherence();

CREATE TRIGGER trg_delivery_shipment_events_prevent_update
BEFORE UPDATE ON delivery_shipment_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_delivery_shipment_events_prevent_delete
BEFORE DELETE ON delivery_shipment_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_mobility_trips_set_updated_at
BEFORE UPDATE ON mobility_trips
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_mobility_trips_assert_coherence
BEFORE INSERT OR UPDATE OF order_id, rider_user_id, passenger_user_id, wallet_id
ON mobility_trips
FOR EACH ROW
EXECUTE FUNCTION assert_mobility_trip_coherence();

CREATE TRIGGER trg_mobility_trip_events_assert_coherence
BEFORE INSERT ON mobility_trip_events
FOR EACH ROW
EXECUTE FUNCTION assert_mobility_trip_event_coherence();

CREATE TRIGGER trg_mobility_trip_events_prevent_update
BEFORE UPDATE ON mobility_trip_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_mobility_trip_events_prevent_delete
BEFORE DELETE ON mobility_trip_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_security_trusted_contacts_set_updated_at
BEFORE UPDATE ON security_trusted_contacts
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_security_biometric_credentials_set_updated_at
BEFORE UPDATE ON security_biometric_credentials
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_security_incidents_set_updated_at
BEFORE UPDATE ON security_incidents
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_security_incidents_assert_coherence
BEFORE INSERT OR UPDATE OF rider_user_id, order_id, trip_id, shipment_id
ON security_incidents
FOR EACH ROW
EXECUTE FUNCTION assert_security_incident_coherence();

CREATE TRIGGER trg_security_incident_events_assert_coherence
BEFORE INSERT ON security_incident_events
FOR EACH ROW
EXECUTE FUNCTION assert_security_incident_event_coherence();

CREATE TRIGGER trg_security_incident_events_prevent_update
BEFORE UPDATE ON security_incident_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_security_incident_events_prevent_delete
BEFORE DELETE ON security_incident_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

COMMENT ON TYPE delivery_shipment_kind_enum IS 'Tipo comercial da entrega urbana.';
COMMENT ON TYPE delivery_shipment_status_enum IS 'Status operacional mutavel do shipment.';
COMMENT ON TYPE delivery_event_type_enum IS 'Evento append-only da entrega.';
COMMENT ON TYPE mobility_trip_service_enum IS 'Servico comercial da corrida.';
COMMENT ON TYPE mobility_trip_status_enum IS 'Status mutavel da corrida Mobility.';
COMMENT ON TYPE mobility_checkpoint_type_enum IS 'Checkpoint append-only da corrida.';
COMMENT ON TYPE security_contact_kind_enum IS 'Tipo de contato confiavel para SOS.';
COMMENT ON TYPE biometric_credential_kind_enum IS 'Tipo de credencial biometrica persistida por hash.';
COMMENT ON TYPE biometric_credential_status_enum IS 'Status operacional da credencial biometrica.';
COMMENT ON TYPE security_incident_type_enum IS 'Natureza do incidente de seguranca.';
COMMENT ON TYPE security_incident_severity_enum IS 'Prioridade do incidente para resposta.';
COMMENT ON TYPE security_incident_status_enum IS 'Status mutavel do incidente de seguranca.';
COMMENT ON TYPE security_incident_event_type_enum IS 'Evento append-only do incidente.';

COMMENT ON TABLE delivery_shipments IS 'Contrato relacional de entregas urbanas integrado a orders, wallets e riders.';
COMMENT ON TABLE delivery_shipment_events IS 'Trilha append-only dos eventos da entrega.';
COMMENT ON TABLE mobility_trips IS 'Contrato relacional da corrida Mobility ligado ao order MOVE.';
COMMENT ON TABLE mobility_trip_events IS 'Checkpoints append-only da corrida para suporte e analytics.';
COMMENT ON TABLE security_trusted_contacts IS 'Contatos confiaveis usados por SOS e escalonamento.';
COMMENT ON TABLE security_biometric_credentials IS 'Credenciais biometricas persistidas somente por hash e metadados.';
COMMENT ON TABLE security_incidents IS 'Incidentes de seguranca ligados a trip, shipment, order, disputa ou geo.';
COMMENT ON TABLE security_incident_events IS 'Trilha append-only das acoes criticas de seguranca.';

COMMENT ON FUNCTION assert_city_ops_rider_user(UUID, TEXT) IS 'Valida se o usuario informado e rider valido com rider_profiles.';
COMMENT ON FUNCTION assert_delivery_shipment_coherence() IS 'Alinha shipment com order, wallet, merchant e rider.';
COMMENT ON FUNCTION assert_delivery_shipment_event_coherence() IS 'Impede evento de entrega apontando para order diferente do shipment.';
COMMENT ON FUNCTION assert_mobility_trip_coherence() IS 'Valida corrida MOVE contra order, wallet e rider.';
COMMENT ON FUNCTION assert_mobility_trip_event_coherence() IS 'Impede checkpoint apontando para order diferente do trip.';
COMMENT ON FUNCTION assert_security_incident_coherence() IS 'Preenche anchors tecnicos do incidente e valida rider associado.';
COMMENT ON FUNCTION assert_security_incident_event_coherence() IS 'Impede notificar contato de outro usuario em incidente alheio.';

COMMENT ON COLUMN delivery_shipments.shipment_id IS 'PK UUID da entrega.';
COMMENT ON COLUMN delivery_shipments.order_id IS 'FK para orders.order_id que originou a entrega.';
COMMENT ON COLUMN delivery_shipments.module_code IS 'FK para module_delivery_registry, normalmente DELIVERY ou modulo emissor.';
COMMENT ON COLUMN delivery_shipments.requester_user_id IS 'FK para users.user_id do solicitante principal.';
COMMENT ON COLUMN delivery_shipments.merchant_user_id IS 'FK opcional para merchant responsavel pela origem comercial.';
COMMENT ON COLUMN delivery_shipments.rider_user_id IS 'FK opcional para rider responsavel pela rota.';
COMMENT ON COLUMN delivery_shipments.wallet_id IS 'FK para wallet do solicitante usada no contexto financeiro da entrega.';
COMMENT ON COLUMN delivery_shipments.source_order_domain IS 'Dominio do order de origem: FOOD ou DROPSHIP.';
COMMENT ON COLUMN delivery_shipments.shipment_kind IS 'Tipo comercial da entrega.';
COMMENT ON COLUMN delivery_shipments.shipment_status IS 'Status mutavel do shipment.';
COMMENT ON COLUMN delivery_shipments.pickup_address_json IS 'Endereco estruturado de coleta.';
COMMENT ON COLUMN delivery_shipments.dropoff_address_json IS 'Endereco estruturado de entrega.';
COMMENT ON COLUMN delivery_shipments.pickup_contact_name IS 'Contato humano da coleta.';
COMMENT ON COLUMN delivery_shipments.pickup_contact_phone IS 'Telefone E.164 da coleta.';
COMMENT ON COLUMN delivery_shipments.receiver_contact_name IS 'Contato humano do recebimento.';
COMMENT ON COLUMN delivery_shipments.receiver_contact_phone IS 'Telefone E.164 do recebedor.';
COMMENT ON COLUMN delivery_shipments.package_count IS 'Quantidade de volumes da entrega.';
COMMENT ON COLUMN delivery_shipments.package_weight_kg IS 'Peso declarado em kg.';
COMMENT ON COLUMN delivery_shipments.declared_value_brl IS 'Valor declarado em BRL.';
COMMENT ON COLUMN delivery_shipments.delivery_fee_brl IS 'Taxa operacional da entrega em BRL.';
COMMENT ON COLUMN delivery_shipments.cash_to_collect_brl IS 'Valor em BRL que o rider precisa coletar no destino, quando aplicavel.';
COMMENT ON COLUMN delivery_shipments.route_distance_km IS 'Distancia planejada da rota em km.';
COMMENT ON COLUMN delivery_shipments.route_duration_sec IS 'Duracao planejada da rota em segundos.';
COMMENT ON COLUMN delivery_shipments.proof_code_hash IS 'Hash do codigo de confirmacao, nunca o codigo bruto.';
COMMENT ON COLUMN delivery_shipments.proof_document_id IS 'FK opcional para documento ou comprovante de entrega.';
COMMENT ON COLUMN delivery_shipments.dispatch_started_at IS 'Horario em que a busca por rider foi iniciada.';
COMMENT ON COLUMN delivery_shipments.assigned_at IS 'Horario em que o rider foi atribuido.';
COMMENT ON COLUMN delivery_shipments.picked_up_at IS 'Horario em que a coleta foi confirmada.';
COMMENT ON COLUMN delivery_shipments.delivered_at IS 'Horario da entrega concluida.';
COMMENT ON COLUMN delivery_shipments.failed_at IS 'Horario de falha operacional irrecuperavel.';
COMMENT ON COLUMN delivery_shipments.cancelled_at IS 'Horario do cancelamento.';
COMMENT ON COLUMN delivery_shipments.cancellation_reason IS 'Motivo textual do cancelamento.';
COMMENT ON COLUMN delivery_shipments.status_notes IS 'Observacoes operacionais resumidas.';
COMMENT ON COLUMN delivery_shipments.metadata_json IS 'Metadados tecnicos da entrega.';
COMMENT ON COLUMN delivery_shipments.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN delivery_shipments.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN delivery_shipment_events.shipment_event_id IS 'PK UUID do evento de entrega.';
COMMENT ON COLUMN delivery_shipment_events.shipment_id IS 'FK para delivery_shipments.';
COMMENT ON COLUMN delivery_shipment_events.order_id IS 'FK para orders.order_id coerente com o shipment.';
COMMENT ON COLUMN delivery_shipment_events.actor_user_id IS 'FK opcional para usuario ou rider que gerou o evento.';
COMMENT ON COLUMN delivery_shipment_events.event_type IS 'Tipo do evento append-only.';
COMMENT ON COLUMN delivery_shipment_events.shipment_status IS 'Status do shipment no momento do evento.';
COMMENT ON COLUMN delivery_shipment_events.geo_json IS 'GeoJSON opcional do checkpoint.';
COMMENT ON COLUMN delivery_shipment_events.notes IS 'Resumo humano do evento.';
COMMENT ON COLUMN delivery_shipment_events.correlation_id IS 'ID de correlacao com dispatch, telemetria ou trace.';
COMMENT ON COLUMN delivery_shipment_events.evidence_document_id IS 'FK opcional para evidencia documental.';
COMMENT ON COLUMN delivery_shipment_events.payload_json IS 'Payload tecnico do evento.';
COMMENT ON COLUMN delivery_shipment_events.occurred_at IS 'Horario append-only do evento.';

COMMENT ON COLUMN mobility_trips.trip_id IS 'PK UUID da corrida.';
COMMENT ON COLUMN mobility_trips.order_id IS 'FK unica para order MOVE que originou a corrida.';
COMMENT ON COLUMN mobility_trips.rider_user_id IS 'FK para users.user_id do rider.';
COMMENT ON COLUMN mobility_trips.passenger_user_id IS 'FK para users.user_id do passageiro.';
COMMENT ON COLUMN mobility_trips.wallet_id IS 'FK para wallet do passageiro usada no contexto financeiro da corrida.';
COMMENT ON COLUMN mobility_trips.module_code IS 'FK para module_delivery_registry, normalmente MOBILITY.';
COMMENT ON COLUMN mobility_trips.trip_service IS 'Tipo comercial do servico de mobilidade.';
COMMENT ON COLUMN mobility_trips.trip_status IS 'Status mutavel da corrida.';
COMMENT ON COLUMN mobility_trips.pickup_address_json IS 'Endereco de embarque em JSONB.';
COMMENT ON COLUMN mobility_trips.dropoff_address_json IS 'Endereco de destino em JSONB.';
COMMENT ON COLUMN mobility_trips.pickup_geo_json IS 'GeoJSON opcional da origem.';
COMMENT ON COLUMN mobility_trips.dropoff_geo_json IS 'GeoJSON opcional do destino.';
COMMENT ON COLUMN mobility_trips.estimated_distance_km IS 'Distancia estimada da corrida.';
COMMENT ON COLUMN mobility_trips.estimated_duration_sec IS 'Duracao estimada da corrida em segundos.';
COMMENT ON COLUMN mobility_trips.actual_distance_km IS 'Distancia real executada em km.';
COMMENT ON COLUMN mobility_trips.actual_duration_sec IS 'Duracao real executada em segundos.';
COMMENT ON COLUMN mobility_trips.estimated_fare_brl IS 'Tarifa estimada em BRL.';
COMMENT ON COLUMN mobility_trips.final_fare_brl IS 'Tarifa final em BRL.';
COMMENT ON COLUMN mobility_trips.surge_multiplier IS 'Multiplicador dinamico aplicado a tarifa.';
COMMENT ON COLUMN mobility_trips.passenger_count IS 'Numero de passageiros declarados.';
COMMENT ON COLUMN mobility_trips.shared_trip IS 'Flag que indica carpool ou compartilhamento.';
COMMENT ON COLUMN mobility_trips.safety_pin_hash IS 'Hash do safety PIN, nunca o PIN bruto.';
COMMENT ON COLUMN mobility_trips.started_at IS 'Horario de inicio real da corrida.';
COMMENT ON COLUMN mobility_trips.boarded_at IS 'Horario de embarque confirmado.';
COMMENT ON COLUMN mobility_trips.completed_at IS 'Horario de conclusao da corrida.';
COMMENT ON COLUMN mobility_trips.cancelled_at IS 'Horario de cancelamento.';
COMMENT ON COLUMN mobility_trips.cancellation_reason IS 'Motivo textual do cancelamento.';
COMMENT ON COLUMN mobility_trips.metadata_json IS 'Metadados tecnicos da corrida.';
COMMENT ON COLUMN mobility_trips.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN mobility_trips.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN mobility_trip_events.trip_event_id IS 'PK UUID do checkpoint.';
COMMENT ON COLUMN mobility_trip_events.trip_id IS 'FK para mobility_trips.';
COMMENT ON COLUMN mobility_trip_events.order_id IS 'FK para orders.order_id coerente com o trip.';
COMMENT ON COLUMN mobility_trip_events.actor_user_id IS 'FK opcional para passageiro, rider ou operador.';
COMMENT ON COLUMN mobility_trip_events.checkpoint_type IS 'Tipo do checkpoint append-only.';
COMMENT ON COLUMN mobility_trip_events.geo_json IS 'GeoJSON opcional do checkpoint.';
COMMENT ON COLUMN mobility_trip_events.speed_kph IS 'Velocidade registrada no checkpoint.';
COMMENT ON COLUMN mobility_trip_events.distance_since_last_km IS 'Distancia acumulada desde o ultimo checkpoint.';
COMMENT ON COLUMN mobility_trip_events.eta_seconds IS 'ETA em segundos informado no checkpoint.';
COMMENT ON COLUMN mobility_trip_events.notes IS 'Resumo humano do checkpoint.';
COMMENT ON COLUMN mobility_trip_events.payload_json IS 'Payload tecnico do checkpoint.';
COMMENT ON COLUMN mobility_trip_events.occurred_at IS 'Horario append-only do checkpoint.';

COMMENT ON COLUMN security_trusted_contacts.security_contact_id IS 'PK UUID do contato confiavel.';
COMMENT ON COLUMN security_trusted_contacts.user_id IS 'FK para users.user_id do dono do contato.';
COMMENT ON COLUMN security_trusted_contacts.contact_kind IS 'Papel do contato dentro da politica SOS.';
COMMENT ON COLUMN security_trusted_contacts.contact_name IS 'Nome do contato.';
COMMENT ON COLUMN security_trusted_contacts.relation_label IS 'Relacao do contato com o usuario.';
COMMENT ON COLUMN security_trusted_contacts.phone_e164 IS 'Telefone E.164 do contato.';
COMMENT ON COLUMN security_trusted_contacts.email IS 'Email do contato.';
COMMENT ON COLUMN security_trusted_contacts.priority IS 'Prioridade de acionamento, menor numero primeiro.';
COMMENT ON COLUMN security_trusted_contacts.notify_sms IS 'Flag para envio por SMS.';
COMMENT ON COLUMN security_trusted_contacts.notify_email IS 'Flag para envio por email.';
COMMENT ON COLUMN security_trusted_contacts.notify_push IS 'Flag para envio por push interno.';
COMMENT ON COLUMN security_trusted_contacts.is_active IS 'Flag que ativa ou desativa o contato.';
COMMENT ON COLUMN security_trusted_contacts.notes IS 'Observacoes internas sobre o contato.';
COMMENT ON COLUMN security_trusted_contacts.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN security_trusted_contacts.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN security_biometric_credentials.biometric_credential_id IS 'PK UUID da credencial biometrica.';
COMMENT ON COLUMN security_biometric_credentials.user_id IS 'FK para users.user_id do titular da credencial.';
COMMENT ON COLUMN security_biometric_credentials.credential_kind IS 'Tipo da biometria persistida por hash.';
COMMENT ON COLUMN security_biometric_credentials.credential_status IS 'Status operacional da credencial.';
COMMENT ON COLUMN security_biometric_credentials.provider_name IS 'Engine ou provider tecnico usado na biometria.';
COMMENT ON COLUMN security_biometric_credentials.template_hash IS 'Hash do template biometrico ou prova derivada.';
COMMENT ON COLUMN security_biometric_credentials.device_reference_hash IS 'Hash opcional do device ou sensor usado na captura.';
COMMENT ON COLUMN security_biometric_credentials.liveness_score IS 'Score de liveness entre 0 e 100.';
COMMENT ON COLUMN security_biometric_credentials.enrollment_document_id IS 'FK opcional para documento de onboarding ou prova.';
COMMENT ON COLUMN security_biometric_credentials.enrolled_at IS 'Horario do cadastro da credencial.';
COMMENT ON COLUMN security_biometric_credentials.verified_at IS 'Horario da ultima verificacao positiva.';
COMMENT ON COLUMN security_biometric_credentials.revoked_at IS 'Horario de revogacao.';
COMMENT ON COLUMN security_biometric_credentials.revocation_reason IS 'Motivo da revogacao.';
COMMENT ON COLUMN security_biometric_credentials.metadata_json IS 'Metadados tecnicos e politicas da credencial.';
COMMENT ON COLUMN security_biometric_credentials.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN security_biometric_credentials.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN security_incidents.security_incident_id IS 'PK UUID do incidente.';
COMMENT ON COLUMN security_incidents.module_code IS 'FK para module_delivery_registry do modulo que originou o caso.';
COMMENT ON COLUMN security_incidents.user_id IS 'FK para users.user_id do usuario impactado.';
COMMENT ON COLUMN security_incidents.reporter_user_id IS 'FK opcional para quem reportou o incidente.';
COMMENT ON COLUMN security_incidents.rider_user_id IS 'FK opcional para rider associado ao incidente.';
COMMENT ON COLUMN security_incidents.order_id IS 'FK opcional para order relacionado.';
COMMENT ON COLUMN security_incidents.trip_id IS 'FK opcional para mobility_trips.';
COMMENT ON COLUMN security_incidents.shipment_id IS 'FK opcional para delivery_shipments.';
COMMENT ON COLUMN security_incidents.legal_dispute_id IS 'FK opcional para disputa juridica correlata.';
COMMENT ON COLUMN security_incidents.incident_type IS 'Natureza do incidente.';
COMMENT ON COLUMN security_incidents.severity IS 'Severidade operacional do incidente.';
COMMENT ON COLUMN security_incidents.incident_status IS 'Status mutavel do caso.';
COMMENT ON COLUMN security_incidents.title IS 'Titulo curto do incidente.';
COMMENT ON COLUMN security_incidents.description IS 'Descricao resumida do incidente.';
COMMENT ON COLUMN security_incidents.address_json IS 'Endereco estruturado do evento, quando existir.';
COMMENT ON COLUMN security_incidents.geo_json IS 'GeoJSON opcional do incidente.';
COMMENT ON COLUMN security_incidents.correlation_id IS 'ID de correlacao com logs, dispatch, trace ou device.';
COMMENT ON COLUMN security_incidents.risk_score IS 'Score de risco de 0 a 100.';
COMMENT ON COLUMN security_incidents.evidence_document_id IS 'FK opcional para documento de evidencia.';
COMMENT ON COLUMN security_incidents.opened_at IS 'Horario de abertura do incidente.';
COMMENT ON COLUMN security_incidents.acknowledged_at IS 'Horario do primeiro ack operacional.';
COMMENT ON COLUMN security_incidents.escalation_deadline_at IS 'Prazo maximo para escalonamento.';
COMMENT ON COLUMN security_incidents.resolved_at IS 'Horario de resolucao.';
COMMENT ON COLUMN security_incidents.resolution_summary IS 'Resumo textual da resolucao.';
COMMENT ON COLUMN security_incidents.metadata_json IS 'Metadados tecnicos e operacionais do caso.';
COMMENT ON COLUMN security_incidents.created_at IS 'Criacao do registro.';
COMMENT ON COLUMN security_incidents.updated_at IS 'Ultima atualizacao do registro.';

COMMENT ON COLUMN security_incident_events.security_incident_event_id IS 'PK UUID do evento do incidente.';
COMMENT ON COLUMN security_incident_events.security_incident_id IS 'FK para security_incidents.';
COMMENT ON COLUMN security_incident_events.actor_user_id IS 'FK opcional para usuario, rider, admin ou system actor.';
COMMENT ON COLUMN security_incident_events.event_type IS 'Tipo do evento append-only.';
COMMENT ON COLUMN security_incident_events.incident_status IS 'Status do incidente no momento do evento.';
COMMENT ON COLUMN security_incident_events.notified_contact_id IS 'FK opcional para contato acionado.';
COMMENT ON COLUMN security_incident_events.document_id IS 'FK opcional para evidencia documental anexada.';
COMMENT ON COLUMN security_incident_events.notes IS 'Resumo humano do evento.';
COMMENT ON COLUMN security_incident_events.payload_json IS 'Payload tecnico do evento.';
COMMENT ON COLUMN security_incident_events.occurred_at IS 'Horario append-only do evento.';

COMMENT ON TRIGGER trg_delivery_shipments_set_updated_at ON delivery_shipments IS 'Atualiza delivery_shipments.updated_at antes de updates.';
COMMENT ON TRIGGER trg_delivery_shipments_assert_coherence ON delivery_shipments IS 'Valida alinhamento do shipment com order, wallet, merchant e rider.';
COMMENT ON TRIGGER trg_delivery_shipment_events_assert_coherence ON delivery_shipment_events IS 'Valida que o evento usa o mesmo order do shipment.';
COMMENT ON TRIGGER trg_delivery_shipment_events_prevent_update ON delivery_shipment_events IS 'Impede UPDATE na trilha append-only de entrega.';
COMMENT ON TRIGGER trg_delivery_shipment_events_prevent_delete ON delivery_shipment_events IS 'Impede DELETE na trilha append-only de entrega.';
COMMENT ON TRIGGER trg_mobility_trips_set_updated_at ON mobility_trips IS 'Atualiza mobility_trips.updated_at antes de updates.';
COMMENT ON TRIGGER trg_mobility_trips_assert_coherence ON mobility_trips IS 'Valida order MOVE, wallet e rider da corrida.';
COMMENT ON TRIGGER trg_mobility_trip_events_assert_coherence ON mobility_trip_events IS 'Valida que o checkpoint usa o mesmo order do trip.';
COMMENT ON TRIGGER trg_mobility_trip_events_prevent_update ON mobility_trip_events IS 'Impede UPDATE na trilha append-only da corrida.';
COMMENT ON TRIGGER trg_mobility_trip_events_prevent_delete ON mobility_trip_events IS 'Impede DELETE na trilha append-only da corrida.';
COMMENT ON TRIGGER trg_security_trusted_contacts_set_updated_at ON security_trusted_contacts IS 'Atualiza security_trusted_contacts.updated_at antes de updates.';
COMMENT ON TRIGGER trg_security_biometric_credentials_set_updated_at ON security_biometric_credentials IS 'Atualiza security_biometric_credentials.updated_at antes de updates.';
COMMENT ON TRIGGER trg_security_incidents_set_updated_at ON security_incidents IS 'Atualiza security_incidents.updated_at antes de updates.';
COMMENT ON TRIGGER trg_security_incidents_assert_coherence ON security_incidents IS 'Preenche e valida anchors tecnicos do incidente.';
COMMENT ON TRIGGER trg_security_incident_events_assert_coherence ON security_incident_events IS 'Impede evento de seguranca notificar contato de outro usuario.';
COMMENT ON TRIGGER trg_security_incident_events_prevent_update ON security_incident_events IS 'Impede UPDATE na trilha append-only de seguranca.';
COMMENT ON TRIGGER trg_security_incident_events_prevent_delete ON security_incident_events IS 'Impede DELETE na trilha append-only de seguranca.';

COMMIT;
