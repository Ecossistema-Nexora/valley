#!/usr/bin/env python3
"""
VALLEY DATABASE ORCHESTRATOR
============================
Propósito: Garantir a aplicação atômica e ordenada de schemas PostgreSQL e coleções MongoDB.

Instruções de Uso:
- python valley_db_orchestrator.py check   -> Checagem estática de ambiente e arquivos.
- python valley_db_orchestrator.py report  -> Gera o VALLEY_DEPLOYMENT_STATUS.md.
- python valley_db_orchestrator.py apply-compose -> Sobe Docker e aplica tudo.

Funcionalidades:
- Detecção de 'provides' via SQL: Evita re-execução de DDLs que geram conflitos de tipo.
- Snapshots: Backup binário atômico de ambos os bancos para restauração rápida.
"""

# argparse cria uma CLI objetiva para check, report, apply e compose.
import argparse

# json le o manifesto de migrations e escreve relatorios tecnicos.
import json

# hashlib calcula checksum dos snapshots exportados.
import hashlib

# os acessa variaveis de ambiente como DATABASE_URL e MONGODB_URI.
import os

# shutil localiza binarios como psql, mongosh, node e docker.
import shutil

# subprocess executa comandos externos de forma controlada.
import subprocess

# sys expõe o interpretador Python atual para execucoes filhas portaveis.
import sys

# time permite polling explicito de readiness sem depender do healthcheck do Compose.
import time

# dataclasses organiza resultados de validacao em objetos simples.
from dataclasses import dataclass

# datetime registra horario de relatorio em UTC.
from datetime import datetime, timezone

# pathlib manipula caminhos de forma portavel.
from pathlib import Path

# typing melhora clareza dos retornos.
from typing import Iterable


# ROOT e a raiz da worktree Valley.
ROOT = Path(__file__).resolve().parents[1]

# ENV_EXAMPLE_PATH guarda defaults locais seguros para PostgreSQL e MongoDB.
ENV_EXAMPLE_PATH = ROOT / '.env.example'

# ENV_PATH guarda overrides locais reais quando o operador cria um .env.
ENV_PATH = ROOT / '.env'

# MANIFEST_PATH e a fonte de ordem das migrations.
MANIFEST_PATH = ROOT / 'database' / 'migrations.json'

# REPORT_DIR guarda relatorios operacionais gerados automaticamente.
REPORT_DIR = ROOT / 'output' / 'deployment'

# REPORT_PATH e o status consolidado mais recente da esteira.
REPORT_PATH = REPORT_DIR / 'VALLEY_DEPLOYMENT_STATUS.md'

# SNAPSHOT_DIR guarda snapshots operacionais exportados do ambiente local.
SNAPSHOT_DIR = ROOT / 'output' / 'snapshots'

# ADMIN_BUILDER_PATH aponta para o gerador do console admin.
ADMIN_BUILDER_PATH = ROOT / 'scripts' / 'valley_admin_builder.py'

# MODULES_DIR guarda os artefatos por modulo gerados pela automacao v47.
MODULES_DIR = ROOT / 'modules'

# CONTRACTS_SUMMARY_PATH guarda a matriz consolidada dos contratos operacionais.
CONTRACTS_SUMMARY_PATH = ROOT / 'output' / 'module-roadmap' / 'VALLEY_MODULE_CONTRACTS.md'

# ROADMAP_PATH guarda o roadmap consolidado de evolucao dos 47 modulos.
ROADMAP_PATH = ROOT / 'output' / 'module-roadmap' / 'VALLEY_MODULE_ROADMAP.md'

# EXECUTION_BACKLOG_PATH guarda a fila executavel consolidada por dominio.
EXECUTION_BACKLOG_PATH = ROOT / 'output' / 'module-roadmap' / 'VALLEY_DOMAIN_EXECUTION_BACKLOG.md'

# PRIORITY_DOMAIN_PLAN_PATH guarda o plano fisico por camada dos dominios prioritarios.
PRIORITY_DOMAIN_PLAN_PATH = ROOT / 'output' / 'module-roadmap' / 'VALLEY_PRIORITY_DOMAIN_DELIVERY_PLAN.md'

# PRIORITY_DOMAIN_SQL_DIR guarda os pacotes SQL fisicos por dominio.
PRIORITY_DOMAIN_SQL_DIR = ROOT / 'database' / 'domain-delivery' / 'priority-domains'

# PRIORITY_DOMAIN_CONTRACTS_DIR guarda os contratos de evento exportados.
PRIORITY_DOMAIN_CONTRACTS_DIR = ROOT / 'contracts' / 'events' / 'priority-domains'

# PYTHON_COMMAND reaproveita o Python atual para evitar alias quebrado como python3 no Windows.
PYTHON_COMMAND = [sys.executable] if sys.executable else ['python3']

# COMPOSE_WAIT_SECONDS define quanto tempo a esteira espera banco e mongo no Compose.
COMPOSE_WAIT_SECONDS = 900

# COMPOSE_BUILDER_SERVICE identifica o worker de aplicacao no docker-compose.
COMPOSE_BUILDER_SERVICE = 'builder'

# TOOLS_BIN_DIR guarda wrappers persistentes do projeto para CLIs externas.
TOOLS_BIN_DIR = ROOT / 'tools' / 'bin'

# POSTGRES_SEED_PATHS guarda seeds operacionais que nao fazem parte do manifesto de schema.
POSTGRES_SEED_PATHS = [
    ROOT / 'database' / 'seeds' / 'postgres' / '001_v47_expansion_tourism_bio_energy_seed.sql',
    ROOT / 'database' / 'seeds' / 'postgres' / '002_v47_priority_domain_delivery_packages_seed.sql',
    ROOT / 'database' / 'seeds' / 'postgres' / '003_v47_product_mode_demo_seed.sql',
    PRIORITY_DOMAIN_SQL_DIR / 'platform_developer' / 'operational_seed.sql',
    PRIORITY_DOMAIN_SQL_DIR / 'logistics_erp_operations' / 'operational_seed.sql',
    PRIORITY_DOMAIN_SQL_DIR / 'ai_memory_operations' / 'operational_seed.sql',
    PRIORITY_DOMAIN_SQL_DIR / 'media_social_growth' / 'operational_seed.sql',
    PRIORITY_DOMAIN_SQL_DIR / 'frontier_iot_energy' / 'operational_seed.sql',
    PRIORITY_DOMAIN_SQL_DIR / 'city_mobility_security' / 'operational_seed.sql',
    PRIORITY_DOMAIN_SQL_DIR / 'commerce_fintech_assets' / 'operational_seed.sql',
]

# MONGODB_SEED_PATHS guarda seeds operacionais MongoDB fora da esteira de migrations.
MONGODB_SEED_PATHS = [
    ROOT / 'database' / 'seeds' / 'mongodb' / '001_v47_expansion_media_wellness_frontier_seed.mongo.js',
    ROOT / 'database' / 'seeds' / 'mongodb' / '002_v47_product_mode_demo_seed.mongo.js',
]

# SEED_IDS centraliza UUIDs deterministicas usadas pelos seeds e smoke checks.
SEED_IDS = {
    'tourism_owner_user_id': '10000000-0000-4000-8000-000000000001',
    'traveler_user_id': '10000000-0000-4000-8000-000000000002',
    'bio_operator_user_id': '10000000-0000-4000-8000-000000000003',
    'energy_operator_user_id': '10000000-0000-4000-8000-000000000004',
    'guide_user_id': '10000000-0000-4000-8000-000000000005',
    'home_counterparty_user_id': '10000000-0000-4000-8000-000000000006',
    'tourism_owner_wallet_id': '20000000-0000-4000-8000-000000000001',
    'traveler_wallet_id': '20000000-0000-4000-8000-000000000002',
    'bio_operator_wallet_id': '20000000-0000-4000-8000-000000000003',
    'energy_operator_wallet_id': '20000000-0000-4000-8000-000000000004',
    'energy_nex_wallet_id': '20000000-0000-4000-8000-000000000005',
    'home_counterparty_wallet_id': '20000000-0000-4000-8000-000000000006',
    'tourism_experience_id': '30000000-0000-4000-8000-000000000001',
    'tourism_booking_id': '30000000-0000-4000-8000-000000000002',
    'tourism_booking_event_id': '30000000-0000-4000-8000-000000000003',
    'bio_program_id': '30000000-0000-4000-8000-000000000101',
    'bio_collection_order_id': '30000000-0000-4000-8000-000000000102',
    'bio_collection_event_id': '30000000-0000-4000-8000-000000000103',
    'energy_asset_id': '30000000-0000-4000-8000-000000000201',
    'energy_counterparty_asset_id': '30000000-0000-4000-8000-000000000202',
    'energy_trade_order_id': '30000000-0000-4000-8000-000000000203',
    'energy_settlement_entry_id': '30000000-0000-4000-8000-000000000204',
    'news_content_id': '40000000-0000-4000-8000-000000000001',
    'fitness_session_id': '40000000-0000-4000-8000-000000000002',
    'gaming_player_state_id': '40000000-0000-4000-8000-000000000003',
    'home_automation_event_id': '40000000-0000-4000-8000-000000000004',
    'space_anchor_id': '40000000-0000-4000-8000-000000000005',
    'tourism_feed_id': '40000000-0000-4000-8000-000000000006',
    'bio_impact_log_id': '40000000-0000-4000-8000-000000000007',
    'energy_meter_stream_id': '40000000-0000-4000-8000-000000000008',
    'home_household_id': '50000000-0000-4000-8000-000000000001',
    'platform_owner_user_id': '10000000-0000-4000-8000-000000000101',
    'platform_counterparty_user_id': '10000000-0000-4000-8000-000000000102',
    'platform_integrator_user_id': '10000000-0000-4000-8000-000000000103',
    'logistics_business_user_id': '10000000-0000-4000-8000-000000000201',
    'logistics_buyer_user_id': '10000000-0000-4000-8000-000000000202',
    'logistics_supplier_user_id': '10000000-0000-4000-8000-000000000203',
    'logistics_customer_user_id': '10000000-0000-4000-8000-000000000204',
    'logistics_rider_user_id': '10000000-0000-4000-8000-000000000205',
    'platform_owner_wallet_id': '20000000-0000-4000-8000-000000000101',
    'platform_counterparty_wallet_id': '20000000-0000-4000-8000-000000000102',
    'logistics_business_wallet_id': '20000000-0000-4000-8000-000000000201',
    'logistics_supplier_wallet_id': '20000000-0000-4000-8000-000000000202',
    'logistics_customer_wallet_id': '20000000-0000-4000-8000-000000000203',
    'logistics_rider_wallet_id': '20000000-0000-4000-8000-000000000204',
    'platform_transaction_id': '30000000-0000-4000-8000-000000000301',
    'platform_document_id': '30000000-0000-4000-8000-000000000302',
    'platform_legal_contract_id': '30000000-0000-4000-8000-000000000303',
    'platform_receipt_id': '30000000-0000-4000-8000-000000000304',
    'platform_template_contract_id': '30000000-0000-4000-8000-000000000305',
    'platform_template_version_id': '30000000-0000-4000-8000-000000000306',
    'platform_checksum_event_id': '30000000-0000-4000-8000-000000000307',
    'platform_receipt_version_id': '30000000-0000-4000-8000-000000000308',
    'platform_api_client_id': '30000000-0000-4000-8000-000000000309',
    'platform_old_credential_id': '30000000-0000-4000-8000-000000000310',
    'platform_new_credential_id': '30000000-0000-4000-8000-000000000311',
    'platform_api_client_limit_id': '30000000-0000-4000-8000-000000000312',
    'platform_webhook_subscription_id': '30000000-0000-4000-8000-000000000313',
    'platform_original_delivery_attempt_id': '30000000-0000-4000-8000-000000000314',
    'platform_replay_delivery_attempt_id': '30000000-0000-4000-8000-000000000315',
    'platform_rotation_event_id': '30000000-0000-4000-8000-000000000316',
    'platform_webhook_replay_request_id': '30000000-0000-4000-8000-000000000317',
    'logistics_business_unit_id': '30000000-0000-4000-8000-000000000401',
    'logistics_fiscal_closure_id': '30000000-0000-4000-8000-000000000402',
    'logistics_approval_policy_id': '30000000-0000-4000-8000-000000000403',
    'logistics_supplier_id': '30000000-0000-4000-8000-000000000404',
    'logistics_warehouse_id': '30000000-0000-4000-8000-000000000405',
    'logistics_inventory_item_id': '30000000-0000-4000-8000-000000000406',
    'logistics_inventory_lot_id': '30000000-0000-4000-8000-000000000407',
    'logistics_procurement_order_id': '30000000-0000-4000-8000-000000000408',
    'logistics_procurement_approval_event_id': '30000000-0000-4000-8000-000000000409',
    'logistics_margin_policy_id': '30000000-0000-4000-8000-000000000410',
    'logistics_order_payment_transaction_id': '30000000-0000-4000-8000-000000000411',
    'logistics_supplier_settlement_transaction_id': '30000000-0000-4000-8000-000000000412',
    'logistics_supplier_reconciliation_id': '30000000-0000-4000-8000-000000000413',
    'logistics_stockout_case_id': '30000000-0000-4000-8000-000000000414',
    'logistics_food_store_contract_id': '30000000-0000-4000-8000-000000000415',
    'logistics_food_menu_item_id': '30000000-0000-4000-8000-000000000416',
    'logistics_warehouse_location_id': '30000000-0000-4000-8000-000000000417',
    'logistics_status_mapping_id': '30000000-0000-4000-8000-000000000418',
    'logistics_proof_document_id': '30000000-0000-4000-8000-000000000419',
    'logistics_food_order_id': '30000000-0000-4000-8000-000000000420',
    'logistics_cycle_count_id': '30000000-0000-4000-8000-000000000421',
    'logistics_inventory_movement_id': '30000000-0000-4000-8000-000000000422',
    'logistics_variance_adjustment_id': '30000000-0000-4000-8000-000000000423',
    'logistics_temperature_incident_id': '30000000-0000-4000-8000-000000000424',
    'logistics_delivery_policy_id': '30000000-0000-4000-8000-000000000425',
    'logistics_shipment_id': '30000000-0000-4000-8000-000000000426',
    'logistics_shipment_event_id': '30000000-0000-4000-8000-000000000427',
    'logistics_delivery_proof_media_id': '30000000-0000-4000-8000-000000000428',
    'logistics_business_invoice_id': '30000000-0000-4000-8000-000000000429',
    'logistics_business_payroll_id': '30000000-0000-4000-8000-000000000430',
    'logistics_vehicle_profile_id': '30000000-0000-4000-8000-000000000431',
    'logistics_move_order_id': '30000000-0000-4000-8000-000000000432',
    'logistics_mobility_trip_id': '30000000-0000-4000-8000-000000000433',
    'logistics_fleet_cost_entry_id': '30000000-0000-4000-8000-000000000434',
    'city_owner_user_id': '10000000-0000-4000-8000-000000000301',
    'city_citizen_user_id': '10000000-0000-4000-8000-000000000302',
    'city_operator_user_id': '10000000-0000-4000-8000-000000000303',
    'city_guide_user_id': '10000000-0000-4000-8000-000000000304',
    'city_owner_wallet_id': '20000000-0000-4000-8000-000000000301',
    'city_citizen_wallet_id': '20000000-0000-4000-8000-000000000302',
    'city_contract_document_id': '30000000-0000-4000-8000-000000000501',
    'city_incident_document_id': '30000000-0000-4000-8000-000000000502',
    'city_gov_document_id': '30000000-0000-4000-8000-000000000503',
    'city_legal_contract_id': '30000000-0000-4000-8000-000000000504',
    'city_contract_owner_party_id': '30000000-0000-4000-8000-000000000505',
    'city_contract_counterparty_party_id': '30000000-0000-4000-8000-000000000506',
    'city_signature_id': '30000000-0000-4000-8000-000000000507',
    'city_fallback_pin_id': '30000000-0000-4000-8000-000000000508',
    'city_dispute_id': '30000000-0000-4000-8000-000000000509',
    'city_contract_audit_event_id': '30000000-0000-4000-8000-000000000510',
    'city_dispute_audit_event_id': '30000000-0000-4000-8000-000000000511',
    'city_event_program_id': '30000000-0000-4000-8000-000000000512',
    'city_ticket_type_id': '30000000-0000-4000-8000-000000000513',
    'city_ticket_transaction_id': '30000000-0000-4000-8000-000000000514',
    'city_ticket_instance_id': '30000000-0000-4000-8000-000000000515',
    'city_ticket_ledger_id': '30000000-0000-4000-8000-000000000516',
    'city_tourism_experience_id': '30000000-0000-4000-8000-000000000517',
    'city_tourism_booking_id': '30000000-0000-4000-8000-000000000518',
    'city_tourism_booking_event_id': '30000000-0000-4000-8000-000000000519',
    'city_security_contact_id': '30000000-0000-4000-8000-000000000520',
    'city_biometric_credential_id': '30000000-0000-4000-8000-000000000521',
    'city_security_incident_id': '30000000-0000-4000-8000-000000000522',
    'city_security_incident_event_id': '30000000-0000-4000-8000-000000000523',
    'city_gov_service_id': '30000000-0000-4000-8000-000000000524',
    'city_gov_fee_transaction_id': '30000000-0000-4000-8000-000000000525',
    'city_gov_request_id': '30000000-0000-4000-8000-000000000526',
    'city_gov_request_submitted_event_id': '30000000-0000-4000-8000-000000000527',
    'city_gov_request_fulfilled_event_id': '30000000-0000-4000-8000-000000000528',
    'city_mobility_benchmark_id': '30000000-0000-4000-8000-000000000529',
    'city_mobility_route_id': '30000000-0000-4000-8000-000000000530',
    'city_mobility_buffer_id': '30000000-0000-4000-8000-000000000531',
    'ai_helena_user_id': '10000000-0000-4000-8000-000000000501',
    'ai_customer_user_id': '10000000-0000-4000-8000-000000000502',
    'ai_professional_user_id': '10000000-0000-4000-8000-000000000503',
    'ai_customer_wallet_id': '20000000-0000-4000-8000-000000000501',
    'ai_professional_wallet_id': '20000000-0000-4000-8000-000000000502',
    'ai_financial_goal_id': '30000000-0000-4000-8000-000000000701',
    'ai_consented_insight_id': '30000000-0000-4000-8000-000000000702',
    'ai_pending_insight_id': '30000000-0000-4000-8000-000000000703',
    'ai_conversation_id': '30000000-0000-4000-8000-000000000704',
    'ai_message_1_id': '30000000-0000-4000-8000-000000000705',
    'ai_message_2_id': '30000000-0000-4000-8000-000000000706',
    'ai_message_3_id': '30000000-0000-4000-8000-000000000707',
    'media_merchant_user_id': '10000000-0000-4000-8000-000000000601',
    'media_creator_user_id': '10000000-0000-4000-8000-000000000602',
    'media_buyer_user_id': '10000000-0000-4000-8000-000000000603',
    'media_player_user_id': '10000000-0000-4000-8000-000000000604',
    'media_merchant_wallet_id': '20000000-0000-4000-8000-000000000601',
    'media_creator_wallet_id': '20000000-0000-4000-8000-000000000602',
    'media_buyer_wallet_id': '20000000-0000-4000-8000-000000000603',
    'media_player_wallet_id': '20000000-0000-4000-8000-000000000604',
    'media_creator_upload_id': '30000000-0000-4000-8000-000000000801',
    'media_order_id': '30000000-0000-4000-8000-000000000802',
    'media_purchase_transaction_id': '30000000-0000-4000-8000-000000000803',
    'media_creator_payout_transaction_id': '30000000-0000-4000-8000-000000000804',
    'media_referral_id': '30000000-0000-4000-8000-000000000805',
    'media_ads_campaign_id': '30000000-0000-4000-8000-000000000806',
    'media_gold_campaign_id': '30000000-0000-4000-8000-000000000807',
    'media_gold_campaign_event_id': '30000000-0000-4000-8000-000000000808',
    'media_pepita_account_id': '30000000-0000-4000-8000-000000000809',
    'media_pepita_ledger_id': '30000000-0000-4000-8000-000000000810',
    'media_gaming_campaign_id': '30000000-0000-4000-8000-000000000811',
    'media_points_ledger_id': '30000000-0000-4000-8000-000000000812',
    'commerce_merchant_user_id': '10000000-0000-4000-8000-000000000401',
    'commerce_customer_user_id': '10000000-0000-4000-8000-000000000402',
    'commerce_affiliate_user_id': '10000000-0000-4000-8000-000000000403',
    'commerce_merchant_wallet_id': '20000000-0000-4000-8000-000000000401',
    'commerce_customer_wallet_id': '20000000-0000-4000-8000-000000000402',
    'commerce_inventory_item_id': '30000000-0000-4000-8000-000000000601',
    'commerce_storefront_id': '30000000-0000-4000-8000-000000000602',
    'commerce_listing_id': '30000000-0000-4000-8000-000000000603',
    'commerce_order_id': '30000000-0000-4000-8000-000000000604',
    'commerce_purchase_transaction_id': '30000000-0000-4000-8000-000000000605',
    'commerce_sale_validation_id': '30000000-0000-4000-8000-000000000606',
    'commerce_plug_transaction_id': '30000000-0000-4000-8000-000000000607',
    'commerce_plug_ledger_transaction_id': '30000000-0000-4000-8000-000000000608',
    'commerce_referral_id': '30000000-0000-4000-8000-000000000609',
    'commerce_financial_goal_id': '30000000-0000-4000-8000-000000000610',
    'commerce_collection_document_id': '30000000-0000-4000-8000-000000000611',
    'commerce_collection_id': '30000000-0000-4000-8000-000000000612',
    'commerce_digital_asset_id': '30000000-0000-4000-8000-000000000613',
    'commerce_digital_event_id': '30000000-0000-4000-8000-000000000614',
    'commerce_property_document_id': '30000000-0000-4000-8000-000000000615',
    'commerce_property_contract_id': '30000000-0000-4000-8000-000000000616',
    'commerce_property_id': '30000000-0000-4000-8000-000000000617',
    'commerce_real_estate_listing_id': '30000000-0000-4000-8000-000000000618',
    'commerce_real_estate_transaction_id': '30000000-0000-4000-8000-000000000619',
    'commerce_real_estate_deal_id': '30000000-0000-4000-8000-000000000620',
    'commerce_insurance_terms_document_id': '30000000-0000-4000-8000-000000000621',
    'commerce_insurance_contract_id': '30000000-0000-4000-8000-000000000622',
    'commerce_insurance_product_id': '30000000-0000-4000-8000-000000000623',
    'commerce_insurance_premium_transaction_id': '30000000-0000-4000-8000-000000000624',
    'commerce_insurance_policy_id': '30000000-0000-4000-8000-000000000625',
    'commerce_insurance_payout_transaction_id': '30000000-0000-4000-8000-000000000626',
    'commerce_insurance_claim_id': '30000000-0000-4000-8000-000000000627',
    'commerce_insurance_claim_event_id': '30000000-0000-4000-8000-000000000628',
    'commerce_insurance_claim_document_id': '30000000-0000-4000-8000-000000000629',
    'dropshipping_mercado_livre_provider_id': '30000000-0000-4000-8000-000000000901',
    'dropshipping_aliexpress_provider_id': '30000000-0000-4000-8000-000000000903',
    'dropshipping_product_source_id': '30000000-0000-4000-8000-000000000908',
    'dropshipping_market_price_snapshot_id': '30000000-0000-4000-8000-000000000909',
    'dropshipping_pricing_decision_id': '30000000-0000-4000-8000-000000000910',
    'dropshipping_reprice_job_id': '30000000-0000-4000-8000-000000000911',
}


@dataclass
class CheckResult:
    """Resultado simples de uma checagem local."""

    # name identifica a checagem.
    name: str

    # ok indica sucesso ou falha.
    ok: bool

    # detail explica o resultado em portugues simples.
    detail: str


def parse_env_file(path: Path) -> dict[str, str]:
    """Le um arquivo .env simples sem depender de biblioteca externa."""

    # values guarda pares KEY=VALUE validos encontrados no arquivo.
    values: dict[str, str] = {}

    # Se o arquivo nao existir, nao ha nada para carregar.
    if not path.exists():
        return values

    # Percorre linha a linha para suportar comentarios e espacos.
    for raw_line in path.read_text(encoding='utf-8').splitlines():
        # line remove espacos desnecessarios.
        line = raw_line.strip()

        # Ignora comentarios e linhas vazias.
        if not line or line.startswith('#') or '=' not in line:
            continue

        # key/value divide apenas no primeiro igual para preservar URLs.
        key, value = line.split('=', 1)

        # key limpa espacos para evitar variavel invalida.
        key = key.strip()

        # value remove espacos e aspas de contorno.
        value = value.strip().strip('"').strip("'")

        # So guarda chaves nao vazias.
        if key:
            values[key] = value

    # Retorna o mapa parseado.
    return values


def load_env_defaults() -> dict[str, str]:
    """Carrega .env.example e .env como defaults locais para a esteira."""

    # loaded_sources registra de qual arquivo veio cada chave carregada.
    loaded_sources: dict[str, str] = {}

    # .env.example vem primeiro como baseline seguro de desenvolvimento local.
    for key, value in parse_env_file(ENV_EXAMPLE_PATH).items():
        # Variavel de ambiente real tem prioridade sobre defaults do repo.
        if key not in os.environ:
            os.environ[key] = value
            loaded_sources[key] = ENV_EXAMPLE_PATH.name

    # .env local sobrescreve apenas o que veio do example, nunca o ambiente real.
    for key, value in parse_env_file(ENV_PATH).items():
        # Pode sobrescrever defaults do example ou preencher lacunas.
        if key not in os.environ or loaded_sources.get(key) == ENV_EXAMPLE_PATH.name:
            os.environ[key] = value
            loaded_sources[key] = ENV_PATH.name

    # Retorna a origem de cada valor carregado por arquivo.
    return loaded_sources


def tool_search_path() -> str:
    """Monta PATH efetivo priorizando wrappers versionados do projeto."""

    # current_path preserva o PATH real do operador.
    current_path = os.environ.get('PATH', '')

    # tools_path aponta para scripts como tools/bin/psql.cmd e mongosh.cmd.
    tools_path = str(TOOLS_BIN_DIR)

    # Evita duplicar caminho quando o operador ja incluiu tools/bin no PATH.
    paths = [item for item in current_path.split(os.pathsep) if item]
    if tools_path not in paths:
        paths.insert(0, tools_path)

    # Retorna PATH portavel para shutil.which.
    return os.pathsep.join(paths)


def find_tool(tool: str) -> str | None:
    """Localiza ferramenta externa considerando wrappers locais do projeto."""

    # shutil.which com path explicito permite encontrar .cmd no Windows via PATHEXT.
    return shutil.which(tool, path=tool_search_path())


def run_command(command: list[str], timeout_seconds: int = 30) -> subprocess.CompletedProcess[str]:
    """Executa comando externo com timeout e captura saida."""

    # try converte timeout em resultado controlado, sem derrubar a automacao.
    try:
        # subprocess.run executa o comando sem shell para reduzir risco de injecao.
        return subprocess.run(
            # command contem binario e argumentos.
            command,
            # cwd fixa a worktree como contexto.
            cwd=ROOT,
            # text retorna stdout/stderr como string.
            text=True,
            # capture_output evita poluir terminal e permite relatorio.
            capture_output=True,
            # timeout impede travamento de Docker ou CLIs indisponiveis.
            timeout=timeout_seconds,
            # check fica False para permitir registrar falhas sem quebrar tudo.
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        # Timeout vira exit code 124, padrao comum de comandos interrompidos.
        return subprocess.CompletedProcess(
            # args preserva o comando original para debug.
            args=command,
            # returncode 124 indica timeout controlado.
            returncode=124,
            # stdout preserva qualquer saida parcial.
            stdout=exc.stdout or '',
            # stderr explica o timeout em portugues simples.
            stderr=f'comando excedeu {timeout_seconds}s e foi interrompido',
        )


def load_manifest() -> dict:
    """Carrega o manifesto JSON de migrations."""

    # Se o arquivo nao existir, a esteira nao consegue saber ordem segura.
    if not MANIFEST_PATH.exists():
        # Falha explicita para correcao imediata.
        raise FileNotFoundError(f'Manifesto nao encontrado: {MANIFEST_PATH}')

    # Le JSON em UTF-8 para preservar textos PT-BR.
    return json.loads(MANIFEST_PATH.read_text(encoding='utf-8'))


def iter_manifest_paths(manifest: dict) -> Iterable[Path]:
    """Itera todos os arquivos referenciados no manifesto."""

    # Percorre migrations PostgreSQL em ordem declarada.
    for item in manifest.get('postgres', []):
        # Converte path relativo para absoluto na worktree.
        yield ROOT / item['path']

    # Percorre scripts MongoDB em ordem declarada.
    for item in manifest.get('mongodb', []):
        # Converte path relativo para absoluto na worktree.
        yield ROOT / item['path']


def validate_manifest(manifest: dict) -> list[CheckResult]:
    """Valida estrutura, ordem e existencia dos arquivos do manifesto."""

    # results acumula as checagens.
    results: list[CheckResult] = []

    # postgres_items guarda migrations SQL.
    postgres_items = manifest.get('postgres', [])

    # mongodb_items guarda scripts Mongo.
    mongodb_items = manifest.get('mongodb', [])

    # Confere se ha migrations PostgreSQL declaradas.
    results.append(CheckResult('manifest.postgres_present', bool(postgres_items), f'{len(postgres_items)} migrations PostgreSQL declaradas.'))

    # Confere se ha scripts Mongo declarados.
    results.append(CheckResult('manifest.mongodb_present', bool(mongodb_items), f'{len(mongodb_items)} scripts MongoDB declarados.'))

    # seen_ids controla dependencias ja vistas.
    seen_ids: set[str] = set()

    # Percorre PostgreSQL em ordem de aplicacao.
    for item in postgres_items:
        # migration_id e o identificador logico da migration.
        migration_id = item['id']

        # path e o arquivo SQL no filesystem.
        path = ROOT / item['path']

        # exists registra se o arquivo existe.
        exists = path.exists()

        # Adiciona resultado de existencia.
        results.append(CheckResult(f'postgres.{migration_id}.exists', exists, item['path']))

        # missing_requirements identifica dependencias ainda nao vistas.
        missing_requirements = [requirement for requirement in item.get('requires', []) if requirement not in seen_ids]

        # A ordem e valida quando todas as dependencias ja apareceram.
        results.append(CheckResult(
            f'postgres.{migration_id}.order',
            not missing_requirements,
            'dependencias OK' if not missing_requirements else f'dependencias fora de ordem: {missing_requirements}',
        ))

        # Marca migration como vista para as proximas.
        seen_ids.add(migration_id)

    # seen_mongo_ids controla dependencias Mongo ja vistas.
    seen_mongo_ids: set[str] = set()

    # Percorre scripts MongoDB.
    for item in mongodb_items:
        # script_id identifica o script Mongo no manifesto.
        script_id = item['id']

        # path e o arquivo JS no filesystem.
        path = ROOT / item['path']

        # Adiciona resultado de existencia.
        results.append(CheckResult(f'mongodb.{script_id}.exists', path.exists(), item['path']))

        # missing_mongo_requirements identifica dependencias ainda nao vistas.
        missing_mongo_requirements = [requirement for requirement in item.get('requires', []) if requirement not in seen_mongo_ids]

        # A ordem Mongo e valida quando todas as dependencias ja apareceram.
        results.append(CheckResult(
            f'mongodb.{script_id}.order',
            not missing_mongo_requirements,
            'dependencias OK' if not missing_mongo_requirements else f'dependencias fora de ordem: {missing_mongo_requirements}',
        ))

        # Marca script Mongo como visto para os proximos.
        seen_mongo_ids.add(script_id)

    # Retorna checagens estruturais.
    return results


def validate_sql_file(path: Path) -> list[CheckResult]:
    """Valida regras estaticas simples de um arquivo SQL."""

    # text le o SQL em UTF-8.
    text = path.read_text(encoding='utf-8')

    # relative deixa nomes curtos no relatorio.
    relative = path.relative_to(ROOT)

    # upper facilita busca case-insensitive de comandos perigosos.
    upper = text.upper()

    # results guarda validacoes do arquivo.
    results = [
        # BEGIN garante que a migration e transacional.
        CheckResult(f'{relative}.begin', 'BEGIN;' in upper, 'Migration contem BEGIN.'),
        # COMMIT garante encerramento transacional explicito.
        CheckResult(f'{relative}.commit', 'COMMIT;' in upper, 'Migration contem COMMIT.'),
        # DROP destrutivo nao e aceito por padrao na esteira autonoma.
        CheckResult(f'{relative}.no_drop', 'DROP TABLE' not in upper and 'DROP TYPE' not in upper, 'Sem DROP TABLE/TYPE destrutivo.'),
        # DELETE sem trigger pode ser perigoso em migrations de schema.
        CheckResult(f'{relative}.no_raw_delete', 'DELETE FROM' not in upper, 'Sem DELETE FROM em migration de schema.'),
        # Comentarios sao obrigatorios para manter explicabilidade.
        CheckResult(f'{relative}.has_comments', '--' in text or 'COMMENT ON' in upper, 'Arquivo contem comentarios ou COMMENT ON.'),
    ]

    # Retorna checagens do SQL.
    return results


def validate_javascript_file(path: Path) -> list[CheckResult]:
    """Valida sintaxe JavaScript do script Mongo quando node estiver disponivel."""

    # node_path localiza o runtime Node.js.
    node_path = find_tool('node')

    # relative deixa nome curto no relatorio.
    relative = path.relative_to(ROOT)

    # Se node nao existir, registra skip sem falhar a arquitetura.
    if not node_path:
        return [CheckResult(f'{relative}.node_check', False, 'node nao encontrado para validar sintaxe JS.')]

    # Executa node --check para validar sintaxe sem rodar contra banco.
    result = run_command([node_path, '--check', str(path)], timeout_seconds=120)

    # ok depende do exit code zero.
    ok = result.returncode == 0

    # detail resume stdout/stderr.
    detail = 'node --check OK' if ok else (result.stderr or result.stdout).strip()

    # Retorna checagem unica.
    return [CheckResult(f'{relative}.node_check', ok, detail)]


def validate_environment() -> list[CheckResult]:
    """Valida ferramentas externas e variaveis de ambiente."""

    # results acumula checagens de ferramenta.
    results: list[CheckResult] = []

    # env_sources registra se DATABASE_URL/MONGODB_URI vieram de .env ou .env.example.
    env_sources = load_env_defaults()

    # python_runtime reaproveita o interpretador que esta rodando este script.
    python_runtime = sys.executable

    # Registra o Python real da sessao antes dos binarios externos.
    results.append(CheckResult('tool.python_runtime', bool(python_runtime), python_runtime or 'nao encontrado no runtime atual'))

    # skip_docker_checks permite rodar o report dentro do builder sem marcar falso negativo.
    skip_docker_checks = os.environ.get('VALLEY_SKIP_DOCKER_CHECKS', '').strip().lower() in {'1', 'true', 'yes'}

    # tools lista binarios externos relevantes para aplicar ou validar migrations.
    tools = ['node', 'psql', 'mongosh', 'docker']

    # Percorre ferramentas conhecidas.
    for tool in tools:
        # O builder de aplicacao nao precisa ter Docker CLI interna.
        if tool == 'docker' and skip_docker_checks:
            results.append(CheckResult('tool.docker', True, 'ignorado no runtime builder'))
            continue

        # path localiza binario no PATH.
        path = find_tool(tool)

        # Registra presenca da ferramenta.
        results.append(CheckResult(f'tool.{tool}', path is not None, path or 'nao encontrado no PATH'))

    # DATABASE_URL e necessario para aplicar PostgreSQL sem Docker exec.
    database_url = os.environ.get('DATABASE_URL')

    # database_url_detail explica se o valor veio do ambiente ou de arquivo local.
    database_url_detail = 'nao configurado'

    # Quando a variavel existir, detalha a fonte.
    if database_url:
        database_url_detail = f'configurado via {env_sources["DATABASE_URL"]}' if 'DATABASE_URL' in env_sources else 'configurado via ambiente'

    # Registra configuracao do PostgreSQL.
    results.append(CheckResult('env.DATABASE_URL', bool(database_url), database_url_detail))

    # MONGODB_URI e necessario para aplicar Mongo sem Docker exec.
    mongodb_uri = os.environ.get('MONGODB_URI')

    # mongodb_uri_detail explica se o valor veio do ambiente ou de arquivo local.
    mongodb_uri_detail = 'nao configurado'

    # Quando a variavel existir, detalha a fonte.
    if mongodb_uri:
        mongodb_uri_detail = f'configurado via {env_sources["MONGODB_URI"]}' if 'MONGODB_URI' in env_sources else 'configurado via ambiente'

    # Registra configuracao do MongoDB.
    results.append(CheckResult('env.MONGODB_URI', bool(mongodb_uri), mongodb_uri_detail))

    # docker compose pode existir mesmo sem daemon; checamos versao com timeout curto.
    docker_path = find_tool('docker')

    # Se o runtime pedir bypass, registra como OK explicito.
    if skip_docker_checks:
        results.append(CheckResult('tool.docker_daemon', True, 'ignorado no runtime builder'))
        results.append(CheckResult('tool.docker_compose', True, 'ignorado no runtime builder'))

    # Se docker existe, tenta validar compose.
    elif docker_path:
        # docker info confirma se o daemon esta respondendo, sem iniciar containers.
        docker_info = run_command([docker_path, 'info', '--format', '{{.ServerVersion}}'], timeout_seconds=30)

        # docker_detail explica melhor quando o daemon nao responde.
        docker_detail = (docker_info.stdout or docker_info.stderr or 'daemon nao respondeu').strip()

        # Timeout pede acao explicita no Docker Desktop ou engine local.
        if docker_info.returncode == 124:
            docker_detail = 'docker info nao respondeu em 30s; iniciar Docker Desktop ou verificar o engine.'

        # Registra prontidao do daemon separada da existencia da CLI.
        results.append(CheckResult('tool.docker_daemon', docker_info.returncode == 0, docker_detail))

        # Executa docker compose version sem exigir daemon.
        compose = run_command([docker_path, 'compose', 'version'], timeout_seconds=10)

        # Registra suporte compose.
        results.append(CheckResult('tool.docker_compose', compose.returncode == 0, (compose.stdout or compose.stderr).strip()))

    # Retorna ambiente.
    return results


def validate_module_artifacts() -> list[CheckResult]:
    """Valida documentos gerados para desenvolvimento dos 47 modulos."""

    # results acumula checagens de artefatos.
    results: list[CheckResult] = []

    # module_dirs localiza pastas numeradas de 01 a 47.
    module_dirs = sorted(MODULES_DIR.glob('[0-9][0-9]-*')) if MODULES_DIR.exists() else []

    # Confere se existem exatamente 47 pastas de modulo.
    results.append(CheckResult('modules.artifacts.directories', len(module_dirs) == 47, f'{len(module_dirs)} pastas de modulo encontradas.'))

    # missing_readme guarda modulos sem README.
    missing_readme = [path.name for path in module_dirs if not (path / 'README.md').exists()]

    # missing_status guarda modulos sem checklist.
    missing_status = [path.name for path in module_dirs if not (path / 'STATUS.md').exists()]

    # missing_contract guarda modulos sem contrato operacional.
    missing_contract = [path.name for path in module_dirs if not (path / 'CONTRACT.md').exists()]

    # Registra README por modulo.
    results.append(CheckResult('modules.artifacts.readme', not missing_readme, 'todos os README.md existem' if not missing_readme else f'faltando: {missing_readme}'))

    # Registra STATUS por modulo.
    results.append(CheckResult('modules.artifacts.status', not missing_status, 'todos os STATUS.md existem' if not missing_status else f'faltando: {missing_status}'))

    # Registra CONTRACT por modulo.
    results.append(CheckResult('modules.artifacts.contract', not missing_contract, 'todos os CONTRACT.md existem' if not missing_contract else f'faltando: {missing_contract}'))

    # Valida roadmap consolidado.
    results.append(CheckResult('modules.artifacts.roadmap', ROADMAP_PATH.exists(), str(ROADMAP_PATH.relative_to(ROOT))))

    # Valida matriz consolidada de contratos.
    results.append(CheckResult('modules.artifacts.contracts_summary', CONTRACTS_SUMMARY_PATH.exists(), str(CONTRACTS_SUMMARY_PATH.relative_to(ROOT))))

    # Valida backlog executavel consolidado por dominio.
    results.append(CheckResult('modules.artifacts.execution_backlog', EXECUTION_BACKLOG_PATH.exists(), str(EXECUTION_BACKLOG_PATH.relative_to(ROOT))))

    # Valida plano fisico da primeira onda de dominios prioritarios.
    results.append(CheckResult('modules.artifacts.priority_delivery_plan', PRIORITY_DOMAIN_PLAN_PATH.exists(), str(PRIORITY_DOMAIN_PLAN_PATH.relative_to(ROOT))))

    # Valida pacotes SQL por dominio prioritario.
    priority_domain_sql_files = sorted(PRIORITY_DOMAIN_SQL_DIR.glob('*/ddl_complement.sql')) if PRIORITY_DOMAIN_SQL_DIR.exists() else []
    results.append(CheckResult(
        'modules.artifacts.priority_delivery_sql',
        bool(priority_domain_sql_files),
        f'{len(priority_domain_sql_files)} arquivos ddl_complement.sql em {PRIORITY_DOMAIN_SQL_DIR.relative_to(ROOT)}',
    ))

    # Valida contratos JSON exportados por dominio prioritario.
    priority_domain_contract_files = sorted(PRIORITY_DOMAIN_CONTRACTS_DIR.glob('*.json')) if PRIORITY_DOMAIN_CONTRACTS_DIR.exists() else []
    results.append(CheckResult(
        'modules.artifacts.priority_delivery_contracts',
        bool(priority_domain_contract_files),
        f'{len(priority_domain_contract_files)} contratos JSON em {PRIORITY_DOMAIN_CONTRACTS_DIR.relative_to(ROOT)}',
    ))

    # Retorna resultados de documentacao operacional.
    return results


def validate_seed_artifacts() -> list[CheckResult]:
    """Valida existencia basica dos seeds operacionais versionados."""

    # results acumula checagens simples de presenca.
    results: list[CheckResult] = []

    # Confere seeds PostgreSQL.
    for path in POSTGRES_SEED_PATHS:
        # Registra existencia com caminho relativo para debug rapido.
        results.append(CheckResult(
            f'seed.{path.relative_to(ROOT)}.exists',
            path.exists(),
            str(path.relative_to(ROOT)),
        ))

    # Confere seeds MongoDB.
    for path in MONGODB_SEED_PATHS:
        # Registra existencia com caminho relativo para debug rapido.
        results.append(CheckResult(
            f'seed.{path.relative_to(ROOT)}.exists',
            path.exists(),
            str(path.relative_to(ROOT)),
        ))

    # Retorna checagens.
    return results


def validate_all() -> list[CheckResult]:
    """Executa todas as validacoes estaticas disponiveis."""

    # manifest carrega a ordem de migrations.
    manifest = load_manifest()

    # results comeca com validacao do ambiente.
    results = validate_environment()

    # Adiciona validacao estrutural do manifesto.
    results.extend(validate_manifest(manifest))

    # Adiciona validacao dos artefatos dos 47 modulos.
    results.extend(validate_module_artifacts())

    # Adiciona validacao dos seeds operacionais versionados.
    results.extend(validate_seed_artifacts())

    # Valida cada arquivo referenciado.
    for path in iter_manifest_paths(manifest):
        # Se arquivo nao existe, pula validacao especifica.
        if not path.exists():
            continue

        # SQL recebe checagens transacionais.
        if path.suffix == '.sql':
            results.extend(validate_sql_file(path))

        # Mongo JS recebe node --check.
        if path.suffix == '.js':
            results.extend(validate_javascript_file(path))

    # Valida seeds SQL fora do manifesto.
    for path in POSTGRES_SEED_PATHS:
        # So valida arquivo existente.
        if path.exists():
            results.extend(validate_sql_file(path))

    # Valida seeds Mongo fora do manifesto.
    for path in MONGODB_SEED_PATHS:
        # So valida arquivo existente.
        if path.exists():
            results.extend(validate_javascript_file(path))

    # Valida registry dos 47 modulos usando o motor existente.
    module_script = ROOT / 'scripts' / 'valley_module_automation.py'

    # Se o script existe, executa validate.
    if module_script.exists():
        # Roda validate para garantir 47 modulos.
        module_result = run_command([*PYTHON_COMMAND, str(module_script), 'validate'], timeout_seconds=30)

        # Registra resultado.
        results.append(CheckResult(
            'modules.registry.validate',
            module_result.returncode == 0,
            (module_result.stdout or module_result.stderr).strip(),
        ))

    # Retorna todas as checagens.
    return results


def sync_admin_console() -> list[Path]:
    """Regenera o console admin para refletir manifesto, docs e relatorio."""

    # Sem builder admin nao ha nada para sincronizar.
    if not ADMIN_BUILDER_PATH.exists():
        return []

    # result executa o builder admin com o mesmo Python atual.
    result = run_command([*PYTHON_COMMAND, str(ADMIN_BUILDER_PATH), 'build'], timeout_seconds=120)

    # Falha explicita evita painel admin desatualizado.
    if result.returncode != 0:
        raise RuntimeError((result.stderr or result.stdout or 'Falha ao sincronizar console admin.').strip())

    # changed converte stdout em caminhos reais do repo.
    changed: list[Path] = []

    for line in result.stdout.splitlines():
        # Ignora heartbeat sem alteracao.
        if not line.strip() or line.strip() == 'Nada para sincronizar.':
            continue

        # path resolve a saida relativa emitida pelo builder.
        path = ROOT / line.strip()

        # So registra artefatos existentes.
        if path.exists():
            changed.append(path)

    # Retorna artefatos efetivamente alterados.
    return changed


def ensure_report_dir() -> None:
    """Garante pasta de relatorios."""

    # mkdir com parents cria output/deployment se nao existir.
    REPORT_DIR.mkdir(parents=True, exist_ok=True)


def ensure_snapshot_dir() -> None:
    """Garante pasta base dos snapshots operacionais."""

    # mkdir com parents cria output/snapshots se nao existir.
    SNAPSHOT_DIR.mkdir(parents=True, exist_ok=True)


def sha256_file(path: Path) -> str:
    """Calcula SHA-256 de um arquivo binario sem carregar tudo em memoria."""

    # digest acumula o hash em blocos.
    digest = hashlib.sha256()

    # Le o arquivo em blocos fixos para suportar dumps grandes.
    with path.open('rb') as handle:
        while True:
            # chunk reduz consumo de memoria.
            chunk = handle.read(1024 * 1024)

            # EOF encerra o loop.
            if not chunk:
                break

            # Atualiza hash com o bloco lido.
            digest.update(chunk)

    # Retorna hash em hexadecimal.
    return digest.hexdigest()


def resolve_snapshot_manifest(snapshot_ref: str | None = None) -> Path:
    """Resolve o manifesto de snapshot pelo caminho informado ou pelo mais recente."""

    # Garante pasta base antes da busca.
    ensure_snapshot_dir()

    # explicit_path permite pasta do snapshot ou manifesto informado pelo operador.
    explicit_path = Path(snapshot_ref).expanduser() if snapshot_ref else None

    # Caminho explicito tem prioridade quando o operador quer um snapshot especifico.
    if explicit_path is not None:
        # candidate_path suporta refs relativas a partir da raiz e caminhos absolutos.
        candidate_path = explicit_path.resolve() if explicit_path.is_absolute() else (ROOT / explicit_path).resolve()

        # Diretorio aponta para o manifesto padrao interno do snapshot.
        if candidate_path.is_dir():
            candidate_path = candidate_path / 'snapshot_manifest.json'

        # Sem manifesto nao ha restore nem verify confiavel.
        if not candidate_path.exists():
            raise FileNotFoundError(f'Snapshot nao encontrado: {candidate_path}')

        return candidate_path

    # manifests ordena snapshots pelo nome UTC embutido no diretorio.
    manifests = sorted(
        SNAPSHOT_DIR.glob('valley_db_snapshot_*/snapshot_manifest.json'),
        key=lambda item: item.parent.name,
        reverse=True,
    )

    # Sem manifesto, nao existe snapshot disponivel.
    if not manifests:
        raise FileNotFoundError(f'Nenhum snapshot encontrado em {SNAPSHOT_DIR}')

    # O primeiro item ja e o snapshot mais recente.
    return manifests[0]


def load_snapshot_manifest(snapshot_ref: str | None = None) -> tuple[Path, dict]:
    """Carrega manifesto de snapshot a partir de ref opcional."""

    # manifest_path localiza o snapshot alvo.
    manifest_path = resolve_snapshot_manifest(snapshot_ref)

    # manifest parseia o JSON de rastreabilidade.
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))

    # Retorna ambos para o chamador reaproveitar base_dir.
    return manifest_path, manifest


def resolve_snapshot_artifact(manifest_path: Path, artifact_ref: str) -> Path:
    """Resolve caminho de artefato descrito no manifesto."""

    # root_relative suporta artefatos registrados a partir da raiz do repo.
    root_relative = (ROOT / artifact_ref).resolve()
    if root_relative.exists():
        return root_relative

    # fallback_to_snapshot suporta manifesto copiado junto dos artefatos.
    return (manifest_path.parent / Path(artifact_ref).name).resolve()


def validate_snapshot_manifest(manifest_path: Path, manifest: dict) -> list[CheckResult]:
    """Valida estrutura, tamanho e checksum dos artefatos do snapshot."""

    # results acumula diagnostico completo do snapshot.
    results: list[CheckResult] = []

    # required_keys garante minimo necessario para restore reproduzivel.
    required_keys = ['snapshot_id', 'postgres', 'mongodb']
    for key in required_keys:
        results.append(
            CheckResult(
                name=f'snapshot.manifest.{key}',
                ok=key in manifest,
                detail='chave presente no manifesto' if key in manifest else 'chave ausente no manifesto',
            )
        )

    # Estrutura minima quebrada encerra validacao cedo para evitar falso contexto.
    if not all(result.ok for result in results):
        return results

    # descriptors centraliza os dois binarios esperados.
    descriptors = [
        ('postgres', manifest.get('postgres', {})),
        ('mongodb', manifest.get('mongodb', {})),
    ]

    for label, descriptor in descriptors:
        # artifact_ref aponta para o arquivo declarado pelo manifesto.
        artifact_ref = descriptor.get('artifact')

        # expected_bytes e expected_sha fazem prova de integridade.
        expected_bytes = descriptor.get('bytes')
        expected_sha = descriptor.get('sha256')

        # Sem artifact, nao ha como verificar nada.
        if not artifact_ref:
            results.append(
                CheckResult(
                    name=f'snapshot.{label}.artifact',
                    ok=False,
                    detail='artifact ausente no manifesto',
                )
            )
            continue

        # artifact_path resolve o binario fisico esperado.
        artifact_path = resolve_snapshot_artifact(manifest_path, str(artifact_ref))

        # existence check evita hash em arquivo ausente.
        results.append(
            CheckResult(
                name=f'snapshot.{label}.exists',
                ok=artifact_path.exists(),
                detail=str(artifact_path),
            )
        )

        # Sem arquivo, nao adianta seguir para bytes e checksum.
        if not artifact_path.exists():
            continue

        # current_bytes mede o tamanho real.
        current_bytes = artifact_path.stat().st_size
        results.append(
            CheckResult(
                name=f'snapshot.{label}.bytes',
                ok=current_bytes == expected_bytes,
                detail=f'esperado={expected_bytes} atual={current_bytes}',
            )
        )

        # current_sha mede integridade real.
        current_sha = sha256_file(artifact_path)
        results.append(
            CheckResult(
                name=f'snapshot.{label}.sha256',
                ok=current_sha == expected_sha,
                detail=f'esperado={expected_sha} atual={current_sha}',
            )
        )

    return results


def capture_binary_command(command: list[str], output_path: Path, timeout_seconds: int = 600) -> CheckResult:
    """Executa comando binario e grava stdout em arquivo local."""

    # Garante pasta do artefato antes da escrita.
    output_path.parent.mkdir(parents=True, exist_ok=True)

    try:
        # stdout vai direto para arquivo binario.
        with output_path.open('wb') as handle:
            result = subprocess.run(
                command,
                cwd=ROOT,
                stdout=handle,
                stderr=subprocess.PIPE,
                timeout=timeout_seconds,
                check=False,
            )
    except subprocess.TimeoutExpired:
        # Timeout deixa o arquivo parcial sem utilidade; remove para evitar ruido.
        if output_path.exists():
            output_path.unlink()

        # Reporta timeout explicitamente.
        return CheckResult(
            name='binary_capture',
            ok=False,
            detail=f'comando excedeu {timeout_seconds}s e foi interrompido',
        )

    # stderr_text normaliza bytes para texto legivel.
    stderr_text = (result.stderr or b'').decode('utf-8', errors='replace').strip()

    # Em falha remove arquivo parcial para nao parecer snapshot valido.
    if result.returncode != 0:
        if output_path.exists():
            output_path.unlink()

        return CheckResult(
            name='binary_capture',
            ok=False,
            detail=stderr_text or f'exit {result.returncode}',
        )

    # Retorna sucesso com tamanho do artefato.
    return CheckResult(
        name='binary_capture',
        ok=True,
        detail=f'{output_path.name} ({output_path.stat().st_size} bytes)',
    )


def stream_binary_to_command(input_path: Path, command: list[str], timeout_seconds: int = 900) -> CheckResult:
    """Envia um arquivo binario para stdin de um comando externo."""

    try:
        # stdin injeta o snapshot binario diretamente no processo filho.
        with input_path.open('rb') as handle:
            result = subprocess.run(
                command,
                cwd=ROOT,
                stdin=handle,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=timeout_seconds,
                check=False,
            )
    except subprocess.TimeoutExpired:
        # Timeout explicito evita restore travado sem feedback.
        return CheckResult(
            name='binary_stream',
            ok=False,
            detail=f'comando excedeu {timeout_seconds}s e foi interrompido',
        )

    # stdout_text facilita leitura quando a ferramenta emite resumo util.
    stdout_text = (result.stdout or b'').decode('utf-8', errors='replace').strip()

    # stderr_text concentra erros da importacao.
    stderr_text = (result.stderr or b'').decode('utf-8', errors='replace').strip()

    # Return code zero indica sucesso do stream.
    if result.returncode == 0:
        return CheckResult(
            name='binary_stream',
            ok=True,
            detail=stdout_text or stderr_text or f'{input_path.name} importado com sucesso',
        )

    # Falha detalha a mensagem real da ferramenta.
    return CheckResult(
        name='binary_stream',
        ok=False,
        detail=stderr_text or stdout_text or f'exit {result.returncode}',
    )


def write_report(results: list[CheckResult], report_path: Path = REPORT_PATH) -> Path:
    """Escreve relatorio Markdown da esteira."""

    # Garante pasta de destino.
    ensure_report_dir()

    # now registra horario UTC do relatorio.
    now = datetime.now(timezone.utc).isoformat()

    # failed filtra checagens com falha.
    failed = [result for result in results if not result.ok]

    # lines inicia o relatorio.
    lines = [
        '# Valley Deployment Status',
        '',
        f'Gerado em UTC: `{now}`.',
        '',
        f'Total de checagens: `{len(results)}`.',
        f'Falhas ou pendencias: `{len(failed)}`.',
        '',
        '## Resultado',
        '',
    ]

    # Adiciona cada checagem em linha simples.
    for result in results:
        # icon torna leitura rapida.
        icon = 'OK' if result.ok else 'PENDENTE'

        # Linha com nome e detalhe.
        lines.append(f'- {icon} - `{result.name}`: {result.detail}')

    # Adiciona instrucao operacional.
    lines.extend([
        '',
        '## Como Aplicar Quando Houver Banco Disponivel',
        '',
        'PowerShell ou terminal com `.env`/`.env.example` na raiz:',
        '',
        '```bash',
        'python scripts/valley_db_orchestrator.py apply-postgres',
        'python scripts/valley_db_orchestrator.py apply-mongo',
        '```',
        '',
        'Override manual por variavel em Bash:',
        '',
        '```bash',
        'DATABASE_URL=postgresql://user:pass@host:5432/db python scripts/valley_db_orchestrator.py apply-postgres',
        'MONGODB_URI=mongodb://localhost:27017/valley python scripts/valley_db_orchestrator.py apply-mongo',
        '```',
        '',
        'Override manual por variavel em PowerShell:',
        '',
        '```powershell',
        "$env:DATABASE_URL='postgresql://user:pass@host:5432/db'; python scripts/valley_db_orchestrator.py apply-postgres",
        "$env:MONGODB_URI='mongodb://localhost:27017/valley'; python scripts/valley_db_orchestrator.py apply-mongo",
        '```',
        '',
        'Ambiente local com Docker Compose (o `apply-compose` ja executa `compose-up`):',
        '',
        '```bash',
        'python scripts/valley_db_orchestrator.py apply-compose',
        'python scripts/valley_db_orchestrator.py report',
        'python scripts/valley_db_orchestrator.py compose-down',
        '```',
        '',
        'Seeds minimos e smoke checks do bloco expansion aplicado:',
        '',
        '```bash',
        'python scripts/valley_db_orchestrator.py seed-compose',
        'python scripts/valley_db_orchestrator.py smoke-compose',
        '```',
        '',
        'Exportar snapshot operacional do banco aplicado no Compose:',
        '',
        '```bash',
        'python scripts/valley_db_orchestrator.py snapshot-compose',
        '```',
        '',
        'Verificar integridade do snapshot mais recente antes de restore:',
        '',
        '```bash',
        'python scripts/valley_db_orchestrator.py snapshot-verify',
        '```',
        '',
        'Restaurar o snapshot mais recente no Compose local:',
        '',
        '```bash',
        'python scripts/valley_db_orchestrator.py restore-compose',
        '```',
        '',
    ])

    # Escreve relatorio em UTF-8.
    report_path.write_text('\n'.join(lines), encoding='utf-8')

    # Retorna caminho gerado.
    return report_path


def sql_literal(value: str) -> str:
    """Escapa string simples para uso em consulta tecnica controlada."""

    # Manifesto e versionado, mas ainda assim escapamos aspas simples.
    return "'" + value.replace("'", "''") + "'"


def psql_query_command(use_compose: bool, query: str) -> list[str] | None:
    """Monta comando psql para consulta escalar de estado."""

    # Compose usa o psql dentro do container postgres.
    if use_compose:
        return ['docker', 'compose', 'exec', '-T', 'postgres', 'psql', '-U', 'valley', '-d', 'valley', '-At', '-c', query]

    # Fora do Compose, usa .env/.env.example e psql local.
    load_env_defaults()
    database_url = os.environ.get('DATABASE_URL')
    psql_path = find_tool('psql')

    # Sem binario ou URL, nao ha como consultar estado.
    if not database_url or not psql_path:
        return None

    # Retorna comando local.
    return [psql_path, database_url, '-At', '-c', query]


def postgres_provides_exist(item: dict, use_compose: bool) -> bool:
    """Verifica se uma migration PostgreSQL ja materializou seus objetos principais."""

    # Comments sao pseudo-provides documentais e podem ser reaplicados com seguranca.
    provides = [value for value in item.get('provides', []) if not str(value).startswith('comments_')]

    # Sem objetos reais, nao pulamos a migration.
    if not provides:
        return False

    # checks recebe uma condicao SQL por provide suportado.
    checks: list[str] = []

    for value in provides:
        # provide_text normaliza o item do manifesto para parse simples.
        provide_text = str(value)

        # relation:schema.name valida tabelas ou views fora do schema public.
        if provide_text.startswith('relation:'):
            relation_name = provide_text.split(':', 1)[1]
            if '.' not in relation_name:
                relation_name = 'public.' + relation_name

            checks.append(f'to_regclass({sql_literal(relation_name)}) IS NOT NULL')
            continue

        # column:public.table.column ou column:table.column valida evolucao por coluna.
        if provide_text.startswith('column:'):
            # path remove o prefixo tecnico.
            path = provide_text.split(':', 1)[1]

            # parts permite esquema opcional.
            parts = path.split('.')

            if len(parts) == 3:
                schema_name, table_name, column_name = parts
            elif len(parts) == 2:
                schema_name, table_name, column_name = 'public', parts[0], parts[1]
            else:
                return False

            checks.append(
                'EXISTS ('
                'SELECT 1 FROM information_schema.columns '
                f'WHERE table_schema = {sql_literal(schema_name)} '
                f'AND table_name = {sql_literal(table_name)} '
                f'AND column_name = {sql_literal(column_name)}'
                ')'
            )
            continue

        # module_catalog:CODE valida linhas sem exigir uma migration ledger separada.
        if provide_text.startswith('module_catalog:'):
            module_code = provide_text.split(':', 1)[1]
            checks.append(
                'EXISTS ('
                'SELECT 1 FROM module_catalog '
                f'WHERE module_code = {sql_literal(module_code)}'
                ')'
            )
            continue

        # Default continua tratando provide como relation publica esperada.
        checks.append(f'to_regclass({sql_literal("public." + provide_text)}) IS NOT NULL')

    # all_exists volta true apenas quando todos existem.
    query = 'SELECT CASE WHEN ' + ' AND '.join(checks) + " THEN 'true' ELSE 'false' END;"

    # command monta a chamada psql apropriada para compose/local.
    command = psql_query_command(use_compose, query)

    # Se nao conseguimos consultar, nao pulamos para evitar falso positivo.
    if command is None:
        return False

    # Executa consulta curta de estado.
    result = run_command(command, timeout_seconds=30)

    # true explicito indica migration ja aplicada no volume.
    return result.returncode == 0 and result.stdout.strip() == 'true'


def mongosh_query_command(use_compose: bool, query: str) -> list[str] | None:
    """Monta comando mongosh para consulta escalar de estado."""

    # Compose usa mongosh dentro do container mongodb.
    if use_compose:
        return ['docker', 'compose', 'exec', '-T', 'mongodb', 'mongosh', 'mongodb://localhost:27017/valley', '--quiet', '--eval', query]

    # Fora do Compose, usa .env/.env.example e mongosh local.
    load_env_defaults()
    mongodb_uri = os.environ.get('MONGODB_URI')
    mongosh_path = find_tool('mongosh')

    # Sem binario ou URI, nao ha como consultar estado.
    if not mongodb_uri or not mongosh_path:
        return None

    # Retorna comando local.
    return [mongosh_path, mongodb_uri, '--quiet', '--eval', query]


def mongo_provides_exist(item: dict, use_compose: bool) -> bool:
    """Verifica se um script MongoDB ja materializou suas collections principais."""

    # provides contem collections esperadas pelo script.
    provides = [str(value) for value in item.get('provides', [])]

    # Sem provides, nao pulamos.
    if not provides:
        return False

    # JSON e mais seguro para injetar nomes no snippet JavaScript.
    required_json = json.dumps(provides)

    # query retorna true somente se todas as collections existirem.
    query = (
        f"const required = {required_json}; "
        "const names = db.getCollectionNames(); "
        "print(required.every((name) => names.includes(name)) ? 'true' : 'false');"
    )

    # command monta mongosh local ou compose.
    command = mongosh_query_command(use_compose, query)

    # Sem consulta disponivel, nao pula.
    if command is None:
        return False

    # Executa consulta curta.
    result = run_command(command, timeout_seconds=30)

    # true explicito indica script ja aplicado.
    return result.returncode == 0 and result.stdout.strip().endswith('true')


def apply_postgres(manifest: dict, use_compose: bool = False) -> int:
    """Aplica migrations PostgreSQL via psql local ou docker compose exec."""

    # postgres_items pega migrations em ordem.
    postgres_items = manifest.get('postgres', [])

    # Se usar compose, executa psql dentro do container.
    if use_compose:
        # command_base chama psql do servico postgres.
        command_base = ['docker', 'compose', 'exec', '-T', 'postgres', 'psql', '-U', 'valley', '-d', 'valley', '-v', 'ON_ERROR_STOP=1', '-f']
    else:
        # Carrega .env/.env.example antes de validar DATABASE_URL.
        load_env_defaults()

        # DATABASE_URL e exigido para psql local.
        database_url = os.environ.get('DATABASE_URL')

        # Se nao houver DATABASE_URL, nao aplica.
        if not database_url:
            print('DATABASE_URL nao configurado; PostgreSQL nao aplicado.')
            return 2

        # psql precisa existir no PATH.
        psql_path = find_tool('psql')

        # Se psql nao existir, nao aplica.
        if not psql_path:
            print('psql nao encontrado; PostgreSQL nao aplicado.')
            return 2

        # command_base chama psql com URL.
        command_base = [psql_path, database_url, '-v', 'ON_ERROR_STOP=1', '-f']

    # Percorre cada migration.
    for item in postgres_items:
        # path e o arquivo SQL.
        path = ROOT / item['path']

        # Se os objetos principais ja existem, evita replay nao idempotente de CREATE TYPE.
        if postgres_provides_exist(item, use_compose=use_compose):
            print(f'postgres {item["id"]}: {path.relative_to(ROOT)} -> skip already applied')
            continue

        # No compose, o caminho precisa estar acessivel; usamos docker compose cp fallback nao implementado.
        if use_compose:
            # docker compose exec nao enxerga arquivo local sem volume; usa stdin via -f -.
            command = ['docker', 'compose', 'exec', '-T', 'postgres', 'psql', '-U', 'valley', '-d', 'valley', '-v', 'ON_ERROR_STOP=1']
            # Executa psql recebendo SQL por stdin.
            result = subprocess.run(command, cwd=ROOT, input=path.read_text(encoding='utf-8'), text=True, capture_output=True, timeout=120, check=False)
        else:
            # Executa psql com arquivo local.
            result = run_command(command_base + [str(path)], timeout_seconds=120)

        # Mostra progresso.
        print(f'postgres {item["id"]}: {path.relative_to(ROOT)} -> {result.returncode}')

        # Se falhar, imprime erro e encerra.
        if result.returncode != 0:
            print(result.stderr or result.stdout)
            return result.returncode

    # Retorna sucesso.
    return 0


def apply_mongo(manifest: dict, use_compose: bool = False) -> int:
    """Aplica scripts MongoDB via mongosh local ou docker compose exec."""

    # mongodb_items pega scripts em ordem.
    mongodb_items = manifest.get('mongodb', [])

    # Se usar compose, mongosh roda dentro do container.
    if use_compose:
        # command_base chama mongosh no servico mongodb.
        command_base = ['docker', 'compose', 'exec', '-T', 'mongodb', 'mongosh', 'mongodb://localhost:27017/valley', '--file']
    else:
        # Carrega .env/.env.example antes de validar MONGODB_URI.
        load_env_defaults()

        # MONGODB_URI e exigido para mongosh local.
        mongodb_uri = os.environ.get('MONGODB_URI')

        # Se nao houver MONGODB_URI, nao aplica.
        if not mongodb_uri:
            print('MONGODB_URI nao configurado; MongoDB nao aplicado.')
            return 2

        # mongosh precisa existir no PATH.
        mongosh_path = find_tool('mongosh')

        # Se mongosh nao existir, nao aplica.
        if not mongosh_path:
            print('mongosh nao encontrado; MongoDB nao aplicado.')
            return 2

        # command_base chama mongosh com URI.
        command_base = [mongosh_path, mongodb_uri, '--file']

    # Percorre cada script Mongo.
    for item in mongodb_items:
        # path e o arquivo JS.
        path = ROOT / item['path']

        # Se as collections principais ja existem, evita replay desnecessario.
        if mongo_provides_exist(item, use_compose=use_compose):
            print(f'mongodb {item["id"]}: {path.relative_to(ROOT)} -> skip already applied')
            continue

        # Compose precisa que o arquivo exista no container; usamos stdin para evitar linha de comando gigante com --eval.
        if use_compose:
            # sh cria um arquivo temporario dentro do container e executa o script com mongosh.
            command = ['docker', 'compose', 'exec', '-T', 'mongodb', 'sh', '-lc', 'cat >/tmp/valley_apply.mongo.js && mongosh mongodb://localhost:27017/valley --quiet --file /tmp/valley_apply.mongo.js']
            result = subprocess.run(command, cwd=ROOT, input=path.read_text(encoding='utf-8'), text=True, capture_output=True, timeout=120, check=False)
        else:
            # Executa mongosh com arquivo local.
            result = run_command(command_base + [str(path)], timeout_seconds=120)

        # Mostra progresso.
        print(f'mongodb {item["id"]}: {path.relative_to(ROOT)} -> {result.returncode}')

        # Se falhar, imprime erro e encerra.
        if result.returncode != 0:
            print(result.stderr or result.stdout)
            return result.returncode

    # Retorna sucesso.
    return 0


def apply_seed_postgres(use_compose: bool = False) -> int:
    """Aplica seeds PostgreSQL versionados fora do manifesto de schema."""

    # Se usar compose, executa psql dentro do container.
    if use_compose:
        # Compose recebe SQL por stdin para evitar problemas de path.
        command = ['docker', 'compose', 'exec', '-T', 'postgres', 'psql', '-U', 'valley', '-d', 'valley', '-v', 'ON_ERROR_STOP=1']
    else:
        # Carrega defaults antes de validar DATABASE_URL.
        load_env_defaults()

        # DATABASE_URL e exigido para seed local.
        database_url = os.environ.get('DATABASE_URL')

        # Sem URL nao ha como aplicar seed.
        if not database_url:
            print('DATABASE_URL nao configurado; seed PostgreSQL nao aplicada.')
            return 2

        # psql precisa existir no PATH.
        psql_path = find_tool('psql')

        # Sem binario nao ha como aplicar seed.
        if not psql_path:
            print('psql nao encontrado; seed PostgreSQL nao aplicada.')
            return 2

        # command_base executa arquivo local diretamente.
        command_base = [psql_path, database_url, '-v', 'ON_ERROR_STOP=1', '-f']

    # Percorre seeds PostgreSQL declarados.
    for path in POSTGRES_SEED_PATHS:
        # Sem arquivo nao ha o que aplicar.
        if not path.exists():
            print(f'seed postgres ausente: {path.relative_to(ROOT)}')
            return 2

        # Compose recebe SQL por stdin.
        if use_compose:
            result = subprocess.run(
                command,
                cwd=ROOT,
                input=path.read_text(encoding='utf-8'),
                text=True,
                capture_output=True,
                timeout=120,
                check=False,
            )
        else:
            # Local usa caminho do arquivo diretamente.
            result = run_command(command_base + [str(path)], timeout_seconds=120)

        # Mostra progresso.
        print(f'seed postgres: {path.relative_to(ROOT)} -> {result.returncode}')

        # Em falha, imprime detalhe e aborta.
        if result.returncode != 0:
            print(result.stderr or result.stdout)
            return result.returncode

    # Retorna sucesso.
    return 0


def apply_seed_mongo(use_compose: bool = False) -> int:
    """Aplica seeds MongoDB versionados fora do manifesto de schema."""

    # Se usar compose, executa mongosh dentro do container.
    if use_compose:
        # Compose injeta o script por stdin e roda dentro do container.
        command = ['docker', 'compose', 'exec', '-T', 'mongodb', 'sh', '-lc', 'cat >/tmp/valley_seed.mongo.js && mongosh mongodb://localhost:27017/valley --quiet --file /tmp/valley_seed.mongo.js']
    else:
        # Carrega defaults antes de validar MONGODB_URI.
        load_env_defaults()

        # MONGODB_URI e exigido para seed local.
        mongodb_uri = os.environ.get('MONGODB_URI')

        # Sem URI nao ha como aplicar seed.
        if not mongodb_uri:
            print('MONGODB_URI nao configurado; seed MongoDB nao aplicada.')
            return 2

        # mongosh precisa existir no PATH.
        mongosh_path = find_tool('mongosh')

        # Sem binario nao ha como aplicar seed.
        if not mongosh_path:
            print('mongosh nao encontrado; seed MongoDB nao aplicada.')
            return 2

        # command_base executa arquivo local diretamente.
        command_base = [mongosh_path, mongodb_uri, '--quiet', '--file']

    # Percorre seeds MongoDB declarados.
    for path in MONGODB_SEED_PATHS:
        # Sem arquivo nao ha o que aplicar.
        if not path.exists():
            print(f'seed mongodb ausente: {path.relative_to(ROOT)}')
            return 2

        # Compose recebe JS por stdin.
        if use_compose:
            result = subprocess.run(
                command,
                cwd=ROOT,
                input=path.read_text(encoding='utf-8'),
                text=True,
                capture_output=True,
                timeout=120,
                check=False,
            )
        else:
            # Local usa caminho do arquivo diretamente.
            result = run_command(command_base + [str(path)], timeout_seconds=120)

        # Mostra progresso.
        print(f'seed mongodb: {path.relative_to(ROOT)} -> {result.returncode}')

        # Em falha, imprime detalhe e aborta.
        if result.returncode != 0:
            print(result.stderr or result.stdout)
            return result.returncode

    # Retorna sucesso.
    return 0


def run_postgres_smoke_checks(check_group: str, checks: dict[str, str], use_compose: bool = False) -> int:
    """Executa um conjunto nomeado de smoke checks booleanos em PostgreSQL."""

    # query concatena checks em uma grade simples nome|true/false.
    query = ' UNION ALL '.join(
        f"SELECT {sql_literal(name)} AS name, CASE WHEN {expression} THEN 'true' ELSE 'false' END AS ok"
        for name, expression in checks.items()
    ) + ';'

    # command monta psql local ou compose.
    command = psql_query_command(use_compose, query)

    # Sem comando nao ha como consultar.
    if command is None:
        print(f'psql nao disponivel para smoke-postgres:{check_group}.')
        return 2

    # Executa consulta de smoke.
    result = run_command(command, timeout_seconds=30)

    # Em falha, imprime saida bruta.
    if result.returncode != 0:
        print(result.stderr or result.stdout)
        return result.returncode

    # all_ok acumula o resultado geral.
    all_ok = True

    # Percorre linhas nome|true ou nome|false.
    for raw_line in result.stdout.splitlines():
        # Ignora linhas vazias.
        if not raw_line.strip() or '|' not in raw_line:
            continue

        # name e ok_text representam o status do check.
        name, ok_text = raw_line.split('|', 1)
        ok = ok_text.strip() == 'true'
        all_ok = all_ok and ok
        status = 'OK' if ok else 'PENDENTE'
        print(f'{status} smoke.postgres.{check_group}.{name}: {ok_text.strip()}')

    # Retorna sucesso apenas quando tudo passou.
    return 0 if all_ok else 1


def smoke_postgres_expansion(use_compose: bool = False) -> int:
    """Executa smoke checks nos seeds e FKs do bloco expansion em PostgreSQL."""

    # ids deixa a montagem das consultas mais legivel.
    ids = SEED_IDS

    # checks mapeia nome de verificacao para expressao SQL booleana.
    checks = {
        'tourism_experience_seed': (
            f"EXISTS (SELECT 1 FROM tourism_experiences "
            f"WHERE experience_id = {sql_literal(ids['tourism_experience_id'])} "
            f"AND experience_code = 'TOURISM_EXP_01')"
        ),
        'tourism_booking_fk_chain': (
            f"EXISTS (SELECT 1 FROM tourism_bookings b "
            f"JOIN tourism_experiences e ON e.experience_id = b.experience_id "
            f"WHERE b.booking_id = {sql_literal(ids['tourism_booking_id'])} "
            f"AND b.traveler_user_id = {sql_literal(ids['traveler_user_id'])} "
            f"AND e.experience_id = {sql_literal(ids['tourism_experience_id'])})"
        ),
        'tourism_booking_event_seed': (
            f"EXISTS (SELECT 1 FROM tourism_booking_events "
            f"WHERE booking_event_id = {sql_literal(ids['tourism_booking_event_id'])} "
            f"AND booking_id = {sql_literal(ids['tourism_booking_id'])})"
        ),
        'bio_program_seed': (
            f"EXISTS (SELECT 1 FROM bio_material_programs "
            f"WHERE program_id = {sql_literal(ids['bio_program_id'])} "
            f"AND program_code = 'BIO_PROGRAM_01')"
        ),
        'bio_collection_fk_chain': (
            f"EXISTS (SELECT 1 FROM bio_collection_orders o "
            f"JOIN bio_material_programs p ON p.program_id = o.program_id "
            f"WHERE o.collection_order_id = {sql_literal(ids['bio_collection_order_id'])} "
            f"AND p.program_id = {sql_literal(ids['bio_program_id'])})"
        ),
        'bio_collection_event_seed': (
            f"EXISTS (SELECT 1 FROM bio_collection_events "
            f"WHERE collection_event_id = {sql_literal(ids['bio_collection_event_id'])} "
            f"AND collection_order_id = {sql_literal(ids['bio_collection_order_id'])})"
        ),
        'energy_assets_seed': (
            f"(SELECT count(*) FROM energy_assets "
            f"WHERE energy_asset_id IN ("
            f"{sql_literal(ids['energy_asset_id'])}, "
            f"{sql_literal(ids['energy_counterparty_asset_id'])})) = 2"
        ),
        'energy_trade_fk_chain': (
            f"EXISTS (SELECT 1 FROM energy_trade_orders t "
            f"JOIN energy_assets a ON a.energy_asset_id = t.source_asset_id "
            f"WHERE t.trade_order_id = {sql_literal(ids['energy_trade_order_id'])} "
            f"AND t.counterparty_asset_id = {sql_literal(ids['energy_counterparty_asset_id'])} "
            f"AND a.energy_asset_id = {sql_literal(ids['energy_asset_id'])})"
        ),
        'energy_settlement_seed': (
            f"EXISTS (SELECT 1 FROM energy_settlement_ledger "
            f"WHERE settlement_entry_id = {sql_literal(ids['energy_settlement_entry_id'])} "
            f"AND trade_order_id = {sql_literal(ids['energy_trade_order_id'])})"
        ),
    }

    # Executa a grade expansion em um helper comum.
    return run_postgres_smoke_checks('expansion', checks, use_compose)


def smoke_postgres_platform_developer(use_compose: bool = False) -> int:
    """Executa smoke checks do seed operacional do dominio platform_developer."""

    # ids deixa a montagem das consultas mais legivel.
    ids = SEED_IDS

    # checks valida encadeamentos reais de docs e tech.
    checks = {
        'docs_template_chain': (
            f"EXISTS (SELECT 1 FROM docs_template_contracts contract "
            f"JOIN docs_template_versions version_row "
            f"  ON version_row.template_contract_id = contract.template_contract_id "
            f"JOIN docs_document_checksum_events checksum_row "
            f"  ON checksum_row.template_version_id = version_row.template_version_id "
            f"JOIN docs_receipt_versions receipt_version "
            f"  ON receipt_version.checksum_event_id = checksum_row.checksum_event_id "
            f"WHERE contract.template_contract_id = {sql_literal(ids['platform_template_contract_id'])} "
            f"  AND version_row.template_version_id = {sql_literal(ids['platform_template_version_id'])} "
            f"  AND checksum_row.checksum_event_id = {sql_literal(ids['platform_checksum_event_id'])} "
            f"  AND receipt_version.receipt_version_id = {sql_literal(ids['platform_receipt_version_id'])})"
        ),
        'docs_templates_view': (
            f"EXISTS (SELECT 1 FROM v_platform_developer_docs_templates "
            f"WHERE template_contract_id = {sql_literal(ids['platform_template_contract_id'])} "
            f"AND published_versions = 1)"
        ),
        'tech_rotation_chain': (
            f"EXISTS (SELECT 1 FROM tech_credential_rotation_events rotation_row "
            f"JOIN tech_api_credentials previous_row "
            f"  ON previous_row.api_credential_id = rotation_row.previous_credential_id "
            f"JOIN tech_api_credentials new_row "
            f"  ON new_row.api_credential_id = rotation_row.new_credential_id "
            f"JOIN tech_client_module_limits limit_row "
            f"  ON limit_row.api_client_id = rotation_row.api_client_id "
            f"WHERE rotation_row.credential_rotation_event_id = {sql_literal(ids['platform_rotation_event_id'])} "
            f"  AND previous_row.api_credential_id = {sql_literal(ids['platform_old_credential_id'])} "
            f"  AND new_row.api_credential_id = {sql_literal(ids['platform_new_credential_id'])} "
            f"  AND limit_row.api_client_limit_id = {sql_literal(ids['platform_api_client_limit_id'])})"
        ),
        'tech_webhook_replay_queue_view': (
            f"EXISTS (SELECT 1 FROM v_platform_developer_webhook_replay_queue "
            f"WHERE webhook_replay_request_id = {sql_literal(ids['platform_webhook_replay_request_id'])} "
            f"AND original_delivery_status = 'FAILED'::webhook_delivery_status_enum "
            f"AND replay_status = 'REPLAYED'::tech_webhook_replay_status_enum)"
        ),
    }

    # Executa a grade do dominio.
    return run_postgres_smoke_checks('platform_developer', checks, use_compose)


def smoke_postgres_logistics_erp_operations(use_compose: bool = False) -> int:
    """Executa smoke checks do seed operacional do dominio logistics_erp_operations."""

    # ids deixa a montagem das consultas mais legivel.
    ids = SEED_IDS

    # checks valida procurement, business, fulfillment, WMS e frota.
    checks = {
        'business_finance_chain': (
            f"EXISTS (SELECT 1 FROM business_invoices invoice_row "
            f"JOIN business_payrolls payroll_row "
            f"  ON payroll_row.business_unit_id = invoice_row.business_unit_id "
            f"JOIN business_fiscal_closures closure_row "
            f"  ON closure_row.business_unit_id = invoice_row.business_unit_id "
            f"WHERE invoice_row.invoice_id = {sql_literal(ids['logistics_business_invoice_id'])} "
            f"  AND payroll_row.payroll_id = {sql_literal(ids['logistics_business_payroll_id'])} "
            f"  AND closure_row.fiscal_closure_id = {sql_literal(ids['logistics_fiscal_closure_id'])})"
        ),
        'business_units_view': (
            f"EXISTS (SELECT 1 FROM v_logistics_erp_business_units "
            f"WHERE business_unit_id = {sql_literal(ids['logistics_business_unit_id'])} "
            f"AND unit_status = 'ACTIVE'::business_unit_status_enum)"
        ),
        'procurement_controls_view': (
            f"EXISTS (SELECT 1 FROM v_logistics_erp_procurement_controls "
            f"WHERE procurement_order_id = {sql_literal(ids['logistics_procurement_order_id'])} "
            f"AND approval_events >= 1 "
            f"AND approval_policy_id = {sql_literal(ids['logistics_approval_policy_id'])})"
        ),
        'stock_wms_chain': (
            f"EXISTS (SELECT 1 FROM inventory_lots lot_row "
            f"JOIN warehouse_locations location_row "
            f"  ON location_row.warehouse_location_id = lot_row.warehouse_location_id "
            f"JOIN warehouse_cycle_counts cycle_row "
            f"  ON cycle_row.item_id = lot_row.item_id "
            f"JOIN warehouse_variance_adjustments adjustment_row "
            f"  ON adjustment_row.cycle_count_id = cycle_row.cycle_count_id "
            f"JOIN warehouse_temperature_incidents temp_row "
            f"  ON temp_row.warehouse_location_id = location_row.warehouse_location_id "
            f"JOIN inventory_stockout_cases stockout_row "
            f"  ON stockout_row.item_id = lot_row.item_id "
            f"WHERE lot_row.inventory_lot_id = {sql_literal(ids['logistics_inventory_lot_id'])} "
            f"  AND location_row.warehouse_location_id = {sql_literal(ids['logistics_warehouse_location_id'])} "
            f"  AND adjustment_row.variance_adjustment_id = {sql_literal(ids['logistics_variance_adjustment_id'])} "
            f"  AND temp_row.temperature_incident_id = {sql_literal(ids['logistics_temperature_incident_id'])} "
            f"  AND stockout_row.stockout_case_id = {sql_literal(ids['logistics_stockout_case_id'])})"
        ),
        'fulfillment_ops_view': (
            f"EXISTS (SELECT 1 FROM v_logistics_erp_fulfillment_ops "
            f"WHERE shipment_id = {sql_literal(ids['logistics_shipment_id'])} "
            f"AND delivery_policy_id = {sql_literal(ids['logistics_delivery_policy_id'])} "
            f"AND food_store_name = 'Valley Kitchen Paulista')"
        ),
        'status_mapping_seed': (
            f"EXISTS (SELECT 1 FROM logistics_status_mappings "
            f"WHERE status_mapping_id = {sql_literal(ids['logistics_status_mapping_id'])} "
            f"AND canonical_status = 'IN_TRANSIT'::logistics_canonical_status_enum)"
        ),
        'fleet_trip_chain': (
            f"EXISTS (SELECT 1 FROM mobility_trips trip_row "
            f"JOIN fleet_vehicle_operating_profiles profile_row "
            f"  ON profile_row.vehicle_operating_profile_id = trip_row.vehicle_operating_profile_id "
            f"JOIN fleet_cost_entries cost_row "
            f"  ON cost_row.vehicle_operating_profile_id = profile_row.vehicle_operating_profile_id "
            f"WHERE trip_row.trip_id = {sql_literal(ids['logistics_mobility_trip_id'])} "
            f"  AND profile_row.vehicle_operating_profile_id = {sql_literal(ids['logistics_vehicle_profile_id'])} "
            f"  AND cost_row.fleet_cost_entry_id = {sql_literal(ids['logistics_fleet_cost_entry_id'])})"
        ),
    }

    # Executa a grade do dominio.
    return run_postgres_smoke_checks('logistics_erp_operations', checks, use_compose)


def smoke_postgres_city_mobility_security(use_compose: bool = False) -> int:
    """Executa smoke checks do seed operacional do dominio city_mobility_security."""

    # ids deixa a montagem das consultas mais legivel.
    ids = SEED_IDS

    # checks valida juridico, experiencia, seguranca e govtech.
    checks = {
        'legal_chain': (
            f"EXISTS (SELECT 1 FROM legal_contracts contract "
            f"JOIN legal_signatures signature_row "
            f"  ON signature_row.legal_contract_id = contract.legal_contract_id "
            f"JOIN legal_disputes dispute_row "
            f"  ON dispute_row.legal_contract_id = contract.legal_contract_id "
            f"WHERE contract.legal_contract_id = {sql_literal(ids['city_legal_contract_id'])} "
            f"  AND signature_row.legal_signature_id = {sql_literal(ids['city_signature_id'])} "
            f"  AND dispute_row.legal_dispute_id = {sql_literal(ids['city_dispute_id'])} "
            f"  AND EXISTS (SELECT 1 FROM legal_contract_parties party_row "
            f"      WHERE party_row.legal_contract_id = contract.legal_contract_id "
            f"        AND party_row.legal_contract_party_id IN ("
            f"            {sql_literal(ids['city_contract_owner_party_id'])}, "
            f"            {sql_literal(ids['city_contract_counterparty_party_id'])})) "
            f"  AND EXISTS (SELECT 1 FROM legal_audit_events audit_row "
            f"      WHERE audit_row.legal_audit_event_id = {sql_literal(ids['city_dispute_audit_event_id'])} "
            f"        AND audit_row.legal_dispute_id = dispute_row.legal_dispute_id))"
        ),
        'legal_ops_view': (
            f"EXISTS (SELECT 1 FROM v_city_mobility_security_legal_ops "
            f"WHERE legal_contract_id = {sql_literal(ids['city_legal_contract_id'])} "
            f"AND party_count = 2 "
            f"AND signed_signatures = 1 "
            f"AND open_disputes = 1)"
        ),
        'experience_chain': (
            f"EXISTS (SELECT 1 FROM tourism_bookings booking_row "
            f"JOIN tourism_experiences experience_row "
            f"  ON experience_row.experience_id = booking_row.experience_id "
            f"JOIN event_ticket_types ticket_type_row "
            f"  ON ticket_type_row.event_ticket_type_id = booking_row.event_ticket_type_id "
            f"JOIN event_programs program_row "
            f"  ON program_row.event_program_id = experience_row.event_program_id "
            f"JOIN event_ticket_ledger ledger_row "
            f"  ON ledger_row.event_ticket_type_id = ticket_type_row.event_ticket_type_id "
            f"WHERE booking_row.booking_id = {sql_literal(ids['city_tourism_booking_id'])} "
            f"  AND experience_row.experience_id = {sql_literal(ids['city_tourism_experience_id'])} "
            f"  AND ticket_type_row.event_ticket_type_id = {sql_literal(ids['city_ticket_type_id'])} "
            f"  AND program_row.event_program_id = {sql_literal(ids['city_event_program_id'])} "
            f"  AND ledger_row.event_ticket_ledger_id = {sql_literal(ids['city_ticket_ledger_id'])})"
        ),
        'experience_ops_view': (
            f"EXISTS (SELECT 1 FROM v_city_mobility_security_experience_ops "
            f"WHERE experience_id = {sql_literal(ids['city_tourism_experience_id'])} "
            f"AND event_ticket_type_id = {sql_literal(ids['city_ticket_type_id'])} "
            f"AND booking_count = 1 "
            f"AND issued_tickets = 1 "
            f"AND booked_gmv_brl = 180.0000)"
        ),
        'incident_ops_view': (
            f"EXISTS (SELECT 1 FROM v_city_mobility_security_incident_ops "
            f"WHERE security_incident_id = {sql_literal(ids['city_security_incident_id'])} "
            f"AND active_contacts = 1 "
            f"AND active_biometrics = 1 "
            f"AND contact_notified = TRUE)"
        ),
        'gov_requests_view': (
            f"EXISTS (SELECT 1 FROM v_city_mobility_security_gov_requests "
            f"WHERE gov_request_id = {sql_literal(ids['city_gov_request_id'])} "
            f"AND request_status = 'FULFILLED'::gov_request_status_enum "
            f"AND event_count = 2 "
            f"AND service_code = 'URBAN_PASS_01')"
        ),
        'mobility_production_route_chain': (
            f"EXISTS (SELECT 1 FROM mobility.user_routes route_row "
            f"JOIN mobility.cost_benchmarks benchmark_row "
            f"  ON benchmark_row.benchmark_id = route_row.benchmark_id "
            f"JOIN mobility.realtime_buffer buffer_row "
            f"  ON buffer_row.route_id = route_row.route_id "
            f"WHERE route_row.route_id = {sql_literal(ids['city_mobility_route_id'])} "
            f"  AND benchmark_row.benchmark_id = {sql_literal(ids['city_mobility_benchmark_id'])} "
            f"  AND buffer_row.buffer_id = {sql_literal(ids['city_mobility_buffer_id'])} "
            f"  AND route_row.user_id = {sql_literal(ids['city_citizen_user_id'])} "
            f"  AND benchmark_row.user_id = route_row.user_id "
            f"  AND buffer_row.user_id = route_row.user_id "
            f"  AND route_row.route_fingerprint = benchmark_row.route_fingerprint)"
        ),
        'mobility_production_ops_view': (
            f"EXISTS (SELECT 1 FROM mobility.v_production_route_ops "
            f"WHERE route_id = {sql_literal(ids['city_mobility_route_id'])} "
            f"AND benchmark_id = {sql_literal(ids['city_mobility_benchmark_id'])} "
            f"AND latest_buffer_id = {sql_literal(ids['city_mobility_buffer_id'])} "
            f"AND latest_buffer_status = 'ACTIVE'::mobility.realtime_buffer_status_enum "
            f"AND competitor_lowest_brl = 24.9000)"
        ),
    }

    # Executa a grade do dominio.
    return run_postgres_smoke_checks('city_mobility_security', checks, use_compose)


def smoke_postgres_commerce_fintech_assets(use_compose: bool = False) -> int:
    """Executa smoke checks do seed operacional do dominio commerce_fintech_assets."""

    # ids deixa a montagem das consultas mais legivel.
    ids = SEED_IDS

    # checks valida commerce, treasury, ativos, real estate e insurance.
    checks = {
        'market_chain': (
            f"EXISTS (SELECT 1 FROM merchant_storefronts storefront_row "
            f"JOIN marketplace_listings listing_row "
            f"  ON listing_row.merchant_user_id = storefront_row.merchant_user_id "
            f"JOIN sale_validation_events validation_row "
            f"  ON validation_row.storefront_id = storefront_row.storefront_id "
            f"JOIN orders order_row "
            f"  ON order_row.order_id = validation_row.order_id "
            f"JOIN transactions tx_row "
            f"  ON tx_row.transaction_id = validation_row.transaction_id "
            f"JOIN affiliate_referrals referral_row "
            f"  ON referral_row.order_id = order_row.order_id "
            f"WHERE storefront_row.storefront_id = {sql_literal(ids['commerce_storefront_id'])} "
            f"  AND listing_row.listing_id = {sql_literal(ids['commerce_listing_id'])} "
            f"  AND order_row.order_id = {sql_literal(ids['commerce_order_id'])} "
            f"  AND tx_row.transaction_id = {sql_literal(ids['commerce_purchase_transaction_id'])} "
            f"  AND referral_row.referral_id = {sql_literal(ids['commerce_referral_id'])})"
        ),
        'market_ops_view': (
            f"EXISTS (SELECT 1 FROM v_commerce_fintech_assets_market_ops "
            f"WHERE listing_id = {sql_literal(ids['commerce_listing_id'])} "
            f"AND validation_events = 1 "
            f"AND validated_gmv_brl = 199.9000 "
            f"AND affiliate_commission_brl = 7.0000)"
        ),
        'dropshipping_provider_configs': (
            f"(SELECT COUNT(*) FROM dropshipping_provider_configs "
            f"WHERE owner_user_id = {sql_literal(ids['commerce_merchant_user_id'])} "
            f"AND block_external_ai_lookup IS TRUE) = 7"
        ),
        'dropshipping_product_chain': (
            f"EXISTS (SELECT 1 FROM v_stock_dropshipping_production_ops ops "
            f"WHERE ops.product_source_id = {sql_literal(ids['dropshipping_product_source_id'])} "
            f"AND ops.item_id = {sql_literal(ids['commerce_inventory_item_id'])} "
            f"AND ops.listing_id = {sql_literal(ids['commerce_listing_id'])} "
            f"AND ops.provider_code = 'ALIEXPRESS'::dropshipping_provider_code_enum "
            f"AND ops.current_supplier_stock = 250.0000)"
        ),
        'dropshipping_pricing_append_only_seed': (
            f"EXISTS (SELECT 1 FROM dropshipping_pricing_decisions decision_row "
            f"JOIN dropshipping_market_price_snapshots snapshot_row "
            f"  ON snapshot_row.market_price_snapshot_id = decision_row.evidence_snapshot_id "
            f"WHERE decision_row.pricing_decision_id = {sql_literal(ids['dropshipping_pricing_decision_id'])} "
            f"AND snapshot_row.market_price_snapshot_id = {sql_literal(ids['dropshipping_market_price_snapshot_id'])} "
            f"AND decision_row.decision_action = 'UPDATE_PRICE'::dropshipping_decision_action_enum "
            f"AND decision_row.decided_price_brl = 169.9000 "
            f"AND snapshot_row.source_type = 'API'::dropshipping_source_type_enum)"
        ),
        'dropshipping_provider_health_view': (
            f"EXISTS (SELECT 1 FROM v_stock_dropshipping_provider_health "
            f"WHERE provider_config_id = {sql_literal(ids['dropshipping_mercado_livre_provider_id'])} "
            f"AND provider_code = 'MERCADO_LIVRE'::dropshipping_provider_code_enum "
            f"AND cache_ttl_minutes = 20 "
            f"AND block_external_ai_lookup IS TRUE "
            f"AND open_jobs = 0 "
            f"AND failed_jobs = 0)"
        ),
        'treasury_ops_view': (
            f"EXISTS (SELECT 1 FROM v_commerce_fintech_assets_treasury_ops "
            f"WHERE goal_id = {sql_literal(ids['commerce_financial_goal_id'])} "
            f"AND plug_transaction_id = {sql_literal(ids['commerce_plug_transaction_id'])} "
            f"AND treasury_transaction_id = {sql_literal(ids['commerce_plug_ledger_transaction_id'])} "
            f"AND goal_status = 'ACTIVE'::financial_goal_status_enum "
            f"AND origin_module = 'PLUG')"
        ),
        'digital_assets_view': (
            f"EXISTS (SELECT 1 FROM v_commerce_fintech_assets_digital_assets "
            f"WHERE digital_asset_id = {sql_literal(ids['commerce_digital_asset_id'])} "
            f"AND event_count = 1 "
            f"AND royalty_amount_brl = 12.5000 "
            f"AND collection_code = 'DIGI_SMART_HOME_01')"
        ),
        'real_estate_chain': (
            f"EXISTS (SELECT 1 FROM real_estate_properties property_row "
            f"JOIN real_estate_deals deal_row "
            f"  ON deal_row.property_id = property_row.property_id "
            f"JOIN digital_assets asset_row "
            f"  ON asset_row.digital_asset_id = property_row.tokenized_asset_id "
            f"WHERE property_row.property_id = {sql_literal(ids['commerce_property_id'])} "
            f"  AND deal_row.deal_id = {sql_literal(ids['commerce_real_estate_deal_id'])} "
            f"  AND asset_row.digital_asset_id = {sql_literal(ids['commerce_digital_asset_id'])})"
        ),
        'insurance_ops_view': (
            f"EXISTS (SELECT 1 FROM v_commerce_fintech_assets_insurance_ops "
            f"WHERE claim_id = {sql_literal(ids['commerce_insurance_claim_id'])} "
            f"AND claim_status = 'PAID'::insurance_claim_status_enum "
            f"AND claim_event_count = 1 "
            f"AND policy_number = 'POL-SMART-0001')"
        ),
    }

    # Executa a grade do dominio.
    return run_postgres_smoke_checks('commerce_fintech_assets', checks, use_compose)


def smoke_mongo_expansion(use_compose: bool = False) -> int:
    """Executa smoke checks nos seeds e links do bloco expansion em MongoDB."""

    # ids deixa a montagem do snippet JavaScript mais legivel.
    ids = SEED_IDS

    # checks mapeia nome para expressao JavaScript booleana.
    checks = {
        'news_content_seed': (
            f"db.news_content_items.countDocuments({{ content_id: {json.dumps(ids['news_content_id'])} }}) === 1"
        ),
        'fitness_session_seed': (
            f"db.fitness_activity_sessions.countDocuments({{ session_id: {json.dumps(ids['fitness_session_id'])}, user_id: {json.dumps(ids['traveler_user_id'])} }}) === 1"
        ),
        'gaming_player_seed': (
            f"db.gaming_player_states.countDocuments({{ player_state_id: {json.dumps(ids['gaming_player_state_id'])}, user_id: {json.dumps(ids['traveler_user_id'])} }}) === 1"
        ),
        'home_automation_seed': (
            f"db.home_automation_events.countDocuments({{ automation_event_id: {json.dumps(ids['home_automation_event_id'])}, household_id: {json.dumps(ids['home_household_id'])} }}) === 1"
        ),
        'space_anchor_seed': (
            f"db.space_anchor_maps.countDocuments({{ anchor_id: {json.dumps(ids['space_anchor_id'])}, tourism_experience_id: {json.dumps(ids['tourism_experience_id'])} }}) === 1"
        ),
        'tourism_feed_seed': (
            f"db.tourism_experience_feeds.countDocuments({{ feed_id: {json.dumps(ids['tourism_feed_id'])}, experience_id: {json.dumps(ids['tourism_experience_id'])} }}) === 1"
        ),
        'bio_impact_seed': (
            f"db.bio_impact_logs.countDocuments({{ impact_log_id: {json.dumps(ids['bio_impact_log_id'])}, collection_order_id: {json.dumps(ids['bio_collection_order_id'])} }}) === 1"
        ),
        'energy_meter_seed': (
            f"db.energy_meter_streams.countDocuments({{ stream_event_id: {json.dumps(ids['energy_meter_stream_id'])}, trade_order_id: {json.dumps(ids['energy_trade_order_id'])} }}) === 1"
        ),
    }

    # checks_js serializa o plano de verificacao para o mongosh.
    checks_js = ', '.join(
        f"[{json.dumps(name)}, ({expression})]"
        for name, expression in checks.items()
    )

    # query imprime linhas nome|true/false para parse simples no Python.
    query = (
        f"const checks = [{checks_js}]; "
        "checks.forEach(([name, ok]) => print(`${name}|${ok ? 'true' : 'false'}`));"
    )

    # command monta mongosh local ou compose.
    command = mongosh_query_command(use_compose, query)

    # Sem comando nao ha como consultar.
    if command is None:
        print('mongosh nao disponivel para smoke-mongo.')
        return 2

    # Executa consulta de smoke.
    result = run_command(command, timeout_seconds=30)

    # Em falha, imprime saida bruta.
    if result.returncode != 0:
        print(result.stderr or result.stdout)
        return result.returncode

    # all_ok acumula o resultado geral.
    all_ok = True

    # Percorre linhas nome|true ou nome|false.
    for raw_line in result.stdout.splitlines():
        # Ignora linhas vazias.
        if not raw_line.strip() or '|' not in raw_line:
            continue

        # name e ok_text representam o status do check.
        name, ok_text = raw_line.split('|', 1)
        ok = ok_text.strip() == 'true'
        all_ok = all_ok and ok
        status = 'OK' if ok else 'PENDENTE'
        print(f'{status} smoke.mongodb.{name}: {ok_text.strip()}')

    # Retorna sucesso apenas quando tudo passou.
    return 0 if all_ok else 1


def seed_compose() -> int:
    """Sobe o Compose se preciso e aplica os seeds operacionais."""

    # Garante banco e mongo ativos antes do seed.
    compose_code = compose_up()
    if compose_code != 0:
        return compose_code

    # Aplica seed PostgreSQL primeiro, porque Mongo referencia UUIDs relacionais ja seedados.
    postgres_code = apply_seed_postgres(use_compose=True)
    if postgres_code != 0:
        return postgres_code

    # Aplica seed MongoDB em seguida.
    return apply_seed_mongo(use_compose=True)


def smoke_compose() -> int:
    """Sobe o Compose se preciso e executa smoke checks relacionais e MongoDB."""

    # Garante banco e mongo ativos antes do smoke.
    compose_code = compose_up()
    if compose_code != 0:
        return compose_code

    # Executa smoke PostgreSQL primeiro.
    postgres_code = smoke_postgres_expansion(use_compose=True)
    if postgres_code != 0:
        return postgres_code

    # Valida o dominio platform_developer.
    platform_code = smoke_postgres_platform_developer(use_compose=True)
    if platform_code != 0:
        return platform_code

    # Valida o dominio logistics_erp_operations.
    logistics_code = smoke_postgres_logistics_erp_operations(use_compose=True)
    if logistics_code != 0:
        return logistics_code

    # Valida o dominio city_mobility_security.
    city_code = smoke_postgres_city_mobility_security(use_compose=True)
    if city_code != 0:
        return city_code

    # Valida o dominio commerce_fintech_assets.
    commerce_code = smoke_postgres_commerce_fintech_assets(use_compose=True)
    if commerce_code != 0:
        return commerce_code

    # Executa smoke MongoDB em seguida.
    return smoke_mongo_expansion(use_compose=True)


def snapshot_compose() -> int:
    """Exporta snapshot operacional do PostgreSQL e MongoDB do Compose."""

    # Garante que o ambiente esteja ativo antes da exportacao.
    compose_code = compose_up()
    if compose_code != 0:
        return compose_code

    # Garante pasta base do snapshot.
    ensure_snapshot_dir()

    # timestamp UTC deixa snapshots ordenaveis e unicos.
    timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')

    # snapshot_dir isola os artefatos desta exportacao.
    snapshot_dir = SNAPSHOT_DIR / f'valley_db_snapshot_{timestamp}'
    snapshot_dir.mkdir(parents=True, exist_ok=True)

    # postgres_dump_path recebe o dump binario custom do Postgres.
    postgres_dump_path = snapshot_dir / 'postgres_valley.dump'

    # mongo_dump_path recebe o archive gzip do Mongo.
    mongo_dump_path = snapshot_dir / 'mongodb_valley.archive.gz'

    # Exporta PostgreSQL via pg_dump dentro do container.
    postgres_result = capture_binary_command(
        ['docker', 'exec', 'valley-postgres', 'pg_dump', '-U', 'valley', '-d', 'valley', '-Fc'],
        postgres_dump_path,
        timeout_seconds=900,
    )
    print(f'{"OK" if postgres_result.ok else "PENDENTE"} snapshot.postgres: {postgres_result.detail}')
    if not postgres_result.ok:
        return 1

    # Exporta MongoDB via mongodump dentro do container.
    mongo_result = capture_binary_command(
        ['docker', 'exec', 'valley-mongodb', 'mongodump', '--uri', 'mongodb://localhost:27017/valley', '--archive', '--gzip'],
        mongo_dump_path,
        timeout_seconds=900,
    )
    print(f'{"OK" if mongo_result.ok else "PENDENTE"} snapshot.mongodb: {mongo_result.detail}')
    if not mongo_result.ok:
        return 1

    # Levanta metadados basicos do estado exportado para rastreabilidade.
    postgres_table_count_command = psql_query_command(
        True,
        "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';",
    )
    mongo_collection_count_command = mongosh_query_command(
        True,
        "print(db.getCollectionNames().length);",
    )

    # Captura totais de objetos exportados quando as ferramentas de consulta estiverem disponiveis.
    postgres_table_count = None
    mongo_collection_count = None

    if postgres_table_count_command is not None:
        postgres_count_result = run_command(postgres_table_count_command, timeout_seconds=30)
        if postgres_count_result.returncode == 0:
            postgres_table_count = postgres_count_result.stdout.strip()

    if mongo_collection_count_command is not None:
        mongo_count_result = run_command(mongo_collection_count_command, timeout_seconds=30)
        if mongo_count_result.returncode == 0:
            mongo_collection_count = mongo_count_result.stdout.strip()

    # manifest_path descreve os artefatos e checksums do snapshot.
    manifest_path = snapshot_dir / 'snapshot_manifest.json'

    # manifest resume o que foi exportado e como restaurar depois.
    manifest = {
        'generated_at_utc': datetime.now(timezone.utc).isoformat(),
        'snapshot_id': snapshot_dir.name,
        'source': 'docker-compose-local',
        'postgres': {
            'service': 'valley-postgres',
            'format': 'pg_dump_custom',
            'artifact': str(postgres_dump_path.relative_to(ROOT)).replace('\\', '/'),
            'bytes': postgres_dump_path.stat().st_size,
            'sha256': sha256_file(postgres_dump_path),
        },
        'mongodb': {
            'service': 'valley-mongodb',
            'format': 'mongodump_archive_gzip',
            'artifact': str(mongo_dump_path.relative_to(ROOT)).replace('\\', '/'),
            'bytes': mongo_dump_path.stat().st_size,
            'sha256': sha256_file(mongo_dump_path),
        },
        'database_state': {
            'public_table_count': postgres_table_count,
            'mongo_collection_count': mongo_collection_count,
        },
        'restore_hints': {
            'postgres': 'pg_restore -d <database> postgres_valley.dump',
            'mongodb': 'mongorestore --drop --gzip --archive=mongodb_valley.archive.gz',
        },
    }

    # Escreve manifesto em JSON para rastreabilidade operacional.
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')

    # Mostra artefatos gerados.
    print(snapshot_dir.relative_to(ROOT))
    print(manifest_path.relative_to(ROOT))

    # Retorna sucesso.
    return 0


def snapshot_verify(snapshot_ref: str | None = None) -> int:
    """Valida o snapshot mais recente ou um snapshot informado."""

    try:
        # manifest_path e manifest localizam o snapshot alvo.
        manifest_path, manifest = load_snapshot_manifest(snapshot_ref)
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        print(f'PENDENTE snapshot.verify: {exc}')
        return 1

    # Exibe o snapshot avaliado para rastreabilidade.
    print(manifest_path.relative_to(ROOT))

    # results executa prova de integridade do manifesto e dos binarios.
    results = validate_snapshot_manifest(manifest_path, manifest)

    # Imprime cada linha de validacao.
    for result in results:
        print(f'{"OK" if result.ok else "PENDENTE"} {result.name}: {result.detail}')

    # Snapshot so e valido quando todas as checagens passam.
    return 0 if all(result.ok for result in results) else 1


def restore_compose(snapshot_ref: str | None = None) -> int:
    """Restaura PostgreSQL e MongoDB no Compose local a partir de snapshot validado."""

    try:
        # manifest_path e manifest definem o snapshot alvo do restore.
        manifest_path, manifest = load_snapshot_manifest(snapshot_ref)
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        print(f'PENDENTE restore.snapshot: {exc}')
        return 1

    # Nunca restaura snapshot sem verificar integridade primeiro.
    validation_results = validate_snapshot_manifest(manifest_path, manifest)
    for result in validation_results:
        print(f'{"OK" if result.ok else "PENDENTE"} {result.name}: {result.detail}')
    if not all(result.ok for result in validation_results):
        return 1

    # Compose precisa estar ativo antes de resetar e importar.
    compose_code = compose_up()
    if compose_code != 0:
        return compose_code

    # Resolve os artefatos fisicos declarados no manifesto.
    postgres_artifact = resolve_snapshot_artifact(manifest_path, str(manifest['postgres']['artifact']))
    mongo_artifact = resolve_snapshot_artifact(manifest_path, str(manifest['mongodb']['artifact']))

    # Termina conexoes ativas no banco alvo antes do dropdb.
    postgres_disconnect = run_command(
        [
            'docker',
            'compose',
            'exec',
            '-T',
            'postgres',
            'psql',
            '-U',
            'valley',
            '-d',
            'postgres',
            '-c',
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'valley' AND pid <> pg_backend_pid();",
        ],
        timeout_seconds=60,
    )
    print((postgres_disconnect.stdout or postgres_disconnect.stderr or 'postgres disconnect executed').strip())
    if postgres_disconnect.returncode != 0:
        return postgres_disconnect.returncode

    # Dropa e recria o database para garantir restore limpo e previsivel.
    postgres_drop = run_command(
        ['docker', 'compose', 'exec', '-T', 'postgres', 'dropdb', '-U', 'valley', '--if-exists', 'valley'],
        timeout_seconds=120,
    )
    print((postgres_drop.stdout or postgres_drop.stderr or 'dropdb valley executado').strip())
    if postgres_drop.returncode != 0:
        return postgres_drop.returncode

    postgres_create = run_command(
        ['docker', 'compose', 'exec', '-T', 'postgres', 'createdb', '-U', 'valley', 'valley'],
        timeout_seconds=120,
    )
    print((postgres_create.stdout or postgres_create.stderr or 'createdb valley executado').strip())
    if postgres_create.returncode != 0:
        return postgres_create.returncode

    # Importa o dump custom do PostgreSQL no banco recem-criado.
    postgres_restore = stream_binary_to_command(
        postgres_artifact,
        ['docker', 'compose', 'exec', '-T', 'postgres', 'pg_restore', '-U', 'valley', '-d', 'valley', '--no-owner', '--no-privileges'],
        timeout_seconds=1800,
    )
    print(f'{"OK" if postgres_restore.ok else "PENDENTE"} restore.postgres: {postgres_restore.detail}')
    if not postgres_restore.ok:
        return 1

    # Limpa o database MongoDB inteiro antes da importacao para garantir reproduzibilidade.
    mongo_drop = run_command(
        [
            'docker',
            'compose',
            'exec',
            '-T',
            'mongodb',
            'mongosh',
            'mongodb://localhost:27017/admin',
            '--quiet',
            '--eval',
            "db.getSiblingDB('valley').dropDatabase(); print('dropDatabase valley executed');",
        ],
        timeout_seconds=60,
    )
    print((mongo_drop.stdout or mongo_drop.stderr or 'dropDatabase valley executado').strip())
    if mongo_drop.returncode != 0:
        return mongo_drop.returncode

    # Importa archive gzip do MongoDB.
    mongo_restore = stream_binary_to_command(
        mongo_artifact,
        ['docker', 'compose', 'exec', '-T', 'mongodb', 'mongorestore', '--uri', 'mongodb://localhost:27017/valley', '--drop', '--gzip', '--archive'],
        timeout_seconds=1800,
    )
    print(f'{"OK" if mongo_restore.ok else "PENDENTE"} restore.mongodb: {mongo_restore.detail}')
    if not mongo_restore.ok:
        return 1

    # Reconta objetos restaurados para comparar com o manifesto.
    all_ok = True

    postgres_expected = manifest.get('database_state', {}).get('public_table_count')
    postgres_count_command = psql_query_command(
        True,
        "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';",
    )
    if postgres_expected is not None and postgres_count_command is not None:
        postgres_count_result = run_command(postgres_count_command, timeout_seconds=30)
        postgres_actual = postgres_count_result.stdout.strip()
        postgres_match = postgres_count_result.returncode == 0 and postgres_actual == str(postgres_expected)
        print(f'{"OK" if postgres_match else "PENDENTE"} restore.postgres.table_count: esperado={postgres_expected} atual={postgres_actual or postgres_count_result.stderr.strip()}')
        all_ok = all_ok and postgres_match

    mongo_expected = manifest.get('database_state', {}).get('mongo_collection_count')
    mongo_count_command = mongosh_query_command(
        True,
        "print(db.getCollectionNames().length);",
    )
    if mongo_expected is not None and mongo_count_command is not None:
        mongo_count_result = run_command(mongo_count_command, timeout_seconds=30)
        mongo_actual = mongo_count_result.stdout.strip()
        mongo_match = mongo_count_result.returncode == 0 and mongo_actual == str(mongo_expected)
        print(f'{"OK" if mongo_match else "PENDENTE"} restore.mongodb.collection_count: esperado={mongo_expected} atual={mongo_actual or mongo_count_result.stderr.strip()}')
        all_ok = all_ok and mongo_match

    return 0 if all_ok else 1


def compose_wait_seconds() -> int:
    """Retorna timeout configurado para readiness do Docker Compose."""

    # raw_value permite override por ambiente sem editar codigo.
    raw_value = os.environ.get('VALLEY_COMPOSE_WAIT_SECONDS', str(COMPOSE_WAIT_SECONDS)).strip()

    # Valores invalidos caem no default seguro.
    if not raw_value.isdigit():
        return COMPOSE_WAIT_SECONDS

    # Enforce de piso evita timeout curto demais.
    return max(int(raw_value), 120)


def wait_for_compose_services(timeout_seconds: int = 240) -> int:
    """Espera PostgreSQL e MongoDB responderem por probes reais dentro dos containers."""

    # deadline limita o tempo total de espera da esteira.
    deadline = time.monotonic() + timeout_seconds

    # last_postgres guarda a ultima resposta observada do PostgreSQL.
    last_postgres = 'probe ainda nao executado'

    # last_mongo guarda a ultima resposta observada do MongoDB.
    last_mongo = 'probe ainda nao executado'

    # Polling simples evita travar indefinidamente em healthcheck instavel do Compose.
    while time.monotonic() < deadline:
        # pg_isready mede se o Postgres aceita conexao TCP real no container.
        postgres_probe = run_command(
            ['docker', 'compose', 'exec', '-T', 'postgres', 'pg_isready', '-h', '127.0.0.1', '-U', 'valley', '-d', 'valley'],
            timeout_seconds=15,
        )

        # postgres_ready depende de exit code zero.
        postgres_ready = postgres_probe.returncode == 0

        # last_postgres preserva a ultima mensagem observada.
        last_postgres = (postgres_probe.stdout or postgres_probe.stderr or f'exit {postgres_probe.returncode}').strip()

        # ping do Mongo confirma resposta da instancia em execucao.
        mongo_probe = run_command(
            ['docker', 'compose', 'exec', '-T', 'mongodb', 'mongosh', 'mongodb://localhost:27017/valley', '--quiet', '--eval', "db.adminCommand('ping').ok"],
            timeout_seconds=20,
        )

        # mongo_output concentra a ultima saida util do probe.
        mongo_output = (mongo_probe.stdout or mongo_probe.stderr or f'exit {mongo_probe.returncode}').strip()

        # mongo_ready exige retorno zero e valor 1 no ping.
        mongo_ready = mongo_probe.returncode == 0 and mongo_output.endswith('1')

        # last_mongo preserva a ultima mensagem observada.
        last_mongo = mongo_output

        # Quando ambos responderem, o compose esta pronto para aplicar migrations.
        if postgres_ready and mongo_ready:
            print(f'compose ready: postgres={last_postgres} | mongo={last_mongo}')
            return 0

        # Pausa curta entre tentativas para nao saturar Docker Desktop.
        time.sleep(5)

    # Imprime estado final observado quando o timeout expirar.
    print(f'compose readiness timeout: postgres={last_postgres} | mongo={last_mongo}')
    return 1


def run_compose_builder() -> int:
    """Executa o worker builder do Compose para aplicar pipeline completa."""

    # docker precisa existir para chamar o service builder.
    docker_path = find_tool('docker')

    # Sem docker nao ha compose builder.
    if not docker_path:
        print('docker nao encontrado; builder do Compose nao executado.')
        return 2

    # command constroi a imagem e roda o builder uma unica vez.
    command = [
        docker_path,
        'compose',
        '--profile',
        COMPOSE_BUILDER_SERVICE,
        'run',
        '--rm',
        '--build',
        COMPOSE_BUILDER_SERVICE,
    ]

    # result executa a pipeline de release dentro do container builder.
    result = run_command(command, timeout_seconds=1800)

    # Imprime saida principal para visibilidade operacional.
    print(result.stdout or result.stderr)

    # Retorna codigo de saida real do builder.
    return result.returncode


def compose_up() -> int:
    """Sobe ambiente local Docker Compose."""

    # docker precisa existir.
    docker_path = find_tool('docker')

    # Sem docker, nao ha compose local.
    if not docker_path:
        print('docker nao encontrado; compose-up ignorado.')
        return 2

    # Sobe os containers sem bloquear na semantica de healthcheck do Compose.
    result = run_command([docker_path, 'compose', 'up', '-d', 'postgres', 'mongodb'], timeout_seconds=240)

    # Imprime saida principal.
    print(result.stdout or result.stderr)

    # Se o up falhar, nao adianta esperar readiness.
    if result.returncode != 0:
        return result.returncode

    # Faz readiness check real dentro dos containers para liberar apply-compose com mais confiabilidade.
    return wait_for_compose_services(timeout_seconds=compose_wait_seconds())


def compose_down() -> int:
    """Para ambiente local Docker Compose sem apagar volumes."""

    # docker precisa existir.
    docker_path = find_tool('docker')

    # Sem docker, nao ha compose local.
    if not docker_path:
        print('docker nao encontrado; compose-down ignorado.')
        return 2

    # Executa compose down preservando dados.
    result = run_command([docker_path, 'compose', 'down'], timeout_seconds=120)

    # Imprime saida principal.
    print(result.stdout or result.stderr)

    # Retorna codigo.
    return result.returncode


def main() -> None:
    """Entrada principal da CLI."""

    # parser configura comandos.
    parser = argparse.ArgumentParser(description='Orquestrador do banco hibrido Valley.')

    # command seleciona operacao.
    parser.add_argument(
        'command',
        choices=[
            'check',
            'report',
            'apply-postgres',
            'apply-mongo',
            'compose-up',
            'compose-down',
            'apply-compose',
            'seed-postgres',
            'seed-mongo',
            'seed-compose',
            'smoke-postgres',
            'smoke-mongo',
            'smoke-compose',
            'snapshot-compose',
            'snapshot-verify',
            'restore-compose',
        ],
        help='Operacao desejada.',
    )

    # snapshot permite escolher um snapshot especifico em verify/restore.
    parser.add_argument(
        '--snapshot',
        dest='snapshot',
        default=None,
        help='Diretorio do snapshot ou caminho do snapshot_manifest.json. Default: snapshot mais recente.',
    )

    # args le CLI.
    args = parser.parse_args()

    # check valida e imprime resultado resumido.
    if args.command == 'check':
        # results executa validacoes.
        results = validate_all()

        # Imprime cada resultado.
        for result in results:
            # status textual simples.
            status = 'OK' if result.ok else 'PENDENTE'

            # Linha de terminal.
            print(f'{status} {result.name}: {result.detail}')

        # Se alguma checagem critica falhou, retorna 1.
        raise SystemExit(0 if all(result.ok or result.name.startswith('tool.') or result.name.startswith('env.') for result in results) else 1)

    # report escreve Markdown de status.
    if args.command == 'report':
        # results executa validacoes.
        results = validate_all()

        # path escreve relatorio.
        path = write_report(results)

        # Atualiza o console admin usando o relatorio recem-gerado.
        sync_admin_console()

        # Imprime caminho relativo.
        print(path.relative_to(ROOT))

        # Report sempre retorna 0, porque pendencias podem ser esperadas sem DB local.
        return

    # compose-up sobe containers.
    if args.command == 'compose-up':
        # Executa compose up.
        raise SystemExit(compose_up())

    # compose-down para containers.
    if args.command == 'compose-down':
        # Executa compose down.
        raise SystemExit(compose_down())

    # Demais comandos precisam do manifesto.
    manifest = load_manifest()

    # apply-postgres aplica SQL.
    if args.command == 'apply-postgres':
        # Executa psql local.
        raise SystemExit(apply_postgres(manifest, use_compose=False))

    # apply-mongo aplica Mongo.
    if args.command == 'apply-mongo':
        # Executa mongosh local.
        raise SystemExit(apply_mongo(manifest, use_compose=False))

    # apply-compose aplica ambos via containers.
    if args.command == 'apply-compose':
        # Garante que o compose esteja ativo antes de aplicar migrations.
        compose_code = compose_up()

        # Se o compose nao subir, nao adianta tentar aplicar.
        if compose_code != 0:
            raise SystemExit(compose_code)

        # Executa a pipeline completa dentro do builder do Compose.
        raise SystemExit(run_compose_builder())

    # seed-postgres aplica seeds relacionais fora do manifesto.
    if args.command == 'seed-postgres':
        raise SystemExit(apply_seed_postgres(use_compose=False))

    # seed-mongo aplica seeds NoSQL fora do manifesto.
    if args.command == 'seed-mongo':
        raise SystemExit(apply_seed_mongo(use_compose=False))

    # seed-compose sobe o ambiente e aplica ambos os seeds.
    if args.command == 'seed-compose':
        raise SystemExit(seed_compose())

    # smoke-postgres valida o bloco expansion no banco relacional.
    if args.command == 'smoke-postgres':
        raise SystemExit(smoke_postgres_expansion(use_compose=False))

    # smoke-mongo valida o bloco expansion no MongoDB.
    if args.command == 'smoke-mongo':
        raise SystemExit(smoke_mongo_expansion(use_compose=False))

    # smoke-compose sobe o ambiente e executa os smoke checks completos.
    if args.command == 'smoke-compose':
        raise SystemExit(smoke_compose())

    # snapshot-compose exporta dump operacional dos bancos no ambiente local Docker.
    if args.command == 'snapshot-compose':
        raise SystemExit(snapshot_compose())

    # snapshot-verify valida integridade do snapshot mais recente ou de um alvo explicito.
    if args.command == 'snapshot-verify':
        raise SystemExit(snapshot_verify(args.snapshot))

    # restore-compose restaura o snapshot validado no banco local Docker Compose.
    if args.command == 'restore-compose':
        raise SystemExit(restore_compose(args.snapshot))


# Executa main quando chamado diretamente.
if __name__ == '__main__':
    # Inicia orquestrador.
    main()
