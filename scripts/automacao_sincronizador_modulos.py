#!/usr/bin/env python3
"""
AUTOMAÇÃO DE MÓDULOS VALLEY (Sincronizador)
===========================================
PROPOSITO: Sincronizar o registry canonico de modulos Valley com documentacao, roadmap e migrations.
CONTEXTO: Este script materializa a evolucao modular a partir de config/modules_v47.json e blueprints relacionados.
REGRAS: Validar obrigatoriamente os 47 modulos, manter saidas deterministicas e acionar apenas artefatos locais controlados.

Propósito: Sincronizar o registro canônico (modules_v47.json) com a estrutura física de diretórios e schemas.
Contexto: Este script é o coração da evolução modular do projeto Valley, garantindo que o DDL e o Roadmap estejam alinhados.
Regras de Negócio:
1. Threshold de Prioridade (2): Define a "Primeira Onda" de domínios prioritários.
2. Consistência: Valida obrigatoriamente a existência dos 47 módulos.

Instruções de Uso:
1. python automacao_sincronizador_modulos.py validate  -> Valida a integridade dos 47 módulos.
2. python automacao_sincronizador_modulos.py sync      -> Gera READMEs, STATUS e CONTRACTS em /modules.
3. python automacao_sincronizador_modulos.py sql       -> Gera a migration 007_v47_module_delivery_automation.sql.
"""

# argparse cria uma CLI simples para rodar sync, validate e roadmap.
import argparse

# json le o registry canonico dos 47 modulos.
import json

# subprocess executa o builder admin como etapa automatica.
import subprocess

# sys reaproveita o Python atual em subprocessos portaveis.
import sys

# dataclasses organiza a estrutura interna do modulo com tipos claros.
from dataclasses import dataclass, field

# pathlib manipula caminhos da worktree sem depender do sistema operacional.
from pathlib import Path

# textwrap ajuda a gerar Markdown legivel e sem indentacao acidental.
from textwrap import dedent


# ROOT aponta para a raiz da worktree Valley.
ROOT = Path(__file__).resolve().parents[1]

# REGISTRY_PATH e a fonte unica para os 47 modulos.
REGISTRY_PATH = ROOT / 'config' / 'modules_v47.json'

# BLUEPRINTS_PATH guarda a evolucao detalhada e canonica dos modulos.
BLUEPRINTS_PATH = ROOT / 'config' / 'modules_v47_blueprints.json'

# MODULES_DIR guarda um diretory por modulo para documentacao operacional.
MODULES_DIR = ROOT / 'modules'

# ROADMAP_DIR guarda relatorios consolidados para implantacao e evolucao.
ROADMAP_DIR = ROOT / 'output' / 'module-roadmap'

# CONTRACTS_SUMMARY_PATH guarda a matriz consolidada dos contratos operacionais.
CONTRACTS_SUMMARY_PATH = ROADMAP_DIR / 'VALLEY_MODULE_CONTRACTS.md'

# EXECUTION_BACKLOG_PATH guarda backlog acionavel agrupado por dominio.
EXECUTION_BACKLOG_PATH = ROADMAP_DIR / 'VALLEY_DOMAIN_EXECUTION_BACKLOG.md'

# PRIORITY_DOMAIN_PLAN_PATH guarda o plano fisico por camada dos dominios prioritarios.
PRIORITY_DOMAIN_PLAN_PATH = ROADMAP_DIR / 'VALLEY_PRIORITY_DOMAIN_DELIVERY_PLAN.md'

# DOMAIN_DELIVERY_DIR guarda pacotes fisicos por dominio e camada.
DOMAIN_DELIVERY_DIR = ROOT / 'database' / 'domain-delivery' / 'priority-domains'

# DOMAIN_EVENT_CONTRACTS_DIR guarda contratos de evento exportados por dominio prioritario.
DOMAIN_EVENT_CONTRACTS_DIR = ROOT / 'contracts' / 'events' / 'priority-domains'

# GENERATED_SQL_PATH guarda a migration gerada a partir do registry dos 47 modulos.
GENERATED_SQL_PATH = ROOT / 'database' / 'postgres' / '007_v47_module_delivery_automation.sql'

# GENERATED_BLUEPRINT_SQL_PATH guarda a migration incremental de blueprint do registry.
GENERATED_BLUEPRINT_SQL_PATH = ROOT / 'database' / 'postgres' / '015_v47_module_blueprints_registry.sql'

# GENERATED_EXECUTION_BACKLOG_SQL_PATH guarda a migration incremental do backlog executavel.
GENERATED_EXECUTION_BACKLOG_SQL_PATH = ROOT / 'database' / 'postgres' / '016_v47_execution_backlog_seed.sql'

# GENERATED_PRIORITY_DOMAIN_SQL_PATH guarda a camada relacional dos pacotes fisicos por dominio.
GENERATED_PRIORITY_DOMAIN_SQL_PATH = ROOT / 'database' / 'postgres' / '017_v47_priority_domain_delivery_packages.sql'

# GENERATED_PRIORITY_DOMAIN_SEED_PATH guarda o seed operacional consolidado dos dominios prioritarios.
GENERATED_PRIORITY_DOMAIN_SEED_PATH = ROOT / 'database' / 'seeds' / 'postgres' / '002_v47_priority_domain_delivery_packages_seed.sql'

# MANUAL_DECISION_PATH registra decisoes humanas e tecnicas sobre implantacao.
MANUAL_DECISION_PATH = ROOT / 'MANUAL_ONLINE' / 'DECISOES_IMPLANTACAO_V47.md'

# ADMIN_BUILDER_PATH aponta para o gerador do console admin.
ADMIN_BUILDER_PATH = ROOT / 'scripts' / 'valley_admin_builder.py'

# PYTHON_COMMAND reaproveita o Python atual em automacoes derivadas.
PYTHON_COMMAND = [sys.executable] if sys.executable else ['python3']

# PHASE_LABELS traduz a fase tecnica para PT-BR simples.
PHASE_LABELS = {
    'DISCOVERY': 'Discovery',
    'DATA_CONTRACT': 'Contrato de dados',
    'BUILD': 'Build',
    'VALIDATE': 'Validacao',
    'DOCUMENT': 'Documentacao',
    'RELEASE': 'Release',
    'EVOLVE': 'Evolucao continua',
}

# DOMAIN_LABELS traduz dominios tecnicos em grupos legiveis.
DOMAIN_LABELS = {
    'logistics_erp_operations': 'Logistics ERP Operations',
    'commerce_fintech_assets': 'Commerce Fintech Assets',
    'services_health_human': 'Services Health Human',
    'education_work_social': 'Education Work Social',
    'platform_developer': 'Platform Developer',
    'media_social_growth': 'Media Social Growth',
    'city_mobility_security': 'City Mobility Security',
    'frontier_iot_energy': 'Frontier IoT Energy',
    'ai_memory_operations': 'AI Memory Operations',
}

# PRIORITY_DOMAIN_THRESHOLD define quais dominios entram na primeira onda fisica.
PRIORITY_DOMAIN_THRESHOLD = 2


@dataclass(frozen=True)
class ValleyModule:
    """Representa um modulo Valley ja normalizado a partir do registry JSON."""

    # number e o numero oficial v47 do modulo.
    number: int

    # code e o identificador tecnico estavel usado por scripts e database.
    code: str

    # name e o nome humano do modulo.
    name: str

    # subtitle descreve a especialidade do modulo em ingles tecnico.
    subtitle: str

    # domain agrupa modulos por familia de arquitetura.
    domain: str

    # tier indica prioridade arquitetural: foundation, core, expansion ou frontier.
    tier: str

    # data_home indica onde o dado vive: postgres, mongo ou ambos.
    data_home: str

    # automation_status registra o quanto ja foi implantado nesta arvore.
    automation_status: str

    # depends_on lista dependencias minimas para desenvolvimento seguro.
    depends_on: list[str]

    # integrates_with lista integracoes de produto e dados.
    integrates_with: list[str]

    # description_ptbr explica finalidade em portugues simples.
    description_ptbr: str

    # current_phase indica em que fase real o modulo se encontra.
    current_phase: str = 'DISCOVERY'

    # primary_actors lista quem opera ou consome o modulo.
    primary_actors: list[str] = field(default_factory=list)

    # key_capabilities lista as capacidades que definem o modulo.
    key_capabilities: list[str] = field(default_factory=list)

    # postgres_entities lista tabelas ou entidades relacionais chave.
    postgres_entities: list[str] = field(default_factory=list)

    # mongo_collections lista colecoes ou payloads volumosos chave.
    mongo_collections: list[str] = field(default_factory=list)

    # event_topics lista eventos tecnicos estaveis para integracao.
    event_topics: list[str] = field(default_factory=list)

    # compliance_tags lista controles e trilhas de compliance relevantes.
    compliance_tags: list[str] = field(default_factory=list)

    # admin_surfaces lista telas, filas ou superficies administrativas necessarias.
    admin_surfaces: list[str] = field(default_factory=list)

    # next_deliverables lista a proxima onda concreta de evolucao.
    next_deliverables: list[str] = field(default_factory=list)

    @property
    def slug(self) -> str:
        """Retorna slug estavel para pasta do modulo."""

        # slug usa numero com zero a esquerda para ordenar no filesystem.
        return f'{self.number:02d}-{self.code.lower().replace("_", "-")}'

    @property
    def status_label(self) -> str:
        """Traduz status tecnico em linguagem simples."""

        # labels centraliza os nomes de status para evitar textos divergentes.
        labels = {
            'planned': 'Planejado',
            'implemented_partial': 'Parcialmente implantado',
            'implemented': 'Implantado',
            'blocked': 'Bloqueado',
        }

        # Retorna traducao conhecida ou o status original quando houver extensao futura.
        return labels.get(self.automation_status, self.automation_status)

    @property
    def phase_label(self) -> str:
        """Traduz fase tecnica em linguagem simples."""

        # Retorna traducao conhecida ou a fase original.
        return PHASE_LABELS.get(self.current_phase, self.current_phase)


@dataclass(frozen=True)
class ExecutionBacklogItem:
    """Representa um item executavel do backlog por modulo e dominio."""

    backlog_key: str
    module_number: int
    module_code: str
    module_name: str
    module_domain: str
    tier: str
    execution_stage: str
    target_data_home: str
    priority: int
    title: str
    description_ptbr: str
    acceptance_criteria: str
    depends_on_keys: list[str]
    evidence_hint: str


@dataclass(frozen=True)
class DomainEventContract:
    """Representa um contrato de evento exportado para um dominio prioritario."""

    contract_key: str
    domain_key: str
    module_code: str
    module_name: str
    event_topic: str
    contract_version: str
    producer_surface: str
    consumer_surfaces: list[str]
    evidence_entities: list[str]
    compliance_tags: list[str]
    payload_schema_json: dict
    artifact_path: Path


@dataclass(frozen=True)
class DomainDeliveryArtifact:
    """Representa um artefato fisico por camada dentro de um pacote de dominio."""

    artifact_key: str
    domain_key: str
    layer_type: str
    target_engine: str
    artifact_path: Path
    module_codes: list[str]
    backlog_keys: list[str]
    depends_on_keys: list[str]
    artifact_payload_json: dict = field(default_factory=dict)


@dataclass(frozen=True)
class DomainDeliveryPackage:
    """Representa um pacote fisico pronto para execucao por dominio prioritario."""

    package_key: str
    domain_key: str
    domain_label: str
    priority_rank: int
    modules: list[ValleyModule]
    backlog_items: list[ExecutionBacklogItem]
    artifacts: list[DomainDeliveryArtifact]
    event_contracts: list[DomainEventContract]


def load_registry() -> list[ValleyModule]:
    """Carrega e valida o registry canonico dos 47 modulos."""

    # Abre o JSON em UTF-8 para preservar acentos do portugues.
    payload = json.loads(REGISTRY_PATH.read_text(encoding='utf-8'))

    # blueprints complementa o registry base com evolucao detalhada por modulo.
    blueprints = load_blueprints()

    # modules_raw contem a lista bruta vinda do arquivo de configuracao.
    modules_raw = payload.get('modules', [])

    # modules converte cada dicionario em ValleyModule fortemente estruturado.
    modules = []
    for item in modules_raw:
        # code identifica qual blueprint deve ser anexado ao modulo base.
        code = item['code']

        # blueprint aplica defaults vazios quando o codigo ainda nao existir no arquivo complementar.
        blueprint = blueprints.get(code, {})

        # merged junta dados canonicos e evolucao detalhada.
        merged = {**item, **blueprint}

        # Instancia o dataclass final ja enriquecido.
        modules.append(ValleyModule(**merged))

    # validate_modules aplica checagens de consistencia antes de gerar arquivos.
    validate_modules(modules)

    # Retorna a lista pronta para sync, roadmap e relatorios.
    return modules


def load_blueprints() -> dict[str, dict]:
    """Carrega blueprints detalhados por codigo tecnico."""

    # Se o arquivo ainda nao existir, retorna vazio para permitir bootstrap.
    if not BLUEPRINTS_PATH.exists():
        return {}

    # payload le a estrutura versionada dos blueprints.
    payload = json.loads(BLUEPRINTS_PATH.read_text(encoding='utf-8'))

    # modules_map centraliza cada blueprint por codigo tecnico.
    return payload.get('modules', {})


def validate_modules(modules: list[ValleyModule]) -> None:
    """Valida unicidade, contagem e dependencias basicas dos 47 modulos."""

    # A contagem oficial do Esquema Consolidado e 47 modulos.
    if len(modules) != 47:
        # Falha cedo para evitar roadmap incompleto.
        raise ValueError(f'Esperado 47 modulos, encontrado {len(modules)}')

    # numbers captura todos os numeros oficiais para validar duplicidade.
    numbers = [module.number for module in modules]

    # codes captura todos os codigos tecnicos para validar duplicidade.
    codes = [module.code for module in modules]

    # Cada numero deve ser unico.
    if len(set(numbers)) != len(numbers):
        # Erro explicito facilita correcao do registry.
        raise ValueError('Existem numeros de modulo duplicados no registry.')

    # Cada codigo deve ser unico.
    if len(set(codes)) != len(codes):
        # Erro explicito facilita correcao do registry.
        raise ValueError('Existem codigos de modulo duplicados no registry.')

    # O conjunto esperado e exatamente 1..47.
    if sorted(numbers) != list(range(1, 48)):
        # Bloqueia buracos ou numeros fora do range oficial.
        raise ValueError('Os numeros dos modulos precisam cobrir exatamente 1..47.')

    # known_codes permite validar dependencias que apontam para outros modulos.
    known_codes = set(codes)

    # external_codes sao conceitos ja existentes no core ou no indice de 41 modulos, mas nao sao modulos v47 isolados.
    external_codes = {'ID', 'AI', 'RIDER', 'WALLETS', 'TRANSACTIONS', 'EQUITY', 'ORDERS', 'INVOICES', 'PAYROLLS', 'TICKETS', 'CLOUD', 'CONNECT', 'CREATOR', 'WEARABLES', 'LOYALTY', 'ADS_INTELLIGENCE', 'API', 'COMMAND_CENTER'}

    # known_phases limita a fase a valores suportados pela migration 007.
    known_phases = set(PHASE_LABELS)

    # Percorre cada modulo para validar dependencias e integracoes.
    for module in modules:
        # dependencies junta depends_on e integrates_with para uma regra unica.
        dependencies = set(module.depends_on) | set(module.integrates_with)

        # unknown guarda referencias que nao sao modulo nem conceito core conhecido.
        unknown = dependencies - known_codes - external_codes

        # Se houver desconhecidos, falha antes de gerar documentacao errada.
        if unknown:
            # Mensagem aponta exatamente qual modulo esta incoerente.
            raise ValueError(f'{module.code} referencia codigos desconhecidos: {sorted(unknown)}')

        # Toda evolucao detalhada deve informar uma fase suportada pela esteira.
        if module.current_phase not in known_phases:
            raise ValueError(f'{module.code} usa fase invalida: {module.current_phase}')

        # Cada modulo precisa ter blueprint minimamente util.
        if not module.primary_actors:
            raise ValueError(f'{module.code} sem primary_actors no blueprint.')
        if not module.key_capabilities:
            raise ValueError(f'{module.code} sem key_capabilities no blueprint.')
        if not module.event_topics:
            raise ValueError(f'{module.code} sem event_topics no blueprint.')
        if not module.compliance_tags:
            raise ValueError(f'{module.code} sem compliance_tags no blueprint.')
        if not module.admin_surfaces:
            raise ValueError(f'{module.code} sem admin_surfaces no blueprint.')
        if not module.next_deliverables:
            raise ValueError(f'{module.code} sem next_deliverables no blueprint.')

        # Toda fronteira relacional principal precisa ser explicitada quando o modulo usa PostgreSQL como home ou apoio hibrido.
        if module.data_home in {'postgres', 'postgres_mongo'} and not module.postgres_entities:
            raise ValueError(f'{module.code} precisa declarar postgres_entities.')

        # Toda fronteira volumosa principal precisa ser explicitada quando o modulo usa MongoDB como home ou apoio hibrido.
        if module.data_home in {'mongo', 'postgres_mongo'} and not module.mongo_collections:
            raise ValueError(f'{module.code} precisa declarar mongo_collections.')


def inline_list(values: list[str]) -> str:
    """Converte lista em texto inline amigavel."""

    # Sem valores, usa marcador neutro.
    if not values:
        return '-'

    # Junta itens mantendo ordem declarada no registry.
    return ', '.join(values)


def bullet_list(values: list[str]) -> str:
    """Converte lista em bullets Markdown."""

    # Sem valores, retorna bullet neutro.
    if not values:
        return '- Nao aplicavel.'

    # Gera um bullet por item para leitura rapida.
    return '\n'.join(f'- {value}' for value in values)


def schema_coverage_label(module: ValleyModule) -> str:
    """Resume a cobertura de schema do modulo."""

    # Pure postgres pode ter colecoes auxiliares, mas a ancora continua relacional.
    if module.data_home == 'postgres':
        if module.mongo_collections:
            return f'PostgreSQL: {len(module.postgres_entities)} entidades principais e {len(module.mongo_collections)} colecoes auxiliares.'
        return f'PostgreSQL: {len(module.postgres_entities)} entidades mapeadas.'

    # Pure mongo pode depender de ancora relacional leve para ledger, docs ou compliance.
    if module.data_home == 'mongo':
        if module.postgres_entities:
            return f'MongoDB: {len(module.mongo_collections)} colecoes principais e {len(module.postgres_entities)} entidades relacionais de apoio.'
        return f'MongoDB: {len(module.mongo_collections)} colecoes mapeadas.'

    # Hibrido mostra ambas as frentes.
    return f'Hibrido: {len(module.postgres_entities)} entidades PostgreSQL e {len(module.mongo_collections)} colecoes MongoDB.'


def module_blueprint_payload(module: ValleyModule) -> dict:
    """Consolida blueprint do modulo em JSON serializavel."""

    return {
        'current_phase': module.current_phase,
        'primary_actors': module.primary_actors,
        'key_capabilities': module.key_capabilities,
        'postgres_entities': module.postgres_entities,
        'mongo_collections': module.mongo_collections,
        'event_topics': module.event_topics,
        'compliance_tags': module.compliance_tags,
        'admin_surfaces': module.admin_surfaces,
        'next_deliverables': module.next_deliverables,
    }


def domain_label(domain: str) -> str:
    """Traduz dominio tecnico em rotulo legivel."""

    # Retorna label conhecida ou o dominio bruto quando surgir nova familia.
    return DOMAIN_LABELS.get(domain, domain)


def phase_execution_offset(phase: str) -> int:
    """Define ajuste de prioridade baseado na fase atual."""

    # DATA_CONTRACT e BUILD sao mais urgentes por destravarem execucao.
    offsets = {
        'DATA_CONTRACT': 0,
        'BUILD': 0,
        'VALIDATE': 1,
        'DOCUMENT': 1,
        'RELEASE': 2,
        'EVOLVE': 2,
        'DISCOVERY': 1,
    }

    # Default conservador para fases futuras.
    return offsets.get(phase, 1)


def build_execution_backlog_items(modules: list[ValleyModule]) -> list[ExecutionBacklogItem]:
    """Expande blueprints em backlog executavel com chave deterministica."""

    # items acumula uma linha executavel por entregavel do modulo.
    items: list[ExecutionBacklogItem] = []

    # tier_base traduz o tier em urgencia estrutural.
    tier_base = {
        'foundation': 1,
        'core': 2,
        'expansion': 3,
        'frontier': 4,
    }

    # Percorre modulos em ordem canonica.
    for module in sorted(modules, key=lambda item: item.number):
        for index, deliverable in enumerate(module.next_deliverables, start=1):
            # backlog_key e estavel para permitir upsert deterministico.
            backlog_key = f'{module.code}.exec.{index:02d}'

            # previous_key encadeia entregas do mesmo modulo.
            previous_key = f'{module.code}.exec.{index - 1:02d}' if index > 1 else None

            # priority combina tier, fase e ordem da entrega.
            priority = min(5, tier_base.get(module.tier, 4) + phase_execution_offset(module.current_phase) + ((index - 1) // 2))

            # evidence_anchor aponta onde o operador deve buscar prova concreta.
            evidence_sources = module.postgres_entities[:2] + module.mongo_collections[:2] + module.event_topics[:1]
            evidence_anchor = inline_list(evidence_sources)

            # title torna a fila legivel em SQL e em dashboards.
            title = f'{module.code} :: {deliverable}'

            # description resume o contexto operacional do item.
            description = (
                f'Dominio {module.module_domain if hasattr(module, "module_domain") else module.domain}. '
                f'Modulo {module.name}. '
                f'Executar: {deliverable}. '
                f'Fase atual {module.current_phase}. '
                f'Data home {module.data_home}. '
                f'Integracoes chave: {inline_list(module.integrates_with)}.'
            )

            # acceptance define quando o item pode sair da fila.
            acceptance = (
                f'Entregavel "{deliverable}" implementado ou descartado com justificativa. '
                f'Documentacao de {module.code} sincronizada. '
                f'Evidencia tecnica alinhada a {evidence_anchor}.'
            )

            # evidence_hint orienta a checagem manual ou automatica posterior.
            evidence_hint = f'Validar evidencias em {evidence_anchor}.'

            items.append(
                ExecutionBacklogItem(
                    backlog_key=backlog_key,
                    module_number=module.number,
                    module_code=module.code,
                    module_name=module.name,
                    module_domain=module.domain,
                    tier=module.tier,
                    execution_stage=module.current_phase,
                    target_data_home=module.data_home,
                    priority=priority,
                    title=title,
                    description_ptbr=description,
                    acceptance_criteria=acceptance,
                    depends_on_keys=[previous_key] if previous_key else [],
                    evidence_hint=evidence_hint,
                )
            )

    return items


def unique_in_order(values: list[str]) -> list[str]:
    """Remove duplicados preservando a ordem original."""

    # seen registra valores ja emitidos.
    seen: set[str] = set()

    # unique_values acumula a versao final sem ruido.
    unique_values: list[str] = []

    for value in values:
        if value in seen:
            continue

        seen.add(value)
        unique_values.append(value)

    return unique_values


def relative_posix_path(path: Path) -> str:
    """Converte caminho absoluto em caminho relativo POSIX dentro do repo."""

    return path.relative_to(ROOT).as_posix()


def build_event_payload_schema(module: ValleyModule, event_topic: str) -> dict:
    """Gera um JSON Schema pragmatico para eventos de um modulo."""

    # evidence_entities ancora onde a entrega sera auditada.
    evidence_entities = unique_in_order(module.postgres_entities[:3] + module.mongo_collections[:2])

    # actor_enums e capability_enums reduzem ambiguidade de payload.
    actor_enums = module.primary_actors[:4] or ['system']
    capability_enums = module.key_capabilities[:4] or ['generic_capability']

    return {
        '$schema': 'https://json-schema.org/draft/2020-12/schema',
        'title': f'{module.code}::{event_topic}',
        'type': 'object',
        'additionalProperties': False,
        'required': [
            'event_id',
            'event_topic',
            'module_code',
            'domain_key',
            'user_id',
            'occurred_at',
            'payload',
            'evidence_refs',
        ],
        'properties': {
            'event_id': {'type': 'string', 'format': 'uuid'},
            'event_topic': {'const': event_topic},
            'module_code': {'const': module.code},
            'domain_key': {'const': module.domain},
            'user_id': {'type': 'string', 'format': 'uuid'},
            'aggregate_id': {'type': 'string', 'format': 'uuid'},
            'aggregate_type': {'type': 'string'},
            'trace_id': {'type': 'string', 'format': 'uuid'},
            'occurred_at': {'type': 'string', 'format': 'date-time'},
            'delivery_phase': {'const': module.current_phase},
            'payload': {
                'type': 'object',
                'additionalProperties': True,
                'properties': {
                    'primary_actor': {'type': 'string', 'enum': actor_enums},
                    'capability': {'type': 'string', 'enum': capability_enums},
                    'status': {'type': 'string'},
                    'details': {'type': 'object', 'additionalProperties': True},
                },
            },
            'evidence_refs': {
                'type': 'array',
                'minItems': 1,
                'items': {'type': 'string', 'enum': evidence_entities or ['users']},
            },
            'compliance_tags': {
                'type': 'array',
                'items': {'type': 'string'},
                'default': module.compliance_tags,
            },
        },
    }


def build_priority_domain_packages(modules: list[ValleyModule]) -> list[DomainDeliveryPackage]:
    """Converte backlog em pacotes fisicos por dominio prioritario."""

    # module_by_code evita buscas repetidas ao montar dominios.
    module_by_code = {module.code: module for module in modules}

    # by_domain agrupa backlog acionavel por familia tecnica.
    by_domain: dict[str, list[ExecutionBacklogItem]] = {}
    for item in build_execution_backlog_items(modules):
        by_domain.setdefault(item.module_domain, []).append(item)

    # packages acumula apenas dominios que entram na primeira onda.
    packages: list[DomainDeliveryPackage] = []

    for domain, items in by_domain.items():
        # priority_rank usa a menor prioridade do dominio para ordenar execucao.
        priority_rank = min(item.priority for item in items)

        # Apenas dominios mais urgentes entram na primeira entrega fisica.
        if priority_rank > PRIORITY_DOMAIN_THRESHOLD:
            continue

        # sorted_items mantem ordem deterministica por urgencia.
        sorted_items = sorted(items, key=lambda item: (item.priority, item.module_number, item.backlog_key))

        # domain_modules segue a ordem canonica dos modulos.
        domain_modules = [
            module_by_code[module_code]
            for module_code in unique_in_order([item.module_code for item in sorted_items])
        ]

        # package_key versiona o pacote sem depender do filesystem.
        package_key = f'{domain}.priority.v1'

        # Domain paths ficam centralizados para evitar drift.
        domain_dir = DOMAIN_DELIVERY_DIR / domain
        ddl_path = domain_dir / 'ddl_complement.sql'
        seed_path = domain_dir / 'operational_seed.sql'
        contract_path = DOMAIN_EVENT_CONTRACTS_DIR / f'{domain}.json'

        # event_contracts expande os topicos canonicos declarados no blueprint.
        event_contracts: list[DomainEventContract] = []
        for module in domain_modules:
            for event_topic in module.event_topics:
                event_contracts.append(
                    DomainEventContract(
                        contract_key=f'{module.code}:{event_topic}:v1',
                        domain_key=domain,
                        module_code=module.code,
                        module_name=module.name,
                        event_topic=event_topic,
                        contract_version='1.0.0',
                        producer_surface=(module.admin_surfaces[0] if module.admin_surfaces else module.code.lower()),
                        consumer_surfaces=unique_in_order(module.integrates_with + module.admin_surfaces[:2]),
                        evidence_entities=unique_in_order(module.postgres_entities[:3] + module.mongo_collections[:2]),
                        compliance_tags=module.compliance_tags,
                        payload_schema_json=build_event_payload_schema(module, event_topic),
                        artifact_path=contract_path,
                    )
                )

        # module_codes e backlog_keys aparecem repetidamente nos tres layers.
        module_codes = [module.code for module in domain_modules]
        backlog_keys = [item.backlog_key for item in sorted_items]

        # artifacts declara os tres layers fisicos que o pacote entrega.
        artifacts = [
            DomainDeliveryArtifact(
                artifact_key=f'{domain}.ddl.v1',
                domain_key=domain,
                layer_type='DDL_COMPLEMENT',
                target_engine='postgres',
                artifact_path=ddl_path,
                module_codes=module_codes,
                backlog_keys=backlog_keys,
                depends_on_keys=[],
                artifact_payload_json={
                    'views': [
                        f'v_{domain}_priority_backlog',
                        f'v_{domain}_delivery_artifacts',
                        f'v_{domain}_event_contracts',
                    ],
                    'priority_rank': priority_rank,
                    'package_key': package_key,
                },
            ),
            DomainDeliveryArtifact(
                artifact_key=f'{domain}.seed.v1',
                domain_key=domain,
                layer_type='OPERATIONS_SEED',
                target_engine='postgres',
                artifact_path=seed_path,
                module_codes=module_codes,
                backlog_keys=backlog_keys,
                depends_on_keys=[f'{domain}.ddl.v1'],
                artifact_payload_json={
                    'package_key': package_key,
                    'contract_count': len(event_contracts),
                    'seed_scope': 'priority_domain_delivery_v1',
                },
            ),
            DomainDeliveryArtifact(
                artifact_key=f'{domain}.contract.v1',
                domain_key=domain,
                layer_type='EVENT_CONTRACT',
                target_engine='filesystem',
                artifact_path=contract_path,
                module_codes=module_codes,
                backlog_keys=backlog_keys,
                depends_on_keys=[f'{domain}.ddl.v1', f'{domain}.seed.v1'],
                artifact_payload_json={
                    'package_key': package_key,
                    'event_topics': [contract.event_topic for contract in event_contracts],
                },
            ),
        ]

        packages.append(
            DomainDeliveryPackage(
                package_key=package_key,
                domain_key=domain,
                domain_label=domain_label(domain),
                priority_rank=priority_rank,
                modules=domain_modules,
                backlog_items=sorted_items,
                artifacts=artifacts,
                event_contracts=event_contracts,
            )
        )

    return sorted(packages, key=lambda package: (package.priority_rank, len(package.backlog_items), package.domain_key))


def domain_package_manifest(package: DomainDeliveryPackage) -> dict:
    """Consolida um pacote de dominio em JSON para seed e auditoria."""

    return {
        'package_key': package.package_key,
        'domain_key': package.domain_key,
        'domain_label': package.domain_label,
        'priority_rank': package.priority_rank,
        'modules': [module.code for module in package.modules],
        'backlog_keys': [item.backlog_key for item in package.backlog_items],
        'artifacts': [
            {
                'artifact_key': artifact.artifact_key,
                'layer_type': artifact.layer_type,
                'target_engine': artifact.target_engine,
                'artifact_path': relative_posix_path(artifact.artifact_path),
            }
            for artifact in package.artifacts
        ],
        'event_topics': [contract.event_topic for contract in package.event_contracts],
    }


def build_priority_domain_delivery_plan(modules: list[ValleyModule]) -> str:
    """Gera plano fisico por camada para os dominios prioritarios."""

    # packages materializa a primeira onda de dominio.
    packages = build_priority_domain_packages(modules)

    lines = [
        '# Priority Domain Delivery Plan - Valley V47',
        '',
        'Este arquivo e gerado por `scripts/automacao_sincronizador_modulos.py`.',
        '',
        'Ele transforma o backlog executavel por dominio em pacotes fisicos por camada, com DDL complementar, seed operacional e contrato de evento exportado.',
        '',
        f'- Threshold de prioridade: `<= {PRIORITY_DOMAIN_THRESHOLD}`.',
        f'- Dominios contemplados nesta onda: `{len(packages)}`.',
        '',
    ]

    for package in packages:
        lines.extend([
            f'## {package.domain_label}',
            '',
            f'- Dominio tecnico: `{package.domain_key}`',
            f'- Pacote: `{package.package_key}`',
            f'- Prioridade minima: `{package.priority_rank}`',
            f'- Modulos: {inline_list([f"`{module.code}`" for module in package.modules])}',
            f'- Itens de backlog cobertos: `{len(package.backlog_items)}`',
            f'- Contratos de evento: `{len(package.event_contracts)}`',
            '',
            '### Camadas',
            '',
        ])

        for artifact in package.artifacts:
            lines.append(
                f'- `{artifact.layer_type}` -> `{relative_posix_path(artifact.artifact_path)}` '
                f'({artifact.target_engine}; depende de {inline_list(artifact.depends_on_keys)})'
            )

        lines.extend([
            '',
            '### Backlog Coberto',
            '',
        ])

        for item in package.backlog_items:
            lines.append(
                f'- `{item.backlog_key}` | prio `{item.priority}` | fase `{item.execution_stage}` | {item.title}'
            )

        lines.extend([
            '',
            '### Eventos',
            '',
        ])

        for contract in package.event_contracts:
            lines.append(
                f'- `{contract.event_topic}` -> produtor `{contract.producer_surface}`; '
                f'consumidores {inline_list(contract.consumer_surfaces)}; '
                f'evidencia {inline_list(contract.evidence_entities)}'
            )

        lines.append('')

    return '\n'.join(lines)


def build_domain_delivery_ddl_sql(package: DomainDeliveryPackage) -> str:
    """Gera o DDL complementar de views operacionais para um dominio prioritario."""

    # domain_key vira prefixo estavel de objetos SQL.
    domain_key = package.domain_key

    return dedent(f"""\
    BEGIN;

    -- Pacote gerado automaticamente para {package.domain_label}.
    -- Artefato: {package.package_key}
    -- Dependencias: migrations 016 e 017 aplicadas.

    CREATE OR REPLACE VIEW v_{domain_key}_priority_backlog AS
    SELECT
        backlog.backlog_key,
        backlog.module_code,
        registry.module_name,
        registry.module_number,
        registry.current_phase,
        backlog.execution_stage,
        backlog.priority,
        backlog.target_data_home,
        backlog.depends_on_keys,
        backlog.evidence_hint,
        registry.module_blueprint_json -> 'postgres_entities' AS postgres_entities,
        registry.module_blueprint_json -> 'mongo_collections' AS mongo_collections,
        registry.module_blueprint_json -> 'event_topics' AS event_topics,
        registry.module_blueprint_json -> 'next_deliverables' AS next_deliverables
    FROM module_evolution_backlog AS backlog
    JOIN module_delivery_registry AS registry
      ON registry.module_code = backlog.module_code
    WHERE backlog.backlog_group = {sql_literal(domain_key)}
      AND backlog.origin_source = 'blueprint_execution_v1';

    CREATE OR REPLACE VIEW v_{domain_key}_delivery_artifacts AS
    SELECT
        artifact_key,
        package_key,
        domain_key,
        layer_type,
        target_engine,
        artifact_path,
        module_codes,
        backlog_keys,
        depends_on_keys,
        artifact_status,
        artifact_payload_json,
        created_at,
        updated_at
    FROM domain_delivery_artifacts
    WHERE domain_key = {sql_literal(domain_key)};

    CREATE OR REPLACE VIEW v_{domain_key}_event_contracts AS
    SELECT
        contract_key,
        package_key,
        domain_key,
        module_code,
        event_topic,
        contract_version,
        producer_surface,
        consumer_surfaces,
        evidence_entities,
        compliance_tags,
        artifact_path,
        contract_status,
        payload_schema_json,
        created_at,
        updated_at
    FROM domain_event_contracts
    WHERE domain_key = {sql_literal(domain_key)};

    COMMENT ON VIEW v_{domain_key}_priority_backlog IS
        'Visao operacional do backlog prioritario do dominio {domain_key}.';

    COMMENT ON VIEW v_{domain_key}_delivery_artifacts IS
        'Visao dos artefatos fisicos por camada do dominio {domain_key}.';

    COMMENT ON VIEW v_{domain_key}_event_contracts IS
        'Visao dos contratos de evento exportados do dominio {domain_key}.';

    COMMIT;
    """)


def build_domain_seed_sql(packages: list[DomainDeliveryPackage]) -> str:
    """Gera seed SQL idempotente para um ou mais pacotes de dominio."""

    # Sem pacotes nao ha valores para UPSERT; retorna seed no-op.
    if not packages:
        return 'BEGIN;\nCOMMIT;\n'

    # package_values, artifact_values e contract_values alimentam UPSERTs deterministicas.
    package_values = []
    artifact_values = []
    contract_values = []

    for package in packages:
        package_values.append(
            '('
            f'{sql_literal(package.package_key)}, '
            f'{sql_literal(package.domain_key)}, '
            f'{sql_literal(package.domain_label)}, '
            f'{package.priority_rank}, '
            f"{sql_literal('priority_domains_v1')}, "
            f'{sql_array([module.code for module in package.modules])}, '
            f'{sql_array([item.backlog_key for item in package.backlog_items])}, '
            f"{sql_literal('READY')}::domain_delivery_package_status_enum, "
            f'{sql_json(domain_package_manifest(package))}'
            ')'
        )

        for artifact in package.artifacts:
            artifact_values.append(
                '('
                f'{sql_literal(artifact.artifact_key)}, '
                f'{sql_literal(package.package_key)}, '
                f'{sql_literal(artifact.domain_key)}, '
                f"{sql_literal(artifact.layer_type)}::domain_delivery_layer_enum, "
                f'{sql_literal(artifact.target_engine)}, '
                f'{sql_literal(relative_posix_path(artifact.artifact_path))}, '
                f'{sql_array(artifact.module_codes)}, '
                f'{sql_array(artifact.backlog_keys)}, '
                f'{sql_array(artifact.depends_on_keys)}, '
                f"{sql_literal('READY')}::domain_delivery_package_status_enum, "
                f'{sql_json(artifact.artifact_payload_json)}'
                ')'
            )

        for contract in package.event_contracts:
            contract_values.append(
                '('
                f'{sql_literal(contract.contract_key)}, '
                f'{sql_literal(package.package_key)}, '
                f'{sql_literal(contract.domain_key)}, '
                f'{sql_literal(contract.module_code)}, '
                f'{sql_literal(contract.event_topic)}, '
                f'{sql_literal(contract.contract_version)}, '
                f'{sql_literal(contract.producer_surface)}, '
                f'{sql_array(contract.consumer_surfaces)}, '
                f'{sql_array(contract.evidence_entities)}, '
                f'{sql_array(contract.compliance_tags)}, '
                f"{sql_literal('READY')}::domain_delivery_package_status_enum, "
                f'{sql_json(contract.payload_schema_json)}, '
                f'{sql_literal(relative_posix_path(contract.artifact_path))}'
                ')'
            )

    package_values_sql = ',\n        '.join(package_values)
    artifact_values_sql = ',\n        '.join(artifact_values)
    contract_values_sql = ',\n        '.join(contract_values)

    return dedent(f"""\
    BEGIN;

    -- Seed operacional idempotente dos pacotes fisicos por dominio prioritario.
    -- Gerado automaticamente por scripts/automacao_sincronizador_modulos.py.

    WITH package_source (
        package_key,
        domain_key,
        domain_label,
        priority_rank,
        package_scope,
        module_codes,
        backlog_keys,
        package_status,
        artifact_manifest_json
    ) AS (
        VALUES
        {package_values_sql}
    )
    INSERT INTO domain_delivery_packages (
        package_key,
        domain_key,
        domain_label,
        priority_rank,
        package_scope,
        module_codes,
        backlog_keys,
        package_status,
        artifact_manifest_json
    )
    SELECT
        package_key,
        domain_key,
        domain_label,
        priority_rank,
        package_scope,
        module_codes,
        backlog_keys,
        package_status,
        artifact_manifest_json
    FROM package_source
    ON CONFLICT (package_key) DO UPDATE SET
        domain_key = EXCLUDED.domain_key,
        domain_label = EXCLUDED.domain_label,
        priority_rank = EXCLUDED.priority_rank,
        package_scope = EXCLUDED.package_scope,
        module_codes = EXCLUDED.module_codes,
        backlog_keys = EXCLUDED.backlog_keys,
        package_status = EXCLUDED.package_status,
        artifact_manifest_json = EXCLUDED.artifact_manifest_json,
        updated_at = NOW();

    WITH artifact_source (
        artifact_key,
        package_key,
        domain_key,
        layer_type,
        target_engine,
        artifact_path,
        module_codes,
        backlog_keys,
        depends_on_keys,
        artifact_status,
        artifact_payload_json
    ) AS (
        VALUES
        {artifact_values_sql}
    )
    INSERT INTO domain_delivery_artifacts (
        artifact_key,
        package_key,
        domain_key,
        layer_type,
        target_engine,
        artifact_path,
        module_codes,
        backlog_keys,
        depends_on_keys,
        artifact_status,
        artifact_payload_json
    )
    SELECT
        artifact_key,
        package_key,
        domain_key,
        layer_type,
        target_engine,
        artifact_path,
        module_codes,
        backlog_keys,
        depends_on_keys,
        artifact_status,
        artifact_payload_json
    FROM artifact_source
    ON CONFLICT (artifact_key) DO UPDATE SET
        package_key = EXCLUDED.package_key,
        domain_key = EXCLUDED.domain_key,
        layer_type = EXCLUDED.layer_type,
        target_engine = EXCLUDED.target_engine,
        artifact_path = EXCLUDED.artifact_path,
        module_codes = EXCLUDED.module_codes,
        backlog_keys = EXCLUDED.backlog_keys,
        depends_on_keys = EXCLUDED.depends_on_keys,
        artifact_status = EXCLUDED.artifact_status,
        artifact_payload_json = EXCLUDED.artifact_payload_json,
        updated_at = NOW();

    WITH contract_source (
        contract_key,
        package_key,
        domain_key,
        module_code,
        event_topic,
        contract_version,
        producer_surface,
        consumer_surfaces,
        evidence_entities,
        compliance_tags,
        contract_status,
        payload_schema_json,
        artifact_path
    ) AS (
        VALUES
        {contract_values_sql}
    )
    INSERT INTO domain_event_contracts (
        contract_key,
        package_key,
        domain_key,
        module_code,
        event_topic,
        contract_version,
        producer_surface,
        consumer_surfaces,
        evidence_entities,
        compliance_tags,
        contract_status,
        payload_schema_json,
        artifact_path
    )
    SELECT
        contract_key,
        package_key,
        domain_key,
        module_code,
        event_topic,
        contract_version,
        producer_surface,
        consumer_surfaces,
        evidence_entities,
        compliance_tags,
        contract_status,
        payload_schema_json,
        artifact_path
    FROM contract_source
    ON CONFLICT (contract_key) DO UPDATE SET
        package_key = EXCLUDED.package_key,
        domain_key = EXCLUDED.domain_key,
        module_code = EXCLUDED.module_code,
        event_topic = EXCLUDED.event_topic,
        contract_version = EXCLUDED.contract_version,
        producer_surface = EXCLUDED.producer_surface,
        consumer_surfaces = EXCLUDED.consumer_surfaces,
        evidence_entities = EXCLUDED.evidence_entities,
        compliance_tags = EXCLUDED.compliance_tags,
        contract_status = EXCLUDED.contract_status,
        payload_schema_json = EXCLUDED.payload_schema_json,
        artifact_path = EXCLUDED.artifact_path,
        updated_at = NOW();

    COMMIT;
    """)


def build_priority_domain_registry_sql(modules: list[ValleyModule]) -> str:
    """Gera a migration SQL que cria o registry fisico por dominio prioritario."""

    # packages so entram para documentar a quantidade desta onda.
    packages = build_priority_domain_packages(modules)

    return dedent(f"""\
    BEGIN;

    -- Primeira onda de pacotes fisicos por dominio prioritario gerados automaticamente.
    -- Dominios nesta onda: {len(packages)}.

    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM pg_type
            WHERE typname = 'domain_delivery_layer_enum'
        ) THEN
            CREATE TYPE domain_delivery_layer_enum AS ENUM (
                'DDL_COMPLEMENT',
                'OPERATIONS_SEED',
                'EVENT_CONTRACT'
            );
        END IF;

        IF NOT EXISTS (
            SELECT 1
            FROM pg_type
            WHERE typname = 'domain_delivery_package_status_enum'
        ) THEN
            CREATE TYPE domain_delivery_package_status_enum AS ENUM (
                'PLANNED',
                'READY',
                'MATERIALIZED',
                'BLOCKED'
            );
        END IF;
    END
    $$;

    CREATE TABLE IF NOT EXISTS domain_delivery_packages (
        domain_package_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        owner_user_id UUID NULL,
        package_key TEXT NOT NULL,
        domain_key TEXT NOT NULL,
        domain_label TEXT NOT NULL,
        priority_rank SMALLINT NOT NULL,
        package_scope TEXT NOT NULL DEFAULT 'priority_domains_v1',
        module_codes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        backlog_keys TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        package_status domain_delivery_package_status_enum NOT NULL DEFAULT 'READY',
        artifact_manifest_json JSONB NOT NULL DEFAULT '{{}}'::JSONB,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_domain_delivery_packages_owner
            FOREIGN KEY (owner_user_id) REFERENCES users (user_id),
        CONSTRAINT ux_domain_delivery_packages_key UNIQUE (package_key),
        CONSTRAINT chk_domain_delivery_packages_key CHECK (btrim(package_key) <> ''),
        CONSTRAINT chk_domain_delivery_packages_domain CHECK (domain_key ~ '^[a-z0-9_]+$'),
        CONSTRAINT chk_domain_delivery_packages_label CHECK (btrim(domain_label) <> ''),
        CONSTRAINT chk_domain_delivery_packages_priority CHECK (priority_rank BETWEEN 1 AND 5),
        CONSTRAINT chk_domain_delivery_packages_scope CHECK (btrim(package_scope) <> '')
    );

    CREATE TABLE IF NOT EXISTS domain_delivery_artifacts (
        domain_artifact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        owner_user_id UUID NULL,
        package_key TEXT NOT NULL,
        artifact_key TEXT NOT NULL,
        domain_key TEXT NOT NULL,
        layer_type domain_delivery_layer_enum NOT NULL,
        target_engine TEXT NOT NULL,
        artifact_path TEXT NOT NULL,
        module_codes TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        backlog_keys TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        depends_on_keys TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        artifact_status domain_delivery_package_status_enum NOT NULL DEFAULT 'READY',
        artifact_payload_json JSONB NOT NULL DEFAULT '{{}}'::JSONB,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_domain_delivery_artifacts_owner
            FOREIGN KEY (owner_user_id) REFERENCES users (user_id),
        CONSTRAINT fk_domain_delivery_artifacts_package
            FOREIGN KEY (package_key) REFERENCES domain_delivery_packages (package_key)
            ON DELETE CASCADE,
        CONSTRAINT ux_domain_delivery_artifacts_key UNIQUE (artifact_key),
        CONSTRAINT chk_domain_delivery_artifacts_key CHECK (btrim(artifact_key) <> ''),
        CONSTRAINT chk_domain_delivery_artifacts_domain CHECK (domain_key ~ '^[a-z0-9_]+$'),
        CONSTRAINT chk_domain_delivery_artifacts_engine CHECK (target_engine IN ('postgres', 'mongo', 'filesystem')),
        CONSTRAINT chk_domain_delivery_artifacts_path CHECK (btrim(artifact_path) <> '')
    );

    CREATE TABLE IF NOT EXISTS domain_event_contracts (
        domain_event_contract_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        owner_user_id UUID NULL,
        package_key TEXT NOT NULL,
        contract_key TEXT NOT NULL,
        domain_key TEXT NOT NULL,
        module_code TEXT NOT NULL,
        event_topic TEXT NOT NULL,
        contract_version TEXT NOT NULL DEFAULT '1.0.0',
        producer_surface TEXT NOT NULL,
        consumer_surfaces TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        evidence_entities TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        compliance_tags TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        contract_status domain_delivery_package_status_enum NOT NULL DEFAULT 'READY',
        payload_schema_json JSONB NOT NULL DEFAULT '{{}}'::JSONB,
        artifact_path TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_domain_event_contracts_owner
            FOREIGN KEY (owner_user_id) REFERENCES users (user_id),
        CONSTRAINT fk_domain_event_contracts_package
            FOREIGN KEY (package_key) REFERENCES domain_delivery_packages (package_key)
            ON DELETE CASCADE,
        CONSTRAINT fk_domain_event_contracts_module
            FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
            ON DELETE CASCADE,
        CONSTRAINT ux_domain_event_contracts_key UNIQUE (contract_key),
        CONSTRAINT ux_domain_event_contracts_module_topic UNIQUE (module_code, event_topic),
        CONSTRAINT chk_domain_event_contracts_key CHECK (btrim(contract_key) <> ''),
        CONSTRAINT chk_domain_event_contracts_domain CHECK (domain_key ~ '^[a-z0-9_]+$'),
        CONSTRAINT chk_domain_event_contracts_topic CHECK (event_topic ~ '^[a-z0-9._]+$'),
        CONSTRAINT chk_domain_event_contracts_version CHECK (btrim(contract_version) <> ''),
        CONSTRAINT chk_domain_event_contracts_surface CHECK (btrim(producer_surface) <> ''),
        CONSTRAINT chk_domain_event_contracts_path CHECK (btrim(artifact_path) <> '')
    );

    CREATE INDEX IF NOT EXISTS ix_domain_delivery_packages_domain_status
        ON domain_delivery_packages (domain_key, package_status, priority_rank);

    CREATE INDEX IF NOT EXISTS ix_domain_delivery_artifacts_domain_layer
        ON domain_delivery_artifacts (domain_key, layer_type, artifact_status);

    CREATE INDEX IF NOT EXISTS ix_domain_event_contracts_domain_module
        ON domain_event_contracts (domain_key, module_code, contract_status);

    DROP TRIGGER IF EXISTS trg_domain_delivery_packages_set_updated_at
        ON domain_delivery_packages;
    CREATE TRIGGER trg_domain_delivery_packages_set_updated_at
    BEFORE UPDATE ON domain_delivery_packages
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

    DROP TRIGGER IF EXISTS trg_domain_delivery_artifacts_set_updated_at
        ON domain_delivery_artifacts;
    CREATE TRIGGER trg_domain_delivery_artifacts_set_updated_at
    BEFORE UPDATE ON domain_delivery_artifacts
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

    DROP TRIGGER IF EXISTS trg_domain_event_contracts_set_updated_at
        ON domain_event_contracts;
    CREATE TRIGGER trg_domain_event_contracts_set_updated_at
    BEFORE UPDATE ON domain_event_contracts
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

    COMMENT ON TABLE domain_delivery_packages IS
        'Registry da primeira onda de pacotes fisicos por dominio, derivado do backlog executavel.';

    COMMENT ON TABLE domain_delivery_artifacts IS
        'Artefatos fisicos por camada: DDL complementar, seed operacional e contrato de evento.';

    COMMENT ON TABLE domain_event_contracts IS
        'Contratos de evento exportados por dominio prioritario para integracao e auditoria.';

    COMMENT ON COLUMN domain_delivery_packages.artifact_manifest_json IS
        'Manifesto consolidado dos artefatos gerados para o dominio.';

    COMMENT ON COLUMN domain_delivery_artifacts.depends_on_keys IS
        'Dependencias internas entre artefatos do mesmo pacote de dominio.';

    COMMENT ON COLUMN domain_event_contracts.payload_schema_json IS
        'JSON Schema pragmatico do evento para produtores e consumidores tecnicos.';

    COMMIT;
    """)


def build_domain_event_contract_json(package: DomainDeliveryPackage) -> str:
    """Exporta o contrato de eventos de um dominio prioritario em JSON."""

    payload = {
        'package_key': package.package_key,
        'domain_key': package.domain_key,
        'domain_label': package.domain_label,
        'priority_rank': package.priority_rank,
        'modules': [
            {
                'module_code': module.code,
                'module_name': module.name,
                'current_phase': module.current_phase,
                'event_topics': [
                    {
                        'contract_key': contract.contract_key,
                        'event_topic': contract.event_topic,
                        'contract_version': contract.contract_version,
                        'producer_surface': contract.producer_surface,
                        'consumer_surfaces': contract.consumer_surfaces,
                        'evidence_entities': contract.evidence_entities,
                        'compliance_tags': contract.compliance_tags,
                        'payload_schema': contract.payload_schema_json,
                    }
                    for contract in package.event_contracts
                    if contract.module_code == module.code
                ],
            }
            for module in package.modules
        ],
    }

    return json.dumps(payload, ensure_ascii=True, indent=2, sort_keys=True) + '\n'


def sync_priority_domain_packages(modules: list[ValleyModule]) -> list[Path]:
    """Gera plano e artefatos fisicos por dominio prioritario."""

    # changed acumula artefatos de pacote efetivamente modificados.
    changed: list[Path] = []

    # packages alimenta os artefatos por camada e o plano consolidado.
    packages = build_priority_domain_packages(modules)

    # Plano consolidado por dominio.
    if write_if_changed(PRIORITY_DOMAIN_PLAN_PATH, build_priority_domain_delivery_plan(modules)):
        changed.append(PRIORITY_DOMAIN_PLAN_PATH)

    # Gera DDL, seed e contrato JSON por dominio.
    for package in packages:
        ddl_path = DOMAIN_DELIVERY_DIR / package.domain_key / 'ddl_complement.sql'
        seed_path = DOMAIN_DELIVERY_DIR / package.domain_key / 'operational_seed.sql'
        contract_path = DOMAIN_EVENT_CONTRACTS_DIR / f'{package.domain_key}.json'

        if write_if_changed(ddl_path, build_domain_delivery_ddl_sql(package)):
            changed.append(ddl_path)

        if write_if_changed(seed_path, build_domain_seed_sql([package])):
            changed.append(seed_path)

        if write_if_changed(contract_path, build_domain_event_contract_json(package)):
            changed.append(contract_path)

    return changed


def module_readme(module: ValleyModule) -> str:
    """Gera README.md operacional de um modulo."""

    # depends_text deixa dependencias legiveis no Markdown.
    depends_text = inline_list(module.depends_on)

    # integrates_text deixa integracoes legiveis no Markdown.
    integrates_text = inline_list(module.integrates_with)

    # lines constroi o Markdown sem depender de dedent com blocos dinamicos.
    lines = [
        f'# {module.number:02d}. {module.name}',
        '',
        'Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.',
        '',
        'Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.',
        '',
        '## Identidade Tecnica',
        '',
        f'- Codigo tecnico: `{module.code}`',
        f'- Subtitulo: `{module.subtitle}`',
        f'- Dominio: `{module.domain}`',
        f'- Tier: `{module.tier}`',
        f'- Data home: `{module.data_home}`',
        f'- Status atual: `{module.status_label}`',
        f'- Fase atual: `{module.current_phase}` ({module.phase_label})',
        f'- Cobertura mapeada: {schema_coverage_label(module)}',
        '',
        '## Finalidade',
        '',
        module.description_ptbr,
        '',
        '## Atores Primarios',
        '',
        bullet_list(module.primary_actors),
        '',
        '## Capacidades-Chave',
        '',
        bullet_list(module.key_capabilities),
        '',
        '## Dependencias',
        '',
        depends_text,
        '',
        '## Integracoes',
        '',
        integrates_text,
        '',
        '## Mapa De Dados',
        '',
        '### PostgreSQL',
        '',
        bullet_list([f'`{value}`' for value in module.postgres_entities]),
        '',
        '### MongoDB',
        '',
        bullet_list([f'`{value}`' for value in module.mongo_collections]),
        '',
        '## Eventos Canonicos',
        '',
        bullet_list([f'`{value}`' for value in module.event_topics]),
        '',
        '## Compliance E Operacao',
        '',
        bullet_list(module.compliance_tags),
        '',
        '## Superficies Admin',
        '',
        bullet_list(module.admin_surfaces),
        '',
        '## Proxima Onda',
        '',
        bullet_list(module.next_deliverables),
        '',
        '## Trilha De Implantacao',
        '',
        '1. Confirmar contrato de dados com `users.user_id` como no central.',
        '2. Definir tabelas PostgreSQL quando houver dinheiro, identidade, contrato, documento ou transacao.',
        '3. Definir colecoes MongoDB quando houver IA, social, telemetria, eventos volumosos ou conteudo semi-estruturado.',
        '4. Registrar regras de negocio em `business_rule_definitions` quando houver pricing, comissao, risco, permissao ou compliance.',
        '5. Atualizar este README, o Manual Online e a vertente PDF a cada mudanca.',
        '',
        '## Criterios De Pronto',
        '',
        '- Schema validado ou justificativa de descarte registrada.',
        '- Integracoes com `PAY`, `ID`, `DOCS`, `ORDERS` ou `TRANSACTIONS` documentadas quando existirem.',
        '- Teste ou validacao tecnica registrada.',
        '- Comentarios em portugues simples com termos tecnicos em ingles onde fizer sentido.',
        '- Blueprint operacional alinhado ao registry detalhado.',
    ]

    return '\n'.join(lines) + '\n'


def module_status(module: ValleyModule) -> str:
    """Gera STATUS.md com checklist evolutivo por modulo."""

    # implemented marca check inicial quando ja existe suporte parcial.
    implemented = module.automation_status in {'implemented_partial', 'implemented'}

    # mark converte booleano em checkbox Markdown.
    mark = 'x' if implemented else ' '

    # has_postgres marca se o blueprint ja mapeou fronteira relacional.
    has_postgres = 'x' if module.postgres_entities else ' '

    # has_mongo marca se o blueprint ja mapeou fronteira volumosa.
    has_mongo = 'x' if module.mongo_collections else ' '

    lines = [
        f'# Status - {module.name}',
        '',
        '- [x] Registry canonico criado.',
        '- [x] Blueprint operacional detalhado registrado.',
        f'- [{mark}] Suporte base de schema ja implantado ou parcialmente implantado.',
        '- [x] Contrato operacional inicial gerado.',
        f'- [{has_postgres}] Fronteira PostgreSQL mapeada.',
        f'- [{has_mongo}] Fronteira MongoDB mapeada.',
        '- [x] Eventos canonicos definidos.',
        '- [x] Fluxos Admin/RBAC/ABAC mapeados.',
        '- [x] Compliance inicial mapeado.',
        '- [ ] Regras de negocio cadastradas ou descartadas em runtime.',
        '- [ ] Testes de integracao planejados.',
        '- [ ] Manual Online atualizado.',
        '- [ ] PDF regenerado.',
        '',
        '## Fase Atual',
        '',
        f'- Codigo: `{module.current_phase}`',
        f'- Leitura simples: {module.phase_label}',
        f'- Cobertura: {schema_coverage_label(module)}',
        '',
        '## Proximos Entregaveis',
        '',
        bullet_list(module.next_deliverables),
        '',
        'Observacao: este status continua vivo e deve evoluir junto com o modulo.',
    ]

    return '\n'.join(lines) + '\n'


def data_home_policy(module: ValleyModule) -> str:
    """Explica a politica de persistencia correta para o modulo."""

    # PostgreSQL e usado para dados transacionais, dinheiro, identidade e contratos.
    if module.data_home == 'postgres':
        # Retorna orientacao objetiva para banco relacional.
        return 'Persistencia principal em PostgreSQL, porque o modulo exige consistencia, `foreign key`, auditoria, dinheiro, contrato ou documento.'

    # MongoDB e usado para alto volume e dados semi-estruturados.
    if module.data_home == 'mongo':
        # Retorna orientacao objetiva para banco NoSQL.
        return 'Persistencia principal em MongoDB, porque o modulo trabalha com IA, social, telemetria, eventos volumosos ou payload semi-estruturado.'

    # postgres_mongo indica fronteira hibrida.
    return 'Persistencia hibrida: PostgreSQL guarda o contrato operacional e MongoDB guarda payload volumoso, IA, social, telemetria ou eventos semi-estruturados.'


def integration_policy(module: ValleyModule) -> str:
    """Monta texto de integracao para dependencias e modulos relacionados."""

    # dependencies contem modulos que precisam existir antes deste modulo evoluir.
    dependencies = inline_list(module.depends_on)

    # integrations contem modulos ou capacidades que conversam com este modulo.
    integrations = inline_list(module.integrates_with)

    # Retorna frase padronizada para contratos.
    return f'Dependencias minimas: {dependencies}. Integracoes previstas: {integrations}.'


def module_contract(module: ValleyModule) -> str:
    """Gera CONTRACT.md com fronteira tecnica de um modulo."""

    # postgres_anchor deixa claro como qualquer tabela futura deve ligar ao core.
    postgres_anchor = '`users.user_id` deve ser a primeira integracao relacional quando houver usuario, empresa, rider, admin ou system actor.'

    # wallet_anchor orienta modulos que tocam dinheiro ou saldo.
    wallet_anchor = '`wallets.wallet_id` e `transactions.transaction_id` devem ser usados quando houver dinheiro, saldo, pagamento, repasse, refund, fee, split ou escrow.'

    # mongo_anchor orienta modulos com dados de alto volume.
    mongo_anchor = '`user_id` em MongoDB deve ser string UUID validada por regex para manter ponte segura com PostgreSQL.'

    lines = [
        f'# Contrato Operacional - {module.number:02d}. {module.name}',
        '',
        'Este arquivo e gerado pela automacao `scripts/automacao_sincronizador_modulos.py`.',
        '',
        'Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.',
        '',
        '## Identidade Do Modulo',
        '',
        f'- Codigo tecnico: `{module.code}`',
        f'- Dominio: `{module.domain}`',
        f'- Tier: `{module.tier}`',
        f'- Data home: `{module.data_home}`',
        f'- Status atual: `{module.status_label}`',
        f'- Fase atual: `{module.current_phase}` ({module.phase_label})',
        '',
        '## Objetivo Simples',
        '',
        module.description_ptbr,
        '',
        '## Politica De Dados',
        '',
        data_home_policy(module),
        '',
        postgres_anchor,
        '',
        wallet_anchor,
        '',
        mongo_anchor,
        '',
        '## Integracoes',
        '',
        integration_policy(module),
        '',
        '## Atores Primarios',
        '',
        bullet_list(module.primary_actors),
        '',
        '## Capacidades-Chave',
        '',
        bullet_list(module.key_capabilities),
        '',
        '## Entidades Relacionais',
        '',
        bullet_list([f'`{value}`' for value in module.postgres_entities]),
        '',
        '## Payloads Volumosos E Colecoes',
        '',
        bullet_list([f'`{value}`' for value in module.mongo_collections]),
        '',
        '## Eventos Canonicos',
        '',
        bullet_list([f'`{value}`' for value in module.event_topics]),
        '',
        '## Compliance, Risco E Guarda',
        '',
        bullet_list(module.compliance_tags),
        '',
        '## Superficies Admin E Operacao',
        '',
        bullet_list(module.admin_surfaces),
        '',
        '## Regras De Evolucao',
        '',
        '1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.',
        '2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.',
        '3. Usar `UUID` para chaves e referencias quando o dado for relacional.',
        '4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `V-Coin`.',
        '5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.',
        '6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.',
        '7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.',
        '',
        '## Primeiro Backlog Tecnico',
        '',
        bullet_list(module.next_deliverables),
    ]

    return '\n'.join(lines) + '\n'


def contracts_summary(modules: list[ValleyModule]) -> str:
    """Gera matriz consolidada dos contratos dos 47 modulos."""

    # lines inicia o documento com proposito e regra central.
    lines = [
        '# Matriz De Contratos Operacionais - Valley V47',
        '',
        'Este arquivo e gerado por `scripts/automacao_sincronizador_modulos.py`.',
        '',
        'A matriz resume a fronteira tecnica dos 47 modulos para orientar desenvolvimento continuo.',
        '',
        '| No | Codigo | Modulo | Tier | Fase | Data home | Compliance |',
        '|---:|---|---|---|---|---|---|',
    ]

    # Percorre modulos ordenados para saida deterministica.
    for module in sorted(modules, key=lambda item: item.number):
        # compliance_text consolida os tags mais importantes da trilha.
        compliance_text = inline_list(module.compliance_tags)

        # Adiciona linha de matriz.
        lines.append(f'| {module.number:02d} | `{module.code}` | {module.name} | `{module.tier}` | `{module.current_phase}` | `{module.data_home}` | {compliance_text} |')

    # Adiciona regra operacional comum.
    lines.extend([
        '',
        '## Regra Comum',
        '',
        'Todo modulo que tocar usuario, empresa, rider, admin ou system actor deve integrar `public.users.user_id`.',
        '',
        'Todo modulo que tocar dinheiro deve integrar `wallets`, `transactions` ou ledger especifico append-only.',
        '',
        'Todo modulo que tocar IA, social, telemetria ou payload volumoso deve manter apenas ponte segura com UUID e guardar o volume no MongoDB ou backend especializado.',
        '',
        'Toda evolucao detalhada deve manter fase, atores, entidades, eventos, compliance e backlog imediato sincronizados no registry canonico.',
        '',
    ])

    # Retorna Markdown final.
    return '\n'.join(lines)


def write_if_changed(path: Path, content: str) -> bool:
    """Escreve arquivo apenas quando o conteudo muda."""

    # Garante que a pasta exista antes da escrita.
    path.parent.mkdir(parents=True, exist_ok=True)

    # Se o arquivo ja existe com o mesmo conteudo, nao toca no timestamp.
    if path.exists() and path.read_text(encoding='utf-8') == content:
        # False indica que nada mudou.
        return False

    # Escreve conteudo em UTF-8 para preservar PT-BR.
    path.write_text(content, encoding='utf-8')

    # True indica arquivo criado ou atualizado.
    return True


def sync_modules(modules: list[ValleyModule]) -> list[Path]:
    """Gera pastas e documentos por modulo."""

    # changed guarda arquivos efetivamente criados ou modificados.
    changed: list[Path] = []

    # Percorre todos os modulos do registry.
    for module in modules:
        # module_dir e a pasta canonica do modulo.
        module_dir = MODULES_DIR / module.slug

        # readme_path aponta para a documentacao principal do modulo.
        readme_path = module_dir / 'README.md'

        # status_path aponta para o checklist de evolucao.
        status_path = module_dir / 'STATUS.md'

        # contract_path aponta para o contrato operacional inicial.
        contract_path = module_dir / 'CONTRACT.md'

        # Escreve README se houver mudanca.
        if write_if_changed(readme_path, module_readme(module)):
            # Registra que o README foi sincronizado.
            changed.append(readme_path)

        # Escreve STATUS se houver mudanca.
        if write_if_changed(status_path, module_status(module)):
            # Registra que o STATUS foi sincronizado.
            changed.append(status_path)

        # Escreve CONTRACT se houver mudanca.
        if write_if_changed(contract_path, module_contract(module)):
            # Registra que o contrato foi sincronizado.
            changed.append(contract_path)

    # Gera indice consolidado de modulos.
    index_path = MODULES_DIR / 'INDEX.md'

    # Escreve indice e captura mudanca se houver.
    if write_if_changed(index_path, modules_index(modules)):
        # Registra INDEX.md como sincronizado.
        changed.append(index_path)

    # Retorna lista de arquivos alterados.
    return changed


def sync_contracts(modules: list[ValleyModule]) -> list[Path]:
    """Sincroniza somente contratos por modulo e matriz consolidada."""

    # changed guarda arquivos criados ou atualizados.
    changed: list[Path] = []

    # Percorre os modulos para gerar CONTRACT.md sem tocar README/STATUS.
    for module in modules:
        # module_dir e a pasta canonica.
        module_dir = MODULES_DIR / module.slug

        # contract_path aponta para o contrato operacional.
        contract_path = module_dir / 'CONTRACT.md'

        # Escreve contrato se mudou.
        if write_if_changed(contract_path, module_contract(module)):
            # Registra mudanca.
            changed.append(contract_path)

    # Escreve matriz consolidada.
    if write_if_changed(CONTRACTS_SUMMARY_PATH, contracts_summary(modules)):
        # Registra mudanca.
        changed.append(CONTRACTS_SUMMARY_PATH)

    # Retorna arquivos alterados.
    return changed


def modules_index(modules: list[ValleyModule]) -> str:
    """Gera indice Markdown dos 47 modulos."""

    # lines inicia o documento com contexto operacional.
    lines = [
        '# Indice Automatizado Dos 47 Modulos Valley',
        '',
        'Este indice e gerado por `scripts/automacao_sincronizador_modulos.py`.',
        '',
        'A saida e deterministica para evitar ruido em automacoes recorrentes.',
        '',
        '| No | Codigo | Modulo | Dominio | Tier | Fase | Data home | Status |',
        '|---:|---|---|---|---|---|---|---|',
    ]

    # Adiciona uma linha por modulo.
    for module in modules:
        # Cada linha conecta numero, codigo e status do modulo.
        lines.append(f'| {module.number:02d} | `{module.code}` | {module.name} | `{module.domain}` | `{module.tier}` | `{module.current_phase}` | `{module.data_home}` | {module.status_label} |')

    # Retorna Markdown final.
    return '\n'.join(lines) + '\n'


def build_roadmap(modules: list[ValleyModule]) -> str:
    """Gera roadmap consolidado de implantacao e evolucao."""

    # Agrupa modulos por tier para orientar prioridade.
    by_tier: dict[str, list[ValleyModule]] = {}

    # Popula dicionario por tier.
    for module in modules:
        # setdefault cria a lista quando a chave ainda nao existe.
        by_tier.setdefault(module.tier, []).append(module)

    # lines inicia o roadmap com decisao arquitetural.
    lines = [
        '# Roadmap Automatizado - Valley Omniverse V47',
        '',
        'Este arquivo e gerado de forma deterministica por `scripts/automacao_sincronizador_modulos.py`.',
        '',
        'Este roadmap automatiza a evolucao dos 47 modulos a partir do registry `config/modules_v47.json`.',
        '',
        'Regra central: tudo que envolve dinheiro, identidade, contratos e documentos vai para PostgreSQL; IA, social, telemetria e alto volume vao para MongoDB ou backend especializado.',
        '',
        '## Cobertura Atual',
        '',
    ]

    # phase_counts resume em que fase a carteira inteira se encontra.
    phase_counts: dict[str, int] = {}
    for module in modules:
        phase_counts[module.current_phase] = phase_counts.get(module.current_phase, 0) + 1

    # Imprime resumo por fase antes da fila de prioridade.
    for phase_code in ['DISCOVERY', 'DATA_CONTRACT', 'BUILD', 'VALIDATE', 'DOCUMENT', 'RELEASE', 'EVOLVE']:
        count = phase_counts.get(phase_code, 0)
        if count:
            lines.append(f'- `{phase_code}`: {count} modulos.')

    # Linha em branco separa resumo do backlog principal.
    lines.extend(['', '## Ordem De Prioridade', ''])
    # Ordem intencional: fundacao antes de expansao.
    for tier in ['foundation', 'core', 'expansion', 'frontier']:
        # modules_for_tier pega modulos daquele tier.
        modules_for_tier = sorted(by_tier.get(tier, []), key=lambda item: item.number)

        # Ignora tier vazio.
        if not modules_for_tier:
            continue

        # Adiciona titulo de tier.
        lines.append(f'### {tier}')
        lines.append('')

        # Adiciona cada modulo do tier com proxima acao.
        for module in modules_for_tier:
            # next_action aponta para o primeiro entregavel explicito do modulo.
            next_action = module.next_deliverables[0]
            # Registra uma linha acionavel.
            lines.append(f'- `{module.code}` - {module.name}: fase `{module.current_phase}`, data home `{module.data_home}`, proxima entrega: {next_action}.')

        # Linha vazia entre tiers.
        lines.append('')

    # Adiciona backlog macro.
    lines.extend([
        '## Backlog Evolutivo Padrao',
        '',
        '1. Validar dependencias e data home do modulo.',
        '2. Revisar `modules/<modulo>/CONTRACT.md` antes de escrever schema ou codigo.',
        '3. Criar ou revisar schema PostgreSQL/MongoDB.',
        '4. Criar regras de negocio em `business_rule_definitions` quando houver pricing, comissao, risco ou compliance.',
        '5. Atualizar `modules/<modulo>/README.md`, `STATUS.md`, `CONTRACT.md` e o blueprint canonico.',
        '6. Atualizar Manual Online e regenerar PDF.',
        '7. Registrar descarte quando a ideia for inviavel, insegura ou duplicada.',
        '',
    ])

    # Retorna roadmap final.
    return '\n'.join(lines)


def build_domain_execution_backlog(modules: list[ValleyModule]) -> str:
    """Gera backlog executavel agrupado por dominio."""

    # items expande entregaveis por modulo para linhas operacionais.
    items = build_execution_backlog_items(modules)

    # by_domain agrupa a fila acionavel por familia arquitetural.
    by_domain: dict[str, list[ExecutionBacklogItem]] = {}
    for item in items:
        by_domain.setdefault(item.module_domain, []).append(item)

    # lines inicia o documento com proposito operacional.
    lines = [
        '# Backlog Executavel Por Dominio - Valley V47',
        '',
        'Este arquivo e gerado por `scripts/automacao_sincronizador_modulos.py`.',
        '',
        'Ele transforma os blueprints dos 47 modulos em fila acionavel, com prioridade, dependencia interna e evidencias tecnicas esperadas.',
        '',
        f'- Total de itens executaveis: {len(items)}.',
        f'- Total de dominios: {len(by_domain)}.',
        '',
    ]

    # Ordem deterministica por dominio para evitar ruido.
    for domain in sorted(by_domain):
        domain_items = sorted(by_domain[domain], key=lambda item: (item.priority, item.module_number, item.backlog_key))

        lines.extend([
            f'## {domain_label(domain)}',
            '',
            f'- Dominio tecnico: `{domain}`',
            f'- Itens: {len(domain_items)}',
            '',
            '| Prio | Key | Modulo | Fase | Data home | Depende de | Entrega |',
            '|---:|---|---|---|---|---|---|',
        ])

        for item in domain_items:
            depends_text = inline_list(item.depends_on_keys)
            lines.append(
                f'| {item.priority} | `{item.backlog_key}` | `{item.module_code}` | '
                f'`{item.execution_stage}` | `{item.target_data_home}` | {depends_text} | {item.title} |'
            )

        lines.extend([
            '',
            '### Evidencias Esperadas',
            '',
        ])

        for item in domain_items:
            lines.append(f'- `{item.backlog_key}`: {item.evidence_hint}')

        lines.append('')

    return '\n'.join(lines)


def sync_roadmap(modules: list[ValleyModule]) -> list[Path]:
    """Gera roadmap consolidado em output/module-roadmap."""

    # changed guarda arquivos modificados.
    changed: list[Path] = []

    # roadmap_path aponta para o Markdown principal de roadmap.
    roadmap_path = ROADMAP_DIR / 'VALLEY_MODULE_ROADMAP.md'

    # Escreve roadmap se houver mudanca.
    if write_if_changed(roadmap_path, build_roadmap(modules)):
        # Registra roadmap como alterado.
        changed.append(roadmap_path)

    # execution_backlog_path aponta para a fila acionavel por dominio.
    execution_backlog_path = EXECUTION_BACKLOG_PATH

    # Escreve backlog executavel se houver mudanca.
    if write_if_changed(execution_backlog_path, build_domain_execution_backlog(modules)):
        changed.append(execution_backlog_path)

    # Retorna arquivos alterados.
    return changed


def sql_literal(value: str | None) -> str:
    """Converte texto Python em literal SQL seguro para arquivo gerado."""

    # NULL e usado quando nao ha valor textual.
    if value is None:
        # Retorna NULL sem aspas porque e palavra-chave SQL.
        return 'NULL'

    # Escapa aspas simples duplicando, conforme regra SQL.
    escaped = value.replace("'", "''")

    # Retorna valor entre aspas simples.
    return f"'{escaped}'"


def sql_array(values: list[str]) -> str:
    """Converte lista de strings em ARRAY SQL de TEXT."""

    # Sem valores, retorna array vazio tipado como TEXT[].
    if not values:
        # Cast explicito evita ambiguidade no PostgreSQL.
        return 'ARRAY[]::TEXT[]'

    # Converte cada item em literal SQL.
    literals = ', '.join(sql_literal(value) for value in values)

    # Retorna ARRAY tipado para dependencias e integracoes.
    return f'ARRAY[{literals}]::TEXT[]'


def sql_json(value: dict) -> str:
    """Converte dict Python em literal JSONB SQL deterministico."""

    # raw serializa com chaves ordenadas para evitar ruido de diff.
    raw = json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(',', ':'))

    # Escapa aspas simples para SQL.
    return sql_literal(raw) + '::JSONB'


def build_delivery_sql(modules: list[ValleyModule]) -> str:
    """Gera migration SQL para automacao de delivery dos 47 modulos."""

    # values_lines recebe uma linha INSERT por modulo.
    values_lines = []

    # execution_items expande backlog acionavel por entregavel.
    execution_items = build_execution_backlog_items(modules)

    # backlog_values_lines recebe uma linha INSERT por item executavel.
    backlog_values_lines = []

    # Percorre modulos em ordem numerica para SQL deterministico.
    for module in sorted(modules, key=lambda item: item.number):
        # blueprint_json consolida a evolucao rica do modulo no registry relacional.
        blueprint_json = sql_json(module_blueprint_payload(module))

        # Cada linha registra o estado inicial do modulo no delivery registry.
        values_lines.append(
            '    ('
            f'{module.number}, '
            f'{sql_literal(module.code)}, '
            f'{sql_literal(module.name)}, '
            f'{sql_literal(module.subtitle)}, '
            f'{sql_literal(module.domain)}, '
            f'{sql_literal(module.tier)}, '
            f'{sql_literal(module.data_home)}, '
            f'{sql_literal(module.automation_status.upper())}, '
            f'{sql_literal(module.current_phase)}, '
            f'{sql_array(module.depends_on)}, '
            f'{sql_array(module.integrates_with)}, '
            f'{sql_literal(module.description_ptbr)}, '
            f'{blueprint_json}'
            ')'
        )

    # Percorre itens acionaveis para gerar seed do backlog.
    for item in execution_items:
        backlog_values_lines.append(
            '    ('
            f'{sql_literal(item.backlog_key)}, '
            f'{sql_literal(item.module_code)}, '
            f'{sql_literal(item.module_domain)}, '
            f'{sql_literal(item.execution_stage)}, '
            f'{sql_literal(item.target_data_home)}, '
            f"{sql_literal('blueprint_execution_v1')}, "
            f'{item.priority}, '
            f'{sql_literal(item.title)}, '
            f'{sql_literal(item.description_ptbr)}, '
            f'{sql_literal(item.acceptance_criteria)}, '
            f'{sql_array(item.depends_on_keys)}, '
            f'{sql_literal(item.evidence_hint)}'
            ')'
        )

    # values_sql junta as linhas com virgula, como exige INSERT multi-row.
    values_sql = ',\n'.join(values_lines)

    # backlog_values_sql junta seed executavel do backlog.
    backlog_values_sql = ',\n'.join(backlog_values_lines)

    # Retorna SQL completo com comentarios em portugues.
    return dedent(f"""\
    -- Valley Hybrid DB Bootstrap - Automacao de delivery dos 47 modulos.
    -- Este arquivo e gerado por scripts/automacao_sincronizador_modulos.py a partir de config/modules_v47.json e config/modules_v47_blueprints.json.
    -- Ele persiste o estado de implantacao, desenvolvimento e evolucao dos modulos no PostgreSQL.
    -- Execute depois de 001, 002, 004 e 005.

    BEGIN;

    SET search_path = public;

    CREATE TYPE module_delivery_phase_enum AS ENUM ('DISCOVERY', 'DATA_CONTRACT', 'BUILD', 'VALIDATE', 'DOCUMENT', 'RELEASE', 'EVOLVE');
    CREATE TYPE module_delivery_status_enum AS ENUM ('PLANNED', 'IMPLEMENTED_PARTIAL', 'IMPLEMENTED', 'BLOCKED', 'DISCARDED');
    CREATE TYPE module_backlog_status_enum AS ENUM ('OPEN', 'IN_PROGRESS', 'DONE', 'DISCARDED');

    CREATE TABLE module_delivery_registry (
        module_delivery_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        owner_user_id UUID,
        module_number SMALLINT NOT NULL,
        module_code TEXT NOT NULL UNIQUE,
        module_name TEXT NOT NULL,
        subtitle TEXT,
        domain TEXT NOT NULL,
        tier TEXT NOT NULL,
        data_home TEXT NOT NULL,
        delivery_status module_delivery_status_enum NOT NULL DEFAULT 'PLANNED',
        current_phase module_delivery_phase_enum NOT NULL DEFAULT 'DISCOVERY',
        depends_on TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        integrates_with TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        description_ptbr TEXT NOT NULL,
        module_blueprint_json JSONB NOT NULL DEFAULT '{{}}'::JSONB,
        automation_policy_json JSONB NOT NULL DEFAULT '{{"manual_confirmation_required":false,"update_manual":true,"regenerate_pdf":true}}'::JSONB,
        last_automation_run_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_module_delivery_registry_owner
            FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
            ON UPDATE CASCADE
            ON DELETE SET NULL,
        CONSTRAINT ux_module_delivery_registry_number UNIQUE (module_number),
        CONSTRAINT chk_module_delivery_registry_number CHECK (module_number BETWEEN 1 AND 47),
        CONSTRAINT chk_module_delivery_registry_code CHECK (module_code ~ '^[A-Z0-9_]+$'),
        CONSTRAINT chk_module_delivery_registry_name CHECK (btrim(module_name) <> ''),
        CONSTRAINT chk_module_delivery_registry_data_home CHECK (data_home IN ('postgres', 'mongo', 'postgres_mongo'))
    );

    CREATE TABLE module_evolution_backlog (
        module_backlog_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        owner_user_id UUID,
        backlog_key TEXT NOT NULL UNIQUE,
        module_code TEXT NOT NULL,
        backlog_group TEXT NOT NULL DEFAULT 'module_execution',
        execution_stage module_delivery_phase_enum NOT NULL DEFAULT 'DISCOVERY',
        target_data_home TEXT NOT NULL DEFAULT 'postgres',
        origin_source TEXT NOT NULL DEFAULT 'registry_bootstrap',
        backlog_status module_backlog_status_enum NOT NULL DEFAULT 'OPEN',
        priority SMALLINT NOT NULL DEFAULT 3,
        title TEXT NOT NULL,
        description_ptbr TEXT NOT NULL,
        acceptance_criteria TEXT NOT NULL,
        depends_on_keys TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
        evidence_hint TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        CONSTRAINT fk_module_evolution_backlog_owner
            FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
            ON UPDATE CASCADE
            ON DELETE SET NULL,
        CONSTRAINT fk_module_evolution_backlog_module
            FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
            ON UPDATE CASCADE
            ON DELETE RESTRICT,
        CONSTRAINT chk_module_evolution_backlog_key CHECK (btrim(backlog_key) <> ''),
        CONSTRAINT chk_module_evolution_backlog_priority CHECK (priority BETWEEN 1 AND 5),
        CONSTRAINT chk_module_evolution_backlog_title CHECK (btrim(title) <> ''),
        CONSTRAINT chk_module_evolution_backlog_description CHECK (btrim(description_ptbr) <> ''),
        CONSTRAINT chk_module_evolution_backlog_acceptance CHECK (btrim(acceptance_criteria) <> ''),
        CONSTRAINT chk_module_evolution_backlog_data_home CHECK (target_data_home IN ('postgres', 'mongo', 'postgres_mongo'))
    );

    CREATE TABLE module_automation_runs (
        module_run_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        owner_user_id UUID,
        module_code TEXT,
        run_kind TEXT NOT NULL,
        run_status TEXT NOT NULL,
        summary_ptbr TEXT NOT NULL,
        artifacts_json JSONB NOT NULL DEFAULT '[]'::JSONB,
        started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        finished_at TIMESTAMPTZ,
        CONSTRAINT fk_module_automation_runs_owner
            FOREIGN KEY (owner_user_id) REFERENCES users (user_id)
            ON UPDATE CASCADE
            ON DELETE SET NULL,
        CONSTRAINT fk_module_automation_runs_module
            FOREIGN KEY (module_code) REFERENCES module_delivery_registry (module_code)
            ON UPDATE CASCADE
            ON DELETE SET NULL,
        CONSTRAINT chk_module_automation_runs_kind CHECK (btrim(run_kind) <> ''),
        CONSTRAINT chk_module_automation_runs_status CHECK (run_status IN ('STARTED', 'SUCCESS', 'FAILED', 'SKIPPED')),
        CONSTRAINT chk_module_automation_runs_summary CHECK (btrim(summary_ptbr) <> ''),
        CONSTRAINT chk_module_automation_runs_timeline CHECK (finished_at IS NULL OR finished_at >= started_at)
    );

    CREATE INDEX ix_module_delivery_registry_status_phase
        ON module_delivery_registry (delivery_status, current_phase);

    CREATE INDEX ix_module_delivery_registry_domain_tier
        ON module_delivery_registry (domain, tier);

    CREATE INDEX ix_module_evolution_backlog_module_status
        ON module_evolution_backlog (module_code, backlog_status, priority);

    CREATE INDEX ix_module_evolution_backlog_group_status
        ON module_evolution_backlog (backlog_group, backlog_status, priority);

    CREATE INDEX ix_module_automation_runs_module_started_at
        ON module_automation_runs (module_code, started_at);

    CREATE TRIGGER trg_module_delivery_registry_set_updated_at
    BEFORE UPDATE ON module_delivery_registry
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

    CREATE TRIGGER trg_module_evolution_backlog_set_updated_at
    BEFORE UPDATE ON module_evolution_backlog
    FOR EACH ROW
    EXECUTE FUNCTION set_updated_at();

    INSERT INTO module_delivery_registry (
        module_number,
        module_code,
        module_name,
        subtitle,
        domain,
        tier,
        data_home,
        delivery_status,
        current_phase,
        depends_on,
        integrates_with,
        description_ptbr,
        module_blueprint_json
    ) VALUES
    {values_sql}
    ON CONFLICT (module_code) DO UPDATE SET
        module_number = EXCLUDED.module_number,
        module_name = EXCLUDED.module_name,
        subtitle = EXCLUDED.subtitle,
        domain = EXCLUDED.domain,
        tier = EXCLUDED.tier,
        data_home = EXCLUDED.data_home,
        delivery_status = EXCLUDED.delivery_status,
        current_phase = EXCLUDED.current_phase,
        depends_on = EXCLUDED.depends_on,
        integrates_with = EXCLUDED.integrates_with,
        description_ptbr = EXCLUDED.description_ptbr,
        module_blueprint_json = EXCLUDED.module_blueprint_json,
        updated_at = NOW();

    INSERT INTO module_evolution_backlog (
        backlog_key,
        module_code,
        backlog_group,
        execution_stage,
        target_data_home,
        origin_source,
        priority,
        title,
        description_ptbr,
        acceptance_criteria,
        depends_on_keys,
        evidence_hint
    ) VALUES
    {backlog_values_sql}
    ON CONFLICT (backlog_key) DO UPDATE SET
        module_code = EXCLUDED.module_code,
        backlog_group = EXCLUDED.backlog_group,
        execution_stage = EXCLUDED.execution_stage,
        target_data_home = EXCLUDED.target_data_home,
        origin_source = EXCLUDED.origin_source,
        priority = EXCLUDED.priority,
        title = EXCLUDED.title,
        description_ptbr = EXCLUDED.description_ptbr,
        acceptance_criteria = EXCLUDED.acceptance_criteria,
        depends_on_keys = EXCLUDED.depends_on_keys,
        evidence_hint = EXCLUDED.evidence_hint,
        updated_at = NOW();

    COMMENT ON TYPE module_delivery_phase_enum IS 'Fase atual da esteira de desenvolvimento do modulo.';
    COMMENT ON TYPE module_delivery_status_enum IS 'Status macro de implantacao do modulo.';
    COMMENT ON TYPE module_backlog_status_enum IS 'Status de item do backlog evolutivo.';
    COMMENT ON TABLE module_delivery_registry IS 'Registro canonico dos 47 modulos para automatizar implantacao, desenvolvimento e evolucao.';
    COMMENT ON TABLE module_evolution_backlog IS 'Backlog executavel por modulo e dominio, gerado a partir do registry canonico.';
    COMMENT ON TABLE module_automation_runs IS 'Historico de execucoes da automacao de modulos.';
    COMMENT ON COLUMN module_delivery_registry.owner_user_id IS 'FK opcional para users.user_id quando houver responsavel humano ou system user.';
    COMMENT ON COLUMN module_delivery_registry.module_code IS 'Codigo tecnico do modulo usado por scripts, regras e roadmap.';
    COMMENT ON COLUMN module_delivery_registry.module_blueprint_json IS 'Blueprint canonico do modulo com atores, entidades, eventos, compliance e backlog imediato.';
    COMMENT ON COLUMN module_delivery_registry.automation_policy_json IS 'Politica da automacao: atualizar manual, PDF e evitar confirmacoes manuais.';
    COMMENT ON COLUMN module_evolution_backlog.backlog_key IS 'Chave deterministica do item executavel para permitir upsert seguro.';
    COMMENT ON COLUMN module_evolution_backlog.backlog_group IS 'Grupo executavel, normalmente igual ao dominio tecnico do modulo.';
    COMMENT ON COLUMN module_evolution_backlog.execution_stage IS 'Fase da esteira em que o item deve ser trabalhado.';
    COMMENT ON COLUMN module_evolution_backlog.depends_on_keys IS 'Dependencias internas do backlog em chaves deterministicas.';
    COMMENT ON COLUMN module_evolution_backlog.evidence_hint IS 'Indicacao objetiva de onde validar a entrega.';
    COMMENT ON COLUMN module_evolution_backlog.acceptance_criteria IS 'Criterio objetivo para concluir o item de evolucao.';
    COMMENT ON COLUMN module_automation_runs.artifacts_json IS 'Arquivos e evidencias geradas pela automacao.';

    COMMIT;
    """)


def build_blueprint_registry_patch_sql(modules: list[ValleyModule]) -> str:
    """Gera migration incremental para adicionar blueprint JSON no registry existente."""

    # values_lines recebe pares modulo/fase/json para update deterministico.
    values_lines = []

    # Monta payload ordenado por numero para gerar SQL estavel.
    for module in sorted(modules, key=lambda item: item.number):
        values_lines.append(
            '    ('
            f'{sql_literal(module.code)}, '
            f'{sql_literal(module.current_phase)}, '
            f'{sql_json(module_blueprint_payload(module))}'
            ')'
        )

    # values_sql vira a tabela virtual da migration incremental.
    values_sql = ',\n'.join(values_lines)

    return dedent(f"""\
    -- Valley Hybrid DB Patch - Blueprints detalhados dos 47 modulos.
    -- Este arquivo e gerado por scripts/automacao_sincronizador_modulos.py.
    -- Ele evolui module_delivery_registry sem recriar a tabela existente.

    BEGIN;

    SET search_path = public;

    ALTER TABLE module_delivery_registry
        ADD COLUMN IF NOT EXISTS module_blueprint_json JSONB NOT NULL DEFAULT '{{}}'::JSONB;

    WITH blueprint_source (module_code, current_phase, module_blueprint_json) AS (
    VALUES
    {values_sql}
    )
    UPDATE module_delivery_registry AS target
    SET
        current_phase = blueprint_source.current_phase::module_delivery_phase_enum,
        module_blueprint_json = blueprint_source.module_blueprint_json,
        updated_at = NOW()
    FROM blueprint_source
    WHERE target.module_code = blueprint_source.module_code;

    COMMENT ON COLUMN module_delivery_registry.module_blueprint_json IS 'Blueprint canonico do modulo com atores, entidades, eventos, compliance e backlog imediato.';

    COMMIT;
    """)


def build_execution_backlog_patch_sql(modules: list[ValleyModule]) -> str:
    """Gera migration incremental para backlog executavel no registry existente."""

    # items expande o backlog acionavel a partir do blueprint canonico.
    items = build_execution_backlog_items(modules)

    # values_lines recebe seed deterministico para upsert por backlog_key.
    values_lines = []

    for item in items:
        values_lines.append(
            '    ('
            f'{sql_literal(item.backlog_key)}, '
            f'{sql_literal(item.module_code)}, '
            f'{sql_literal(item.module_domain)}, '
            f'{sql_literal(item.execution_stage)}, '
            f'{sql_literal(item.target_data_home)}, '
            f"{sql_literal('blueprint_execution_v1')}, "
            f'{item.priority}, '
            f'{sql_literal(item.title)}, '
            f'{sql_literal(item.description_ptbr)}, '
            f'{sql_literal(item.acceptance_criteria)}, '
            f'{sql_array(item.depends_on_keys)}, '
            f'{sql_literal(item.evidence_hint)}'
            ')'
        )

    # values_sql vira tabela virtual para upsert deterministico.
    values_sql = ',\n'.join(values_lines)

    return dedent(f"""\
    -- Valley Hybrid DB Patch - Backlog executavel dos 47 modulos.
    -- Este arquivo e gerado por scripts/automacao_sincronizador_modulos.py.
    -- Ele evolui module_evolution_backlog para uma fila acionavel por dominio.

    BEGIN;

    SET search_path = public;

    ALTER TABLE module_evolution_backlog
        ADD COLUMN IF NOT EXISTS backlog_key TEXT;

    ALTER TABLE module_evolution_backlog
        ADD COLUMN IF NOT EXISTS backlog_group TEXT;

    ALTER TABLE module_evolution_backlog
        ADD COLUMN IF NOT EXISTS execution_stage module_delivery_phase_enum;

    ALTER TABLE module_evolution_backlog
        ADD COLUMN IF NOT EXISTS target_data_home TEXT;

    ALTER TABLE module_evolution_backlog
        ADD COLUMN IF NOT EXISTS origin_source TEXT;

    ALTER TABLE module_evolution_backlog
        ADD COLUMN IF NOT EXISTS depends_on_keys TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

    ALTER TABLE module_evolution_backlog
        ADD COLUMN IF NOT EXISTS evidence_hint TEXT;

    UPDATE module_evolution_backlog AS backlog
    SET
        backlog_key = COALESCE(backlog.backlog_key, 'legacy:' || backlog.module_backlog_id::TEXT),
        backlog_group = COALESCE(backlog.backlog_group, registry.domain),
        execution_stage = COALESCE(backlog.execution_stage, registry.current_phase),
        target_data_home = COALESCE(backlog.target_data_home, registry.data_home),
        origin_source = COALESCE(backlog.origin_source, 'legacy_registry_seed'),
        evidence_hint = COALESCE(backlog.evidence_hint, 'Registro legado sem chave deterministica.')
    FROM module_delivery_registry AS registry
    WHERE registry.module_code = backlog.module_code;

    ALTER TABLE module_evolution_backlog
        ALTER COLUMN backlog_key SET NOT NULL;

    ALTER TABLE module_evolution_backlog
        ALTER COLUMN backlog_group SET NOT NULL;

    ALTER TABLE module_evolution_backlog
        ALTER COLUMN execution_stage SET NOT NULL;

    ALTER TABLE module_evolution_backlog
        ALTER COLUMN target_data_home SET NOT NULL;

    ALTER TABLE module_evolution_backlog
        ALTER COLUMN origin_source SET NOT NULL;

    CREATE UNIQUE INDEX IF NOT EXISTS ux_module_evolution_backlog_key
        ON module_evolution_backlog (backlog_key);

    CREATE INDEX IF NOT EXISTS ix_module_evolution_backlog_group_status
        ON module_evolution_backlog (backlog_group, backlog_status, priority);

    WITH execution_source (
        backlog_key,
        module_code,
        backlog_group,
        execution_stage,
        target_data_home,
        origin_source,
        priority,
        title,
        description_ptbr,
        acceptance_criteria,
        depends_on_keys,
        evidence_hint
    ) AS (
    VALUES
    {values_sql}
    )
    INSERT INTO module_evolution_backlog (
        backlog_key,
        module_code,
        backlog_group,
        execution_stage,
        target_data_home,
        origin_source,
        priority,
        title,
        description_ptbr,
        acceptance_criteria,
        depends_on_keys,
        evidence_hint
    )
    SELECT
        backlog_key,
        module_code,
        backlog_group,
        execution_stage::module_delivery_phase_enum,
        target_data_home,
        origin_source,
        priority,
        title,
        description_ptbr,
        acceptance_criteria,
        depends_on_keys,
        evidence_hint
    FROM execution_source
    ON CONFLICT (backlog_key) DO UPDATE SET
        module_code = EXCLUDED.module_code,
        backlog_group = EXCLUDED.backlog_group,
        execution_stage = EXCLUDED.execution_stage,
        target_data_home = EXCLUDED.target_data_home,
        origin_source = EXCLUDED.origin_source,
        priority = EXCLUDED.priority,
        title = EXCLUDED.title,
        description_ptbr = EXCLUDED.description_ptbr,
        acceptance_criteria = EXCLUDED.acceptance_criteria,
        depends_on_keys = EXCLUDED.depends_on_keys,
        evidence_hint = EXCLUDED.evidence_hint,
        updated_at = NOW();

    COMMENT ON TABLE module_evolution_backlog IS 'Backlog executavel por modulo e dominio, gerado a partir do registry canonico.';
    COMMENT ON COLUMN module_evolution_backlog.backlog_key IS 'Chave deterministica do item executavel para permitir upsert seguro.';
    COMMENT ON COLUMN module_evolution_backlog.backlog_group IS 'Grupo executavel, normalmente igual ao dominio tecnico do modulo.';
    COMMENT ON COLUMN module_evolution_backlog.execution_stage IS 'Fase da esteira em que o item deve ser trabalhado.';
    COMMENT ON COLUMN module_evolution_backlog.depends_on_keys IS 'Dependencias internas do backlog em chaves deterministicas.';
    COMMENT ON COLUMN module_evolution_backlog.evidence_hint IS 'Indicacao objetiva de onde validar a entrega.';

    COMMIT;
    """)


def sync_delivery_sql(modules: list[ValleyModule]) -> list[Path]:
    """Gera a migration SQL de automacao dos 47 modulos."""

    # changed guarda arquivos modificados.
    changed: list[Path] = []

    # sql_content monta o SQL a partir do registry.
    sql_content = build_delivery_sql(modules)

    # Escreve a migration se houver mudanca.
    if write_if_changed(GENERATED_SQL_PATH, sql_content):
        # Registra a migration como alterada.
        changed.append(GENERATED_SQL_PATH)

    # blueprint_sql aplica a evolucao incremental no registry ja existente.
    blueprint_sql = build_blueprint_registry_patch_sql(modules)

    # Escreve a migration incremental se houve mudanca.
    if write_if_changed(GENERATED_BLUEPRINT_SQL_PATH, blueprint_sql):
        changed.append(GENERATED_BLUEPRINT_SQL_PATH)

    # execution_backlog_sql aplica backlog executavel no registry existente.
    execution_backlog_sql = build_execution_backlog_patch_sql(modules)

    # Escreve a migration incremental do backlog executavel.
    if write_if_changed(GENERATED_EXECUTION_BACKLOG_SQL_PATH, execution_backlog_sql):
        changed.append(GENERATED_EXECUTION_BACKLOG_SQL_PATH)

    # priority_registry_sql cria o registry fisico por dominio prioritario.
    priority_registry_sql = build_priority_domain_registry_sql(modules)

    # Escreve a migration de pacotes fisicos prioritarios.
    if write_if_changed(GENERATED_PRIORITY_DOMAIN_SQL_PATH, priority_registry_sql):
        changed.append(GENERATED_PRIORITY_DOMAIN_SQL_PATH)

    # priority_seed_sql consolida o seed operacional dos dominios prioritarios.
    priority_seed_sql = build_domain_seed_sql(build_priority_domain_packages(modules))

    # Escreve o seed operacional consolidado da primeira onda.
    if write_if_changed(GENERATED_PRIORITY_DOMAIN_SEED_PATH, priority_seed_sql):
        changed.append(GENERATED_PRIORITY_DOMAIN_SEED_PATH)

    # Retorna arquivos alterados.
    return changed


def sync_admin_console() -> list[Path]:
    """Regenera o console admin para refletir docs, roadmap e migrations."""

    # Sem builder admin nao ha nada para sincronizar.
    if not ADMIN_BUILDER_PATH.exists():
        return []

    # result executa o builder admin com o mesmo Python atual.
    result = subprocess.run(
        [*PYTHON_COMMAND, str(ADMIN_BUILDER_PATH), 'build'],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )

    # Falha explicita evita painel admin desatualizado.
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or 'Falha ao sincronizar console admin.')

    # changed converte a saida do builder em caminhos reais.
    changed: list[Path] = []

    for line in result.stdout.splitlines():
        # Ignora heartbeat sem alteracao.
        if not line.strip() or line.strip() == 'Nada para sincronizar.':
            continue

        # path resolve o caminho relativo emitido pelo builder.
        path = ROOT / line.strip()

        # So registra caminhos que existam no filesystem.
        if path.exists():
            changed.append(path)

    # Retorna artefatos alterados do console admin.
    return changed


def main() -> None:
    """Entrada principal da CLI de automacao."""

    # parser define comandos de operacao.
    parser = argparse.ArgumentParser(description='Automacao dos 47 modulos Valley.')

    # command escolhe a acao desejada.
    parser.add_argument('command', choices=['validate', 'sync', 'roadmap', 'contracts', 'sql', 'packages', 'admin'], help='Acao da automacao.')

    # args carrega argumentos da linha de comando.
    args = parser.parse_args()

    # modules carrega e valida registry antes de qualquer acao.
    modules = load_registry()

    # validate apenas confirma consistencia.
    if args.command == 'validate':
        # Mensagem curta para logs de automacao.
        print('Registry valido: 47 modulos.')
        # Encerra sem escrever arquivos.
        return

    # changed acumula arquivos alterados por comandos que escrevem.
    changed: list[Path] = []

    # sync gera modulos e roadmap.
    if args.command == 'sync':
        # Sincroniza documentacao por modulo.
        changed.extend(sync_modules(modules))
        # Sincroniza roadmap consolidado.
        changed.extend(sync_roadmap(modules))
        # Sincroniza matriz consolidada de contratos.
        changed.extend(sync_contracts(modules))
        # Sincroniza pacotes fisicos dos dominios prioritarios.
        changed.extend(sync_priority_domain_packages(modules))
        # Sincroniza o console admin refletindo os artefatos atuais.
        changed.extend(sync_admin_console())

    # roadmap gera apenas roadmap consolidado.
    if args.command == 'roadmap':
        # Sincroniza somente roadmap.
        changed.extend(sync_roadmap(modules))
        # Sincroniza o plano fisico por dominio derivado do backlog.
        changed.extend(sync_priority_domain_packages(modules))
        # Sincroniza o painel para refletir novo roadmap.
        changed.extend(sync_admin_console())

    # contracts gera contratos operacionais sem tocar o restante.
    if args.command == 'contracts':
        # Sincroniza contratos por modulo e matriz.
        changed.extend(sync_contracts(modules))
        # Exporta contratos de evento por dominio prioritario.
        changed.extend(sync_priority_domain_packages(modules))
        # Sincroniza o painel para refletir novos contratos.
        changed.extend(sync_admin_console())

    # sql gera somente a migration do delivery registry.
    if args.command == 'sql':
        # Sincroniza SQL de automacao.
        changed.extend(sync_delivery_sql(modules))
        # Sincroniza artefatos fisicos por dominio para manter caminhos coerentes.
        changed.extend(sync_priority_domain_packages(modules))
        # Sincroniza o painel para refletir trilha de automacao.
        changed.extend(sync_admin_console())

    # packages gera apenas os pacotes fisicos por camada.
    if args.command == 'packages':
        # Sincroniza plano, DDL complementar, seeds e contratos por dominio.
        changed.extend(sync_priority_domain_packages(modules))
        # Sincroniza o painel para refletir os novos pacotes.
        changed.extend(sync_admin_console())

    # admin regenera apenas o console web e seu dataset.
    if args.command == 'admin':
        # Sincroniza somente o console admin.
        changed.extend(sync_admin_console())

    # Imprime arquivos alterados em caminho relativo para automacoes.
    for path in changed:
        # relative_to deixa a saida limpa.
        print(path.relative_to(ROOT))

    # Se nada mudou, informa estado estavel.
    if not changed:
        # Mensagem clara para heartbeat e CI local.
        print('Nada para sincronizar.')


# Executa main quando chamado como script.
if __name__ == '__main__':
    # Inicia automacao.
    main()

