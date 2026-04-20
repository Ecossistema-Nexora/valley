#!/usr/bin/env python3
"""Orquestra validacao e implantacao do banco hibrido Valley."""

# argparse cria uma CLI objetiva para check, report, apply e compose.
import argparse

# json le o manifesto de migrations e escreve relatorios tecnicos.
import json

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

# ADMIN_BUILDER_PATH aponta para o gerador do console admin.
ADMIN_BUILDER_PATH = ROOT / 'scripts' / 'valley_admin_builder.py'

# MODULES_DIR guarda os artefatos por modulo gerados pela automacao v47.
MODULES_DIR = ROOT / 'modules'

# CONTRACTS_SUMMARY_PATH guarda a matriz consolidada dos contratos operacionais.
CONTRACTS_SUMMARY_PATH = ROOT / 'output' / 'module-roadmap' / 'VALLEY_MODULE_CONTRACTS.md'

# ROADMAP_PATH guarda o roadmap consolidado de evolucao dos 47 modulos.
ROADMAP_PATH = ROOT / 'output' / 'module-roadmap' / 'VALLEY_MODULE_ROADMAP.md'

# PYTHON_COMMAND reaproveita o Python atual para evitar alias quebrado como python3 no Windows.
PYTHON_COMMAND = [sys.executable] if sys.executable else ['python3']

# COMPOSE_WAIT_SECONDS define quanto tempo a esteira espera banco e mongo no Compose.
COMPOSE_WAIT_SECONDS = 900

# COMPOSE_BUILDER_SERVICE identifica o worker de aplicacao no docker-compose.
COMPOSE_BUILDER_SERVICE = 'builder'


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
    node_path = shutil.which('node')

    # relative deixa nome curto no relatorio.
    relative = path.relative_to(ROOT)

    # Se node nao existir, registra skip sem falhar a arquitetura.
    if not node_path:
        return [CheckResult(f'{relative}.node_check', False, 'node nao encontrado para validar sintaxe JS.')]

    # Executa node --check para validar sintaxe sem rodar contra banco.
    result = run_command([node_path, '--check', str(path)], timeout_seconds=20)

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

    # tools lista binarios externos relevantes para aplicar ou validar migrations.
    tools = ['node', 'psql', 'mongosh', 'docker']

    # Percorre ferramentas conhecidas.
    for tool in tools:
        # path localiza binario no PATH.
        path = shutil.which(tool)

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

    # skip_docker_checks permite rodar o report dentro do builder sem marcar falso negativo.
    skip_docker_checks = os.environ.get('VALLEY_SKIP_DOCKER_CHECKS', '').strip().lower() in {'1', 'true', 'yes'}

    # docker compose pode existir mesmo sem daemon; checamos versao com timeout curto.
    docker_path = shutil.which('docker')

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

    # Retorna resultados de documentacao operacional.
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
    ])

    # Escreve relatorio em UTF-8.
    report_path.write_text('\n'.join(lines), encoding='utf-8')

    # Retorna caminho gerado.
    return report_path


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
        psql_path = shutil.which('psql')

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
        mongosh_path = shutil.which('mongosh')

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
    docker_path = shutil.which('docker')

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
    docker_path = shutil.which('docker')

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
    docker_path = shutil.which('docker')

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
    parser.add_argument('command', choices=['check', 'report', 'apply-postgres', 'apply-mongo', 'compose-up', 'compose-down', 'apply-compose'], help='Operacao desejada.')

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


# Executa main quando chamado diretamente.
if __name__ == '__main__':
    # Inicia orquestrador.
    main()
