BEGIN;

-- Corrige ambiguidade PL/pgSQL entre variavel local e coluna reward_type
-- no trigger de GOLD/Pepita, mantendo o contrato de coerencia existente.

SET search_path = public;

CREATE OR REPLACE FUNCTION assert_gold_campaign_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    storefront_merchant_id UUID;
    zone_storefront_id UUID;
    zone_merchant_id UUID;
    wallet_owner_id UUID;
    campaign_reward_type reward_type_enum;
BEGIN
    SELECT user_id
    INTO wallet_owner_id
    FROM wallets
    WHERE wallet_id = NEW.wallet_id;

    IF wallet_owner_id IS NULL THEN
        RAISE EXCEPTION 'wallet_id % nao encontrado em wallets', NEW.wallet_id;
    END IF;

    IF wallet_owner_id <> NEW.merchant_user_id THEN
        RAISE EXCEPTION 'wallet_id % nao pertence ao merchant_user_id %', NEW.wallet_id, NEW.merchant_user_id;
    END IF;

    IF NEW.target_storefront_id IS NOT NULL THEN
        SELECT merchant_user_id
        INTO storefront_merchant_id
        FROM merchant_storefronts
        WHERE storefront_id = NEW.target_storefront_id;

        IF storefront_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'target_storefront_id % nao pertence ao merchant_user_id %', NEW.target_storefront_id, NEW.merchant_user_id;
        END IF;
    END IF;

    IF NEW.target_zone_id IS NOT NULL THEN
        SELECT
            z.storefront_id,
            s.merchant_user_id
        INTO
            zone_storefront_id,
            zone_merchant_id
        FROM merchant_service_zones z
        JOIN merchant_storefronts s
          ON s.storefront_id = z.storefront_id
        WHERE z.service_zone_id = NEW.target_zone_id;

        IF zone_merchant_id <> NEW.merchant_user_id THEN
            RAISE EXCEPTION 'target_zone_id % nao pertence ao merchant_user_id %', NEW.target_zone_id, NEW.merchant_user_id;
        END IF;

        IF NEW.target_storefront_id IS NOT NULL AND zone_storefront_id <> NEW.target_storefront_id THEN
            RAISE EXCEPTION 'target_zone_id % nao pertence ao target_storefront_id %', NEW.target_zone_id, NEW.target_storefront_id;
        END IF;
    END IF;

    IF NEW.campaign_id IS NOT NULL THEN
        SELECT gamification_campaigns.reward_type
        INTO campaign_reward_type
        FROM gamification_campaigns
        WHERE campaign_id = NEW.campaign_id;

        IF campaign_reward_type <> 'PEPITA' THEN
            RAISE EXCEPTION 'campaign_id % precisa ser uma gamification_campaign com reward_type PEPITA', NEW.campaign_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION assert_gold_campaign_coherence() IS
    'Valida split, wallet, storefront, zona e campanha de Pepita ligados a GOLD sem ambiguidade de reward_type.';

COMMIT;
