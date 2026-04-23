-- Valley Hybrid DB Bootstrap - Mobility production schema v47.
-- Este arquivo cria a camada relacional de planejamento Mobility sem misturar
-- buffer de rota e benchmark de custo com a execucao consolidada em mobility_trips.

BEGIN;

SET search_path = public, mobility;

CREATE SCHEMA IF NOT EXISTS mobility;

COMMENT ON SCHEMA mobility IS
    'Schema relacional de producao para planejamento Mobility: benchmark, rotas de usuario e buffer realtime.';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_type type_row
          JOIN pg_namespace namespace_row
            ON namespace_row.oid = type_row.typnamespace
         WHERE namespace_row.nspname = 'mobility'
           AND type_row.typname = 'cost_benchmark_status_enum'
    ) THEN
        CREATE TYPE mobility.cost_benchmark_status_enum AS ENUM (
            'ACTIVE',
            'STALE',
            'EXPIRED',
            'ARCHIVED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_type type_row
          JOIN pg_namespace namespace_row
            ON namespace_row.oid = type_row.typnamespace
         WHERE namespace_row.nspname = 'mobility'
           AND type_row.typname = 'route_status_enum'
    ) THEN
        CREATE TYPE mobility.route_status_enum AS ENUM (
            'PLANNED',
            'OFFERED',
            'ACCEPTED',
            'IN_PROGRESS',
            'COMPLETED',
            'CANCELLED',
            'EXPIRED'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_type type_row
          JOIN pg_namespace namespace_row
            ON namespace_row.oid = type_row.typnamespace
         WHERE namespace_row.nspname = 'mobility'
           AND type_row.typname = 'route_kind_enum'
    ) THEN
        CREATE TYPE mobility.route_kind_enum AS ENUM (
            'URBAN_RIDE',
            'CARPOOL',
            'MULTIMODAL',
            'ACCESSIBLE',
            'TOURISM',
            'DELIVERY_SUPPORT'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_type type_row
          JOIN pg_namespace namespace_row
            ON namespace_row.oid = type_row.typnamespace
         WHERE namespace_row.nspname = 'mobility'
           AND type_row.typname = 'realtime_subject_role_enum'
    ) THEN
        CREATE TYPE mobility.realtime_subject_role_enum AS ENUM (
            'PASSENGER',
            'RIDER',
            'VEHICLE',
            'DEVICE',
            'OPERATIONS'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_type type_row
          JOIN pg_namespace namespace_row
            ON namespace_row.oid = type_row.typnamespace
         WHERE namespace_row.nspname = 'mobility'
           AND type_row.typname = 'realtime_source_kind_enum'
    ) THEN
        CREATE TYPE mobility.realtime_source_kind_enum AS ENUM (
            'APP',
            'DRIVER_APP',
            'GPS',
            'PARTNER_API',
            'IOT',
            'SECURITY'
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_type type_row
          JOIN pg_namespace namespace_row
            ON namespace_row.oid = type_row.typnamespace
         WHERE namespace_row.nspname = 'mobility'
           AND type_row.typname = 'realtime_buffer_status_enum'
    ) THEN
        CREATE TYPE mobility.realtime_buffer_status_enum AS ENUM (
            'ACTIVE',
            'STALE',
            'EXPIRED',
            'SUPPRESSED'
        );
    END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS mobility.cost_benchmarks (
    benchmark_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'MOBILITY',
    route_fingerprint TEXT NOT NULL,
    region_code TEXT NOT NULL,
    benchmark_status mobility.cost_benchmark_status_enum NOT NULL DEFAULT 'ACTIVE',
    observed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    origin_geo_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    destination_geo_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    estimated_distance_km DECIMAL(12,3),
    estimated_duration_sec INTEGER,
    valley_estimated_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    valley_max_accepted_brl DECIMAL(18,4),
    competitor_lowest_brl DECIMAL(18,4),
    competitor_median_brl DECIMAL(18,4),
    competitor_highest_brl DECIMAL(18,4),
    provider_quotes_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    selected_provider TEXT,
    notes TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_mobility_cost_benchmarks_user
        FOREIGN KEY (user_id) REFERENCES public.users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_cost_benchmarks_module
        FOREIGN KEY (module_code) REFERENCES public.module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_mobility_cost_benchmarks_route_fingerprint
        CHECK (btrim(route_fingerprint) <> ''),
    CONSTRAINT chk_mobility_cost_benchmarks_region
        CHECK (btrim(region_code) <> ''),
    CONSTRAINT chk_mobility_cost_benchmarks_timeline
        CHECK (expires_at > observed_at),
    CONSTRAINT chk_mobility_cost_benchmarks_geo
        CHECK (
            jsonb_typeof(origin_geo_json) = 'object'
            AND jsonb_typeof(destination_geo_json) = 'object'
        ),
    CONSTRAINT chk_mobility_cost_benchmarks_metrics
        CHECK (
            (estimated_distance_km IS NULL OR estimated_distance_km >= 0)
            AND (estimated_duration_sec IS NULL OR estimated_duration_sec >= 0)
        ),
    CONSTRAINT chk_mobility_cost_benchmarks_prices
        CHECK (
            valley_estimated_brl >= 0
            AND (valley_max_accepted_brl IS NULL OR valley_max_accepted_brl >= valley_estimated_brl)
            AND (competitor_lowest_brl IS NULL OR competitor_lowest_brl >= 0)
            AND (competitor_median_brl IS NULL OR competitor_median_brl >= 0)
            AND (competitor_highest_brl IS NULL OR competitor_highest_brl >= 0)
            AND (
                competitor_lowest_brl IS NULL
                OR competitor_median_brl IS NULL
                OR competitor_lowest_brl <= competitor_median_brl
            )
            AND (
                competitor_median_brl IS NULL
                OR competitor_highest_brl IS NULL
                OR competitor_median_brl <= competitor_highest_brl
            )
        ),
    CONSTRAINT chk_mobility_cost_benchmarks_provider_quotes
        CHECK (jsonb_typeof(provider_quotes_json) = 'array'),
    CONSTRAINT chk_mobility_cost_benchmarks_selected_provider
        CHECK (selected_provider IS NULL OR btrim(selected_provider) <> ''),
    CONSTRAINT chk_mobility_cost_benchmarks_notes
        CHECK (notes IS NULL OR btrim(notes) <> ''),
    CONSTRAINT chk_mobility_cost_benchmarks_metadata
        CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE TABLE IF NOT EXISTS mobility.user_routes (
    route_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    wallet_id UUID,
    module_code TEXT NOT NULL DEFAULT 'MOBILITY',
    order_id UUID,
    trip_id UUID,
    benchmark_id UUID,
    route_status mobility.route_status_enum NOT NULL DEFAULT 'PLANNED',
    route_kind mobility.route_kind_enum NOT NULL DEFAULT 'URBAN_RIDE',
    route_fingerprint TEXT NOT NULL,
    origin_label TEXT,
    destination_label TEXT,
    origin_geo_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    destination_geo_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    waypoints_json JSONB NOT NULL DEFAULT '[]'::JSONB,
    requested_modes TEXT[] NOT NULL DEFAULT ARRAY['MOBILITY']::TEXT[],
    selected_mode TEXT,
    selected_provider TEXT,
    planned_for TIMESTAMPTZ,
    estimate_expires_at TIMESTAMPTZ,
    estimated_distance_km DECIMAL(12,3),
    estimated_duration_sec INTEGER,
    estimated_cost_brl DECIMAL(18,4),
    carbon_estimate_kg DECIMAL(12,6),
    accessibility_flags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    safety_context_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    pricing_snapshot_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    routing_engine TEXT NOT NULL DEFAULT 'VALLEY_ROUTER',
    trace_id TEXT,
    accepted_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_mobility_user_routes_user
        FOREIGN KEY (user_id) REFERENCES public.users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_user_routes_wallet
        FOREIGN KEY (wallet_id) REFERENCES public.wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_user_routes_module
        FOREIGN KEY (module_code) REFERENCES public.module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_user_routes_order
        FOREIGN KEY (order_id) REFERENCES public.orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_user_routes_trip
        FOREIGN KEY (trip_id) REFERENCES public.mobility_trips (trip_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_user_routes_benchmark
        FOREIGN KEY (benchmark_id) REFERENCES mobility.cost_benchmarks (benchmark_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_mobility_user_routes_fingerprint
        CHECK (btrim(route_fingerprint) <> ''),
    CONSTRAINT chk_mobility_user_routes_labels
        CHECK (
            (origin_label IS NULL OR btrim(origin_label) <> '')
            AND (destination_label IS NULL OR btrim(destination_label) <> '')
        ),
    CONSTRAINT chk_mobility_user_routes_geo
        CHECK (
            jsonb_typeof(origin_geo_json) = 'object'
            AND jsonb_typeof(destination_geo_json) = 'object'
            AND jsonb_typeof(waypoints_json) = 'array'
        ),
    CONSTRAINT chk_mobility_user_routes_requested_modes
        CHECK (COALESCE(array_length(requested_modes, 1), 0) > 0),
    CONSTRAINT chk_mobility_user_routes_selected_values
        CHECK (
            (selected_mode IS NULL OR btrim(selected_mode) <> '')
            AND (selected_provider IS NULL OR btrim(selected_provider) <> '')
            AND btrim(routing_engine) <> ''
            AND (trace_id IS NULL OR btrim(trace_id) <> '')
        ),
    CONSTRAINT chk_mobility_user_routes_estimate_window
        CHECK (
            estimate_expires_at IS NULL
            OR estimate_expires_at > created_at
        ),
    CONSTRAINT chk_mobility_user_routes_metrics
        CHECK (
            (estimated_distance_km IS NULL OR estimated_distance_km >= 0)
            AND (estimated_duration_sec IS NULL OR estimated_duration_sec >= 0)
            AND (estimated_cost_brl IS NULL OR estimated_cost_brl >= 0)
            AND (carbon_estimate_kg IS NULL OR carbon_estimate_kg >= 0)
        ),
    CONSTRAINT chk_mobility_user_routes_context_json
        CHECK (
            jsonb_typeof(safety_context_json) = 'object'
            AND jsonb_typeof(pricing_snapshot_json) = 'object'
            AND jsonb_typeof(metadata_json) = 'object'
        ),
    CONSTRAINT chk_mobility_user_routes_timeline
        CHECK (
            (started_at IS NULL OR accepted_at IS NULL OR started_at >= accepted_at)
            AND (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at)
            AND (cancelled_at IS NULL OR accepted_at IS NULL OR cancelled_at >= accepted_at)
        ),
    CONSTRAINT chk_mobility_user_routes_status_dates
        CHECK (
            (route_status <> 'ACCEPTED' OR accepted_at IS NOT NULL)
            AND (route_status <> 'IN_PROGRESS' OR started_at IS NOT NULL)
            AND (route_status <> 'COMPLETED' OR completed_at IS NOT NULL)
            AND (route_status <> 'CANCELLED' OR cancelled_at IS NOT NULL)
        ),
    CONSTRAINT chk_mobility_user_routes_cancellation_reason
        CHECK (cancellation_reason IS NULL OR btrim(cancellation_reason) <> '')
);

CREATE TABLE IF NOT EXISTS mobility.realtime_buffer (
    buffer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'MOBILITY',
    route_id UUID,
    order_id UUID,
    trip_id UUID,
    subject_role mobility.realtime_subject_role_enum NOT NULL DEFAULT 'PASSENGER',
    source_kind mobility.realtime_source_kind_enum NOT NULL DEFAULT 'APP',
    buffer_status mobility.realtime_buffer_status_enum NOT NULL DEFAULT 'ACTIVE',
    source_reference TEXT,
    geo_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    heading_degrees DECIMAL(6,2),
    speed_kph DECIMAL(10,3),
    accuracy_meters DECIMAL(10,3),
    battery_level DECIMAL(5,2),
    network_quality TEXT,
    eta_seconds INTEGER,
    distance_remaining_km DECIMAL(12,3),
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '5 minutes'),
    trace_id TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_mobility_realtime_buffer_user
        FOREIGN KEY (user_id) REFERENCES public.users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_realtime_buffer_module
        FOREIGN KEY (module_code) REFERENCES public.module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_realtime_buffer_route
        FOREIGN KEY (route_id) REFERENCES mobility.user_routes (route_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_realtime_buffer_order
        FOREIGN KEY (order_id) REFERENCES public.orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_mobility_realtime_buffer_trip
        FOREIGN KEY (trip_id) REFERENCES public.mobility_trips (trip_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_mobility_realtime_buffer_source_reference
        CHECK (source_reference IS NULL OR btrim(source_reference) <> ''),
    CONSTRAINT chk_mobility_realtime_buffer_geo
        CHECK (jsonb_typeof(geo_json) = 'object'),
    CONSTRAINT chk_mobility_realtime_buffer_metrics
        CHECK (
            (heading_degrees IS NULL OR (heading_degrees >= 0 AND heading_degrees <= 360))
            AND (speed_kph IS NULL OR speed_kph >= 0)
            AND (accuracy_meters IS NULL OR accuracy_meters >= 0)
            AND (battery_level IS NULL OR (battery_level >= 0 AND battery_level <= 100))
            AND (eta_seconds IS NULL OR eta_seconds >= 0)
            AND (distance_remaining_km IS NULL OR distance_remaining_km >= 0)
        ),
    CONSTRAINT chk_mobility_realtime_buffer_text
        CHECK (
            (network_quality IS NULL OR btrim(network_quality) <> '')
            AND (trace_id IS NULL OR btrim(trace_id) <> '')
        ),
    CONSTRAINT chk_mobility_realtime_buffer_window
        CHECK (
            received_at >= captured_at
            AND expires_at > captured_at
        ),
    CONSTRAINT chk_mobility_realtime_buffer_metadata
        CHECK (jsonb_typeof(metadata_json) = 'object')
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_mobility_cost_benchmarks_active_route_region
    ON mobility.cost_benchmarks (user_id, route_fingerprint, region_code)
    WHERE benchmark_status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS ix_mobility_cost_benchmarks_user_observed
    ON mobility.cost_benchmarks (user_id, observed_at DESC);

CREATE INDEX IF NOT EXISTS ix_mobility_cost_benchmarks_region_status
    ON mobility.cost_benchmarks (region_code, benchmark_status, expires_at);

CREATE INDEX IF NOT EXISTS ix_mobility_user_routes_user_status
    ON mobility.user_routes (user_id, route_status, planned_for DESC);

CREATE INDEX IF NOT EXISTS ix_mobility_user_routes_trip
    ON mobility.user_routes (trip_id)
    WHERE trip_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_mobility_user_routes_benchmark
    ON mobility.user_routes (benchmark_id)
    WHERE benchmark_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_mobility_realtime_buffer_user_active
    ON mobility.realtime_buffer (user_id, buffer_status, captured_at DESC)
    WHERE buffer_status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS ix_mobility_realtime_buffer_route_time
    ON mobility.realtime_buffer (route_id, captured_at DESC)
    WHERE route_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_mobility_realtime_buffer_trip_time
    ON mobility.realtime_buffer (trip_id, captured_at DESC)
    WHERE trip_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_mobility_realtime_buffer_expires
    ON mobility.realtime_buffer (expires_at)
    WHERE buffer_status IN ('ACTIVE', 'STALE');

CREATE OR REPLACE FUNCTION mobility.assert_user_route_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    route_wallet_user_id UUID;
    route_order_user_id UUID;
    route_order_wallet_id UUID;
    route_order_domain public.order_domain_enum;
    route_trip_user_id UUID;
    route_trip_order_id UUID;
    route_trip_wallet_id UUID;
    benchmark_user_id UUID;
    benchmark_route_fingerprint TEXT;
BEGIN
    IF NEW.trip_id IS NOT NULL THEN
        SELECT passenger_user_id, order_id, wallet_id
          INTO route_trip_user_id, route_trip_order_id, route_trip_wallet_id
          FROM public.mobility_trips
         WHERE trip_id = NEW.trip_id;

        IF route_trip_user_id IS NULL THEN
            RAISE EXCEPTION 'Mobility trip % does not exist for route %', NEW.trip_id, NEW.route_id;
        END IF;

        IF route_trip_user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Route user % differs from trip passenger %', NEW.user_id, route_trip_user_id;
        END IF;

        IF NEW.order_id IS NULL THEN
            NEW.order_id := route_trip_order_id;
        ELSIF NEW.order_id <> route_trip_order_id THEN
            RAISE EXCEPTION 'Route order % differs from trip order %', NEW.order_id, route_trip_order_id;
        END IF;

        IF NEW.wallet_id IS NULL THEN
            NEW.wallet_id := route_trip_wallet_id;
        ELSIF NEW.wallet_id <> route_trip_wallet_id THEN
            RAISE EXCEPTION 'Route wallet % differs from trip wallet %', NEW.wallet_id, route_trip_wallet_id;
        END IF;
    END IF;

    IF NEW.order_id IS NOT NULL THEN
        SELECT user_id, wallet_id, order_domain
          INTO route_order_user_id, route_order_wallet_id, route_order_domain
          FROM public.orders
         WHERE order_id = NEW.order_id;

        IF route_order_user_id IS NULL THEN
            RAISE EXCEPTION 'Order % does not exist for route %', NEW.order_id, NEW.route_id;
        END IF;

        IF route_order_domain <> 'MOVE' THEN
            RAISE EXCEPTION 'Mobility route requires MOVE order. Found % for order %', route_order_domain, NEW.order_id;
        END IF;

        IF route_order_user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Route user % differs from order user %', NEW.user_id, route_order_user_id;
        END IF;

        IF NEW.wallet_id IS NULL THEN
            NEW.wallet_id := route_order_wallet_id;
        ELSIF NEW.wallet_id <> route_order_wallet_id THEN
            RAISE EXCEPTION 'Route wallet % differs from order wallet %', NEW.wallet_id, route_order_wallet_id;
        END IF;
    END IF;

    IF NEW.wallet_id IS NOT NULL THEN
        SELECT user_id
          INTO route_wallet_user_id
          FROM public.wallets
         WHERE wallet_id = NEW.wallet_id;

        IF route_wallet_user_id IS NULL THEN
            RAISE EXCEPTION 'Wallet % does not exist for route %', NEW.wallet_id, NEW.route_id;
        END IF;

        IF route_wallet_user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Route wallet % belongs to user %, not %', NEW.wallet_id, route_wallet_user_id, NEW.user_id;
        END IF;
    END IF;

    IF NEW.benchmark_id IS NOT NULL THEN
        SELECT user_id, route_fingerprint
          INTO benchmark_user_id, benchmark_route_fingerprint
          FROM mobility.cost_benchmarks
         WHERE benchmark_id = NEW.benchmark_id;

        IF benchmark_user_id IS NULL THEN
            RAISE EXCEPTION 'Cost benchmark % does not exist for route %', NEW.benchmark_id, NEW.route_id;
        END IF;

        IF benchmark_user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Benchmark user % differs from route user %', benchmark_user_id, NEW.user_id;
        END IF;

        IF benchmark_route_fingerprint <> NEW.route_fingerprint THEN
            RAISE EXCEPTION 'Benchmark route fingerprint % differs from route fingerprint %',
                benchmark_route_fingerprint, NEW.route_fingerprint;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION mobility.assert_realtime_buffer_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    buffer_route_user_id UUID;
    buffer_route_order_id UUID;
    buffer_route_trip_id UUID;
    buffer_trip_passenger_user_id UUID;
    buffer_trip_rider_user_id UUID;
    buffer_trip_order_id UUID;
    buffer_order_user_id UUID;
    buffer_order_rider_user_id UUID;
    buffer_order_domain public.order_domain_enum;
BEGIN
    IF NEW.subject_role = 'RIDER' THEN
        PERFORM public.assert_city_ops_rider_user(NEW.user_id, 'mobility.realtime_buffer');
    END IF;

    IF NEW.route_id IS NOT NULL THEN
        SELECT user_id, order_id, trip_id
          INTO buffer_route_user_id, buffer_route_order_id, buffer_route_trip_id
          FROM mobility.user_routes
         WHERE route_id = NEW.route_id;

        IF buffer_route_user_id IS NULL THEN
            RAISE EXCEPTION 'Route % does not exist for realtime buffer %', NEW.route_id, NEW.buffer_id;
        END IF;

        IF buffer_route_user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Realtime buffer user % differs from route user %', NEW.user_id, buffer_route_user_id;
        END IF;

        IF NEW.order_id IS NULL THEN
            NEW.order_id := buffer_route_order_id;
        ELSIF buffer_route_order_id IS NOT NULL AND NEW.order_id <> buffer_route_order_id THEN
            RAISE EXCEPTION 'Realtime buffer order % differs from route order %', NEW.order_id, buffer_route_order_id;
        END IF;

        IF NEW.trip_id IS NULL THEN
            NEW.trip_id := buffer_route_trip_id;
        ELSIF buffer_route_trip_id IS NOT NULL AND NEW.trip_id <> buffer_route_trip_id THEN
            RAISE EXCEPTION 'Realtime buffer trip % differs from route trip %', NEW.trip_id, buffer_route_trip_id;
        END IF;
    END IF;

    IF NEW.trip_id IS NOT NULL THEN
        SELECT passenger_user_id, rider_user_id, order_id
          INTO buffer_trip_passenger_user_id, buffer_trip_rider_user_id, buffer_trip_order_id
          FROM public.mobility_trips
         WHERE trip_id = NEW.trip_id;

        IF buffer_trip_passenger_user_id IS NULL THEN
            RAISE EXCEPTION 'Mobility trip % does not exist for realtime buffer %', NEW.trip_id, NEW.buffer_id;
        END IF;

        IF NEW.subject_role = 'PASSENGER' AND buffer_trip_passenger_user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Realtime passenger user % differs from trip passenger %',
                NEW.user_id, buffer_trip_passenger_user_id;
        END IF;

        IF NEW.subject_role = 'RIDER' AND buffer_trip_rider_user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Realtime rider user % differs from trip rider %',
                NEW.user_id, buffer_trip_rider_user_id;
        END IF;

        IF NEW.order_id IS NULL THEN
            NEW.order_id := buffer_trip_order_id;
        ELSIF NEW.order_id <> buffer_trip_order_id THEN
            RAISE EXCEPTION 'Realtime order % differs from trip order %', NEW.order_id, buffer_trip_order_id;
        END IF;
    END IF;

    IF NEW.order_id IS NOT NULL THEN
        SELECT user_id, rider_user_id, order_domain
          INTO buffer_order_user_id, buffer_order_rider_user_id, buffer_order_domain
          FROM public.orders
         WHERE order_id = NEW.order_id;

        IF buffer_order_user_id IS NULL THEN
            RAISE EXCEPTION 'Order % does not exist for realtime buffer %', NEW.order_id, NEW.buffer_id;
        END IF;

        IF buffer_order_domain <> 'MOVE' THEN
            RAISE EXCEPTION 'Realtime buffer requires MOVE order. Found % for order %', buffer_order_domain, NEW.order_id;
        END IF;

        IF NEW.subject_role = 'PASSENGER' AND buffer_order_user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Realtime passenger user % differs from order user %',
                NEW.user_id, buffer_order_user_id;
        END IF;

        IF NEW.subject_role = 'RIDER'
           AND buffer_order_rider_user_id IS NOT NULL
           AND buffer_order_rider_user_id <> NEW.user_id THEN
            RAISE EXCEPTION 'Realtime rider user % differs from order rider %',
                NEW.user_id, buffer_order_rider_user_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgname = 'trg_mobility_cost_benchmarks_set_updated_at'
           AND tgrelid = 'mobility.cost_benchmarks'::REGCLASS
    ) THEN
        CREATE TRIGGER trg_mobility_cost_benchmarks_set_updated_at
        BEFORE UPDATE ON mobility.cost_benchmarks
        FOR EACH ROW
        EXECUTE FUNCTION public.set_updated_at();
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgname = 'trg_mobility_user_routes_set_updated_at'
           AND tgrelid = 'mobility.user_routes'::REGCLASS
    ) THEN
        CREATE TRIGGER trg_mobility_user_routes_set_updated_at
        BEFORE UPDATE ON mobility.user_routes
        FOR EACH ROW
        EXECUTE FUNCTION public.set_updated_at();
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgname = 'trg_mobility_user_routes_assert_coherence'
           AND tgrelid = 'mobility.user_routes'::REGCLASS
    ) THEN
        CREATE TRIGGER trg_mobility_user_routes_assert_coherence
        BEFORE INSERT OR UPDATE OF user_id, wallet_id, order_id, trip_id, benchmark_id, route_fingerprint
        ON mobility.user_routes
        FOR EACH ROW
        EXECUTE FUNCTION mobility.assert_user_route_coherence();
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgname = 'trg_mobility_realtime_buffer_set_updated_at'
           AND tgrelid = 'mobility.realtime_buffer'::REGCLASS
    ) THEN
        CREATE TRIGGER trg_mobility_realtime_buffer_set_updated_at
        BEFORE UPDATE ON mobility.realtime_buffer
        FOR EACH ROW
        EXECUTE FUNCTION public.set_updated_at();
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_trigger
         WHERE tgname = 'trg_mobility_realtime_buffer_assert_coherence'
           AND tgrelid = 'mobility.realtime_buffer'::REGCLASS
    ) THEN
        CREATE TRIGGER trg_mobility_realtime_buffer_assert_coherence
        BEFORE INSERT OR UPDATE OF user_id, route_id, order_id, trip_id, subject_role
        ON mobility.realtime_buffer
        FOR EACH ROW
        EXECUTE FUNCTION mobility.assert_realtime_buffer_coherence();
    END IF;
END;
$$;

CREATE OR REPLACE VIEW mobility.v_production_route_ops AS
SELECT
    route_row.route_id,
    route_row.user_id,
    route_row.wallet_id,
    route_row.order_id,
    route_row.trip_id,
    route_row.route_status,
    route_row.route_kind,
    route_row.route_fingerprint,
    route_row.origin_label,
    route_row.destination_label,
    route_row.selected_provider,
    route_row.planned_for,
    route_row.estimated_distance_km,
    route_row.estimated_duration_sec,
    route_row.estimated_cost_brl,
    benchmark_row.benchmark_id,
    benchmark_row.benchmark_status,
    benchmark_row.region_code,
    benchmark_row.valley_estimated_brl,
    benchmark_row.competitor_lowest_brl,
    buffer_row.buffer_id AS latest_buffer_id,
    buffer_row.buffer_status AS latest_buffer_status,
    buffer_row.captured_at AS latest_buffer_captured_at,
    buffer_row.expires_at AS latest_buffer_expires_at,
    route_row.metadata_json,
    route_row.created_at,
    route_row.updated_at
FROM mobility.user_routes route_row
LEFT JOIN mobility.cost_benchmarks benchmark_row
  ON benchmark_row.benchmark_id = route_row.benchmark_id
LEFT JOIN LATERAL (
    SELECT
        realtime_row.buffer_id,
        realtime_row.buffer_status,
        realtime_row.captured_at,
        realtime_row.expires_at
      FROM mobility.realtime_buffer realtime_row
     WHERE realtime_row.route_id = route_row.route_id
     ORDER BY realtime_row.captured_at DESC
     LIMIT 1
) buffer_row ON TRUE;

COMMENT ON TABLE mobility.cost_benchmarks IS
    'Benchmarks relacionais de custo Mobility por usuario, rota e regiao.';
COMMENT ON TABLE mobility.user_routes IS
    'Rotas planejadas/ofertadas do usuario antes ou durante a execucao em mobility_trips.';
COMMENT ON TABLE mobility.realtime_buffer IS
    'Buffer mutavel de localizacao e ETA para Mobility em tempo real.';
COMMENT ON VIEW mobility.v_production_route_ops IS
    'Visao operacional do modo producao Mobility unindo rota, benchmark e ultimo buffer realtime.';

COMMENT ON COLUMN mobility.cost_benchmarks.user_id IS 'FK obrigatoria para users.user_id do usuario dono do benchmark.';
COMMENT ON COLUMN mobility.cost_benchmarks.route_fingerprint IS 'Chave deterministica da origem/destino/modos usada para reconciliar benchmark e rota.';
COMMENT ON COLUMN mobility.cost_benchmarks.provider_quotes_json IS 'Array de cotacoes externas ou internas usadas no benchmark.';
COMMENT ON COLUMN mobility.user_routes.user_id IS 'FK obrigatoria para users.user_id do passageiro ou solicitante da rota.';
COMMENT ON COLUMN mobility.user_routes.benchmark_id IS 'FK opcional para o benchmark de custo usado na oferta.';
COMMENT ON COLUMN mobility.user_routes.pricing_snapshot_json IS 'Snapshot de preco exposto no momento da oferta.';
COMMENT ON COLUMN mobility.realtime_buffer.user_id IS 'FK obrigatoria para users.user_id do sujeito monitorado.';
COMMENT ON COLUMN mobility.realtime_buffer.route_id IS 'FK opcional para mobility.user_routes.';
COMMENT ON COLUMN mobility.realtime_buffer.trip_id IS 'FK opcional para public.mobility_trips quando a corrida ja existe.';

COMMENT ON FUNCTION mobility.assert_user_route_coherence() IS
    'Valida rota Mobility contra wallet, order MOVE, trip e benchmark do mesmo usuario.';
COMMENT ON FUNCTION mobility.assert_realtime_buffer_coherence() IS
    'Valida buffer realtime contra rota, order MOVE e trip quando informados.';

COMMENT ON TRIGGER trg_mobility_cost_benchmarks_set_updated_at ON mobility.cost_benchmarks IS
    'Atualiza updated_at em benchmarks de custo Mobility.';
COMMENT ON TRIGGER trg_mobility_user_routes_set_updated_at ON mobility.user_routes IS
    'Atualiza updated_at em rotas de usuario Mobility.';
COMMENT ON TRIGGER trg_mobility_user_routes_assert_coherence ON mobility.user_routes IS
    'Valida coerencia de usuario, wallet, order, trip e benchmark na rota.';
COMMENT ON TRIGGER trg_mobility_realtime_buffer_set_updated_at ON mobility.realtime_buffer IS
    'Atualiza updated_at em buffers realtime Mobility.';
COMMENT ON TRIGGER trg_mobility_realtime_buffer_assert_coherence ON mobility.realtime_buffer IS
    'Valida coerencia do buffer realtime com rota, order e trip.';

COMMIT;
