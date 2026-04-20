-- Valley Hybrid DB Bootstrap - Core release bundle v47.
-- Este arquivo fecha o gap restante do tier core com contratos para SERVICES, HEALTH, JOBS, PHARMACY e EVENTS.
-- Ele amplia o order_domain_enum e cria tabelas relacionais, FKs, checks, indices parciais e trilhas append-only quando a prova operacional exige imutabilidade.
-- Execute depois de 011, porque reutiliza users, wallets, orders, transactions, document_records, legal_contracts e a camada city ops.

-- Fase 1: ampliar o enum do motor transacional.
-- Nota tecnica: os novos valores do enum precisam ser confirmados em COMMIT antes de serem usados em defaults, checks e triggers da fase seguinte.
BEGIN;

SET search_path = public;

ALTER TYPE order_domain_enum ADD VALUE IF NOT EXISTS 'SERVICES';
ALTER TYPE order_domain_enum ADD VALUE IF NOT EXISTS 'PHARMACY';
ALTER TYPE order_domain_enum ADD VALUE IF NOT EXISTS 'EVENTS';

COMMENT ON TYPE order_domain_enum IS 'Define o dominio do pedido mestre: Food, Move, Dropship, Services, Pharmacy ou Events.';
COMMENT ON COLUMN orders.order_domain IS 'Dominio operacional do pedido: Food, Move, Dropship, Services, Pharmacy ou Events.';

COMMIT;

-- Fase 2: criar o lote core usando os novos dominios ja visiveis.
BEGIN;

SET search_path = public;

-- service_provider_status_enum controla onboarding e operacao do prestador.
CREATE TYPE service_provider_status_enum AS ENUM ('ONBOARDING', 'ACTIVE', 'PAUSED', 'SUSPENDED', 'ARCHIVED');

-- service_catalog_status_enum controla publicacao dos servicos ofertados.
CREATE TYPE service_catalog_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'ARCHIVED');

-- service_booking_mode_enum explica como o cliente pode contratar o servico.
CREATE TYPE service_booking_mode_enum AS ENUM ('INSTANT', 'QUOTE_REQUIRED', 'SCHEDULED');

-- service_booking_status_enum controla o lifecycle do agendamento/execucao.
CREATE TYPE service_booking_status_enum AS ENUM ('REQUESTED', 'QUOTED', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'DISPUTED');

-- service_booking_event_type_enum preserva a trilha append-only da prestacao.
CREATE TYPE service_booking_event_type_enum AS ENUM ('REQUESTED', 'QUOTED', 'CONFIRMED', 'CHECKIN', 'STARTED', 'COMPLETED', 'CANCELLED', 'DISPUTE_OPENED');

-- health_profile_status_enum guarda o estado do perfil clinico resumido.
CREATE TYPE health_profile_status_enum AS ENUM ('ACTIVE', 'RESTRICTED', 'ARCHIVED');

-- health_care_plan_status_enum controla o lifecycle do plano de cuidado.
CREATE TYPE health_care_plan_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED', 'ARCHIVED');

-- health_prescription_status_enum controla a validade e dispensacao da prescricao.
CREATE TYPE health_prescription_status_enum AS ENUM ('ISSUED', 'PARTIALLY_DISPENSED', 'FULLY_DISPENSED', 'EXPIRED', 'CANCELLED', 'REVOKED');

-- job_posting_status_enum controla a vaga desde rascunho ate arquivamento.
CREATE TYPE job_posting_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'FILLED', 'CANCELLED', 'ARCHIVED');

-- job_employment_type_enum classifica o modelo de contratacao.
CREATE TYPE job_employment_type_enum AS ENUM ('FULL_TIME', 'PART_TIME', 'CONTRACT', 'GIG', 'FREELANCE', 'INTERNSHIP');

-- job_remote_mode_enum descreve a forma de trabalho.
CREATE TYPE job_remote_mode_enum AS ENUM ('ONSITE', 'HYBRID', 'REMOTE');

-- job_application_status_enum controla a candidatura no pipeline.
CREATE TYPE job_application_status_enum AS ENUM ('SUBMITTED', 'SCREENING', 'SHORTLISTED', 'OFFERED', 'HIRED', 'REJECTED', 'WITHDRAWN');

-- job_engagement_status_enum controla o vinculo de trabalho apos aceite.
CREATE TYPE job_engagement_status_enum AS ENUM ('PENDING_START', 'ACTIVE', 'PAUSED', 'COMPLETED', 'CANCELLED', 'DISPUTED');

-- pharmacy_catalog_status_enum controla catalogo comercial da farmacia.
CREATE TYPE pharmacy_catalog_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'ARCHIVED');

-- pharmacy_item_type_enum classifica medicamento, suplemento ou device.
CREATE TYPE pharmacy_item_type_enum AS ENUM ('MEDICATION', 'SUPPLEMENT', 'DEVICE', 'CONTROLLED_SUBSTANCE');

-- pharmacy_fulfillment_status_enum controla a ordem farmaceutica ate a entrega.
CREATE TYPE pharmacy_fulfillment_status_enum AS ENUM ('PENDING_REVIEW', 'AUTHORIZED', 'PREPARING', 'DISPATCHED', 'DELIVERED', 'REJECTED', 'CANCELLED');

-- pharmacy_dispense_event_type_enum preserva a trilha append-only da dispensacao.
CREATE TYPE pharmacy_dispense_event_type_enum AS ENUM ('RESERVED', 'AUTHORIZED', 'DISPENSED', 'DISPATCHED', 'DELIVERED', 'CANCELLED', 'REVERSED');

-- event_program_status_enum controla publicacao e operacao do evento.
CREATE TYPE event_program_status_enum AS ENUM ('DRAFT', 'PUBLISHED', 'LIVE', 'ENDED', 'CANCELLED', 'ARCHIVED');

-- event_ticket_type_status_enum controla a disponibilidade do lote de ingresso.
CREATE TYPE event_ticket_type_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'SOLD_OUT', 'ARCHIVED');

-- event_ticket_status_enum descreve o estado atual do ingresso na trilha append-only.
CREATE TYPE event_ticket_status_enum AS ENUM ('AVAILABLE', 'HELD', 'SOLD', 'CHECKED_IN', 'REFUNDED', 'VOIDED', 'TRANSFERRED');

-- event_ticket_event_type_enum registra cada mutacao append-only do ingresso.
CREATE TYPE event_ticket_event_type_enum AS ENUM ('MINTED', 'HELD', 'SOLD', 'CHECKED_IN', 'REFUNDED', 'VOIDED', 'TRANSFERRED');

-- service_provider_profiles registra prestadores profissionais e sua wallet operacional.
CREATE TABLE service_provider_profiles (
    provider_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_user_id UUID NOT NULL UNIQUE,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'SERVICES',
    provider_status service_provider_status_enum NOT NULL DEFAULT 'ONBOARDING',
    display_headline TEXT NOT NULL,
    bio_summary TEXT,
    service_radius_km DECIMAL(10,3) NOT NULL DEFAULT 0,
    average_rating NUMERIC(4,2) NOT NULL DEFAULT 0,
    review_count INTEGER NOT NULL DEFAULT 0,
    is_remote_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    accepts_marketplace_leads BOOLEAN NOT NULL DEFAULT TRUE,
    availability_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    compliance_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    legal_contract_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_service_provider_profiles_user
        FOREIGN KEY (provider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_provider_profiles_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_provider_profiles_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_provider_profiles_legal_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_service_provider_profiles_module CHECK (module_code = 'SERVICES'),
    CONSTRAINT chk_service_provider_profiles_headline CHECK (btrim(display_headline) <> ''),
    CONSTRAINT chk_service_provider_profiles_bio CHECK (bio_summary IS NULL OR btrim(bio_summary) <> ''),
    CONSTRAINT chk_service_provider_profiles_radius CHECK (service_radius_km >= 0),
    CONSTRAINT chk_service_provider_profiles_rating CHECK (average_rating >= 0 AND average_rating <= 5),
    CONSTRAINT chk_service_provider_profiles_reviews CHECK (review_count >= 0),
    CONSTRAINT chk_service_provider_profiles_availability_json CHECK (jsonb_typeof(availability_json) = 'object'),
    CONSTRAINT chk_service_provider_profiles_compliance_json CHECK (jsonb_typeof(compliance_json) = 'object')
);

-- service_catalog_services publica os servicos ofertados pelo prestador.
CREATE TABLE service_catalog_services (
    service_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider_profile_id UUID NOT NULL,
    provider_user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'SERVICES',
    service_code TEXT NOT NULL,
    service_title TEXT NOT NULL,
    category_code TEXT NOT NULL,
    catalog_status service_catalog_status_enum NOT NULL DEFAULT 'DRAFT',
    booking_mode service_booking_mode_enum NOT NULL DEFAULT 'SCHEDULED',
    base_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    max_price_brl DECIMAL(18,4),
    estimated_duration_minutes INTEGER,
    remote_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    onsite_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    location_policy_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    requirements_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_service_catalog_services_profile
        FOREIGN KEY (provider_profile_id) REFERENCES service_provider_profiles (provider_profile_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_catalog_services_user
        FOREIGN KEY (provider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_catalog_services_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_service_catalog_services_code UNIQUE (provider_user_id, service_code),
    CONSTRAINT chk_service_catalog_services_module CHECK (module_code = 'SERVICES'),
    CONSTRAINT chk_service_catalog_services_code CHECK (service_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_service_catalog_services_title CHECK (btrim(service_title) <> ''),
    CONSTRAINT chk_service_catalog_services_category CHECK (category_code ~ '^[A-Z0-9_]{2,80}$'),
    CONSTRAINT chk_service_catalog_services_prices CHECK (
        base_price_brl >= 0
        AND (max_price_brl IS NULL OR max_price_brl >= base_price_brl)
    ),
    CONSTRAINT chk_service_catalog_services_duration CHECK (
        estimated_duration_minutes IS NULL OR estimated_duration_minutes > 0
    ),
    CONSTRAINT chk_service_catalog_services_mode CHECK (remote_enabled OR onsite_enabled),
    CONSTRAINT chk_service_catalog_services_location_json CHECK (jsonb_typeof(location_policy_json) = 'object'),
    CONSTRAINT chk_service_catalog_services_requirements_json CHECK (jsonb_typeof(requirements_json) = 'object'),
    CONSTRAINT chk_service_catalog_services_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

-- service_bookings registra a contratacao do servico usando order domain SERVICES.
CREATE TABLE service_bookings (
    booking_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE,
    service_id UUID NOT NULL,
    provider_user_id UUID NOT NULL,
    customer_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'SERVICES',
    booking_status service_booking_status_enum NOT NULL DEFAULT 'REQUESTED',
    quote_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    final_amount_brl DECIMAL(18,4),
    scheduled_start_at TIMESTAMPTZ,
    scheduled_end_at TIMESTAMPTZ,
    service_address_json JSONB,
    remote_session_url TEXT,
    related_legal_contract_id UUID,
    checkin_code_hash TEXT,
    checked_in_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    notes TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_service_bookings_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_bookings_service
        FOREIGN KEY (service_id) REFERENCES service_catalog_services (service_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_bookings_provider
        FOREIGN KEY (provider_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_bookings_customer
        FOREIGN KEY (customer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_bookings_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_bookings_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_bookings_legal_contract
        FOREIGN KEY (related_legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_service_bookings_module CHECK (module_code = 'SERVICES'),
    CONSTRAINT chk_service_bookings_distinct_users CHECK (provider_user_id <> customer_user_id),
    CONSTRAINT chk_service_bookings_amounts CHECK (
        quote_amount_brl >= 0
        AND (final_amount_brl IS NULL OR final_amount_brl >= 0)
    ),
    CONSTRAINT chk_service_bookings_address_json CHECK (
        service_address_json IS NULL OR jsonb_typeof(service_address_json) = 'object'
    ),
    CONSTRAINT chk_service_bookings_remote_url CHECK (
        remote_session_url IS NULL OR remote_session_url ~ '^https://'
    ),
    CONSTRAINT chk_service_bookings_checkin_hash CHECK (
        checkin_code_hash IS NULL OR checkin_code_hash ~ '^[a-fA-F0-9]{64}$'
    ),
    CONSTRAINT chk_service_bookings_cancellation_reason CHECK (
        cancellation_reason IS NULL OR btrim(cancellation_reason) <> ''
    ),
    CONSTRAINT chk_service_bookings_notes CHECK (notes IS NULL OR btrim(notes) <> ''),
    CONSTRAINT chk_service_bookings_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_service_bookings_timeline CHECK (
        (scheduled_end_at IS NULL OR scheduled_start_at IS NULL OR scheduled_end_at >= scheduled_start_at)
        AND (checked_in_at IS NULL OR scheduled_start_at IS NULL OR checked_in_at >= scheduled_start_at - INTERVAL '2 hours')
        AND (started_at IS NULL OR checked_in_at IS NULL OR started_at >= checked_in_at)
        AND (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at)
        AND (cancelled_at IS NULL OR scheduled_start_at IS NULL OR cancelled_at >= scheduled_start_at - INTERVAL '24 hours')
    ),
    CONSTRAINT chk_service_bookings_status_dates CHECK (
        (booking_status <> 'COMPLETED' OR completed_at IS NOT NULL)
        AND (booking_status <> 'CANCELLED' OR cancelled_at IS NOT NULL)
    )
);

-- service_booking_events preserva a trilha append-only da prestacao.
CREATE TABLE service_booking_events (
    booking_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL,
    order_id UUID NOT NULL,
    actor_user_id UUID,
    event_type service_booking_event_type_enum NOT NULL,
    booking_status service_booking_status_enum NOT NULL,
    notes TEXT,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_service_booking_events_booking
        FOREIGN KEY (booking_id) REFERENCES service_bookings (booking_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_booking_events_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_service_booking_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_service_booking_events_notes CHECK (notes IS NULL OR btrim(notes) <> ''),
    CONSTRAINT chk_service_booking_events_payload_json CHECK (jsonb_typeof(payload_json) = 'object')
);

-- health_profiles guarda resumo sensivel e minimizado do contexto clinico do usuario.
CREATE TABLE health_profiles (
    health_profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    module_code TEXT NOT NULL DEFAULT 'HEALTH',
    primary_care_user_id UUID,
    profile_status health_profile_status_enum NOT NULL DEFAULT 'ACTIVE',
    blood_type TEXT,
    allergy_summary TEXT,
    chronic_conditions_summary TEXT,
    emergency_notes TEXT,
    consent_json JSONB NOT NULL DEFAULT '{"share_with_pharmacy":false,"share_with_advisor":false}'::JSONB,
    risk_flags_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    last_reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_health_profiles_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_health_profiles_primary_care
        FOREIGN KEY (primary_care_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_health_profiles_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_health_profiles_module CHECK (module_code = 'HEALTH'),
    CONSTRAINT chk_health_profiles_distinct_users CHECK (
        primary_care_user_id IS NULL OR primary_care_user_id <> user_id
    ),
    CONSTRAINT chk_health_profiles_blood_type CHECK (
        blood_type IS NULL OR blood_type IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')
    ),
    CONSTRAINT chk_health_profiles_allergy_summary CHECK (
        allergy_summary IS NULL OR btrim(allergy_summary) <> ''
    ),
    CONSTRAINT chk_health_profiles_conditions_summary CHECK (
        chronic_conditions_summary IS NULL OR btrim(chronic_conditions_summary) <> ''
    ),
    CONSTRAINT chk_health_profiles_emergency_notes CHECK (
        emergency_notes IS NULL OR btrim(emergency_notes) <> ''
    ),
    CONSTRAINT chk_health_profiles_consent_json CHECK (jsonb_typeof(consent_json) = 'object'),
    CONSTRAINT chk_health_profiles_risk_flags_json CHECK (jsonb_typeof(risk_flags_json) = 'object')
);

-- health_care_plans registra planos de cuidado e acompanhamento.
CREATE TABLE health_care_plans (
    care_plan_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_user_id UUID NOT NULL,
    professional_user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'HEALTH',
    plan_status health_care_plan_status_enum NOT NULL DEFAULT 'DRAFT',
    plan_title TEXT NOT NULL,
    goal_summary TEXT NOT NULL,
    care_plan_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    source_session_id UUID,
    started_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    next_review_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_health_care_plans_patient
        FOREIGN KEY (patient_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_health_care_plans_professional
        FOREIGN KEY (professional_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_health_care_plans_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_health_care_plans_session
        FOREIGN KEY (source_session_id) REFERENCES teletherapy_sessions (session_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_health_care_plans_module CHECK (module_code = 'HEALTH'),
    CONSTRAINT chk_health_care_plans_distinct_users CHECK (patient_user_id <> professional_user_id),
    CONSTRAINT chk_health_care_plans_title CHECK (btrim(plan_title) <> ''),
    CONSTRAINT chk_health_care_plans_goal_summary CHECK (btrim(goal_summary) <> ''),
    CONSTRAINT chk_health_care_plans_plan_json CHECK (jsonb_typeof(care_plan_json) = 'object'),
    CONSTRAINT chk_health_care_plans_timeline CHECK (
        (ends_at IS NULL OR started_at IS NULL OR ends_at >= started_at)
        AND (next_review_at IS NULL OR started_at IS NULL OR next_review_at >= started_at)
    )
);

-- health_prescriptions registra prescricoes resumidas e referenciaveis pela farmacia.
CREATE TABLE health_prescriptions (
    prescription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_user_id UUID NOT NULL,
    prescriber_user_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'HEALTH',
    document_id UUID,
    prescription_status health_prescription_status_enum NOT NULL DEFAULT 'ISSUED',
    prescription_code TEXT NOT NULL UNIQUE,
    medication_summary_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    guidance_text TEXT,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMPTZ NOT NULL,
    refill_count SMALLINT NOT NULL DEFAULT 0,
    controlled_substance BOOLEAN NOT NULL DEFAULT FALSE,
    last_dispensed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_health_prescriptions_patient
        FOREIGN KEY (patient_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_health_prescriptions_prescriber
        FOREIGN KEY (prescriber_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_health_prescriptions_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_health_prescriptions_document
        FOREIGN KEY (document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_health_prescriptions_module CHECK (module_code = 'HEALTH'),
    CONSTRAINT chk_health_prescriptions_distinct_users CHECK (patient_user_id <> prescriber_user_id),
    CONSTRAINT chk_health_prescriptions_code CHECK (prescription_code ~ '^[A-Z0-9_-]{6,80}$'),
    CONSTRAINT chk_health_prescriptions_medication_json CHECK (jsonb_typeof(medication_summary_json) = 'object'),
    CONSTRAINT chk_health_prescriptions_guidance CHECK (guidance_text IS NULL OR btrim(guidance_text) <> ''),
    CONSTRAINT chk_health_prescriptions_refill_count CHECK (refill_count >= 0),
    CONSTRAINT chk_health_prescriptions_validity CHECK (valid_until > issued_at),
    CONSTRAINT chk_health_prescriptions_last_dispensed CHECK (
        last_dispensed_at IS NULL OR last_dispensed_at >= issued_at
    )
);

-- job_postings registra vagas e gigs financiadas por employer wallet.
CREATE TABLE job_postings (
    job_posting_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employer_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'JOBS',
    posting_status job_posting_status_enum NOT NULL DEFAULT 'DRAFT',
    employment_type job_employment_type_enum NOT NULL,
    remote_mode job_remote_mode_enum NOT NULL DEFAULT 'ONSITE',
    title TEXT NOT NULL,
    role_summary TEXT NOT NULL,
    location_json JSONB,
    compensation_min_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    compensation_max_brl DECIMAL(18,4),
    currency_code CHAR(3) NOT NULL DEFAULT 'BRL',
    openings_count SMALLINT NOT NULL DEFAULT 1,
    expires_at TIMESTAMPTZ,
    requirements_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_job_postings_employer
        FOREIGN KEY (employer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_job_postings_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_job_postings_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_job_postings_module CHECK (module_code = 'JOBS'),
    CONSTRAINT chk_job_postings_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_job_postings_summary CHECK (btrim(role_summary) <> ''),
    CONSTRAINT chk_job_postings_location_json CHECK (
        location_json IS NULL OR jsonb_typeof(location_json) = 'object'
    ),
    CONSTRAINT chk_job_postings_compensation CHECK (
        compensation_min_brl >= 0
        AND (compensation_max_brl IS NULL OR compensation_max_brl >= compensation_min_brl)
    ),
    CONSTRAINT chk_job_postings_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_job_postings_openings CHECK (openings_count > 0),
    CONSTRAINT chk_job_postings_requirements_json CHECK (jsonb_typeof(requirements_json) = 'object'),
    CONSTRAINT chk_job_postings_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_job_postings_expiration CHECK (expires_at IS NULL OR expires_at > created_at)
);

-- job_applications registra a candidatura do usuario para uma vaga.
CREATE TABLE job_applications (
    job_application_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_posting_id UUID NOT NULL,
    candidate_user_id UUID NOT NULL,
    application_status job_application_status_enum NOT NULL DEFAULT 'SUBMITTED',
    resume_document_id UUID,
    cover_note TEXT,
    profile_snapshot_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_job_applications_posting
        FOREIGN KEY (job_posting_id) REFERENCES job_postings (job_posting_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_job_applications_candidate
        FOREIGN KEY (candidate_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_job_applications_resume
        FOREIGN KEY (resume_document_id) REFERENCES document_records (document_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT ux_job_applications_candidate UNIQUE (job_posting_id, candidate_user_id),
    CONSTRAINT chk_job_applications_cover_note CHECK (cover_note IS NULL OR btrim(cover_note) <> ''),
    CONSTRAINT chk_job_applications_profile_json CHECK (jsonb_typeof(profile_snapshot_json) = 'object')
);

-- job_engagements registra o vinculo contratado apos uma candidatura aceita.
CREATE TABLE job_engagements (
    job_engagement_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_posting_id UUID NOT NULL,
    job_application_id UUID UNIQUE,
    employer_user_id UUID NOT NULL,
    worker_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    transaction_id UUID,
    legal_contract_id UUID,
    module_code TEXT NOT NULL DEFAULT 'JOBS',
    engagement_status job_engagement_status_enum NOT NULL DEFAULT 'PENDING_START',
    agreed_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    settlement_cycle TEXT NOT NULL DEFAULT 'MONTHLY',
    settlement_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    scheduled_start_at TIMESTAMPTZ,
    actual_start_at TIMESTAMPTZ,
    actual_end_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_job_engagements_posting
        FOREIGN KEY (job_posting_id) REFERENCES job_postings (job_posting_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_job_engagements_application
        FOREIGN KEY (job_application_id) REFERENCES job_applications (job_application_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_job_engagements_employer
        FOREIGN KEY (employer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_job_engagements_worker
        FOREIGN KEY (worker_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_job_engagements_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_job_engagements_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_job_engagements_legal_contract
        FOREIGN KEY (legal_contract_id) REFERENCES legal_contracts (legal_contract_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_job_engagements_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_job_engagements_module CHECK (module_code = 'JOBS'),
    CONSTRAINT chk_job_engagements_distinct_users CHECK (employer_user_id <> worker_user_id),
    CONSTRAINT chk_job_engagements_amount CHECK (agreed_amount_brl >= 0),
    CONSTRAINT chk_job_engagements_cycle CHECK (btrim(settlement_cycle) <> ''),
    CONSTRAINT chk_job_engagements_settlement_json CHECK (jsonb_typeof(settlement_json) = 'object'),
    CONSTRAINT chk_job_engagements_cancellation_reason CHECK (
        cancellation_reason IS NULL OR btrim(cancellation_reason) <> ''
    ),
    CONSTRAINT chk_job_engagements_timeline CHECK (
        (actual_start_at IS NULL OR scheduled_start_at IS NULL OR actual_start_at >= scheduled_start_at - INTERVAL '30 days')
        AND (actual_end_at IS NULL OR actual_start_at IS NULL OR actual_end_at >= actual_start_at)
        AND (cancelled_at IS NULL OR scheduled_start_at IS NULL OR cancelled_at >= scheduled_start_at - INTERVAL '30 days')
    ),
    CONSTRAINT chk_job_engagements_status_dates CHECK (
        (engagement_status <> 'COMPLETED' OR actual_end_at IS NOT NULL)
        AND (engagement_status <> 'CANCELLED' OR cancelled_at IS NOT NULL)
    )
);

-- pharmacy_catalog_items registra itens farmaceuticos vendiveis ou controlados.
CREATE TABLE pharmacy_catalog_items (
    pharmacy_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pharmacy_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    inventory_item_id UUID,
    module_code TEXT NOT NULL DEFAULT 'PHARMACY',
    catalog_status pharmacy_catalog_status_enum NOT NULL DEFAULT 'DRAFT',
    item_code TEXT NOT NULL,
    item_name TEXT NOT NULL,
    item_type pharmacy_item_type_enum NOT NULL DEFAULT 'MEDICATION',
    requires_prescription BOOLEAN NOT NULL DEFAULT FALSE,
    anvisa_code TEXT,
    price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    available_quantity INTEGER NOT NULL DEFAULT 0,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_pharmacy_catalog_items_user
        FOREIGN KEY (pharmacy_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pharmacy_catalog_items_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pharmacy_catalog_items_inventory
        FOREIGN KEY (inventory_item_id) REFERENCES inventory_items (item_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_pharmacy_catalog_items_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_pharmacy_catalog_items_code UNIQUE (pharmacy_user_id, item_code),
    CONSTRAINT chk_pharmacy_catalog_items_module CHECK (module_code = 'PHARMACY'),
    CONSTRAINT chk_pharmacy_catalog_items_code CHECK (item_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_pharmacy_catalog_items_name CHECK (btrim(item_name) <> ''),
    CONSTRAINT chk_pharmacy_catalog_items_anvisa CHECK (
        anvisa_code IS NULL OR anvisa_code ~ '^[A-Z0-9_-]{4,64}$'
    ),
    CONSTRAINT chk_pharmacy_catalog_items_values CHECK (price_brl >= 0 AND available_quantity >= 0),
    CONSTRAINT chk_pharmacy_catalog_items_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

-- pharmacy_fulfillments registra o fluxo farmaceutico ligado a order PHARMACY.
CREATE TABLE pharmacy_fulfillments (
    pharmacy_fulfillment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL UNIQUE,
    patient_user_id UUID NOT NULL,
    pharmacy_user_id UUID NOT NULL,
    pharmacist_user_id UUID,
    wallet_id UUID NOT NULL,
    prescription_id UUID,
    module_code TEXT NOT NULL DEFAULT 'PHARMACY',
    fulfillment_status pharmacy_fulfillment_status_enum NOT NULL DEFAULT 'PENDING_REVIEW',
    requires_id_check BOOLEAN NOT NULL DEFAULT TRUE,
    controlled_substance BOOLEAN NOT NULL DEFAULT FALSE,
    total_amount_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    reviewed_at TIMESTAMPTZ,
    dispensed_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_pharmacy_fulfillments_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pharmacy_fulfillments_patient
        FOREIGN KEY (patient_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pharmacy_fulfillments_pharmacy
        FOREIGN KEY (pharmacy_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pharmacy_fulfillments_pharmacist
        FOREIGN KEY (pharmacist_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_pharmacy_fulfillments_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pharmacy_fulfillments_prescription
        FOREIGN KEY (prescription_id) REFERENCES health_prescriptions (prescription_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT fk_pharmacy_fulfillments_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_pharmacy_fulfillments_module CHECK (module_code = 'PHARMACY'),
    CONSTRAINT chk_pharmacy_fulfillments_users CHECK (
        patient_user_id <> pharmacy_user_id
        AND (pharmacist_user_id IS NULL OR pharmacist_user_id <> patient_user_id)
    ),
    CONSTRAINT chk_pharmacy_fulfillments_amount CHECK (total_amount_brl >= 0),
    CONSTRAINT chk_pharmacy_fulfillments_cancellation_reason CHECK (
        cancellation_reason IS NULL OR btrim(cancellation_reason) <> ''
    ),
    CONSTRAINT chk_pharmacy_fulfillments_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_pharmacy_fulfillments_timeline CHECK (
        (dispensed_at IS NULL OR reviewed_at IS NULL OR dispensed_at >= reviewed_at)
        AND (delivered_at IS NULL OR dispensed_at IS NULL OR delivered_at >= dispensed_at)
        AND (cancelled_at IS NULL OR reviewed_at IS NULL OR cancelled_at >= reviewed_at)
    ),
    CONSTRAINT chk_pharmacy_fulfillments_status_dates CHECK (
        (fulfillment_status <> 'DELIVERED' OR delivered_at IS NOT NULL)
        AND (fulfillment_status <> 'CANCELLED' OR cancelled_at IS NOT NULL)
    )
);

-- pharmacy_fulfillment_items registra as linhas dispensadas por order farmaceutica.
CREATE TABLE pharmacy_fulfillment_items (
    pharmacy_fulfillment_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pharmacy_fulfillment_id UUID NOT NULL,
    pharmacy_item_id UUID NOT NULL,
    quantity_requested INTEGER NOT NULL DEFAULT 1,
    quantity_authorized INTEGER NOT NULL DEFAULT 0,
    quantity_dispensed INTEGER NOT NULL DEFAULT 0,
    unit_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    line_total_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_pharmacy_fulfillment_items_fulfillment
        FOREIGN KEY (pharmacy_fulfillment_id) REFERENCES pharmacy_fulfillments (pharmacy_fulfillment_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_pharmacy_fulfillment_items_item
        FOREIGN KEY (pharmacy_item_id) REFERENCES pharmacy_catalog_items (pharmacy_item_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_pharmacy_fulfillment_items_quantities CHECK (
        quantity_requested > 0
        AND quantity_authorized >= 0
        AND quantity_dispensed >= 0
        AND quantity_authorized <= quantity_requested
        AND quantity_dispensed <= quantity_authorized
    ),
    CONSTRAINT chk_pharmacy_fulfillment_items_prices CHECK (
        unit_price_brl >= 0
        AND line_total_brl >= 0
    )
);

-- pharmacy_dispense_events preserva a trilha append-only da dispensacao.
CREATE TABLE pharmacy_dispense_events (
    pharmacy_dispense_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pharmacy_fulfillment_id UUID NOT NULL,
    order_id UUID NOT NULL,
    actor_user_id UUID,
    event_type pharmacy_dispense_event_type_enum NOT NULL,
    notes TEXT,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_pharmacy_dispense_events_fulfillment
        FOREIGN KEY (pharmacy_fulfillment_id) REFERENCES pharmacy_fulfillments (pharmacy_fulfillment_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pharmacy_dispense_events_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_pharmacy_dispense_events_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_pharmacy_dispense_events_notes CHECK (notes IS NULL OR btrim(notes) <> ''),
    CONSTRAINT chk_pharmacy_dispense_events_payload_json CHECK (jsonb_typeof(payload_json) = 'object')
);

-- event_programs registra o evento/experiencia e sua wallet organizadora.
CREATE TABLE event_programs (
    event_program_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organizer_user_id UUID NOT NULL,
    wallet_id UUID NOT NULL,
    module_code TEXT NOT NULL DEFAULT 'EVENTS',
    event_status event_program_status_enum NOT NULL DEFAULT 'DRAFT',
    title TEXT NOT NULL,
    venue_name TEXT,
    venue_json JSONB,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    sales_start_at TIMESTAMPTZ,
    sales_end_at TIMESTAMPTZ,
    max_capacity INTEGER,
    age_rating TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_event_programs_organizer
        FOREIGN KEY (organizer_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_event_programs_wallet
        FOREIGN KEY (wallet_id) REFERENCES wallets (wallet_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_event_programs_module
        FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT chk_event_programs_module CHECK (module_code = 'EVENTS'),
    CONSTRAINT chk_event_programs_title CHECK (btrim(title) <> ''),
    CONSTRAINT chk_event_programs_venue_name CHECK (venue_name IS NULL OR btrim(venue_name) <> ''),
    CONSTRAINT chk_event_programs_venue_json CHECK (
        venue_json IS NULL OR jsonb_typeof(venue_json) = 'object'
    ),
    CONSTRAINT chk_event_programs_capacity CHECK (max_capacity IS NULL OR max_capacity > 0),
    CONSTRAINT chk_event_programs_age_rating CHECK (age_rating IS NULL OR btrim(age_rating) <> ''),
    CONSTRAINT chk_event_programs_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object'),
    CONSTRAINT chk_event_programs_timeline CHECK (
        ends_at > starts_at
        AND (sales_start_at IS NULL OR sales_start_at <= starts_at)
        AND (sales_end_at IS NULL OR sales_start_at IS NULL OR sales_end_at >= sales_start_at)
        AND (sales_end_at IS NULL OR sales_end_at <= ends_at)
    )
);

-- event_ticket_types registra lotes e configuracao comercial do ingresso.
CREATE TABLE event_ticket_types (
    event_ticket_type_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_program_id UUID NOT NULL,
    ticket_type_status event_ticket_type_status_enum NOT NULL DEFAULT 'DRAFT',
    ticket_name TEXT NOT NULL,
    batch_code TEXT NOT NULL,
    unit_price_brl DECIMAL(18,4) NOT NULL DEFAULT 0,
    inventory_total INTEGER NOT NULL,
    inventory_available INTEGER NOT NULL,
    max_per_order SMALLINT NOT NULL DEFAULT 10,
    is_transferable BOOLEAN NOT NULL DEFAULT FALSE,
    sales_start_at TIMESTAMPTZ,
    sales_end_at TIMESTAMPTZ,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_event_ticket_types_program
        FOREIGN KEY (event_program_id) REFERENCES event_programs (event_program_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT ux_event_ticket_types_batch UNIQUE (event_program_id, batch_code),
    CONSTRAINT chk_event_ticket_types_name CHECK (btrim(ticket_name) <> ''),
    CONSTRAINT chk_event_ticket_types_batch CHECK (batch_code ~ '^[A-Z0-9_-]{2,80}$'),
    CONSTRAINT chk_event_ticket_types_prices CHECK (unit_price_brl >= 0),
    CONSTRAINT chk_event_ticket_types_inventory CHECK (
        inventory_total > 0
        AND inventory_available >= 0
        AND inventory_available <= inventory_total
    ),
    CONSTRAINT chk_event_ticket_types_max_per_order CHECK (max_per_order > 0),
    CONSTRAINT chk_event_ticket_types_window CHECK (
        sales_end_at IS NULL OR sales_start_at IS NULL OR sales_end_at >= sales_start_at
    ),
    CONSTRAINT chk_event_ticket_types_metadata_json CHECK (jsonb_typeof(metadata_json) = 'object')
);

-- event_ticket_ledger preserva a trilha append-only de cada ingresso.
CREATE TABLE event_ticket_ledger (
    event_ticket_ledger_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_instance_id UUID NOT NULL,
    event_program_id UUID NOT NULL,
    event_ticket_type_id UUID NOT NULL,
    order_id UUID,
    holder_user_id UUID NOT NULL,
    actor_user_id UUID,
    transaction_id UUID,
    ticket_code TEXT NOT NULL,
    qr_hash_sha256 TEXT NOT NULL,
    ticket_status event_ticket_status_enum NOT NULL,
    event_type event_ticket_event_type_enum NOT NULL,
    seat_label TEXT,
    payload_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_event_ticket_ledger_program
        FOREIGN KEY (event_program_id) REFERENCES event_programs (event_program_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_event_ticket_ledger_type
        FOREIGN KEY (event_ticket_type_id) REFERENCES event_ticket_types (event_ticket_type_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_event_ticket_ledger_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_event_ticket_ledger_holder
        FOREIGN KEY (holder_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_event_ticket_ledger_actor
        FOREIGN KEY (actor_user_id) REFERENCES users (user_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,
    CONSTRAINT fk_event_ticket_ledger_transaction
        FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
    CONSTRAINT chk_event_ticket_ledger_code CHECK (ticket_code ~ '^[A-Z0-9_-]{6,120}$'),
    CONSTRAINT chk_event_ticket_ledger_qr_hash CHECK (qr_hash_sha256 ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT chk_event_ticket_ledger_seat CHECK (seat_label IS NULL OR btrim(seat_label) <> ''),
    CONSTRAINT chk_event_ticket_ledger_payload_json CHECK (jsonb_typeof(payload_json) = 'object')
);

CREATE INDEX ix_service_provider_profiles_status
    ON service_provider_profiles (provider_status, updated_at);

CREATE INDEX ix_service_catalog_services_provider_status
    ON service_catalog_services (provider_user_id, catalog_status, updated_at);

CREATE INDEX ix_service_catalog_services_active
    ON service_catalog_services (category_code, updated_at)
    WHERE catalog_status = 'ACTIVE';

CREATE INDEX ix_service_bookings_customer_status
    ON service_bookings (customer_user_id, booking_status, scheduled_start_at);

CREATE INDEX ix_service_bookings_provider_status
    ON service_bookings (provider_user_id, booking_status, scheduled_start_at);

CREATE INDEX ix_service_booking_events_booking_time
    ON service_booking_events (booking_id, occurred_at);

CREATE INDEX ix_health_care_plans_patient_status
    ON health_care_plans (patient_user_id, plan_status, next_review_at);

CREATE INDEX ix_health_prescriptions_patient_status
    ON health_prescriptions (patient_user_id, prescription_status, valid_until);

CREATE INDEX ix_health_prescriptions_valid
    ON health_prescriptions (valid_until)
    WHERE prescription_status IN ('ISSUED', 'PARTIALLY_DISPENSED');

CREATE INDEX ix_job_postings_employer_status
    ON job_postings (employer_user_id, posting_status, expires_at);

CREATE INDEX ix_job_postings_active
    ON job_postings (employment_type, remote_mode, expires_at)
    WHERE posting_status = 'ACTIVE';

CREATE INDEX ix_job_applications_candidate_status
    ON job_applications (candidate_user_id, application_status, applied_at);

CREATE INDEX ix_job_applications_posting_status
    ON job_applications (job_posting_id, application_status, applied_at);

CREATE INDEX ix_job_engagements_employer_status
    ON job_engagements (employer_user_id, engagement_status, created_at);

CREATE INDEX ix_job_engagements_worker_status
    ON job_engagements (worker_user_id, engagement_status, created_at);

CREATE INDEX ix_pharmacy_catalog_items_pharmacy_status
    ON pharmacy_catalog_items (pharmacy_user_id, catalog_status, updated_at);

CREATE INDEX ix_pharmacy_catalog_items_active
    ON pharmacy_catalog_items (requires_prescription, item_type, updated_at)
    WHERE catalog_status = 'ACTIVE';

CREATE INDEX ix_pharmacy_fulfillments_patient_status
    ON pharmacy_fulfillments (patient_user_id, fulfillment_status, created_at);

CREATE INDEX ix_pharmacy_fulfillments_pharmacy_status
    ON pharmacy_fulfillments (pharmacy_user_id, fulfillment_status, created_at);

CREATE INDEX ix_pharmacy_dispense_events_fulfillment_time
    ON pharmacy_dispense_events (pharmacy_fulfillment_id, occurred_at);

CREATE INDEX ix_event_programs_organizer_status
    ON event_programs (organizer_user_id, event_status, starts_at);

CREATE INDEX ix_event_programs_live
    ON event_programs (starts_at, ends_at)
    WHERE event_status IN ('PUBLISHED', 'LIVE');

CREATE INDEX ix_event_ticket_types_program_status
    ON event_ticket_types (event_program_id, ticket_type_status, sales_end_at);

CREATE INDEX ix_event_ticket_ledger_ticket_instance
    ON event_ticket_ledger (ticket_instance_id, occurred_at);

CREATE INDEX ix_event_ticket_ledger_program_time
    ON event_ticket_ledger (event_program_id, occurred_at);

CREATE UNIQUE INDEX ux_event_ticket_ledger_ticket_code_minted
    ON event_ticket_ledger (ticket_code)
    WHERE event_type = 'MINTED';

CREATE INDEX ix_event_ticket_ledger_order
    ON event_ticket_ledger (order_id, occurred_at)
    WHERE order_id IS NOT NULL;

-- assert_release_wallet_owner valida dono e ativo da wallet usada em modulos core deste release.
CREATE OR REPLACE FUNCTION assert_release_wallet_owner(expected_user_id UUID, wallet_to_check UUID, context_name TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    wallet_owner_id UUID;
BEGIN
    SELECT user_id
      INTO wallet_owner_id
      FROM wallets
     WHERE wallet_id = wallet_to_check;

    IF wallet_owner_id IS NULL THEN
        RAISE EXCEPTION 'Wallet % does not exist for %', wallet_to_check, context_name;
    END IF;

    IF wallet_owner_id <> expected_user_id THEN
        RAISE EXCEPTION 'Wallet owner % differs from expected user % for %', wallet_owner_id, expected_user_id, context_name;
    END IF;
END;
$$;

-- assert_service_catalog_coherence garante que o service referencia o mesmo usuario do provider profile.
CREATE OR REPLACE FUNCTION assert_service_catalog_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    expected_provider_user_id UUID;
BEGIN
    SELECT provider_user_id
      INTO expected_provider_user_id
      FROM service_provider_profiles
     WHERE provider_profile_id = NEW.provider_profile_id;

    IF expected_provider_user_id IS NULL THEN
        RAISE EXCEPTION 'Provider profile % does not exist for service %', NEW.provider_profile_id, NEW.service_id;
    END IF;

    IF expected_provider_user_id <> NEW.provider_user_id THEN
        RAISE EXCEPTION 'Service provider user % differs from provider profile user %', NEW.provider_user_id, expected_provider_user_id;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_service_booking_coherence garante order SERVICES, wallet do cliente e provider coerente com o catalogo.
CREATE OR REPLACE FUNCTION assert_service_booking_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    order_user_id UUID;
    order_wallet_id UUID;
    order_domain_value order_domain_enum;
    order_merchant_user_id UUID;
    service_provider_user_id UUID;
BEGIN
    SELECT user_id, wallet_id, order_domain, merchant_user_id
      INTO order_user_id, order_wallet_id, order_domain_value, order_merchant_user_id
      FROM orders
     WHERE order_id = NEW.order_id;

    IF order_user_id IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist for service booking %', NEW.order_id, NEW.booking_id;
    END IF;

    IF order_domain_value <> 'SERVICES' THEN
        RAISE EXCEPTION 'Service booking requires SERVICES order. Found % for order %', order_domain_value, NEW.order_id;
    END IF;

    IF order_user_id <> NEW.customer_user_id THEN
        RAISE EXCEPTION 'Service booking customer % differs from order user %', NEW.customer_user_id, order_user_id;
    END IF;

    IF order_wallet_id <> NEW.wallet_id THEN
        RAISE EXCEPTION 'Service booking wallet % differs from order wallet %', NEW.wallet_id, order_wallet_id;
    END IF;

    SELECT provider_user_id
      INTO service_provider_user_id
      FROM service_catalog_services
     WHERE service_id = NEW.service_id;

    IF service_provider_user_id IS NULL THEN
        RAISE EXCEPTION 'Service % does not exist for booking %', NEW.service_id, NEW.booking_id;
    END IF;

    IF service_provider_user_id <> NEW.provider_user_id THEN
        RAISE EXCEPTION 'Service booking provider % differs from catalog provider %', NEW.provider_user_id, service_provider_user_id;
    END IF;

    IF order_merchant_user_id IS NOT NULL AND order_merchant_user_id <> NEW.provider_user_id THEN
        RAISE EXCEPTION 'Service booking provider % differs from order merchant %', NEW.provider_user_id, order_merchant_user_id;
    END IF;

    PERFORM assert_release_wallet_owner(NEW.customer_user_id, NEW.wallet_id, 'service_bookings');

    RETURN NEW;
END;
$$;

-- assert_service_booking_event_coherence impede evento apontando para order errado.
CREATE OR REPLACE FUNCTION assert_service_booking_event_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    expected_order_id UUID;
BEGIN
    SELECT order_id
      INTO expected_order_id
      FROM service_bookings
     WHERE booking_id = NEW.booking_id;

    IF expected_order_id IS NULL THEN
        RAISE EXCEPTION 'Service booking % does not exist for event %', NEW.booking_id, NEW.booking_event_id;
    END IF;

    IF expected_order_id <> NEW.order_id THEN
        RAISE EXCEPTION 'Service booking event order % differs from booking order %', NEW.order_id, expected_order_id;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_job_posting_wallet_owner garante que a wallet da vaga pertence ao empregador.
CREATE OR REPLACE FUNCTION assert_job_posting_wallet_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM assert_release_wallet_owner(NEW.employer_user_id, NEW.wallet_id, 'job_postings');
    RETURN NEW;
END;
$$;

-- assert_job_application_coherence impede candidatura do proprio employer e garante vaga existente.
CREATE OR REPLACE FUNCTION assert_job_application_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    posting_employer_user_id UUID;
BEGIN
    SELECT employer_user_id
      INTO posting_employer_user_id
      FROM job_postings
     WHERE job_posting_id = NEW.job_posting_id;

    IF posting_employer_user_id IS NULL THEN
        RAISE EXCEPTION 'Job posting % does not exist for application %', NEW.job_posting_id, NEW.job_application_id;
    END IF;

    IF posting_employer_user_id = NEW.candidate_user_id THEN
        RAISE EXCEPTION 'Employer cannot apply to its own job posting %', NEW.job_posting_id;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_job_engagement_coherence garante alinhamento entre vaga, candidatura, worker e wallet do employer.
CREATE OR REPLACE FUNCTION assert_job_engagement_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    posting_employer_user_id UUID;
    application_posting_id UUID;
    application_candidate_user_id UUID;
BEGIN
    SELECT employer_user_id
      INTO posting_employer_user_id
      FROM job_postings
     WHERE job_posting_id = NEW.job_posting_id;

    IF posting_employer_user_id IS NULL THEN
        RAISE EXCEPTION 'Job posting % does not exist for engagement %', NEW.job_posting_id, NEW.job_engagement_id;
    END IF;

    IF posting_employer_user_id <> NEW.employer_user_id THEN
        RAISE EXCEPTION 'Job engagement employer % differs from posting employer %', NEW.employer_user_id, posting_employer_user_id;
    END IF;

    IF NEW.job_application_id IS NOT NULL THEN
        SELECT job_posting_id, candidate_user_id
          INTO application_posting_id, application_candidate_user_id
          FROM job_applications
         WHERE job_application_id = NEW.job_application_id;

        IF application_posting_id IS NULL THEN
            RAISE EXCEPTION 'Job application % does not exist for engagement %', NEW.job_application_id, NEW.job_engagement_id;
        END IF;

        IF application_posting_id <> NEW.job_posting_id THEN
            RAISE EXCEPTION 'Job engagement posting % differs from application posting %', NEW.job_posting_id, application_posting_id;
        END IF;

        IF application_candidate_user_id <> NEW.worker_user_id THEN
            RAISE EXCEPTION 'Job engagement worker % differs from application candidate %', NEW.worker_user_id, application_candidate_user_id;
        END IF;
    END IF;

    PERFORM assert_release_wallet_owner(NEW.employer_user_id, NEW.wallet_id, 'job_engagements');

    RETURN NEW;
END;
$$;

-- assert_pharmacy_catalog_wallet_owner garante que a wallet do catalogo pertence a farmacia.
CREATE OR REPLACE FUNCTION assert_pharmacy_catalog_wallet_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM assert_release_wallet_owner(NEW.pharmacy_user_id, NEW.wallet_id, 'pharmacy_catalog_items');
    RETURN NEW;
END;
$$;

-- assert_pharmacy_fulfillment_coherence garante order PHARMACY, wallet do paciente e prescricao alinhada.
CREATE OR REPLACE FUNCTION assert_pharmacy_fulfillment_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    order_user_id UUID;
    order_wallet_id UUID;
    order_domain_value order_domain_enum;
    order_merchant_user_id UUID;
    prescription_patient_user_id UUID;
BEGIN
    SELECT user_id, wallet_id, order_domain, merchant_user_id
      INTO order_user_id, order_wallet_id, order_domain_value, order_merchant_user_id
      FROM orders
     WHERE order_id = NEW.order_id;

    IF order_user_id IS NULL THEN
        RAISE EXCEPTION 'Order % does not exist for pharmacy fulfillment %', NEW.order_id, NEW.pharmacy_fulfillment_id;
    END IF;

    IF order_domain_value <> 'PHARMACY' THEN
        RAISE EXCEPTION 'Pharmacy fulfillment requires PHARMACY order. Found % for order %', order_domain_value, NEW.order_id;
    END IF;

    IF order_user_id <> NEW.patient_user_id THEN
        RAISE EXCEPTION 'Pharmacy fulfillment patient % differs from order user %', NEW.patient_user_id, order_user_id;
    END IF;

    IF order_wallet_id <> NEW.wallet_id THEN
        RAISE EXCEPTION 'Pharmacy fulfillment wallet % differs from order wallet %', NEW.wallet_id, order_wallet_id;
    END IF;

    IF order_merchant_user_id IS NOT NULL AND order_merchant_user_id <> NEW.pharmacy_user_id THEN
        RAISE EXCEPTION 'Pharmacy fulfillment pharmacy % differs from order merchant %', NEW.pharmacy_user_id, order_merchant_user_id;
    END IF;

    IF NEW.prescription_id IS NOT NULL THEN
        SELECT patient_user_id
          INTO prescription_patient_user_id
          FROM health_prescriptions
         WHERE prescription_id = NEW.prescription_id;

        IF prescription_patient_user_id IS NULL THEN
            RAISE EXCEPTION 'Prescription % does not exist for pharmacy fulfillment %', NEW.prescription_id, NEW.pharmacy_fulfillment_id;
        END IF;

        IF prescription_patient_user_id <> NEW.patient_user_id THEN
            RAISE EXCEPTION 'Prescription patient % differs from fulfillment patient %', prescription_patient_user_id, NEW.patient_user_id;
        END IF;
    END IF;

    PERFORM assert_release_wallet_owner(NEW.patient_user_id, NEW.wallet_id, 'pharmacy_fulfillments');

    RETURN NEW;
END;
$$;

-- assert_pharmacy_fulfillment_item_coherence garante item da mesma farmacia do fulfillment.
CREATE OR REPLACE FUNCTION assert_pharmacy_fulfillment_item_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    fulfillment_pharmacy_user_id UUID;
    item_pharmacy_user_id UUID;
BEGIN
    SELECT pharmacy_user_id
      INTO fulfillment_pharmacy_user_id
      FROM pharmacy_fulfillments
     WHERE pharmacy_fulfillment_id = NEW.pharmacy_fulfillment_id;

    IF fulfillment_pharmacy_user_id IS NULL THEN
        RAISE EXCEPTION 'Pharmacy fulfillment % does not exist for fulfillment item %', NEW.pharmacy_fulfillment_id, NEW.pharmacy_fulfillment_item_id;
    END IF;

    SELECT pharmacy_user_id
      INTO item_pharmacy_user_id
      FROM pharmacy_catalog_items
     WHERE pharmacy_item_id = NEW.pharmacy_item_id;

    IF item_pharmacy_user_id IS NULL THEN
        RAISE EXCEPTION 'Pharmacy catalog item % does not exist for fulfillment item %', NEW.pharmacy_item_id, NEW.pharmacy_fulfillment_item_id;
    END IF;

    IF item_pharmacy_user_id <> fulfillment_pharmacy_user_id THEN
        RAISE EXCEPTION 'Pharmacy item owner % differs from fulfillment pharmacy %', item_pharmacy_user_id, fulfillment_pharmacy_user_id;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_pharmacy_dispense_event_coherence impede evento apontando para order errado.
CREATE OR REPLACE FUNCTION assert_pharmacy_dispense_event_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    expected_order_id UUID;
BEGIN
    SELECT order_id
      INTO expected_order_id
      FROM pharmacy_fulfillments
     WHERE pharmacy_fulfillment_id = NEW.pharmacy_fulfillment_id;

    IF expected_order_id IS NULL THEN
        RAISE EXCEPTION 'Pharmacy fulfillment % does not exist for dispense event %', NEW.pharmacy_fulfillment_id, NEW.pharmacy_dispense_event_id;
    END IF;

    IF expected_order_id <> NEW.order_id THEN
        RAISE EXCEPTION 'Pharmacy dispense event order % differs from fulfillment order %', NEW.order_id, expected_order_id;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_event_program_wallet_owner garante que a wallet do evento pertence ao organizador.
CREATE OR REPLACE FUNCTION assert_event_program_wallet_owner()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM assert_release_wallet_owner(NEW.organizer_user_id, NEW.wallet_id, 'event_programs');
    RETURN NEW;
END;
$$;

-- assert_event_ticket_type_coherence garante que a janela do lote cabe no evento.
CREATE OR REPLACE FUNCTION assert_event_ticket_type_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    program_sales_start_at TIMESTAMPTZ;
    program_sales_end_at TIMESTAMPTZ;
    program_starts_at TIMESTAMPTZ;
    program_ends_at TIMESTAMPTZ;
BEGIN
    SELECT sales_start_at, sales_end_at, starts_at, ends_at
      INTO program_sales_start_at, program_sales_end_at, program_starts_at, program_ends_at
      FROM event_programs
     WHERE event_program_id = NEW.event_program_id;

    IF program_starts_at IS NULL THEN
        RAISE EXCEPTION 'Event program % does not exist for ticket type %', NEW.event_program_id, NEW.event_ticket_type_id;
    END IF;

    IF NEW.sales_start_at IS NOT NULL AND program_sales_start_at IS NOT NULL AND NEW.sales_start_at < program_sales_start_at THEN
        RAISE EXCEPTION 'Ticket type sales_start_at % is earlier than event sales_start_at %', NEW.sales_start_at, program_sales_start_at;
    END IF;

    IF NEW.sales_end_at IS NOT NULL AND program_sales_end_at IS NOT NULL AND NEW.sales_end_at > program_sales_end_at THEN
        RAISE EXCEPTION 'Ticket type sales_end_at % is later than event sales_end_at %', NEW.sales_end_at, program_sales_end_at;
    END IF;

    IF NEW.sales_end_at IS NOT NULL AND NEW.sales_end_at > program_ends_at THEN
        RAISE EXCEPTION 'Ticket type sales_end_at % is later than event end %', NEW.sales_end_at, program_ends_at;
    END IF;

    RETURN NEW;
END;
$$;

-- assert_event_ticket_ledger_coherence garante que o ingresso aponta para o lote e order corretos.
CREATE OR REPLACE FUNCTION assert_event_ticket_ledger_coherence()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    expected_program_id UUID;
    order_domain_value order_domain_enum;
BEGIN
    SELECT event_program_id
      INTO expected_program_id
      FROM event_ticket_types
     WHERE event_ticket_type_id = NEW.event_ticket_type_id;

    IF expected_program_id IS NULL THEN
        RAISE EXCEPTION 'Event ticket type % does not exist for ticket ledger %', NEW.event_ticket_type_id, NEW.event_ticket_ledger_id;
    END IF;

    IF expected_program_id <> NEW.event_program_id THEN
        RAISE EXCEPTION 'Event ticket ledger program % differs from ticket type program %', NEW.event_program_id, expected_program_id;
    END IF;

    IF NEW.order_id IS NOT NULL THEN
        SELECT order_domain
          INTO order_domain_value
          FROM orders
         WHERE order_id = NEW.order_id;

        IF order_domain_value IS NULL THEN
            RAISE EXCEPTION 'Order % does not exist for event ticket ledger %', NEW.order_id, NEW.event_ticket_ledger_id;
        END IF;

        IF order_domain_value <> 'EVENTS' THEN
            RAISE EXCEPTION 'Event ticket ledger requires EVENTS order when order_id is present. Found %', order_domain_value;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_service_provider_profiles_set_updated_at
BEFORE UPDATE ON service_provider_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_catalog_services_set_updated_at
BEFORE UPDATE ON service_catalog_services
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_catalog_services_assert_coherence
BEFORE INSERT OR UPDATE OF provider_profile_id, provider_user_id ON service_catalog_services
FOR EACH ROW
EXECUTE FUNCTION assert_service_catalog_coherence();

CREATE TRIGGER trg_service_bookings_set_updated_at
BEFORE UPDATE ON service_bookings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_bookings_assert_coherence
BEFORE INSERT OR UPDATE OF order_id, service_id, provider_user_id, customer_user_id, wallet_id ON service_bookings
FOR EACH ROW
EXECUTE FUNCTION assert_service_booking_coherence();

CREATE TRIGGER trg_service_booking_events_assert_coherence
BEFORE INSERT ON service_booking_events
FOR EACH ROW
EXECUTE FUNCTION assert_service_booking_event_coherence();

CREATE TRIGGER trg_service_booking_events_prevent_update
BEFORE UPDATE ON service_booking_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_service_booking_events_prevent_delete
BEFORE DELETE ON service_booking_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_health_profiles_set_updated_at
BEFORE UPDATE ON health_profiles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_health_care_plans_set_updated_at
BEFORE UPDATE ON health_care_plans
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_health_prescriptions_set_updated_at
BEFORE UPDATE ON health_prescriptions
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_job_postings_set_updated_at
BEFORE UPDATE ON job_postings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_job_postings_wallet_owner
BEFORE INSERT OR UPDATE OF employer_user_id, wallet_id ON job_postings
FOR EACH ROW
EXECUTE FUNCTION assert_job_posting_wallet_owner();

CREATE TRIGGER trg_job_applications_set_updated_at
BEFORE UPDATE ON job_applications
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_job_applications_assert_coherence
BEFORE INSERT OR UPDATE OF job_posting_id, candidate_user_id ON job_applications
FOR EACH ROW
EXECUTE FUNCTION assert_job_application_coherence();

CREATE TRIGGER trg_job_engagements_set_updated_at
BEFORE UPDATE ON job_engagements
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_job_engagements_assert_coherence
BEFORE INSERT OR UPDATE OF job_posting_id, job_application_id, employer_user_id, worker_user_id, wallet_id ON job_engagements
FOR EACH ROW
EXECUTE FUNCTION assert_job_engagement_coherence();

CREATE TRIGGER trg_pharmacy_catalog_items_set_updated_at
BEFORE UPDATE ON pharmacy_catalog_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_pharmacy_catalog_items_wallet_owner
BEFORE INSERT OR UPDATE OF pharmacy_user_id, wallet_id ON pharmacy_catalog_items
FOR EACH ROW
EXECUTE FUNCTION assert_pharmacy_catalog_wallet_owner();

CREATE TRIGGER trg_pharmacy_fulfillments_set_updated_at
BEFORE UPDATE ON pharmacy_fulfillments
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_pharmacy_fulfillments_assert_coherence
BEFORE INSERT OR UPDATE OF order_id, patient_user_id, pharmacy_user_id, wallet_id, prescription_id ON pharmacy_fulfillments
FOR EACH ROW
EXECUTE FUNCTION assert_pharmacy_fulfillment_coherence();

CREATE TRIGGER trg_pharmacy_fulfillment_items_set_updated_at
BEFORE UPDATE ON pharmacy_fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_pharmacy_fulfillment_items_assert_coherence
BEFORE INSERT OR UPDATE OF pharmacy_fulfillment_id, pharmacy_item_id ON pharmacy_fulfillment_items
FOR EACH ROW
EXECUTE FUNCTION assert_pharmacy_fulfillment_item_coherence();

CREATE TRIGGER trg_pharmacy_dispense_events_assert_coherence
BEFORE INSERT ON pharmacy_dispense_events
FOR EACH ROW
EXECUTE FUNCTION assert_pharmacy_dispense_event_coherence();

CREATE TRIGGER trg_pharmacy_dispense_events_prevent_update
BEFORE UPDATE ON pharmacy_dispense_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_pharmacy_dispense_events_prevent_delete
BEFORE DELETE ON pharmacy_dispense_events
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_event_programs_set_updated_at
BEFORE UPDATE ON event_programs
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_event_programs_wallet_owner
BEFORE INSERT OR UPDATE OF organizer_user_id, wallet_id ON event_programs
FOR EACH ROW
EXECUTE FUNCTION assert_event_program_wallet_owner();

CREATE TRIGGER trg_event_ticket_types_set_updated_at
BEFORE UPDATE ON event_ticket_types
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_event_ticket_types_assert_coherence
BEFORE INSERT OR UPDATE OF event_program_id, sales_start_at, sales_end_at ON event_ticket_types
FOR EACH ROW
EXECUTE FUNCTION assert_event_ticket_type_coherence();

CREATE TRIGGER trg_event_ticket_ledger_assert_coherence
BEFORE INSERT ON event_ticket_ledger
FOR EACH ROW
EXECUTE FUNCTION assert_event_ticket_ledger_coherence();

CREATE TRIGGER trg_event_ticket_ledger_prevent_update
BEFORE UPDATE ON event_ticket_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

CREATE TRIGGER trg_event_ticket_ledger_prevent_delete
BEFORE DELETE ON event_ticket_ledger
FOR EACH ROW
EXECUTE FUNCTION prevent_append_only_mutation();

COMMENT ON TABLE service_provider_profiles IS 'Prestadores profissionais do modulo Services ligados a wallet e contrato legal.';
COMMENT ON TABLE service_catalog_services IS 'Catalogo de servicos ofertados pelo prestador.';
COMMENT ON TABLE service_bookings IS 'Contratacao do servico ligada a order domain SERVICES.';
COMMENT ON TABLE service_booking_events IS 'Trilha append-only da prestacao de servico.';
COMMENT ON TABLE health_profiles IS 'Resumo clinico minimizado do usuario para cuidado e farmacia.';
COMMENT ON TABLE health_care_plans IS 'Planos de cuidado e acompanhamento profissional.';
COMMENT ON TABLE health_prescriptions IS 'Prescricoes resumidas referenciaveis por farmacia e documentos.';
COMMENT ON TABLE job_postings IS 'Vagas e gigs com integracao financeira ao employer wallet.';
COMMENT ON TABLE job_applications IS 'Candidaturas dos usuarios para vagas e gigs.';
COMMENT ON TABLE job_engagements IS 'Vinculo de trabalho contratado apos aceite da candidatura.';
COMMENT ON TABLE pharmacy_catalog_items IS 'Catalogo farmaceutico vendido pela farmacia.';
COMMENT ON TABLE pharmacy_fulfillments IS 'Fluxo operacional da order PHARMACY ate a entrega.';
COMMENT ON TABLE pharmacy_fulfillment_items IS 'Linhas da dispensacao farmaceutica.';
COMMENT ON TABLE pharmacy_dispense_events IS 'Trilha append-only da dispensacao farmaceutica.';
COMMENT ON TABLE event_programs IS 'Eventos e experiencias com wallet organizadora.';
COMMENT ON TABLE event_ticket_types IS 'Lotes e configuracao comercial dos ingressos.';
COMMENT ON TABLE event_ticket_ledger IS 'Trilha append-only do lifecycle do ingresso.';

COMMENT ON FUNCTION assert_release_wallet_owner(UUID, UUID, TEXT) IS 'Valida se a wallet informada pertence ao usuario esperado.';
COMMENT ON FUNCTION assert_service_catalog_coherence() IS 'Valida coerencia entre service_catalog_services e service_provider_profiles.';
COMMENT ON FUNCTION assert_service_booking_coherence() IS 'Valida order SERVICES, wallet do cliente e provider do catalogo.';
COMMENT ON FUNCTION assert_service_booking_event_coherence() IS 'Impede evento de servico apontando para order diferente do booking.';
COMMENT ON FUNCTION assert_job_posting_wallet_owner() IS 'Valida que a wallet da vaga pertence ao employer.';
COMMENT ON FUNCTION assert_job_application_coherence() IS 'Impede employer de candidatar-se na propria vaga.';
COMMENT ON FUNCTION assert_job_engagement_coherence() IS 'Valida alinhamento entre posting, application, worker e wallet.';
COMMENT ON FUNCTION assert_pharmacy_catalog_wallet_owner() IS 'Valida que a wallet do catalogo pertence a farmacia.';
COMMENT ON FUNCTION assert_pharmacy_fulfillment_coherence() IS 'Valida order PHARMACY, paciente, farmacia, wallet e prescricao.';
COMMENT ON FUNCTION assert_pharmacy_fulfillment_item_coherence() IS 'Valida que a linha dispensada pertence a mesma farmacia do fulfillment.';
COMMENT ON FUNCTION assert_pharmacy_dispense_event_coherence() IS 'Impede evento de dispensacao apontando para order diferente do fulfillment.';
COMMENT ON FUNCTION assert_event_program_wallet_owner() IS 'Valida que a wallet do evento pertence ao organizador.';
COMMENT ON FUNCTION assert_event_ticket_type_coherence() IS 'Valida que a janela de venda do lote cabe na janela do evento.';
COMMENT ON FUNCTION assert_event_ticket_ledger_coherence() IS 'Valida programa, lote e order EVENTS da trilha de ingresso.';

COMMENT ON COLUMN service_provider_profiles.provider_user_id IS 'FK para users.user_id do prestador.';
COMMENT ON COLUMN service_provider_profiles.wallet_id IS 'FK para wallet operacional do prestador.';
COMMENT ON COLUMN service_provider_profiles.provider_status IS 'Status do prestador no modulo Services.';
COMMENT ON COLUMN service_provider_profiles.display_headline IS 'Headline comercial curta do prestador.';
COMMENT ON COLUMN service_provider_profiles.average_rating IS 'Media agregada de reputacao entre 0 e 5.';
COMMENT ON COLUMN service_provider_profiles.availability_json IS 'Agenda e disponibilidade resumidas em JSONB.';

COMMENT ON COLUMN service_catalog_services.service_code IS 'Codigo tecnico estavel do servico.';
COMMENT ON COLUMN service_catalog_services.catalog_status IS 'Status de publicacao do servico.';
COMMENT ON COLUMN service_catalog_services.booking_mode IS 'Modo de contratacao do servico.';
COMMENT ON COLUMN service_catalog_services.base_price_brl IS 'Preco base em BRL.';
COMMENT ON COLUMN service_catalog_services.requirements_json IS 'Requisitos ou materiais em JSONB.';

COMMENT ON COLUMN service_bookings.order_id IS 'FK para order master no dominio SERVICES.';
COMMENT ON COLUMN service_bookings.service_id IS 'FK para o servico contratado.';
COMMENT ON COLUMN service_bookings.quote_amount_brl IS 'Valor inicialmente cotado em BRL.';
COMMENT ON COLUMN service_bookings.final_amount_brl IS 'Valor final liquidado em BRL.';
COMMENT ON COLUMN service_bookings.related_legal_contract_id IS 'FK opcional para contrato juridico da prestacao.';
COMMENT ON COLUMN service_bookings.checkin_code_hash IS 'Hash do codigo de check-in, nunca o codigo bruto.';

COMMENT ON COLUMN health_profiles.user_id IS 'FK para users.user_id do titular do perfil clinico.';
COMMENT ON COLUMN health_profiles.primary_care_user_id IS 'FK opcional para profissional principal.';
COMMENT ON COLUMN health_profiles.consent_json IS 'Consentimentos estruturados para compartilhamento clinico.';
COMMENT ON COLUMN health_profiles.risk_flags_json IS 'Flags de risco operacional em JSONB.';

COMMENT ON COLUMN health_care_plans.patient_user_id IS 'FK para paciente.';
COMMENT ON COLUMN health_care_plans.professional_user_id IS 'FK para profissional dono do plano.';
COMMENT ON COLUMN health_care_plans.care_plan_json IS 'Plano estruturado em JSONB.';
COMMENT ON COLUMN health_care_plans.source_session_id IS 'FK opcional para teletherapy_sessions que originou o plano.';

COMMENT ON COLUMN health_prescriptions.prescription_code IS 'Codigo tecnico estavel da prescricao.';
COMMENT ON COLUMN health_prescriptions.document_id IS 'FK opcional para documento/receipt da prescricao.';
COMMENT ON COLUMN health_prescriptions.medication_summary_json IS 'Resumo estruturado dos itens prescritos.';
COMMENT ON COLUMN health_prescriptions.controlled_substance IS 'Flag para substancia controlada.';

COMMENT ON COLUMN job_postings.wallet_id IS 'FK para wallet do employer usada em ofertas e settle.';
COMMENT ON COLUMN job_postings.posting_status IS 'Status da vaga ou gig.';
COMMENT ON COLUMN job_postings.employment_type IS 'Tipo de contratacao.';
COMMENT ON COLUMN job_postings.remote_mode IS 'Modo de trabalho onsite, hybrid ou remote.';
COMMENT ON COLUMN job_postings.requirements_json IS 'Requisitos estruturados da vaga.';

COMMENT ON COLUMN job_applications.resume_document_id IS 'FK opcional para documento/arquivo de curriculo.';
COMMENT ON COLUMN job_applications.profile_snapshot_json IS 'Snapshot estruturado do perfil aplicado.';

COMMENT ON COLUMN job_engagements.wallet_id IS 'FK para wallet do employer usada na relacao financeira.';
COMMENT ON COLUMN job_engagements.transaction_id IS 'FK opcional para transacao de pagamento/adiantamento.';
COMMENT ON COLUMN job_engagements.legal_contract_id IS 'FK opcional para contrato juridico do vinculo.';
COMMENT ON COLUMN job_engagements.settlement_json IS 'Regras estruturadas de settle do vinculo.';

COMMENT ON COLUMN pharmacy_catalog_items.inventory_item_id IS 'FK opcional para inventory_items quando houver espelhamento com estoque.';
COMMENT ON COLUMN pharmacy_catalog_items.requires_prescription IS 'Indica se o item exige health_prescriptions valida.';
COMMENT ON COLUMN pharmacy_catalog_items.anvisa_code IS 'Codigo regulatorio ou classificacao oficial.';

COMMENT ON COLUMN pharmacy_fulfillments.order_id IS 'FK para order master no dominio PHARMACY.';
COMMENT ON COLUMN pharmacy_fulfillments.prescription_id IS 'FK opcional para health_prescriptions.';
COMMENT ON COLUMN pharmacy_fulfillments.total_amount_brl IS 'Valor total em BRL da dispensacao.';
COMMENT ON COLUMN pharmacy_fulfillments.requires_id_check IS 'Indica se a entrega exige validacao de identidade.';

COMMENT ON COLUMN pharmacy_fulfillment_items.quantity_requested IS 'Quantidade originalmente pedida.';
COMMENT ON COLUMN pharmacy_fulfillment_items.quantity_authorized IS 'Quantidade autorizada apos revisao clinica.';
COMMENT ON COLUMN pharmacy_fulfillment_items.quantity_dispensed IS 'Quantidade realmente dispensada.';

COMMENT ON COLUMN pharmacy_dispense_events.event_type IS 'Tipo do evento append-only da dispensacao.';
COMMENT ON COLUMN pharmacy_dispense_events.occurred_at IS 'Horario append-only do evento.';

COMMENT ON COLUMN event_programs.wallet_id IS 'FK para wallet do organizador.';
COMMENT ON COLUMN event_programs.sales_start_at IS 'Inicio opcional da janela de vendas.';
COMMENT ON COLUMN event_programs.sales_end_at IS 'Fim opcional da janela de vendas.';

COMMENT ON COLUMN event_ticket_types.batch_code IS 'Codigo tecnico estavel do lote.';
COMMENT ON COLUMN event_ticket_types.inventory_total IS 'Capacidade total do lote.';
COMMENT ON COLUMN event_ticket_types.inventory_available IS 'Capacidade disponivel do lote.';
COMMENT ON COLUMN event_ticket_types.is_transferable IS 'Indica se o ingresso pode ser transferido.';

COMMENT ON COLUMN event_ticket_ledger.ticket_instance_id IS 'Identificador logico do ingresso ao longo da trilha.';
COMMENT ON COLUMN event_ticket_ledger.ticket_code IS 'Codigo publico estavel do ingresso.';
COMMENT ON COLUMN event_ticket_ledger.qr_hash_sha256 IS 'Hash do QR/token de acesso, nunca o token bruto.';
COMMENT ON COLUMN event_ticket_ledger.ticket_status IS 'Estado do ingresso apos o evento registrado.';
COMMENT ON COLUMN event_ticket_ledger.event_type IS 'Tipo do evento append-only do ingresso.';

COMMENT ON TRIGGER trg_service_catalog_services_assert_coherence ON service_catalog_services IS 'Valida coerencia do catalogo com o provider profile.';
COMMENT ON TRIGGER trg_service_bookings_assert_coherence ON service_bookings IS 'Valida order SERVICES, wallet do cliente e provider do booking.';
COMMENT ON TRIGGER trg_service_booking_events_assert_coherence ON service_booking_events IS 'Impede evento de booking com order incorreto.';
COMMENT ON TRIGGER trg_service_booking_events_prevent_update ON service_booking_events IS 'Impede UPDATE na trilha append-only de booking.';
COMMENT ON TRIGGER trg_service_booking_events_prevent_delete ON service_booking_events IS 'Impede DELETE na trilha append-only de booking.';
COMMENT ON TRIGGER trg_job_postings_wallet_owner ON job_postings IS 'Valida ownership da wallet do employer.';
COMMENT ON TRIGGER trg_job_applications_assert_coherence ON job_applications IS 'Impede candidatura do proprio employer.';
COMMENT ON TRIGGER trg_job_engagements_assert_coherence ON job_engagements IS 'Valida alinhamento entre posting, application, worker e wallet.';
COMMENT ON TRIGGER trg_pharmacy_catalog_items_wallet_owner ON pharmacy_catalog_items IS 'Valida ownership da wallet da farmacia.';
COMMENT ON TRIGGER trg_pharmacy_fulfillments_assert_coherence ON pharmacy_fulfillments IS 'Valida order PHARMACY, paciente, farmacia e prescricao.';
COMMENT ON TRIGGER trg_pharmacy_fulfillment_items_assert_coherence ON pharmacy_fulfillment_items IS 'Valida item da mesma farmacia do fulfillment.';
COMMENT ON TRIGGER trg_pharmacy_dispense_events_assert_coherence ON pharmacy_dispense_events IS 'Impede evento de dispensacao com order incorreto.';
COMMENT ON TRIGGER trg_pharmacy_dispense_events_prevent_update ON pharmacy_dispense_events IS 'Impede UPDATE na trilha append-only farmaceutica.';
COMMENT ON TRIGGER trg_pharmacy_dispense_events_prevent_delete ON pharmacy_dispense_events IS 'Impede DELETE na trilha append-only farmaceutica.';
COMMENT ON TRIGGER trg_event_programs_wallet_owner ON event_programs IS 'Valida ownership da wallet do organizador.';
COMMENT ON TRIGGER trg_event_ticket_types_assert_coherence ON event_ticket_types IS 'Valida janela do lote dentro da janela do evento.';
COMMENT ON TRIGGER trg_event_ticket_ledger_assert_coherence ON event_ticket_ledger IS 'Valida programa, lote e order EVENTS da trilha.';
COMMENT ON TRIGGER trg_event_ticket_ledger_prevent_update ON event_ticket_ledger IS 'Impede UPDATE na trilha append-only de ingressos.';
COMMENT ON TRIGGER trg_event_ticket_ledger_prevent_delete ON event_ticket_ledger IS 'Impede DELETE na trilha append-only de ingressos.';

COMMIT;
