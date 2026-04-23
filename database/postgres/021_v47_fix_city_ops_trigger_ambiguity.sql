BEGIN;

-- Corrige ambiguidades de nome em triggers do bloco city_ops. As funcoes
-- declaravam variaveis locais com o mesmo nome de colunas consultadas em
-- orders, o que quebra inserts de delivery_shipments e mobility_trips.
CREATE OR REPLACE FUNCTION assert_delivery_shipment_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    order_user_id UUID;
    order_wallet_id UUID;
    linked_order_domain order_domain_enum;
    order_merchant_user_id UUID;
    order_rider_user_id UUID;
BEGIN
    SELECT
        order_row.user_id,
        order_row.wallet_id,
        order_row.order_domain,
        order_row.merchant_user_id,
        order_row.rider_user_id
      INTO
        order_user_id,
        order_wallet_id,
        linked_order_domain,
        order_merchant_user_id,
        order_rider_user_id
      FROM orders AS order_row
     WHERE order_row.order_id = NEW.order_id;

    IF order_user_id IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist for shipment %', NEW.order_id, NEW.shipment_id;
    END IF;

    IF order_user_id <> NEW.requester_user_id THEN
        RAISE EXCEPTION 'Shipment requester % differs from order user %', NEW.requester_user_id, order_user_id;
    END IF;

    IF order_wallet_id <> NEW.wallet_id THEN
        RAISE EXCEPTION 'Shipment wallet % differs from order wallet %', NEW.wallet_id, order_wallet_id;
    END IF;

    IF linked_order_domain <> NEW.source_order_domain THEN
        RAISE EXCEPTION 'Shipment domain % differs from order domain %', NEW.source_order_domain, linked_order_domain;
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

CREATE OR REPLACE FUNCTION assert_mobility_trip_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    order_user_id UUID;
    order_wallet_id UUID;
    linked_order_domain order_domain_enum;
    order_rider_user_id UUID;
BEGIN
    SELECT
        order_row.user_id,
        order_row.wallet_id,
        order_row.order_domain,
        order_row.rider_user_id
      INTO
        order_user_id,
        order_wallet_id,
        linked_order_domain,
        order_rider_user_id
      FROM orders AS order_row
     WHERE order_row.order_id = NEW.order_id;

    IF order_user_id IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist for trip %', NEW.order_id, NEW.trip_id;
    END IF;

    IF linked_order_domain <> 'MOVE' THEN
        RAISE EXCEPTION 'Mobility trip requires MOVE order. Found % for order %', linked_order_domain, NEW.order_id;
    END IF;

    IF order_user_id <> NEW.passenger_user_id THEN
        RAISE EXCEPTION 'Trip passenger % differs from order user %', NEW.passenger_user_id, order_user_id;
    END IF;

    IF order_wallet_id <> NEW.wallet_id THEN
        RAISE EXCEPTION 'Trip wallet % differs from order wallet %', NEW.wallet_id, order_wallet_id;
    END IF;

    IF NEW.rider_user_id IS NULL THEN
        NEW.rider_user_id := order_rider_user_id;
    END IF;

    IF order_rider_user_id IS NOT NULL AND NEW.rider_user_id <> order_rider_user_id THEN
        RAISE EXCEPTION 'Trip rider % differs from order rider %', NEW.rider_user_id, order_rider_user_id;
    END IF;

    PERFORM assert_city_ops_rider_user(NEW.rider_user_id, 'mobility_trips');

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION assert_delivery_shipment_coherence() IS
    'Alinha shipment com order, wallet, merchant e rider sem ambiguidade entre variavel local e coluna de orders.';
COMMENT ON FUNCTION assert_mobility_trip_coherence() IS
    'Valida corrida MOVE contra order, wallet e rider sem ambiguidade entre variavel local e coluna de orders.';

COMMIT;
