BEGIN;

-- Corrige o trigger TECH para nao acessar NEW.connector_id fora da tabela
-- tech_webhook_subscriptions. Em expressoes SQL dentro de IF, o PostgreSQL
-- nao garante short-circuit; por isso a versao original podia falhar quando
-- o mesmo trigger era executado em tech_api_credentials ou tech_api_usage_daily.
CREATE OR REPLACE FUNCTION assert_tech_owner_coherence()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME IN ('tech_api_credentials', 'tech_api_usage_daily') THEN
        IF NOT EXISTS (
            SELECT 1
            FROM tech_api_clients
            WHERE tech_api_clients.api_client_id = NEW.api_client_id
              AND tech_api_clients.owner_user_id = NEW.owner_user_id
        ) THEN
            RAISE EXCEPTION 'api_client_id % nao pertence ao owner_user_id % em %',
                NEW.api_client_id,
                NEW.owner_user_id,
                TG_TABLE_NAME;
        END IF;
    END IF;

    IF TG_TABLE_NAME = 'tech_webhook_subscriptions' THEN
        IF NEW.api_client_id IS NOT NULL THEN
            IF NOT EXISTS (
                SELECT 1
                FROM tech_api_clients
                WHERE tech_api_clients.api_client_id = NEW.api_client_id
                  AND tech_api_clients.owner_user_id = NEW.owner_user_id
            ) THEN
                RAISE EXCEPTION 'api_client_id % nao pertence ao owner_user_id % em tech_webhook_subscriptions',
                    NEW.api_client_id,
                    NEW.owner_user_id;
            END IF;
        END IF;

        IF NEW.connector_id IS NOT NULL THEN
            IF NOT EXISTS (
                SELECT 1
                FROM tech_integration_connectors
                WHERE tech_integration_connectors.connector_id = NEW.connector_id
                  AND tech_integration_connectors.owner_user_id = NEW.owner_user_id
            ) THEN
                RAISE EXCEPTION 'connector_id % nao pertence ao owner_user_id % em tech_webhook_subscriptions',
                    NEW.connector_id,
                    NEW.owner_user_id;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION assert_tech_owner_coherence() IS
    'Trigger function que impede credencial, webhook ou uso diario com owner_user_id divergente, sem referenciar colunas inexistentes em outras tabelas.';

COMMIT;
