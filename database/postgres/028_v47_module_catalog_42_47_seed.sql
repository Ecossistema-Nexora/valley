BEGIN;

-- Sincroniza module_catalog com o registro v47 completo.
-- module_delivery_registry ja conhecia 42-47; esta migration fecha o drift
-- sem reescrever o bootstrap 004.

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
) VALUES
    (
        42,
        'BUSINESS',
        'Valley Business',
        'PJ: operacao empresarial',
        'Admin: gestao fiscal',
        'ERP integrado para empresas, fiscais, estoque e folha.',
        'Assinatura, fees operacionais e automacao fiscal',
        TRUE,
        'Valley Omniverse V47 - Registro Canonico de Modulos'
    ),
    (
        43,
        'PLUG',
        'Valley Plug',
        'PJ: lojistas e prestadores',
        'PF: pagadores presenciais',
        'Maquininha, Tap-to-Pay, MDR e antecipacao D+0.',
        'MDR, antecipacao e servicos financeiros',
        TRUE,
        'Valley Omniverse V47 - Registro Canonico de Modulos'
    ),
    (
        44,
        'UP',
        'Valley Up',
        'Influencer: afiliados',
        'PJ: marcas e merchants',
        'Afiliados, indicacoes, comissoes e links de atribuicao.',
        'Comissao de afiliacao e CAC zero',
        TRUE,
        'Valley Omniverse V47 - Registro Canonico de Modulos'
    ),
    (
        45,
        'MEDIA',
        'Valley Media',
        'Influencer: criadores',
        'PJ: marcas anunciantes',
        'Painel de criadores, uploads, monetizacao e distribuicao de conteudo.',
        'Revenue share, ads e ferramentas creator',
        TRUE,
        'Valley Omniverse V47 - Registro Canonico de Modulos'
    ),
    (
        46,
        'CHAT',
        'Valley Chat',
        'PF: usuarios finais',
        'PJ: atendimento e operacao',
        'Mensageria com persona pessoal/profissional e retencao segura.',
        'Bundle de plataforma e automacoes premium',
        TRUE,
        'Valley Omniverse V47 - Registro Canonico de Modulos'
    ),
    (
        47,
        'DOCS',
        'Valley Docs',
        'PF/PJ: documentos e recibos',
        'Admin: compliance documental',
        'Geracao de documentos, recibos, checksums e registros imutaveis.',
        'Geracao documental, compliance e armazenamento',
        TRUE,
        'Valley Omniverse V47 - Registro Canonico de Modulos'
    )
ON CONFLICT (module_code) DO UPDATE SET
    module_number = EXCLUDED.module_number,
    module_name = EXCLUDED.module_name,
    primary_audience = EXCLUDED.primary_audience,
    secondary_audience = EXCLUDED.secondary_audience,
    central_function = EXCLUDED.central_function,
    monetization_model = EXCLUDED.monetization_model,
    is_active = EXCLUDED.is_active,
    source_document = EXCLUDED.source_document,
    updated_at = NOW();

COMMENT ON TABLE module_catalog IS
    'Catalogo canonico dos 47 modulos v47, adaptado ao modelo public core-first.';

COMMIT;
