-- 038_sheet_to_rider_mirror_runtime.sql
-- Runtime produtivo de espelhamento Sheet/Stitch -> Valley Rider.
-- Depende de 002, 011, 036 e 037.

BEGIN;

SET search_path = public;

CREATE OR REPLACE FUNCTION sheet_resolve_wallet_for_order(p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_wallet_id UUID;
BEGIN
    SELECT w.wallet_id
      INTO v_wallet_id
      FROM wallets w
     WHERE w.user_id = p_user_id
     ORDER BY w.created_at ASC
     LIMIT 1;

    IF v_wallet_id IS NULL THEN
        RAISE EXCEPTION 'No wallet found for user_id=%', p_user_id;
    END IF;

    RETURN v_wallet_id;
END;
$$;

CREATE OR REPLACE FUNCTION sheet_enqueue_rider_mirror_job_for_freight(p_sheet_freight_id UUID)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_job_id UUID;
    v_freight RECORD;
BEGIN
    SELECT *
      INTO v_freight
      FROM sheet_physical_freights
     WHERE sheet_freight_id = p_sheet_freight_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'sheet_physical_freight not found: %', p_sheet_freight_id;
    END IF;

    SELECT sheet_to_rider_mirror_job_id
      INTO v_job_id
      FROM sheet_to_rider_mirror_jobs
     WHERE sheet_freight_id = p_sheet_freight_id
       AND mirror_status IN ('PENDING', 'RETRY', 'MIRRORED')
     ORDER BY created_at DESC
     LIMIT 1;

    IF v_job_id IS NOT NULL THEN
        RETURN v_job_id;
    END IF;

    INSERT INTO sheet_to_rider_mirror_jobs (
        sheet_source_document_id,
        sheet_sale_id,
        sheet_freight_id,
        mirror_status,
        payload_json
    ) VALUES (
        v_freight.sheet_source_document_id,
        v_freight.sheet_sale_id,
        v_freight.sheet_freight_id,
        'PENDING',
        jsonb_build_object(
            'reason', 'freight_ready_for_rider_mirror',
            'freight_status', v_freight.freight_status,
            'tracking_code', v_freight.tracking_code
        )
    )
    RETURNING sheet_to_rider_mirror_job_id INTO v_job_id;

    RETURN v_job_id;
END;
$$;

CREATE OR REPLACE FUNCTION sheet_mirror_one_job_to_rider(p_job_id UUID)
RETURNS TABLE (
    mirror_job_id UUID,
    mirror_status sheet_to_rider_mirror_status_enum,
    order_id UUID,
    shipment_id UUID,
    error_message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_job RECORD;
    v_sale RECORD;
    v_freight RECORD;
    v_order_id UUID;
    v_shipment_id UUID;
    v_wallet_id UUID;
    v_pickup_json JSONB;
    v_dropoff_json JSONB;
    v_order_total DECIMAL(18,4);
BEGIN
    SELECT *
      INTO v_job
      FROM sheet_to_rider_mirror_jobs
     WHERE sheet_to_rider_mirror_job_id = p_job_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'mirror job not found: %', p_job_id;
    END IF;

    SELECT * INTO v_sale FROM sheet_sales WHERE sheet_sale_id = v_job.sheet_sale_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'sheet sale not found for mirror job: %', p_job_id;
    END IF;

    SELECT * INTO v_freight FROM sheet_physical_freights WHERE sheet_freight_id = v_job.sheet_freight_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'sheet freight not found for mirror job: %', p_job_id;
    END IF;

    IF v_sale.customer_user_id IS NULL THEN
        RAISE EXCEPTION 'sheet sale % has no customer_user_id', v_sale.sheet_sale_id;
    END IF;

    v_wallet_id := sheet_resolve_wallet_for_order(v_sale.customer_user_id);

    v_pickup_json := COALESCE(v_freight.metadata_json -> 'pickup_address', '{}'::JSONB);
    v_dropoff_json := COALESCE(v_freight.metadata_json -> 'dropoff_address', '{}'::JSONB);
    IF jsonb_typeof(v_pickup_json) <> 'object' THEN v_pickup_json := '{}'::JSONB; END IF;
    IF jsonb_typeof(v_dropoff_json) <> 'object' THEN v_dropoff_json := '{}'::JSONB; END IF;

    v_order_total := v_sale.subtotal_brl + v_sale.freight_charged_brl - v_sale.discount_brl;
    IF v_order_total < 0 THEN v_order_total := 0; END IF;

    IF v_sale.linked_order_id IS NULL THEN
        INSERT INTO orders (
            user_id,
            wallet_id,
            order_domain,
            order_status,
            merchant_user_id,
            source_channel,
            currency_code,
            subtotal_brl,
            delivery_fee_brl,
            service_fee_brl,
            discount_brl,
            tax_brl,
            total_brl,
            total_nex,
            pickup_address_json,
            dropoff_address_json,
            customer_notes,
            ops_notes,
            supplier_name,
            tracking_code,
            tracking_provider
        ) VALUES (
            v_sale.customer_user_id,
            v_wallet_id,
            'DROPSHIP',
            'PLACED',
            v_sale.merchant_user_id,
            'SHEET_STITCH',
            'BRL',
            v_sale.subtotal_brl,
            v_sale.freight_charged_brl,
            0,
            v_sale.discount_brl,
            0,
            v_order_total,
            0,
            v_pickup_json,
            v_dropoff_json,
            'Pedido local espelhado do Sheet/Stitch',
            'Fonte de verdade: sheet_sales/sheet_physical_freights',
            'SHEET_LOCAL_STORE',
            v_freight.tracking_code,
            COALESCE(v_freight.carrier_name, 'SHEET_FREIGHT')
        ) RETURNING orders.order_id INTO v_order_id;

        UPDATE sheet_sales
           SET linked_order_id = v_order_id
         WHERE sheet_sale_id = v_sale.sheet_sale_id;
    ELSE
        v_order_id := v_sale.linked_order_id;
    END IF;

    IF v_freight.linked_shipment_id IS NULL THEN
        INSERT INTO delivery_shipments (
            order_id,
            module_code,
            requester_user_id,
            merchant_user_id,
            wallet_id,
            source_order_domain,
            shipment_kind,
            shipment_status,
            pickup_address_json,
            dropoff_address_json,
            pickup_contact_name,
            pickup_contact_phone,
            receiver_contact_name,
            receiver_contact_phone,
            package_count,
            package_weight_kg,
            declared_value_brl,
            delivery_fee_brl,
            cash_to_collect_brl,
            dispatch_started_at,
            status_notes,
            metadata_json
        ) VALUES (
            v_order_id,
            'DELIVERY',
            v_sale.merchant_user_id,
            v_sale.merchant_user_id,
            v_wallet_id,
            'DROPSHIP',
            'MARKETPLACE',
            'DISPATCHING',
            v_pickup_json,
            v_dropoff_json,
            NULLIF(v_freight.metadata_json ->> 'pickup_contact_name', ''),
            NULLIF(v_freight.metadata_json ->> 'pickup_contact_phone', ''),
            NULLIF(v_freight.metadata_json ->> 'receiver_contact_name', ''),
            NULLIF(v_freight.metadata_json ->> 'receiver_contact_phone', ''),
            COALESCE((v_freight.metadata_json ->> 'package_count')::SMALLINT, 1),
            COALESCE((v_freight.metadata_json ->> 'package_weight_kg')::DECIMAL(10,3), 0),
            v_freight.declared_value_brl,
            v_freight.customer_freight_charge_brl,
            0,
            NOW(),
            'Espelhado do Sheet/Stitch para operação Rider',
            jsonb_build_object(
                'sheet_sale_id', v_sale.sheet_sale_id,
                'sheet_freight_id', v_freight.sheet_freight_id,
                'sale_number', v_sale.sale_number,
                'tracking_code', v_freight.tracking_code,
                'source', 'sheet_source_of_truth'
            )
        ) RETURNING delivery_shipments.shipment_id INTO v_shipment_id;

        UPDATE sheet_physical_freights
           SET linked_shipment_id = v_shipment_id,
               freight_status = CASE WHEN freight_status = 'DRAFT' THEN 'CREATED' ELSE freight_status END
         WHERE sheet_freight_id = v_freight.sheet_freight_id;

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
            v_shipment_id,
            v_order_id,
            v_sale.merchant_user_id,
            'CREATED',
            'DISPATCHING',
            'Entrega criada por espelhamento Sheet/Stitch',
            'sheet:' || v_freight.sheet_freight_id::TEXT,
            jsonb_build_object('sheet_sale_id', v_sale.sheet_sale_id, 'sheet_freight_id', v_freight.sheet_freight_id)
        );
    ELSE
        v_shipment_id := v_freight.linked_shipment_id;
    END IF;

    UPDATE sheet_to_rider_mirror_jobs
       SET order_id = v_order_id,
           shipment_id = v_shipment_id,
           mirror_status = 'MIRRORED',
           mirrored_at = NOW(),
           last_error = NULL,
           payload_json = payload_json || jsonb_build_object('mirrored_order_id', v_order_id, 'mirrored_shipment_id', v_shipment_id)
     WHERE sheet_to_rider_mirror_job_id = p_job_id;

    RETURN QUERY SELECT p_job_id, 'MIRRORED'::sheet_to_rider_mirror_status_enum, v_order_id, v_shipment_id, NULL::TEXT;

EXCEPTION WHEN OTHERS THEN
    UPDATE sheet_to_rider_mirror_jobs
       SET attempts = attempts + 1,
           mirror_status = CASE WHEN attempts + 1 >= 5 THEN 'FAILED' ELSE 'RETRY' END,
           last_error = SQLERRM
     WHERE sheet_to_rider_mirror_job_id = p_job_id;

    RETURN QUERY SELECT p_job_id, 'FAILED'::sheet_to_rider_mirror_status_enum, NULL::UUID, NULL::UUID, SQLERRM;
END;
$$;

CREATE OR REPLACE FUNCTION sheet_process_rider_mirror_jobs(p_limit INTEGER DEFAULT 25)
RETURNS TABLE (
    mirror_job_id UUID,
    mirror_status sheet_to_rider_mirror_status_enum,
    order_id UUID,
    shipment_id UUID,
    error_message TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_job_id UUID;
BEGIN
    FOR v_job_id IN
        SELECT sheet_to_rider_mirror_job_id
          FROM sheet_to_rider_mirror_jobs
         WHERE mirror_status IN ('PENDING', 'RETRY')
         ORDER BY created_at ASC
         LIMIT p_limit
    LOOP
        RETURN QUERY SELECT * FROM sheet_mirror_one_job_to_rider(v_job_id);
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION trg_sheet_physical_freights_enqueue_rider_mirror()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.freight_status IN ('CREATED', 'LABEL_PRINTED', 'COLLECTED', 'IN_TRANSIT') THEN
        PERFORM sheet_enqueue_rider_mirror_job_for_freight(NEW.sheet_freight_id);
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sheet_physical_freights_enqueue_rider_mirror ON sheet_physical_freights;
CREATE TRIGGER trg_sheet_physical_freights_enqueue_rider_mirror
AFTER INSERT OR UPDATE OF freight_status ON sheet_physical_freights
FOR EACH ROW
EXECUTE FUNCTION trg_sheet_physical_freights_enqueue_rider_mirror();

COMMENT ON FUNCTION sheet_process_rider_mirror_jobs(INTEGER) IS 'Processa fila de espelhamento Sheet/Stitch -> orders/delivery_shipments para o APK Rider.';
COMMENT ON FUNCTION sheet_mirror_one_job_to_rider(UUID) IS 'Espelha uma venda/frete canônico do Sheet para order e delivery_shipment, preservando rastreabilidade.';

COMMIT;
