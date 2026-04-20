#!/usr/bin/env python3
"""Automatiza implantacao, desenvolvimento e evolucao dos 47 modulos Valley."""

# argparse cria uma CLI simples para rodar sync, validate e roadmap.
import argparse

# json le o registry canonico dos 47 modulos.
import json

# subprocess executa o builder admin como etapa automatica.
import subprocess

# sys reaproveita o Python atual em subprocessos portaveis.
import sys

# dataclasses organiza a estrutura interna do modulo com tipos claros.
from dataclasses import dataclass

# pathlib manipula caminhos da worktree sem depender do sistema operacional.
from pathlib import Path

# textwrap ajuda a gerar Markdown legivel e sem indentacao acidental.
from textwrap import dedent


# ROOT aponta para a raiz da worktree Valley.
ROOT = Path(__file__).resolve().parents[1]

# REGISTRY_PATH e a fonte unica para os 47 modulos.
REGISTRY_PATH = ROOT / 'config' / 'modules_v47.json'

# MODULES_DIR guarda um diretory por modulo para documentacao operacional.
MODULES_DIR = ROOT / 'modules'

# ROADMAP_DIR guarda relatorios consolidados para implantacao e evolucao.
ROADMAP_DIR = ROOT / 'output' / 'module-roadmap'

# CONTRACTS_SUMMARY_PATH guarda a matriz consolidada dos contratos operacionais.
CONTRACTS_SUMMARY_PATH = ROADMAP_DIR / 'VALLEY_MODULE_CONTRACTS.md'

# GENERATED_SQL_PATH guarda a migration gerada a partir do registry dos 47 modulos.
GENERATED_SQL_PATH = ROOT / 'database' / 'postgres' / '007_v47_module_delivery_automation.sql'

# MANUAL_DECISION_PATH registra decisoes humanas e tecnicas sobre implantacao.
MANUAL_DECISION_PATH = ROOT / 'MANUAL_ONLINE' / 'DECISOES_IMPLANTACAO_V47.md'

# ADMIN_BUILDER_PATH aponta para o gerador do console admin.
ADMIN_BUILDER_PATH = ROOT / 'scripts' / 'valley_admin_builder.py'

# PYTHON_COMMAND reaproveita o Python atual em automacoes derivadas.
PYTHON_COMMAND = [sys.executable] if sys.executable else ['python3']


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


def load_registry() -> list[ValleyModule]:
    """Carrega e valida o registry canonico dos 47 modulos."""

    # Abre o JSON em UTF-8 para preservar acentos do portugues.
    payload = json.loads(REGISTRY_PATH.read_text(encoding='utf-8'))

    # modules_raw contem a lista bruta vinda do arquivo de configuracao.
    modules_raw = payload.get('modules', [])

    # modules converte cada dicionario em ValleyModule fortemente estruturado.
    modules = [ValleyModule(**item) for item in modules_raw]

    # validate_modules aplica checagens de consistencia antes de gerar arquivos.
    validate_modules(modules)

    # Retorna a lista pronta para sync, roadmap e relatorios.
    return modules


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


def module_readme(module: ValleyModule) -> str:
    """Gera README.md operacional de um modulo."""

    # depends_text deixa dependencias legiveis no Markdown.
    depends_text = ', '.join(module.depends_on) if module.depends_on else 'Sem dependencia declarada'

    # integrates_text deixa integracoes legiveis no Markdown.
    integrates_text = ', '.join(module.integrates_with) if module.integrates_with else 'Sem integracao declarada'

    # Retorna Markdown em PT-BR com termos tecnicos em ingles.
    return dedent(f"""\
    # {module.number:02d}. {module.name}

    Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

    Ele descreve o modulo em linguagem simples e serve como ponto inicial para desenvolvimento, implantacao e evolucao continua.

    ## Identidade Tecnica

    - Codigo tecnico: `{module.code}`
    - Subtitulo: `{module.subtitle}`
    - Dominio: `{module.domain}`
    - Tier: `{module.tier}`
    - Data home: `{module.data_home}`
    - Status atual: `{module.status_label}`

    ## Finalidade

    {module.description_ptbr}

    ## Dependencias

    {depends_text}

    ## Integracoes

    {integrates_text}

    ## Trilha De Implantacao

    1. Confirmar contrato de dados com `users.user_id` como no central.
    2. Definir tabelas PostgreSQL quando houver dinheiro, identidade, contrato, documento ou transacao.
    3. Definir colecoes MongoDB quando houver IA, social, telemetria, eventos volumosos ou conteudo semi-estruturado.
    4. Registrar regras de negocio em `business_rule_definitions` quando houver pricing, comissao, risco, permissao ou compliance.
    5. Atualizar este README, o Manual Online e a vertente PDF a cada mudanca.

    ## Criterios De Pronto

    - Schema validado ou justificativa de descarte registrada.
    - Integracoes com `PAY`, `ID`, `DOCS`, `ORDERS` ou `TRANSACTIONS` documentadas quando existirem.
    - Teste ou validacao tecnica registrada.
    - Comentarios em portugues simples com termos tecnicos em ingles onde fizer sentido.
    """)


def module_status(module: ValleyModule) -> str:
    """Gera STATUS.md com checklist evolutivo por modulo."""

    # implemented marca check inicial quando ja existe suporte parcial.
    implemented = module.automation_status in {'implemented_partial', 'implemented'}

    # mark converte booleano em checkbox Markdown.
    mark = 'x' if implemented else ' '

    # Retorna checklist simples e acionavel.
    return dedent(f"""\
    # Status - {module.name}

    - [x] Registry canonico criado.
    - [{mark}] Suporte base de schema ja implantado ou parcialmente implantado.
    - [x] Contrato operacional inicial gerado.
    - [ ] Schema PostgreSQL especifico revisado.
    - [ ] Schema MongoDB especifico revisado.
    - [ ] Regras de negocio cadastradas ou descartadas.
    - [ ] Fluxos Admin/RBAC/ABAC definidos.
    - [ ] Testes de integracao planejados.
    - [ ] Manual Online atualizado.
    - [ ] PDF regenerado.

    Observacao: este status e inicial e deve evoluir junto com o modulo.
    """)


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
    dependencies = ', '.join(module.depends_on) if module.depends_on else 'Sem dependencia declarada'

    # integrations contem modulos ou capacidades que conversam com este modulo.
    integrations = ', '.join(module.integrates_with) if module.integrates_with else 'Sem integracao declarada'

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

    # Retorna Markdown deterministico com linguagem simples.
    return dedent(f"""\
    # Contrato Operacional - {module.number:02d}. {module.name}

    Este arquivo e gerado pela automacao `scripts/valley_module_automation.py`.

    Ele define a fronteira inicial do modulo para guiar desenvolvimento, implantacao e evolucao sem quebrar o nucleo Valley.

    ## Identidade Do Modulo

    - Codigo tecnico: `{module.code}`
    - Dominio: `{module.domain}`
    - Tier: `{module.tier}`
    - Data home: `{module.data_home}`
    - Status atual: `{module.status_label}`

    ## Objetivo Simples

    {module.description_ptbr}

    ## Politica De Dados

    {data_home_policy(module)}

    {postgres_anchor}

    {wallet_anchor}

    {mongo_anchor}

    ## Integracoes

    {integration_policy(module)}

    ## Regras De Evolucao

    1. Nao criar tabela duplicada de usuario; usar sempre `public.users`.
    2. Nao criar schema legado paralelo; manter objetos novos em `public` enquanto esta worktree exigir core-first.
    3. Usar `UUID` para chaves e referencias quando o dado for relacional.
    4. Usar `DECIMAL(18,4)` para BRL e `DECIMAL(18,8)` para `$NEX`.
    5. Usar `TIMESTAMPTZ` para eventos com tempo operacional.
    6. Usar `append-only` quando o dado representar dinheiro, auditoria, certificado, receipt, regra versionada ou trilha legal.
    7. Atualizar Manual Online e PDF em qualquer mudanca de schema, script ou contrato.

    ## Primeiro Backlog Tecnico

    - Confirmar se o modulo precisa de tabela propria ou se usa tabelas compartilhadas ja existentes.
    - Definir eventos de entrada e saida com nomes tecnicos estaveis.
    - Definir permissao Admin/RBAC/ABAC quando houver operacao sensivel.
    - Registrar regra de negocio em `business_rule_definitions` quando houver pricing, comissao, limite, risco ou compliance.
    - Validar se dados volumosos ficam fora do PostgreSQL.
    """)


def contracts_summary(modules: list[ValleyModule]) -> str:
    """Gera matriz consolidada dos contratos dos 47 modulos."""

    # lines inicia o documento com proposito e regra central.
    lines = [
        '# Matriz De Contratos Operacionais - Valley V47',
        '',
        'Este arquivo e gerado por `scripts/valley_module_automation.py`.',
        '',
        'A matriz resume a fronteira tecnica dos 47 modulos para orientar desenvolvimento continuo.',
        '',
        '| Nº | Codigo | Modulo | Tier | Data home | Dependencias | Integracoes |',
        '|---:|---|---|---|---|---|---|',
    ]

    # Percorre modulos ordenados para saida deterministica.
    for module in sorted(modules, key=lambda item: item.number):
        # depends_text normaliza lista vazia.
        depends_text = ', '.join(module.depends_on) if module.depends_on else '-'

        # integrates_text normaliza lista vazia.
        integrates_text = ', '.join(module.integrates_with) if module.integrates_with else '-'

        # Adiciona linha de matriz.
        lines.append(f'| {module.number:02d} | `{module.code}` | {module.name} | `{module.tier}` | `{module.data_home}` | {depends_text} | {integrates_text} |')

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
        'Este indice e gerado por `scripts/valley_module_automation.py`.',
        '',
        'A saida e deterministica para evitar ruido em automacoes recorrentes.',
        '',
        '| Nº | Codigo | Modulo | Dominio | Tier | Data home | Status |',
        '|---:|---|---|---|---|---|---|',
    ]

    # Adiciona uma linha por modulo.
    for module in modules:
        # Cada linha conecta numero, codigo e status do modulo.
        lines.append(f'| {module.number:02d} | `{module.code}` | {module.name} | `{module.domain}` | `{module.tier}` | `{module.data_home}` | {module.status_label} |')

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
        'Este arquivo e gerado de forma deterministica por `scripts/valley_module_automation.py`.',
        '',
        'Este roadmap automatiza a evolucao dos 47 modulos a partir do registry `config/modules_v47.json`.',
        '',
        'Regra central: tudo que envolve dinheiro, identidade, contratos e documentos vai para PostgreSQL; IA, social, telemetria e alto volume vao para MongoDB ou backend especializado.',
        '',
        '## Ordem De Prioridade',
        '',
    ]

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
            # next_action depende do status atual.
            next_action = 'evoluir contratos especificos' if module.automation_status == 'implemented_partial' else 'definir primeiro schema especifico'
            # Registra uma linha acionavel.
            lines.append(f'- `{module.code}` - {module.name}: {next_action}.')

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
        '5. Atualizar `modules/<modulo>/README.md`, `STATUS.md` e `CONTRACT.md`.',
        '6. Atualizar Manual Online e regenerar PDF.',
        '7. Registrar descarte quando a ideia for inviavel, insegura ou duplicada.',
        '',
    ])

    # Retorna roadmap final.
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


def build_delivery_sql(modules: list[ValleyModule]) -> str:
    """Gera migration SQL para automacao de delivery dos 47 modulos."""

    # values_lines recebe uma linha INSERT por modulo.
    values_lines = []

    # Percorre modulos em ordem numerica para SQL deterministico.
    for module in sorted(modules, key=lambda item: item.number):
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
            f'{sql_array(module.depends_on)}, '
            f'{sql_array(module.integrates_with)}, '
            f'{sql_literal(module.description_ptbr)}'
            ')'
        )

    # values_sql junta as linhas com virgula, como exige INSERT multi-row.
    values_sql = ',\n'.join(values_lines)

    # Retorna SQL completo com comentarios em portugues.
    return dedent(f"""\
    -- Valley Hybrid DB Bootstrap - Automacao de delivery dos 47 modulos.
    -- Este arquivo e gerado por scripts/valley_module_automation.py a partir de config/modules_v47.json.
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
        module_code TEXT NOT NULL,
        backlog_status module_backlog_status_enum NOT NULL DEFAULT 'OPEN',
        priority SMALLINT NOT NULL DEFAULT 3,
        title TEXT NOT NULL,
        description_ptbr TEXT NOT NULL,
        acceptance_criteria TEXT NOT NULL,
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
        CONSTRAINT chk_module_evolution_backlog_priority CHECK (priority BETWEEN 1 AND 5),
        CONSTRAINT chk_module_evolution_backlog_title CHECK (btrim(title) <> ''),
        CONSTRAINT chk_module_evolution_backlog_description CHECK (btrim(description_ptbr) <> ''),
        CONSTRAINT chk_module_evolution_backlog_acceptance CHECK (btrim(acceptance_criteria) <> '')
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
        depends_on,
        integrates_with,
        description_ptbr
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
        depends_on = EXCLUDED.depends_on,
        integrates_with = EXCLUDED.integrates_with,
        description_ptbr = EXCLUDED.description_ptbr,
        updated_at = NOW();

    INSERT INTO module_evolution_backlog (
        module_code,
        priority,
        title,
        description_ptbr,
        acceptance_criteria
    )
    SELECT
        module_code,
        CASE WHEN tier = 'foundation' THEN 1 WHEN tier = 'core' THEN 2 WHEN tier = 'expansion' THEN 3 ELSE 4 END,
        'Definir contrato de dados especifico para ' || module_name,
        'Criar ou revisar schema, regras, integracoes e documentacao do modulo ' || module_name || '.',
        'Schema definido ou descarte justificado; Manual Online atualizado; PDF regenerado; validacao registrada.'
    FROM module_delivery_registry
    ON CONFLICT DO NOTHING;

    COMMENT ON TYPE module_delivery_phase_enum IS 'Fase atual da esteira de desenvolvimento do modulo.';
    COMMENT ON TYPE module_delivery_status_enum IS 'Status macro de implantacao do modulo.';
    COMMENT ON TYPE module_backlog_status_enum IS 'Status de item do backlog evolutivo.';
    COMMENT ON TABLE module_delivery_registry IS 'Registro canonico dos 47 modulos para automatizar implantacao, desenvolvimento e evolucao.';
    COMMENT ON TABLE module_evolution_backlog IS 'Backlog evolutivo por modulo, gerado a partir do registry canonico.';
    COMMENT ON TABLE module_automation_runs IS 'Historico de execucoes da automacao de modulos.';
    COMMENT ON COLUMN module_delivery_registry.owner_user_id IS 'FK opcional para users.user_id quando houver responsavel humano ou system user.';
    COMMENT ON COLUMN module_delivery_registry.module_code IS 'Codigo tecnico do modulo usado por scripts, regras e roadmap.';
    COMMENT ON COLUMN module_delivery_registry.automation_policy_json IS 'Politica da automacao: atualizar manual, PDF e evitar confirmacoes manuais.';
    COMMENT ON COLUMN module_evolution_backlog.acceptance_criteria IS 'Criterio objetivo para concluir o item de evolucao.';
    COMMENT ON COLUMN module_automation_runs.artifacts_json IS 'Arquivos e evidencias geradas pela automacao.';

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
    parser.add_argument('command', choices=['validate', 'sync', 'roadmap', 'contracts', 'sql', 'admin'], help='Acao da automacao.')

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
        # Sincroniza o console admin refletindo os artefatos atuais.
        changed.extend(sync_admin_console())

    # roadmap gera apenas roadmap consolidado.
    if args.command == 'roadmap':
        # Sincroniza somente roadmap.
        changed.extend(sync_roadmap(modules))
        # Sincroniza o painel para refletir novo roadmap.
        changed.extend(sync_admin_console())

    # contracts gera contratos operacionais sem tocar o restante.
    if args.command == 'contracts':
        # Sincroniza contratos por modulo e matriz.
        changed.extend(sync_contracts(modules))
        # Sincroniza o painel para refletir novos contratos.
        changed.extend(sync_admin_console())

    # sql gera somente a migration do delivery registry.
    if args.command == 'sql':
        # Sincroniza SQL de automacao.
        changed.extend(sync_delivery_sql(modules))
        # Sincroniza o painel para refletir trilha de automacao.
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
