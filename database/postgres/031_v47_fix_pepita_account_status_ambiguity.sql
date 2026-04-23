BEGIN;

-- Corrige ambiguidade PL/pgSQL entre variavel local account_status e coluna
-- pepita_accounts.account_status durante aplicacao append-only do ledger Pepita.

SET search_path = public;

CREATE OR REPLACE FUNCTION apply_pepita_ledger_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    account_user_id UUID;
    pepita_status pepita_account_status_enum;
    current_balance DECIMAL(18,4);
    new_balance DECIMAL(18,4);
    event_candidate_id UUID;
    validation_customer_id UUID;
    validation_campaign_id UUID;
    validation_cap_brl DECIMAL(18,4);
BEGIN
    SELECT
        user_id,
        pepita_accounts.account_status,
        current_balance_brl
    INTO
        account_user_id,
        pepita_status,
        current_balance
    FROM pepita_accounts
    WHERE pepita_account_id = NEW.pepita_account_id
    FOR UPDATE;

    IF account_user_id IS NULL THEN
        RAISE EXCEPTION 'pepita_account_id % nao encontrado em pepita_accounts', NEW.pepita_account_id;
    END IF;

    IF account_user_id <> NEW.user_id THEN
        RAISE EXCEPTION 'pepita_account_id % nao pertence ao user_id %', NEW.pepita_account_id, NEW.user_id;
    END IF;

    IF pepita_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'pepita_account_id % nao esta ACTIVE para novos lancamentos', NEW.pepita_account_id;
    END IF;

    IF NEW.entry_type IN ('REDEEM', 'EXPIRE') AND NEW.amount_brl >= 0 THEN
        RAISE EXCEPTION 'entry_type % exige amount_brl negativo', NEW.entry_type;
    END IF;

    IF NEW.entry_type IN ('EARN', 'GOLD_CONVERSION') AND NEW.amount_brl <= 0 THEN
        RAISE EXCEPTION 'entry_type % exige amount_brl positivo', NEW.entry_type;
    END IF;

    IF NEW.gold_campaign_event_id IS NOT NULL THEN
        SELECT candidate_user_id
        INTO event_candidate_id
        FROM gold_campaign_events
        WHERE gold_campaign_event_id = NEW.gold_campaign_event_id;

        IF event_candidate_id IS NOT NULL AND event_candidate_id <> NEW.user_id THEN
            RAISE EXCEPTION 'gold_campaign_event_id % nao pertence ao user_id %', NEW.gold_campaign_event_id, NEW.user_id;
        END IF;
    END IF;

    IF NEW.sale_validation_id IS NOT NULL THEN
        SELECT
            customer_user_id,
            gold_campaign_id,
            pepita_cap_brl
        INTO
            validation_customer_id,
            validation_campaign_id,
            validation_cap_brl
        FROM sale_validation_events
        WHERE sale_validation_id = NEW.sale_validation_id;

        IF validation_customer_id IS NOT NULL AND validation_customer_id <> NEW.user_id THEN
            RAISE EXCEPTION 'sale_validation_id % nao pertence ao user_id %', NEW.sale_validation_id, NEW.user_id;
        END IF;

        IF NEW.gold_campaign_id IS NOT NULL
           AND validation_campaign_id IS NOT NULL
           AND validation_campaign_id <> NEW.gold_campaign_id THEN
            RAISE EXCEPTION 'gold_campaign_id % nao casa com sale_validation_id %', NEW.gold_campaign_id, NEW.sale_validation_id;
        END IF;

        IF NEW.amount_brl > 0
           AND NEW.entry_type IN ('EARN', 'GOLD_CONVERSION')
           AND NEW.amount_brl > validation_cap_brl THEN
            RAISE EXCEPTION 'amount_brl % ultrapassa pepita_cap_brl % da sale_validation_id %', NEW.amount_brl, validation_cap_brl, NEW.sale_validation_id;
        END IF;
    END IF;

    new_balance := current_balance + NEW.amount_brl;

    IF new_balance < 0 THEN
        RAISE EXCEPTION 'pepita_account_id % ficaria negativo com amount_brl %', NEW.pepita_account_id, NEW.amount_brl;
    END IF;

    NEW.balance_after_brl := new_balance;

    UPDATE pepita_accounts
    SET
        current_balance_brl = new_balance,
        lifetime_earned_brl = lifetime_earned_brl + CASE
            WHEN NEW.amount_brl > 0 AND NEW.entry_type IN ('EARN', 'GOLD_CONVERSION', 'REVERSAL', 'ADJUSTMENT') THEN NEW.amount_brl
            ELSE 0
        END,
        lifetime_redeemed_brl = lifetime_redeemed_brl + CASE
            WHEN NEW.entry_type = 'REDEEM' THEN ABS(NEW.amount_brl)
            ELSE 0
        END,
        lifetime_expired_brl = lifetime_expired_brl + CASE
            WHEN NEW.entry_type = 'EXPIRE' THEN ABS(NEW.amount_brl)
            ELSE 0
        END,
        last_activity_at = NEW.created_at,
        updated_at = NOW()
    WHERE pepita_account_id = NEW.pepita_account_id;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION apply_pepita_ledger_entry() IS
    'Aplica lancamento append-only de Pepita com validacao de conta e saldo sem ambiguidade de account_status.';

COMMIT;
