BEGIN;

-- Aprofunda o dominio City Mobility Security com views operacionais reais.
-- Consolida juridico, experiencias, seguranca e govtech sobre as tabelas
-- ja criadas nas migrations core e expansion anteriores.

CREATE OR REPLACE VIEW v_city_mobility_security_legal_ops AS
SELECT
    contract.legal_contract_id,
    contract.owner_user_id,
    contract.counterparty_user_id,
    contract.contract_type,
    contract.title,
    contract.contract_status,
    COUNT(DISTINCT party.legal_contract_party_id) AS party_count,
    COUNT(DISTINCT signature.legal_signature_id)
        FILTER (WHERE signature.signature_status = 'SIGNED') AS signed_signatures,
    COUNT(DISTINCT dispute.legal_dispute_id)
        FILTER (WHERE dispute.dispute_status IN ('OPEN', 'UNDER_REVIEW', 'MEDIATION')) AS open_disputes,
    MAX(audit.created_at) AS last_legal_event_at
FROM legal_contracts AS contract
LEFT JOIN legal_contract_parties AS party
  ON party.legal_contract_id = contract.legal_contract_id
LEFT JOIN legal_signatures AS signature
  ON signature.legal_contract_id = contract.legal_contract_id
LEFT JOIN legal_disputes AS dispute
  ON dispute.legal_contract_id = contract.legal_contract_id
LEFT JOIN legal_audit_events AS audit
  ON audit.legal_contract_id = contract.legal_contract_id
WHERE contract.module_code = 'LEGAL'
GROUP BY
    contract.legal_contract_id,
    contract.owner_user_id,
    contract.counterparty_user_id,
    contract.contract_type,
    contract.title,
    contract.contract_status;

CREATE OR REPLACE VIEW v_city_mobility_security_experience_ops AS
SELECT
    experience.experience_id,
    experience.experience_code,
    experience.experience_status,
    experience.experience_kind,
    experience.city_code,
    program.event_program_id,
    program.title AS event_title,
    program.event_status,
    ticket_type.event_ticket_type_id,
    ticket_type.ticket_name,
    COUNT(DISTINCT booking.booking_id) AS booking_count,
    COUNT(DISTINCT ledger.event_ticket_ledger_id)
        FILTER (WHERE ledger.ticket_status IN ('SOLD', 'TRANSFERRED', 'CHECKED_IN')) AS issued_tickets,
    COALESCE(
        SUM(booking.total_brl)
            FILTER (
                WHERE booking.booking_status IN ('CONFIRMED', 'CHECKED_IN', 'IN_PROGRESS', 'COMPLETED')
            ),
        0
    ) AS booked_gmv_brl
FROM tourism_experiences AS experience
LEFT JOIN event_programs AS program
  ON program.event_program_id = experience.event_program_id
LEFT JOIN event_ticket_types AS ticket_type
  ON ticket_type.event_program_id = program.event_program_id
LEFT JOIN tourism_bookings AS booking
  ON booking.experience_id = experience.experience_id
LEFT JOIN event_ticket_ledger AS ledger
  ON ledger.event_ticket_type_id = ticket_type.event_ticket_type_id
WHERE experience.module_code = 'TOURISM'
GROUP BY
    experience.experience_id,
    experience.experience_code,
    experience.experience_status,
    experience.experience_kind,
    experience.city_code,
    program.event_program_id,
    program.title,
    program.event_status,
    ticket_type.event_ticket_type_id,
    ticket_type.ticket_name;

CREATE OR REPLACE VIEW v_city_mobility_security_incident_ops AS
SELECT
    incident.security_incident_id,
    incident.user_id,
    incident.incident_type,
    incident.severity,
    incident.incident_status,
    incident.legal_dispute_id,
    COUNT(DISTINCT contact.security_contact_id)
        FILTER (WHERE contact.is_active) AS active_contacts,
    COUNT(DISTINCT credential.biometric_credential_id)
        FILTER (WHERE credential.credential_status = 'ACTIVE') AS active_biometrics,
    BOOL_OR(event.event_type = 'CONTACT_NOTIFIED') AS contact_notified,
    MAX(event.occurred_at) AS last_incident_event_at
FROM security_incidents AS incident
LEFT JOIN security_trusted_contacts AS contact
  ON contact.user_id = incident.user_id
LEFT JOIN security_biometric_credentials AS credential
  ON credential.user_id = incident.user_id
LEFT JOIN security_incident_events AS event
  ON event.security_incident_id = incident.security_incident_id
WHERE incident.module_code = 'SECURITY'
GROUP BY
    incident.security_incident_id,
    incident.user_id,
    incident.incident_type,
    incident.severity,
    incident.incident_status,
    incident.legal_dispute_id;

CREATE OR REPLACE VIEW v_city_mobility_security_gov_requests AS
SELECT
    request_row.gov_request_id,
    request_row.protocol_code,
    request_row.request_status,
    request_row.requester_user_id,
    request_row.assigned_officer_user_id,
    request_row.submitted_at,
    request_row.resolved_at,
    catalog.gov_service_id,
    catalog.service_code,
    catalog.service_title,
    catalog.department_name,
    catalog.sla_business_days,
    COUNT(event_row.gov_request_event_id) AS event_count,
    MAX(event_row.occurred_at) AS last_event_at
FROM gov_service_requests AS request_row
JOIN gov_service_catalog AS catalog
  ON catalog.gov_service_id = request_row.gov_service_id
LEFT JOIN gov_request_events AS event_row
  ON event_row.gov_request_id = request_row.gov_request_id
WHERE request_row.module_code = 'GOV'
GROUP BY
    request_row.gov_request_id,
    request_row.protocol_code,
    request_row.request_status,
    request_row.requester_user_id,
    request_row.assigned_officer_user_id,
    request_row.submitted_at,
    request_row.resolved_at,
    catalog.gov_service_id,
    catalog.service_code,
    catalog.service_title,
    catalog.department_name,
    catalog.sla_business_days;

COMMENT ON VIEW v_city_mobility_security_legal_ops IS
    'Resumo juridico do dominio com contratos, assinaturas, disputas e ultima auditoria.';
COMMENT ON VIEW v_city_mobility_security_experience_ops IS
    'Consolida experiencia, evento, ticket e booking em uma visao operacional unica.';
COMMENT ON VIEW v_city_mobility_security_incident_ops IS
    'Visao de seguranca com contatos confiaveis, biometria e ultima acao sobre o incidente.';
COMMENT ON VIEW v_city_mobility_security_gov_requests IS
    'Pipeline govtech de catalogo, solicitacao e eventos do atendimento.';

COMMIT;
