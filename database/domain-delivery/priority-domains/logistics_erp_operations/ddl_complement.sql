BEGIN;

-- Pacote complementar do dominio Logistics ERP Operations.
-- DDL real materializado em:
--   - database/postgres/019_v47_logistics_erp_operations_business_ddl.sql
--   - database/postgres/017_v47_priority_domain_delivery_packages.sql

CREATE OR REPLACE VIEW v_logistics_erp_business_units AS
SELECT
    unit.business_unit_id,
    unit.business_user_id,
    unit.unit_code,
    unit.unit_name,
    unit.unit_type,
    unit.unit_status,
    COUNT(*) FILTER (WHERE closure.closure_status = 'OPEN') AS open_closures,
    MAX(closure.closure_period_end) AS last_closure_period_end
FROM business_units AS unit
LEFT JOIN business_fiscal_closures AS closure
  ON closure.business_unit_id = unit.business_unit_id
GROUP BY
    unit.business_unit_id,
    unit.business_user_id,
    unit.unit_code,
    unit.unit_name,
    unit.unit_type,
    unit.unit_status;

CREATE OR REPLACE VIEW v_logistics_erp_procurement_controls AS
SELECT
    order_row.procurement_order_id,
    order_row.procurement_status,
    order_row.business_unit_id,
    order_row.approval_policy_id,
    order_row.approval_due_at,
    policy.policy_name,
    policy.sla_hours,
    COUNT(event.approval_event_id) AS approval_events,
    MAX(event.occurred_at) AS last_event_at
FROM procurement_orders AS order_row
LEFT JOIN procurement_approval_policies AS policy
  ON policy.approval_policy_id = order_row.approval_policy_id
LEFT JOIN procurement_approval_events AS event
  ON event.procurement_order_id = order_row.procurement_order_id
GROUP BY
    order_row.procurement_order_id,
    order_row.procurement_status,
    order_row.business_unit_id,
    order_row.approval_policy_id,
    order_row.approval_due_at,
    policy.policy_name,
    policy.sla_hours;

CREATE OR REPLACE VIEW v_logistics_erp_fulfillment_ops AS
SELECT
    shipment.shipment_id,
    shipment.shipment_status,
    shipment.delivery_policy_id,
    shipment.promised_delivery_at,
    shipment.reassignment_count,
    shipment.proof_media_required,
    policy.policy_name AS delivery_policy_name,
    store.store_name AS food_store_name,
    profile.vehicle_reference,
    profile.health_score
FROM delivery_shipments AS shipment
LEFT JOIN delivery_operation_policies AS policy
  ON policy.delivery_policy_id = shipment.delivery_policy_id
LEFT JOIN orders AS order_row
  ON order_row.order_id = shipment.order_id
LEFT JOIN food_store_contracts AS store
  ON store.food_store_contract_id = order_row.food_store_contract_id
LEFT JOIN mobility_trips AS trip
  ON trip.order_id = order_row.order_id
LEFT JOIN fleet_vehicle_operating_profiles AS profile
  ON profile.vehicle_operating_profile_id = trip.vehicle_operating_profile_id;

COMMENT ON VIEW v_logistics_erp_business_units IS
    'Resumo de unidades e fechamento fiscal do dominio Logistics ERP Operations.';
COMMENT ON VIEW v_logistics_erp_procurement_controls IS
    'Consulta operacional de aprovacao, SLA e eventos de procurement.';
COMMENT ON VIEW v_logistics_erp_fulfillment_ops IS
    'Visao consolidada de entrega, food e frota sobre o novo DDL operacional.';

COMMIT;
