BEGIN;

-- Reconcilia o catalogo usado por FKs legadas com o registro operacional v47.
-- module_delivery_registry contem os 47 modulos executaveis; module_catalog pode
-- carregar codigos historicos. Esta migration adiciona os codigos faltantes sem
-- apagar ou renumerar registros existentes.

SET search_path = public;

DO $$
DECLARE
    missing_count INTEGER;
    available_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO missing_count
    FROM module_delivery_registry registry
    LEFT JOIN module_catalog catalog
        ON catalog.module_code = registry.module_code
    WHERE catalog.module_code IS NULL;

    SELECT COUNT(*)
    INTO available_count
    FROM generate_series(1, 99) AS available(module_number)
    LEFT JOIN module_catalog catalog
        ON catalog.module_number = available.module_number
    WHERE catalog.module_number IS NULL;

    IF missing_count > available_count THEN
        RAISE EXCEPTION
            'module_catalog sem numeros livres suficientes: faltantes=%, livres=%',
            missing_count,
            available_count;
    END IF;
END $$;

WITH missing_registry AS (
    SELECT
        registry.module_code,
        registry.module_name,
        registry.subtitle,
        registry.description_ptbr,
        registry.domain,
        registry.tier,
        registry.data_home,
        registry.module_number AS registry_module_number,
        ROW_NUMBER() OVER (ORDER BY registry.module_number, registry.module_code) AS allocation_rank
    FROM module_delivery_registry registry
    LEFT JOIN module_catalog catalog
        ON catalog.module_code = registry.module_code
    WHERE catalog.module_code IS NULL
),
available_numbers AS (
    SELECT
        available.module_number,
        ROW_NUMBER() OVER (ORDER BY available.module_number) AS allocation_rank
    FROM generate_series(1, 99) AS available(module_number)
    LEFT JOIN module_catalog catalog
        ON catalog.module_number = available.module_number
    WHERE catalog.module_number IS NULL
),
catalog_aliases AS (
    SELECT
        available_numbers.module_number,
        missing_registry.module_code,
        missing_registry.module_name,
        CASE
            WHEN missing_registry.tier IN ('foundation', 'core') THEN 'PF/PJ: operacao essencial'
            WHEN missing_registry.tier = 'frontier' THEN 'Admin/PJ: fronteira operacional'
            ELSE 'PF/PJ: expansao operacional'
        END AS primary_audience,
        COALESCE(NULLIF(missing_registry.subtitle, ''), 'Modulo operacional v47') AS secondary_audience,
        missing_registry.description_ptbr AS central_function,
        CASE missing_registry.data_home
            WHEN 'postgres' THEN 'Receita operacional auditavel em PostgreSQL'
            WHEN 'mongo' THEN 'Receita de dados, midia ou telemetria operacional'
            ELSE 'Receita hibrida com trilhas relacionais e eventos MongoDB'
        END AS monetization_model
    FROM missing_registry
    INNER JOIN available_numbers
        ON available_numbers.allocation_rank = missing_registry.allocation_rank
)
INSERT INTO module_catalog (
    module_number,
    module_code,
    module_name,
    primary_audience,
    secondary_audience,
    central_function,
    monetization_model,
    is_active,
    source_document
)
SELECT
    module_number,
    module_code,
    module_name,
    primary_audience,
    secondary_audience,
    central_function,
    monetization_model,
    TRUE,
    'module_delivery_registry v47 reconciliation'
FROM catalog_aliases
ON CONFLICT (module_code) DO UPDATE SET
    module_name = EXCLUDED.module_name,
    primary_audience = EXCLUDED.primary_audience,
    secondary_audience = EXCLUDED.secondary_audience,
    central_function = EXCLUDED.central_function,
    monetization_model = EXCLUDED.monetization_model,
    is_active = EXCLUDED.is_active,
    source_document = EXCLUDED.source_document,
    updated_at = NOW();

COMMENT ON TABLE module_catalog IS
    'Catalogo operacional de modulos e aliases v47 usado por regras, campanhas e FKs legadas.';

COMMIT;
