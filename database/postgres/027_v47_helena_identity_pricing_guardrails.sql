BEGIN;

-- Fecha lacunas extraidas do master spec da Helena:
-- origem natal no Nexus-ID e filtro operacional de competitividade Stock.

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS birth_city TEXT,
    ADD COLUMN IF NOT EXISTS birth_state CHAR(2);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_users_birth_city_not_blank'
          AND conrelid = 'users'::REGCLASS
    ) THEN
        ALTER TABLE users
            ADD CONSTRAINT chk_users_birth_city_not_blank
            CHECK (birth_city IS NULL OR btrim(birth_city) <> '');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_users_birth_state_format'
          AND conrelid = 'users'::REGCLASS
    ) THEN
        ALTER TABLE users
            ADD CONSTRAINT chk_users_birth_state_format
            CHECK (birth_state IS NULL OR birth_state ~ '^[A-Z]{2}$');
    END IF;
END
$$;

COMMENT ON COLUMN users.birth_city IS
    'Cidade natal usada por personalizacao da Helena e segmentacao cultural opcional.';
COMMENT ON COLUMN users.birth_state IS
    'UF natal em ISO-2 usada por personalizacao da Helena e filtros regionais opcionais.';

CREATE OR REPLACE FUNCTION assert_listing_competitiveness_10pct(
    control_listing_id UUID,
    control_pricing_status listing_pricing_status_enum,
    control_minimum_price_brl DECIMAL,
    control_last_market_reference_brl DECIMAL,
    control_last_competitor_name TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    listing_status marketplace_listing_status_enum;
    listing_price_brl DECIMAL(18,4);
    benchmark_reference_brl DECIMAL(18,4);
    benchmark_competitor_name TEXT;
    normalized_last_competitor TEXT;
    effective_valley_price_brl DECIMAL(18,4);
    max_allowed_price_brl DECIMAL(18,4);
BEGIN
    SELECT
        marketplace_listings.listing_status,
        marketplace_listings.price_brl
    INTO
        listing_status,
        listing_price_brl
    FROM marketplace_listings
    WHERE marketplace_listings.listing_id = control_listing_id;

    IF listing_status <> 'ACTIVE'::marketplace_listing_status_enum
       AND control_pricing_status <> 'COMPETITIVE'::listing_pricing_status_enum THEN
        RETURN;
    END IF;

    SELECT
        snapshot.competitor_name,
        (snapshot.competitor_price_brl + snapshot.shipping_price_brl)::DECIMAL(18,4)
    INTO
        benchmark_competitor_name,
        benchmark_reference_brl
    FROM marketplace_competitor_snapshots AS snapshot
    WHERE snapshot.listing_id = control_listing_id
      AND upper(regexp_replace(snapshot.competitor_name, '[^A-Za-z0-9]+', '', 'g'))
            IN ('MERCADOLIVRE', 'AMAZON', 'MAGALU')
    ORDER BY
        (snapshot.competitor_price_brl + snapshot.shipping_price_brl) ASC,
        snapshot.captured_at DESC
    LIMIT 1;

    normalized_last_competitor := upper(
        regexp_replace(COALESCE(control_last_competitor_name, ''), '[^A-Za-z0-9]+', '', 'g')
    );

    IF benchmark_reference_brl IS NULL
       AND control_last_market_reference_brl IS NOT NULL
       AND normalized_last_competitor IN ('MERCADOLIVRE', 'AMAZON', 'MAGALU') THEN
        benchmark_reference_brl := control_last_market_reference_brl;
        benchmark_competitor_name := control_last_competitor_name;
    END IF;

    IF benchmark_reference_brl IS NULL OR benchmark_reference_brl <= 0 THEN
        RAISE EXCEPTION
            'listing_id % precisa de referencia valida de Mercado Livre, Amazon ou Magalu para ficar ativo/competitivo',
            control_listing_id;
    END IF;

    effective_valley_price_brl := GREATEST(
        listing_price_brl,
        COALESCE(control_minimum_price_brl, 0.0000)
    );
    max_allowed_price_brl := ROUND((benchmark_reference_brl * 0.9000)::NUMERIC, 4)::DECIMAL(18,4);

    IF effective_valley_price_brl > max_allowed_price_brl THEN
        RAISE EXCEPTION
            'listing_id % precisa estar 10%% abaixo de %. Preco efetivo %, limite %',
            control_listing_id,
            benchmark_competitor_name,
            effective_valley_price_brl,
            max_allowed_price_brl;
    END IF;
END;
$$;

COMMENT ON FUNCTION assert_listing_competitiveness_10pct(UUID, listing_pricing_status_enum, DECIMAL, DECIMAL, TEXT) IS
    'Valida que listing ativo ou competitivo esta ao menos 10 por cento abaixo de Mercado Livre, Amazon ou Magalu.';

CREATE OR REPLACE FUNCTION assert_listing_control_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    listing_merchant UUID;
    binding_module TEXT;
BEGIN
    SELECT merchant_user_id
    INTO listing_merchant
    FROM marketplace_listings
    WHERE listing_id = NEW.listing_id;

    IF listing_merchant IS NULL THEN
        RAISE EXCEPTION 'listing_id % nao encontrado em marketplace_listings', NEW.listing_id;
    END IF;

    IF listing_merchant <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'listing_id % pertence ao merchant_user_id %, nao a %', NEW.listing_id, listing_merchant, NEW.merchant_user_id;
    END IF;

    IF NEW.rule_binding_id IS NOT NULL THEN
        SELECT module_code
        INTO binding_module
        FROM rule_runtime_bindings
        WHERE binding_id = NEW.rule_binding_id;

        IF binding_module <> 'MARKETPLACE' THEN
            RAISE EXCEPTION 'rule_binding_id % precisa apontar para module_code MARKETPLACE', NEW.rule_binding_id;
        END IF;
    END IF;

    PERFORM assert_listing_competitiveness_10pct(
        NEW.listing_id,
        NEW.pricing_status,
        NEW.minimum_price_brl,
        NEW.last_market_reference_brl,
        NEW.last_competitor_name
    );

    RETURN NEW;
END;
$$;

UPDATE business_rule_definitions
SET
    description = 'Listing de isca so pode ficar ativo quando estiver pelo menos 10 por cento abaixo de Mercado Livre, Amazon ou Magalu e ainda mantiver margem positiva.',
    constraints_json = '{"must_beat_market":true,"required_discount_rate":0.10,"benchmark_competitors":["Mercado Livre","Amazon","Magalu"],"require_positive_margin":true,"auto_pause_when_not_competitive":true}'::JSONB,
    updated_at = NOW()
WHERE rule_code = 'BR-MKT-COMP-002';

COMMIT;
