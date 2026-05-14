# Roadmap Automatizado - Valley Omniverse V47

Este arquivo e gerado de forma deterministica por `scripts/automacao_sincronizador_modulos.py`.

Este roadmap automatiza a evolucao dos 47 modulos a partir do registry `config/modules_v47.json`.

Regra central: tudo que envolve dinheiro, identidade, contratos e documentos vai para PostgreSQL; IA, social, telemetria e alto volume vao para MongoDB ou backend especializado.

## Cobertura Atual

- `DATA_CONTRACT`: 5 modulos.
- `BUILD`: 4 modulos.
- `VALIDATE`: 38 modulos.

## Ordem De Prioridade

### foundation

- `REPLY` - Valley REPLY: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar fluxo fiscal ponta a ponta.
- `STOCK` - Valley Stock: fase `VALIDATE`, data home `postgres`, proxima entrega: definir politica de margem por canal.
- `LOG` - Valley Log: fase `VALIDATE`, data home `mongo`, proxima entrega: normalizar status canonicos.
- `WMS` - Valley WMS: fase `VALIDATE`, data home `postgres_mongo`, proxima entrega: fechar mapa de enderecamento.
- `MARKETPLACE` - Valley Marketplace: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar politica de seller score.
- `PAY` - Valley Pay: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar matriz de limites.
- `TECH` - Valley Tech: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar rotate de credenciais.
- `LEGAL` - Valley Legal: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar clausulas parametrizadas.
- `IOT` - Valley IoT: fase `VALIDATE`, data home `mongo`, proxima entrega: fechar inventario de device.
- `BUSINESS` - Valley Business: fase `DATA_CONTRACT`, data home `postgres`, proxima entrega: criar contrato especifico de empresa e unidade.
- `DOCS` - Valley Docs: fase `DATA_CONTRACT`, data home `postgres`, proxima entrega: criar contrato especifico de template.

### core

- `FOOD` - Valley Food: fase `DATA_CONTRACT`, data home `postgres`, proxima entrega: criar contrato especifico de cardapio e loja.
- `DELIVERY` - Valley Delivery: fase `VALIDATE`, data home `postgres_mongo`, proxima entrega: fechar reatribuicao automatica.
- `FLEET` - Valley Fleet: fase `VALIDATE`, data home `mongo`, proxima entrega: fechar score de saude do veiculo.
- `SERVICES` - Valley Services: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar score de prestador.
- `HEALTH` - Valley Health: fase `VALIDATE`, data home `postgres_mongo`, proxima entrega: amarrar consentimento granular.
- `JOBS` - Valley Jobs: fase `VALIDATE`, data home `postgres_mongo`, proxima entrega: fechar score explicavel.
- `ADS` - Valley Ads: fase `VALIDATE`, data home `mongo`, proxima entrega: fechar janela de atribuicao.
- `INFLUENCERS` - Valley Influencers: fase `BUILD`, data home `mongo`, proxima entrega: fechar score de creator fit.
- `SOCIAL` - Valley Social: fase `BUILD`, data home `mongo`, proxima entrega: fechar score de reputacao.
- `PHARMACY` - Valley Pharmacy: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar checagem de receita.
- `EVENTS` - Valley Events: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar anti-scalping.
- `MOBILITY` - Valley Mobility: fase `VALIDATE`, data home `postgres_mongo`, proxima entrega: fechar calculo de tarifa.
- `SECURITY` - Valley Security: fase `VALIDATE`, data home `postgres_mongo`, proxima entrega: fechar severidade de incidente.
- `AGENDA` - Valley Agenda: fase `VALIDATE`, data home `mongo`, proxima entrega: fechar recorrencia canonica.
- `ADVISOR` - Valley Advisor: fase `BUILD`, data home `postgres_mongo`, proxima entrega: fechar registro de consentimento.
- `FINANCAS` - Valley Financas: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar agregacao por categoria.
- `MENTE` - Valley Mente: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar trilha de nota cifrada.
- `PLUG` - Valley Plug: fase `DATA_CONTRACT`, data home `postgres`, proxima entrega: criar contrato especifico de terminal.
- `UP` - Valley Up: fase `DATA_CONTRACT`, data home `postgres_mongo`, proxima entrega: criar contrato especifico de atribuicao.
- `MEDIA` - Valley Media: fase `BUILD`, data home `postgres_mongo`, proxima entrega: fechar pipeline de media.
- `CHAT` - Valley Chat: fase `VALIDATE`, data home `postgres_mongo`, proxima entrega: fechar politica de retention.

### expansion

- `DIGITAL` - Valley Digital: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar politica de metadata.
- `REAL_ESTATE` - Valley Real Estate: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar onboarding documental.
- `EDU` - Valley Edu: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar emissao de certificado.
- `NEWS_PODCAST` - Valley News & Podcast: fase `VALIDATE`, data home `mongo`, proxima entrega: fechar taxonomia editorial.
- `FITNESS` - Valley Fitness: fase `VALIDATE`, data home `mongo`, proxima entrega: fechar score de consistencia.
- `VET` - Valley Vet: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar historico vacinal.
- `TOURISM` - Valley Tourism: fase `VALIDATE`, data home `postgres_mongo`, proxima entrega: fechar politica de cancelamento.
- `GOV` - Valley Gov: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar taxonomia de servico publico.
- `CHARITY` - Valley Charity: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar prova de impacto.
- `INSURANCE` - Valley Insurance: fase `VALIDATE`, data home `postgres`, proxima entrega: fechar score de risco.
- `GAMING` - Valley Gaming: fase `VALIDATE`, data home `mongo`, proxima entrega: fechar regra de quest.
- `BIO` - Valley Bio: fase `VALIDATE`, data home `postgres_mongo`, proxima entrega: fechar score de impacto por material.
- `HOME` - Valley Home: fase `VALIDATE`, data home `mongo`, proxima entrega: fechar modelo de household.
- `ENERGY` - Valley Energy: fase `VALIDATE`, data home `postgres_mongo`, proxima entrega: fechar matching de energia.

### frontier

- `SPACE` - Valley Space: fase `VALIDATE`, data home `mongo`, proxima entrega: fechar taxonomia de ancora.

## Backlog Evolutivo Padrao

1. Validar dependencias e data home do modulo.
2. Revisar `modules/<modulo>/CONTRACT.md` antes de escrever schema ou codigo.
3. Criar ou revisar schema PostgreSQL/MongoDB.
4. Criar regras de negocio em `business_rule_definitions` quando houver pricing, comissao, risco ou compliance.
5. Atualizar `modules/<modulo>/README.md`, `STATUS.md`, `CONTRACT.md` e o blueprint canonico.
6. Atualizar Manual Online e regenerar PDF.
7. Registrar descarte quando a ideia for inviavel, insegura ou duplicada.
