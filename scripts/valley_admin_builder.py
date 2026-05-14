#!/usr/bin/env python3
# PROPOSITO: Automatizar valley admin builder no workspace Valley.
# CONTEXTO: Este modulo apoia operacao, geracao, validacao ou integracao ligada ao caminho scripts/valley_admin_builder.py.
# REGRAS: Nao expor segredos, manter comportamento idempotente e preservar contratos usados por release e runtime.

"""Gera o painel admin estatico a partir dos artefatos canonicos do Valley."""

import argparse
import json
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from urllib import error, request


ROOT = Path(__file__).resolve().parents[1]
REGISTRY_PATH = ROOT / 'config' / 'modules_v47.json'
MANIFEST_PATH = ROOT / 'database' / 'migrations.json'
MODULES_DIR = ROOT / 'modules'
REPORT_PATH = ROOT / 'output' / 'deployment' / 'VALLEY_DEPLOYMENT_STATUS.md'
EXTERNAL_ACCESS_PATH = ROOT / 'output' / 'deployment' / 'VALLEY_EXTERNAL_ACCESS.md'
PUBLIC_RUNTIME_PATH = ROOT / 'tmp' / 'runtime' / 'valley-admin-public-runtime.json'
DEFAULT_NGROK_API_URL = 'http://127.0.0.1:4040/api/tunnels'
ROADMAP_PATH = ROOT / 'output' / 'module-roadmap' / 'VALLEY_MODULE_ROADMAP.md'
CONTRACTS_SUMMARY_PATH = ROOT / 'output' / 'module-roadmap' / 'VALLEY_MODULE_CONTRACTS.md'
GOVERNANCE_PATH = ROOT / 'MANUAL_ONLINE' / 'NORMA_UNIFICADA_V47.md'
GOVERNANCE_JSON_PATH = ROOT / 'config' / 'valley_governance.json'
NGROK_CONFIG_PATH = ROOT / 'config' / 'ngrok' / 'valley-ngrok.yml'
ADMIN_DIR = ROOT / 'admin'
DATA_JSON_PATH = ADMIN_DIR / 'valley_admin_data.json'
DATA_JS_PATH = ADMIN_DIR / 'valley_admin_data.js'


def read_text(path: Path) -> str:
    """Le arquivo UTF-8 quando existir."""

    if not path.exists():
        return ''

    return path.read_text(encoding='utf-8')


def read_json(path: Path) -> dict[str, object] | None:
    """Le JSON objeto quando existir e estiver valido."""

    if not path.exists():
        return None

    try:
        content = json.loads(path.read_text(encoding='utf-8-sig'))
    except (OSError, json.JSONDecodeError):
        return None

    if not isinstance(content, dict):
        return None

    return content


def read_json_url(url: str, timeout: float = 2.0) -> dict[str, object] | None:
    """Le JSON objeto remoto quando o endpoint responder."""

    try:
        with request.urlopen(url, timeout=timeout) as response:
            content = json.loads(response.read().decode('utf-8'))
    except (error.URLError, TimeoutError, json.JSONDecodeError, OSError):
        return None

    if not isinstance(content, dict):
        return None

    return content


def relative_from_admin(path: Path) -> str:
    """Converte caminho absoluto para referencia relativa ao painel admin."""

    return str(Path('..') / path.relative_to(ROOT)).replace('\\', '/')


def parse_checklist(markdown: str) -> list[dict[str, object]]:
    """Extrai checklist do STATUS.md."""

    items: list[dict[str, object]] = []

    for line in markdown.splitlines():
        match = re.match(r'^- \[(?P<flag>[ xX])\] (?P<label>.+)$', line.strip())

        if not match:
            continue

        items.append({
            'done': match.group('flag').lower() == 'x',
            'label': match.group('label').strip(),
        })

    return items


def short_markdown(markdown: str, max_lines: int = 10) -> str:
    """Reduz Markdown longo para preview compacto."""

    lines = [line.rstrip() for line in markdown.splitlines() if line.strip()]

    if len(lines) <= max_lines:
        return '\n'.join(lines)

    return '\n'.join(lines[:max_lines]) + '\n...'


def parse_report_summary(markdown: str) -> dict[str, object]:
    """Resume o relatorio operacional para o topo do painel."""

    if not markdown:
        return {
            'available': False,
            'generated_at_utc': None,
            'total_checks': 0,
            'failed_checks': 0,
            'top_failures': [],
        }

    generated_at_match = re.search(r'Gerado em UTC: `([^`]+)`', markdown)
    total_checks_match = re.search(r'Total de checagens: `([0-9]+)`', markdown)
    failed_checks_match = re.search(r'Falhas ou pendencias: `([0-9]+)`', markdown)

    top_failures: list[str] = []

    for line in markdown.splitlines():
        if line.startswith('- PENDENTE - '):
            top_failures.append(line.replace('- PENDENTE - ', '', 1))

        if len(top_failures) == 5:
            break

    return {
        'available': True,
        'generated_at_utc': generated_at_match.group(1) if generated_at_match else None,
        'total_checks': int(total_checks_match.group(1)) if total_checks_match else 0,
        'failed_checks': int(failed_checks_match.group(1)) if failed_checks_match else 0,
        'top_failures': top_failures,
    }


def module_admin_actions(module: dict[str, object], checklist: list[dict[str, object]]) -> list[str]:
    """Gera a lista padrao de acoes administrativas por modulo."""

    actions: list[str] = []
    data_home = str(module.get('data_home', ''))
    pending_action_map = {
        'schema postgresql especifico revisado.': 'revisar_schema_postgres',
        'schema mongodb especifico revisado.': 'revisar_schema_mongo',
        'fluxos admin/rbac/abac definidos.': 'alinhar_rbac_abac',
        'regras de negocio cadastradas ou descartadas.': 'registrar_regras_negocio',
        'testes de integracao planejados.': 'planejar_testes_integracao',
        'manual online atualizado.': 'atualizar_manual',
        'pdf regenerado.': 'regenerar_pdf',
    }

    if 'postgres' in data_home:
        actions.append('revisar_schema_postgres')

    if 'mongo' in data_home:
        actions.append('revisar_schema_mongo')

    actions.extend([
        'alinhar_rbac_abac',
        'registrar_regras_negocio',
        'planejar_testes_integracao',
        'atualizar_manual',
        'regenerar_pdf',
    ])

    for item in checklist:
        if item['done']:
            continue

        label = str(item['label']).lower()

        if label in pending_action_map:
            actions.append(pending_action_map[label])
            continue

        if 'admin/rbac/abac' in label:
            actions.append('alinhar_rbac_abac')
        elif 'regras de negocio' in label:
            actions.append('registrar_regras_negocio')
        elif 'testes de integracao' in label:
            actions.append('planejar_testes_integracao')
        elif 'manual online' in label:
            actions.append('atualizar_manual')
        elif 'pdf' in label:
            actions.append('regenerar_pdf')

    return list(dict.fromkeys(actions))


def load_module_payload() -> list[dict[str, object]]:
    """Carrega os modulos e enriquece com docs e checklist."""

    registry = json.loads(REGISTRY_PATH.read_text(encoding='utf-8'))
    modules_raw = registry.get('modules', [])
    modules: list[dict[str, object]] = []

    for module in modules_raw:
        slug = f"{int(module['number']):02d}-{str(module['code']).lower().replace('_', '-')}"
        module_dir = MODULES_DIR / slug
        readme_path = module_dir / 'README.md'
        status_path = module_dir / 'STATUS.md'
        contract_path = module_dir / 'CONTRACT.md'

        readme_content = read_text(readme_path)
        status_content = read_text(status_path)
        contract_content = read_text(contract_path)
        checklist = parse_checklist(status_content)
        completed = sum(1 for item in checklist if item['done'])

        modules.append({
            **module,
            'slug': slug,
            'status_label': {
                'planned': 'Planejado',
                'implemented_partial': 'Parcialmente implantado',
                'implemented': 'Implantado',
                'blocked': 'Bloqueado',
            }.get(module['automation_status'], module['automation_status']),
            'paths': {
                'module_dir': relative_from_admin(module_dir),
                'readme': relative_from_admin(readme_path),
                'status': relative_from_admin(status_path),
                'contract': relative_from_admin(contract_path),
            },
            'docs': {
                'readme': readme_content,
                'status': status_content,
                'contract': contract_content,
                'readme_preview': short_markdown(readme_content),
                'contract_preview': short_markdown(contract_content),
            },
            'checklist': {
                'done': completed,
                'pending': max(len(checklist) - completed, 0),
                'total': len(checklist),
                'items': checklist,
            },
            'admin_actions': module_admin_actions(module, checklist),
        })

    return modules


def percentage(value: float, total: float) -> float:
    """Calcula percentual arredondado com seguranca para divisao por zero."""

    if total <= 0:
        return 0.0

    return round((value / total) * 100, 2)


def module_readiness(module: dict[str, object]) -> float:
    """Calcula a prontidao estimada de um modulo a partir do checklist."""

    checklist = dict(module.get('checklist', {}))
    return percentage(float(checklist.get('done', 0)), float(checklist.get('total', 0)))


def build_release_summary(modules: list[dict[str, object]]) -> dict[str, object]:
    """Resume o estado de release dos 47 modulos para consumo no cockpit."""

    checklist_done_total = sum(int(module['checklist']['done']) for module in modules)
    checklist_pending_total = sum(int(module['checklist']['pending']) for module in modules)
    checklist_items_total = sum(int(module['checklist']['total']) for module in modules)
    modules_completed = sum(1 for module in modules if int(module['checklist']['pending']) == 0)
    modules_with_pending = sum(1 for module in modules if int(module['checklist']['pending']) > 0)
    average_module_readiness = round(
        sum(module_readiness(module) for module in modules) / len(modules),
        2,
    ) if modules else 0.0

    top_modules_with_pending = [
        {
            'number': module['number'],
            'code': module['code'],
            'name': module['name'],
            'tier': module['tier'],
            'automation_status': module['automation_status'],
            'status_label': module['status_label'],
            'checklist_done': module['checklist']['done'],
            'checklist_pending': module['checklist']['pending'],
            'checklist_total': module['checklist']['total'],
            'module_readiness_percentage': module_readiness(module),
        }
        for module in sorted(
            modules,
            key=lambda item: (
                -int(item['checklist']['pending']),
                module_readiness(item),
                int(item['number']),
            ),
        )
        if int(module['checklist']['pending']) > 0
    ][:10]

    by_tier: dict[str, dict[str, object]] = {}
    by_status: dict[str, dict[str, object]] = {}

    for dimension_name, bucket in (('tier', by_tier), ('automation_status', by_status)):
        groups = sorted({str(module[dimension_name]) for module in modules})

        for group in groups:
            group_modules = [module for module in modules if str(module[dimension_name]) == group]
            group_done = sum(int(module['checklist']['done']) for module in group_modules)
            group_pending = sum(int(module['checklist']['pending']) for module in group_modules)
            group_total = sum(int(module['checklist']['total']) for module in group_modules)
            group_completed = sum(1 for module in group_modules if int(module['checklist']['pending']) == 0)
            group_with_pending = sum(1 for module in group_modules if int(module['checklist']['pending']) > 0)

            bucket[group] = {
                'modules_total': len(group_modules),
                'modules_completed': group_completed,
                'modules_with_pending': group_with_pending,
                'checklist_items_total': group_total,
                'checklist_items_done': group_done,
                'checklist_items_pending': group_pending,
                'checklist_completion_percentage': percentage(group_done, group_total),
                'average_module_readiness_percentage': round(
                    sum(module_readiness(module) for module in group_modules) / len(group_modules),
                    2,
                ) if group_modules else 0.0,
            }

    return {
        'modules_total': len(modules),
        'modules_completed': modules_completed,
        'modules_with_pending': modules_with_pending,
        'checklist_items_total': checklist_items_total,
        'checklist_items_done': checklist_done_total,
        'checklist_items_pending': checklist_pending_total,
        'checklist_completion_percentage': percentage(checklist_done_total, checklist_items_total),
        'average_module_readiness_percentage': average_module_readiness,
        'top_modules_with_pending': top_modules_with_pending,
        'by_tier': by_tier,
        'by_automation_status': by_status,
    }


def build_release_queue_summary(modules: list[dict[str, object]]) -> dict[str, object]:
    """Prioriza os proximos modulos de release para o cockpit."""

    tier_rank = {
        'foundation': 0,
        'core': 1,
        'expansion': 2,
        'frontier': 3,
    }
    queue_items: list[dict[str, object]] = []

    for module in sorted(
        modules,
        key=lambda item: (
            tier_rank.get(str(item.get('tier')), 99),
            0 if str(item.get('automation_status')) == 'planned' else 1,
            -int(item['checklist']['pending']),
            module_readiness(item),
            int(item.get('number', 0)),
        ),
    ):
        pending = int(module['checklist']['pending'])

        if pending <= 0:
            continue

        queue_items.append({
            'number': module['number'],
            'code': module['code'],
            'name': module['name'],
            'subtitle': module['subtitle'],
            'domain': module['domain'],
            'tier': module['tier'],
            'data_home': module['data_home'],
            'automation_status': module['automation_status'],
            'status_label': module['status_label'],
            'checklist_done': module['checklist']['done'],
            'checklist_pending': pending,
            'checklist_total': module['checklist']['total'],
            'module_readiness_percentage': module_readiness(module),
            'next_focus': module['admin_actions'][:3],
        })

    return {
        'items_total': len(queue_items),
        'items': queue_items[:12],
    }


def build_public_runtime_summary() -> dict[str, object]:
    """Resume o runtime publico do painel admin a partir do manifesto Cloudflare."""

    runtime_manifest = read_json(PUBLIC_RUNTIME_PATH)
    summary = {
        'available': False,
        'path': relative_from_admin(PUBLIC_RUNTIME_PATH),
        'status': 'missing',
        'public_url': None,
        'permanence': None,
        'smoke_endpoints': {
            'healthz': None,
            'admin_data': None,
        },
    }

    if not isinstance(runtime_manifest, dict):
        return summary

    public_url = runtime_manifest.get('public_url')
    permanence = runtime_manifest.get('permanence')
    status = runtime_manifest.get('status') or 'invalid'
    smoke_endpoints = runtime_manifest.get('smoke_endpoints')

    if isinstance(public_url, str) and public_url:
        public_url = public_url.rstrip('/')
        default_healthz = f'{public_url}/healthz'
        default_admin_data = f'{public_url}/api/admin-data'
        available = True
    else:
        public_url = None
        default_healthz = None
        default_admin_data = None
        available = False

    return {
        'available': available,
        'path': relative_from_admin(PUBLIC_RUNTIME_PATH),
        'status': status,
        'public_url': public_url,
        'permanence': permanence,
        'smoke_endpoints': {
            'healthz': (smoke_endpoints or {}).get('healthz', default_healthz),
            'admin_data': (smoke_endpoints or {}).get('admin_data', default_admin_data),
        },
    }


def build_payload() -> dict[str, object]:
    """Monta o payload final consumido pelo console admin."""

    registry = json.loads(REGISTRY_PATH.read_text(encoding='utf-8'))
    manifest = json.loads(MANIFEST_PATH.read_text(encoding='utf-8'))
    modules = load_module_payload()
    report_summary = parse_report_summary(read_text(REPORT_PATH))

    by_tier = Counter(str(module['tier']) for module in modules)
    by_status = Counter(str(module['automation_status']) for module in modules)
    by_data_home = Counter(str(module['data_home']) for module in modules)
    by_domain = Counter(str(module['domain']) for module in modules)

    return {
        'generated_at_utc': datetime.now(timezone.utc).isoformat(),
        'registry_name': registry.get('registry_name'),
        'source': registry.get('source'),
        'language_policy': registry.get('language_policy'),
        'module_summary': {
            'total': len(modules),
            'by_tier': dict(sorted(by_tier.items())),
            'by_status': dict(sorted(by_status.items())),
            'by_data_home': dict(sorted(by_data_home.items())),
            'by_domain': dict(sorted(by_domain.items())),
        },
        'release_summary': build_release_summary(modules),
        'release_queue_summary': build_release_queue_summary(modules),
        'public_runtime': build_public_runtime_summary(),
        'database_summary': {
            'postgres_migrations': len(manifest.get('postgres', [])),
            'mongodb_scripts': len(manifest.get('mongodb', [])),
            'postgres_items': manifest.get('postgres', []),
            'mongodb_items': manifest.get('mongodb', []),
        },
        'deployment_summary': report_summary,
        'public_access': {
            'path': relative_from_admin(EXTERNAL_ACCESS_PATH),
            'cloudflare_launcher_path': relative_from_admin(ROOT / 'scripts' / 'start_termius_cloudflare_tunnel.ps1'),
            'preview': short_markdown(read_text(EXTERNAL_ACCESS_PATH), max_lines=14),
        },
        'roadmap': {
            'path': relative_from_admin(ROADMAP_PATH),
            'preview': short_markdown(read_text(ROADMAP_PATH), max_lines=14),
        },
        'contracts_summary': {
            'path': relative_from_admin(CONTRACTS_SUMMARY_PATH),
            'preview': short_markdown(read_text(CONTRACTS_SUMMARY_PATH), max_lines=14),
        },
        'governance': {
            'path': relative_from_admin(GOVERNANCE_PATH),
            'json_path': relative_from_admin(GOVERNANCE_JSON_PATH),
            'preview': short_markdown(read_text(GOVERNANCE_PATH), max_lines=16),
        },
        'admin_commands': [
            'python scripts/serve_valley_admin.py --port 8080',
            'powershell -ExecutionPolicy Bypass -File scripts/start_valley_admin_public.ps1',
            'python scripts/show_valley_public_urls.py',
            'python scripts/automacao_sincronizador_modulos.py sync',
            'python scripts/valley_db_orchestrator.py check',
            'python scripts/valley_db_orchestrator.py report',
            'powershell -ExecutionPolicy Bypass -File scripts/run_valley_compose_builder.ps1',
        ],
        'modules': modules,
    }


def write_if_changed(path: Path, content: str) -> bool:
    """Escreve arquivo somente quando houver mudanca real."""

    current = read_text(path)

    if current == content:
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')
    return True


def build_admin_data() -> list[Path]:
    """Gera JSON e JS do painel admin."""

    payload = build_payload()
    json_content = json.dumps(payload, ensure_ascii=False, indent=2) + '\n'
    js_content = 'window.VALLEY_ADMIN_DATA = ' + json.dumps(payload, ensure_ascii=False, indent=2) + ';\n'
    changed: list[Path] = []

    if write_if_changed(DATA_JSON_PATH, json_content):
        changed.append(DATA_JSON_PATH)

    if write_if_changed(DATA_JS_PATH, js_content):
        changed.append(DATA_JS_PATH)

    return changed


def main() -> None:
    """Entrada principal do builder admin."""

    parser = argparse.ArgumentParser(description='Builder do painel admin Valley.')
    parser.add_argument('command', choices=['build'], help='Acao desejada.')
    args = parser.parse_args()
    changed = build_admin_data() if args.command == 'build' else []

    for path in changed:
        print(path.relative_to(ROOT))

    if not changed:
        print('Nada para sincronizar.')


if __name__ == '__main__':
    main()
