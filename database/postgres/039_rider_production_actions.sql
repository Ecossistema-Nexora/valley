-- 039_rider_production_actions.sql
-- Acoes produtivas do APK Rider sobre entregas espelhadas do Sheet.
-- Garante fluxo transacional: aceitar -> coletar -> entregar -> retroalimentar Sheet.

BEGIN;

SET search_path = public;

CREATE OR REPLACE VIEW rider_sheet_active_delivery_view AS
SELECT
    ds.shipment_id,
    ds.order_id,
    ds.rider_user_id,
    ds.shipment_status,
    ds.pickup_address_json,
    ds.dropoff_address_json,
    ds.pickup_contact_name,
    ds.pickup_contact_phone,
    ds.receiver_contact_name,
    ds.receiver_contact_phone,
    ds.package_count,
    ds.package_weight_kg,
    ds.declared_value_brl,
    ds.delivery_fee_brl AS rider_visible_delivery_fee_brl,
    ds.route_distance_km,
    ds.route_duration_sec,
    sf.sheet_freight_id,
    sf.sheet_sale_id,
    ss.sale_number,
    sf.tracking_code,
    sf.freight_status,
    sf.pickup_window_start,
    sf.pickup_window_end,
    ss.payment_status,
    ss.total_brl,
    ds.created_at,
    ds.updated_at
FROM delivery_shipments ds
JOIN sheet_physical_freights sf ON sf.linked_shipment_id = ds.shipment_id
JOIN sheet_sales ss ON ss.sheet_sale_id = sf.sheet_sale_id
WHERE ds.shipment_status IN ('DISPATCHING', 'ASSIGNED', 'PICKED_UP', 'IN_TRANSIT');

CREATE OR REPLACE VIEW rider_sheet_delivery_history_view AS
SELECT
    ds.shipment_id,
    ds.order_id,
    ds.rider_user_id,
    ds.shipment_status,
    sf.sheet_freight_id,
    sf.sheet_sale_id,
    ss.sale_number,
    sf.tracking_code,
    sf.freight_status,
    ds.delivery_fee_brl AS rider_visible_delivery_fee_brl,
    ds.picked_up_at,
    ds.delivered_at,
    ds.failed_at,
    ds.cancelled_at,
    ds.created_at
FROM delivery_shipments ds
JOIN sheet_physical_freights sf ON sf.linked_shipment_id = ds.shipment_id
JOIN sheet_sales ss ON ss.sheet_sale_id = sf.sheet_sale_id;

CREATE OR REPLACE FUNCTION rider_accept_sheet_delivery(p_shipment_id UUID, p_rider_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id UUID;
    v_current_status delivery_shipment_status_enum;
BEGIN
    SELECT order_id, shipment_status
      INTO v_order_id, v_current_status
      FROM delivery_shipments
     WHERE shipment_id = p_shipment_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shipment not found: %', p_shipment_id;
    END IF;

    IF v_current_status NOT IN ('DISPATCHING', 'ASSIGNED') THEN
        RAISE EXCEPTION 'Shipment % cannot be accepted from status %', p_shipment_id, v_current_status;
    END IF;

    UPDATE delivery_shipments
       SET rider_user_id = p_rider_user_id,
           shipment_status = 'ASSIGNED',
           assigned_at = COALESCE(assigned_at, NOW()),
           status_notes = 'Aceito pelo Rider via APK'
     WHERE shipment_id = p_shipment_id;

    UPDATE orders
       SET rider_user_id = p_rider_user_id,
           order_status = CASE WHEN order_status IN ('DRAFT', 'PLACED') THEN 'CONFIRMED' ELSE order_status END,
           dispatched_at = COALESCE(dispatched_at, NOW())
     WHERE order_id = v_order_id;

    INSERT INTO delivery_shipment_events (
        shipment_id,
        order_id,
        actor_user_id,
        event_type,
        shipment_status,
        notes,
        correlation_id,
        payload_json
    ) VALUES (
        p_shipment_id,
        v_order_id,
        p_rider_user_id,
        'RIDER_ASSIGNED',
        'ASSIGNED',
        'Rider aceitou entrega espelhada do Sheet',
        'rider_accept:' || p_shipment_id::TEXT,
        jsonb_build_object('source', 'apk_rider', 'action', 'accept')
    );

    RETURN p_shipment_id;
END;
$$;

CREATE OR REPLACE FUNCTION rider_confirm_sheet_pickup(p_shipment_id UUID, p_rider_user_id UUID, p_geo_json JSONB DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id UUID;
    v_current_status delivery_shipment_status_enum;
    v_current_rider UUID;
BEGIN
    SELECT order_id, shipment_status, rider_user_id
      INTO v_order_id, v_current_status, v_current_rider
      FROM delivery_shipments
     WHERE shipment_id = p_shipment_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shipment not found: %', p_shipment_id;
    END IF;

    IF v_current_rider IS DISTINCT FROM p_rider_user_id THEN
        RAISE EXCEPTION 'Rider % is not assigned to shipment %', p_rider_user_id, p_shipment_id;
    END IF;

    IF v_current_status <> 'ASSIGNED' THEN
        RAISE EXCEPTION 'Shipment % cannot be picked up from status %', p_shipment_id, v_current_status;
    END IF;

    UPDATE delivery_shipments
       SET shipment_status = 'PICKED_UP',
           picked_up_at = COALESCE(picked_up_at, NOW()),
           status_notes = 'Coleta confirmada pelo Rider'
     WHERE shipment_id = p_shipment_id;

    UPDATE orders
       SET order_status = 'IN_TRANSIT'
     WHERE order_id = v_order_id;

    UPDATE sheet_physical_freights
       SET freight_status = 'COLLECTED'
     WHERE linked_shipment_id = p_shipment_id;

    INSERT INTO delivery_shipment_events (
        shipment_id,
        order_id,
        actor_user_id,
        event_type,
        shipment_status,
        geo_json,
        notes,
        correlation_id,
        payload_json
    ) VALUES (
        p_shipment_id,
        v_order_id,
        p_rider_user_id,
        'PICKED_UP',
        'PICKED_UP',
        p_geo_json,
        'Coleta confirmada pelo Rider e retroalimentada no Sheet',
        'rider_pickup:' || p_shipment_id::TEXT,
        jsonb_build_object('source', 'apk_rider', 'action', 'pickup')
    );

    RETURN p_shipment_id;
END;
$$;

CREATE OR REPLACE FUNCTION rider_confirm_sheet_delivery(p_shipment_id UUID, p_rider_user_id UUID, p_geo_json JSONB DEFAULT NULL, p_proof_document_id UUID DEFAULT NULL)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id UUID;
    v_current_status delivery_shipment_status_enum;
    v_current_rider UUID;
BEGIN
    SELECT order_id, shipment_status, rider_user_id
      INTO v_order_id, v_current_status, v_current_rider
      FROM delivery_shipments
     WHERE shipment_id = p_shipment_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Shipment not found: %', p_shipment_id;
    END IF;

    IF v_current_rider IS DISTINCT FROM p_rider_user_id THEN
        RAISE EXCEPTION 'Rider % is not assigned to shipment %', p_rider_user_id, p_shipment_id;
    END IF;

    IF v_current_status NOT IN ('PICKED_UP', 'IN_TRANSIT') THEN
        RAISE EXCEPTION 'Shipment % cannot be delivered from status %', p_shipment_id, v_current_status;
    END IF;

    UPDATE delivery_shipments
       SET shipment_status = 'DELIVERED',
           delivered_at = COALESCE(delivered_at, NOW()),
           proof_document_id = COALESCE(p_proof_document_id, proof_document_id),
           status_notes = 'Entrega finalizada pelo Rider'
     WHERE shipment_id = p_shipment_id;

    UPDATE orders
       SET order_status = 'DELIVERED',
           delivered_at = COALESCE(delivered_at, NOW())
     WHERE order_id = v_order_id;

    UPDATE sheet_physical_freights
       SET freight_status = 'DELIVERED',
           proof_document_id = COALESCE(p_proof_document_id, proof_document_id)
     WHERE linked_shipment_id = p_shipment_id;

    INSERT INTO delivery_shipment_events (
        shipment_id,
        order_id,
        actor_user_id,
        event_type,
        shipment_status,
        geo_json,
        evidence_document_id,
        notes,
        correlation_id,
        payload_json
    ) VALUES (
        p_shipment_id,
        v_order_id,
        p_rider_user_id,
        'DELIVERED',
        'DELIVERED',
        p_geo_json,
        p_proof_document_id,
        'Entrega finalizada pelo Rider e retroalimentada no Sheet',
        'rider_deliver:' || p_shipment_id::TEXT,
        jsonb_build_object('source', 'apk_rider', 'action', 'deliver')
    );

    RETURN p_shipment_id;
END;
$$;

COMMENT ON VIEW rider_sheet_active_delivery_view IS 'API-safe view para home/ofertas do APK Rider. Nao expõe custo interno, margem ou taxa de plataforma.';
COMMENT ON FUNCTION rider_accept_sheet_delivery(UUID, UUID) IS 'Aceita entrega Sheet espelhada para um Rider em transacao.';
COMMENT ON FUNCTION rider_confirm_sheet_pickup(UUID, UUID, JSONB) IS 'Confirma coleta e retroalimenta Sheet.';
COMMENT ON FUNCTION rider_confirm_sheet_delivery(UUID, UUID, JSONB, UUID) IS 'Confirma entrega, prova e retroalimenta Sheet.';

COMMIT;
