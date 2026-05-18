-- Valley Rider Realtime Operations
-- Escopo exclusivo: aplicativo de logistica e entregadores Valley Rider.
-- Objetivo: suportar presenca operacional, GPS em tempo real, rota, ofertas,
-- auditoria de aceite/finalizacao e OTA sem expor custos internos ao front Rider.

BEGIN;

SET search_path = public;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rider_presence_status_enum') THEN
        CREATE TYPE rider_presence_status_enum AS ENUM ('OFFLINE', 'ONLINE', 'BUSY', 'PAUSED', 'SOS');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rider_realtime_transport_enum') THEN
        CREATE TYPE rider_realtime_transport_enum AS ENUM ('WEBSOCKET', 'POLLING', 'PUSH_FALLBACK');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rider_offer_status_enum') THEN
        CREATE TYPE rider_offer_status_enum AS ENUM ('OFFERED', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'CANCELLED');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rider_route_point_kind_enum') THEN
        CREATE TYPE rider_route_point_kind_enum AS ENUM ('CURRENT', 'PICKUP', 'DROPOFF', 'CHECKPOINT', 'DETOUR', 'SOS');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rider_ota_patch_status_enum') THEN
        CREATE TYPE rider_ota_patch_status_enum AS ENUM ('AVAILABLE', 'DOWNLOADING', 'READY_NEXT_RESTART', 'APPLIED', 'FAILED', 'ROLLED_BACK');
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS rider_realtime_sessions (
    rider_realtime_session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_user_id UUID NOT NULL,
    device_id_hash TEXT NOT NULL,
    presence_status rider_presence_status_enum NOT NULL DEFAULT 'OFFLINE',
    transport rider_realtime_transport_enum NOT NULL DEFAULT 'WEBSOCKET',
    app_version TEXT NOT NULL,
    ota_channel TEXT NOT NULL DEFAULT 'stable',
    service_zone_code TEXT,
    last_latitude DECIMAL(10,7),
    last_longitude DECIMAL(10,7),
    last_accuracy_m DECIMAL(10,3),
    last_heading_deg DECIMAL(7,3),
    last_speed_kph DECIMAL(10,3),
    last_ping_at TIMESTAMPTZ,
    connected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    disconnected_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_rider_realtime_sessions_user
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_rider_realtime_sessions_device_hash CHECK (device_id_hash ~ '^[a-fA-F0-9]{64,128}$'),
    CONSTRAINT chk_rider_realtime_sessions_app_version CHECK (btrim(app_version) <> ''),
    CONSTRAINT chk_rider_realtime_sessions_ota_channel CHECK (btrim(ota_channel) <> ''),
    CONSTRAINT chk_rider_realtime_sessions_lat CHECK (last_latitude IS NULL OR last_latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_rider_realtime_sessions_lng CHECK (last_longitude IS NULL OR last_longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_rider_realtime_sessions_accuracy CHECK (last_accuracy_m IS NULL OR last_accuracy_m >= 0),
    CONSTRAINT chk_rider_realtime_sessions_heading CHECK (last_heading_deg IS NULL OR last_heading_deg BETWEEN 0 AND 360),
    CONSTRAINT chk_rider_realtime_sessions_speed CHECK (last_speed_kph IS NULL OR last_speed_kph >= 0),
    CONSTRAINT chk_rider_realtime_sessions_metadata CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_rider_realtime_sessions_timeline CHECK (disconnected_at IS NULL OR disconnected_at >= connected_at)
);

CREATE TABLE IF NOT EXISTS rider_location_pings (
    rider_location_ping_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_realtime_session_id UUID NOT NULL,
    rider_user_id UUID NOT NULL,
    shipment_id UUID,
    trip_id UUID,
    route_point_kind rider_route_point_kind_enum NOT NULL DEFAULT 'CURRENT',
    latitude DECIMAL(10,7) NOT NULL,
    longitude DECIMAL(10,7) NOT NULL,
    accuracy_m DECIMAL(10,3),
    heading_deg DECIMAL(7,3),
    speed_kph DECIMAL(10,3),
    battery_level SMALLINT,
    network_type TEXT,
    is_mocked_location BOOLEAN NOT NULL DEFAULT FALSE,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_rider_location_pings_session
        FOREIGN KEY (rider_realtime_session_id) REFERENCES rider_realtime_sessions (rider_realtime_session_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rider_location_pings_user
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rider_location_pings_shipment
        FOREIGN KEY (shipment_id) REFERENCES delivery_shipments (shipment_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rider_location_pings_trip
        FOREIGN KEY (trip_id) REFERENCES mobility_trips (trip_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_rider_location_pings_lat CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_rider_location_pings_lng CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_rider_location_pings_accuracy CHECK (accuracy_m IS NULL OR accuracy_m >= 0),
    CONSTRAINT chk_rider_location_pings_heading CHECK (heading_deg IS NULL OR heading_deg BETWEEN 0 AND 360),
    CONSTRAINT chk_rider_location_pings_speed CHECK (speed_kph IS NULL OR speed_kph >= 0),
    CONSTRAINT chk_rider_location_pings_battery CHECK (battery_level IS NULL OR battery_level BETWEEN 0 AND 100),
    CONSTRAINT chk_rider_location_pings_payload CHECK (jsonb_typeof(payload_json) = 'object')
);

CREATE TABLE IF NOT EXISTS rider_route_snapshots (
    rider_route_snapshot_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_user_id UUID NOT NULL,
    shipment_id UUID,
    trip_id UUID,
    route_polyline TEXT NOT NULL,
    pickup_latitude DECIMAL(10,7),
    pickup_longitude DECIMAL(10,7),
    dropoff_latitude DECIMAL(10,7),
    dropoff_longitude DECIMAL(10,7),
    distance_km DECIMAL(12,3) NOT NULL DEFAULT 0,
    duration_sec INTEGER NOT NULL DEFAULT 0,
    navigation_provider TEXT NOT NULL DEFAULT 'GOOGLE_MAPS',
    external_navigation_uri TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_rider_route_snapshots_user
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rider_route_snapshots_shipment
        FOREIGN KEY (shipment_id) REFERENCES delivery_shipments (shipment_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rider_route_snapshots_trip
        FOREIGN KEY (trip_id) REFERENCES mobility_trips (trip_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_rider_route_snapshots_anchor CHECK (shipment_id IS NOT NULL OR trip_id IS NOT NULL),
    CONSTRAINT chk_rider_route_snapshots_polyline CHECK (btrim(route_polyline) <> ''),
    CONSTRAINT chk_rider_route_snapshots_pickup_lat CHECK (pickup_latitude IS NULL OR pickup_latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_rider_route_snapshots_pickup_lng CHECK (pickup_longitude IS NULL OR pickup_longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_rider_route_snapshots_dropoff_lat CHECK (dropoff_latitude IS NULL OR dropoff_latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_rider_route_snapshots_dropoff_lng CHECK (dropoff_longitude IS NULL OR dropoff_longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_rider_route_snapshots_metrics CHECK (distance_km >= 0 AND duration_sec >= 0),
    CONSTRAINT chk_rider_route_snapshots_provider CHECK (navigation_provider IN ('GOOGLE_MAPS', 'WAZE', 'INTERNAL')),
    CONSTRAINT chk_rider_route_snapshots_uri CHECK (external_navigation_uri IS NULL OR external_navigation_uri ~ '^https?://'),
    CONSTRAINT chk_rider_route_snapshots_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS rider_delivery_offers (
    rider_delivery_offer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_user_id UUID NOT NULL,
    shipment_id UUID,
    trip_id UUID,
    offer_status rider_offer_status_enum NOT NULL DEFAULT 'OFFERED',
    rider_payout_brl DECIMAL(18,4) NOT NULL,
    estimated_distance_km DECIMAL(12,3) NOT NULL DEFAULT 0,
    estimated_duration_sec INTEGER NOT NULL DEFAULT 0,
    pickup_label TEXT NOT NULL,
    dropoff_label TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    responded_at TIMESTAMPTZ,
    rejection_reason TEXT,
    correlation_id TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_rider_delivery_offers_user
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rider_delivery_offers_shipment
        FOREIGN KEY (shipment_id) REFERENCES delivery_shipments (shipment_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_rider_delivery_offers_trip
        FOREIGN KEY (trip_id) REFERENCES mobility_trips (trip_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_rider_delivery_offers_anchor CHECK (shipment_id IS NOT NULL OR trip_id IS NOT NULL),
    CONSTRAINT chk_rider_delivery_offers_payout CHECK (rider_payout_brl >= 0),
    CONSTRAINT chk_rider_delivery_offers_metrics CHECK (estimated_distance_km >= 0 AND estimated_duration_sec >= 0),
    CONSTRAINT chk_rider_delivery_offers_labels CHECK (btrim(pickup_label) <> '' AND btrim(dropoff_label) <> ''),
    CONSTRAINT chk_rider_delivery_offers_expiration CHECK (expires_at > created_at),
    CONSTRAINT chk_rider_delivery_offers_response CHECK (responded_at IS NULL OR responded_at >= created_at),
    CONSTRAINT chk_rider_delivery_offers_rejection CHECK (rejection_reason IS NULL OR btrim(rejection_reason) <> ''),
    CONSTRAINT chk_rider_delivery_offers_correlation CHECK (correlation_id IS NULL OR btrim(correlation_id) <> ''),
    CONSTRAINT chk_rider_delivery_offers_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS rider_ota_patch_state (
    rider_ota_patch_state_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_user_id UUID NOT NULL,
    device_id_hash TEXT NOT NULL,
    app_version TEXT NOT NULL,
    patch_version TEXT NOT NULL,
    ota_channel TEXT NOT NULL DEFAULT 'stable',
    patch_status rider_ota_patch_status_enum NOT NULL DEFAULT 'AVAILABLE',
    download_url TEXT,
    checksum_sha256 TEXT,
    applied_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    failure_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_rider_ota_patch_state_user
        FOREIGN KEY (rider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_rider_ota_patch_state_device_hash CHECK (device_id_hash ~ '^[a-fA-F0-9]{64,128}$'),
    CONSTRAINT chk_rider_ota_patch_state_app_version CHECK (btrim(app_version) <> ''),
    CONSTRAINT chk_rider_ota_patch_state_patch_version CHECK (btrim(patch_version) <> ''),
    CONSTRAINT chk_rider_ota_patch_state_channel CHECK (btrim(ota_channel) <> ''),
    CONSTRAINT chk_rider_ota_patch_state_download_url CHECK (download_url IS NULL OR download_url ~ '^https?://'),
    CONSTRAINT chk_rider_ota_patch_state_checksum CHECK (checksum_sha256 IS NULL OR checksum_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_rider_ota_patch_state_failure_reason CHECK (failure_reason IS NULL OR btrim(failure_reason) <> ''),
    CONSTRAINT chk_rider_ota_patch_state_metadata CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_rider_realtime_sessions_user_status
    ON rider_realtime_sessions (rider_user_id, presence_status, updated_at DESC);

CREATE INDEX IF NOT EXISTS ix_rider_location_pings_user_time
    ON rider_location_pings (rider_user_id, occurred_at DESC);

CREATE INDEX IF NOT EXISTS ix_rider_location_pings_shipment_time
    ON rider_location_pings (shipment_id, occurred_at DESC)
    WHERE shipment_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_rider_location_pings_trip_time
    ON rider_location_pings (trip_id, occurred_at DESC)
    WHERE trip_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_rider_delivery_offers_user_status
    ON rider_delivery_offers (rider_user_id, offer_status, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_rider_delivery_offers_active
    ON rider_delivery_offers (expires_at, created_at DESC)
    WHERE offer_status = 'OFFERED';

CREATE INDEX IF NOT EXISTS ix_rider_ota_patch_state_device_status
    ON rider_ota_patch_state (device_id_hash, patch_status, created_at DESC);

DROP TRIGGER IF EXISTS trg_rider_realtime_sessions_set_updated_at ON rider_realtime_sessions;
CREATE TRIGGER trg_rider_realtime_sessions_set_updated_at
BEFORE UPDATE ON rider_realtime_sessions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_rider_delivery_offers_set_updated_at ON rider_delivery_offers;
CREATE TRIGGER trg_rider_delivery_offers_set_updated_at
BEFORE UPDATE ON rider_delivery_offers
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_rider_ota_patch_state_set_updated_at ON rider_ota_patch_state;
CREATE TRIGGER trg_rider_ota_patch_state_set_updated_at
BEFORE UPDATE ON rider_ota_patch_state
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_rider_location_pings_prevent_update ON rider_location_pings;
CREATE TRIGGER trg_rider_location_pings_prevent_update
BEFORE UPDATE ON rider_location_pings
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_rider_location_pings_prevent_delete ON rider_location_pings;
CREATE TRIGGER trg_rider_location_pings_prevent_delete
BEFORE DELETE ON rider_location_pings
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_rider_route_snapshots_prevent_update ON rider_route_snapshots;
CREATE TRIGGER trg_rider_route_snapshots_prevent_update
BEFORE UPDATE ON rider_route_snapshots
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

DROP TRIGGER IF EXISTS trg_rider_route_snapshots_prevent_delete ON rider_route_snapshots;
CREATE TRIGGER trg_rider_route_snapshots_prevent_delete
BEFORE DELETE ON rider_route_snapshots
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE OR REPLACE VIEW rider_frontend_offer_view AS
SELECT
    rider_delivery_offer_id,
    rider_user_id,
    shipment_id,
    trip_id,
    offer_status,
    rider_payout_brl,
    estimated_distance_km,
    estimated_duration_sec,
    pickup_label,
    dropoff_label,
    expires_at,
    responded_at,
    correlation_id,
    created_at,
    updated_at
FROM rider_delivery_offers;

COMMENT ON VIEW rider_frontend_offer_view IS
    'BR-PRO-001: view segura do Rider. Expoe somente rider_payout_brl e oculta taxas, margem, custos operacionais e valores internos da plataforma.';

COMMENT ON TABLE rider_realtime_sessions IS 'Sessao operacional do Rider para presenca, transporte realtime, app version e ultimo ping.';
COMMENT ON TABLE rider_location_pings IS 'Pings GPS append-only do Rider para tracking em tempo real e auditoria de rota.';
COMMENT ON TABLE rider_route_snapshots IS 'Snapshots de rota com polyline, pontos de coleta/entrega e deep link externo.';
COMMENT ON TABLE rider_delivery_offers IS 'Ofertas de entrega/corrida para Rider; o front deve consumir somente rider_frontend_offer_view.';
COMMENT ON TABLE rider_ota_patch_state IS 'Estado de patches OTA/Code Push por dispositivo Rider.';

COMMIT;
