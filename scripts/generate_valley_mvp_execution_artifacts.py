#!/usr/bin/env python3
# PROPOSITO: Automatizar generate valley mvp execution artifacts no workspace Valley.
# CONTEXTO: Este modulo apoia operacao, geracao, validacao ou integracao ligada ao caminho scripts/generate_valley_mvp_execution_artifacts.py.
# REGRAS: Nao expor segredos, manter comportamento idempotente e preservar contratos usados por release e runtime.

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "config" / "mvp" / "valley_mvp_manifest.v1.json"
MODULES_PATH = ROOT / "config" / "modules_v47.json"
CONTRACT_MATRIX_PATH = ROOT / "output" / "module-roadmap" / "VALLEY_MODULE_CONTRACTS.md"
MODULES_DIR = ROOT / "modules"
OUTPUT_PATH = ROOT / "output" / "module-roadmap" / "VALLEY_MVP_EXECUTION_BACKLOG.md"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def parse_contract_matrix(path: Path) -> dict[str, dict[str, str]]:
    data: dict[str, dict[str, str]] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("|"):
            continue
        parts = [part.strip() for part in line.strip().strip("|").split("|")]
        if len(parts) != 7 or parts[0] in {"No", "---:"}:
            continue
        code = parts[1].strip("`")
        data[code] = {
            "module": parts[2],
            "tier": parts[3].strip("`"),
            "phase": parts[4].strip("`"),
            "data_home": parts[5].strip("`"),
            "compliance": parts[6],
        }
    return data


def module_dir_name(number: int, code: str) -> str:
    return f"{number:02d}-{code.lower().replace('_', '-')}"


def parse_backlog_items(contract_path: Path) -> list[str]:
    if not contract_path.exists():
        return []
    lines = contract_path.read_text(encoding="utf-8").splitlines()
    items: list[str] = []
    capture = False
    for line in lines:
        if line.startswith("## Primeiro Backlog Tecnico"):
            capture = True
            continue
        if capture and line.startswith("## "):
            break
        if capture and line.startswith("- "):
            items.append(line[2:].strip())
    return items


def render_module_section(module: dict, matrix: dict[str, dict[str, str]]) -> list[str]:
    code = module["code"]
    row = matrix.get(code, {})
    contract_path = MODULES_DIR / module_dir_name(module["number"], code) / "CONTRACT.md"
    backlog_items = parse_backlog_items(contract_path)
    lines = [
        f"#### {module['number']:02d}. `{code}` - {module['name']}",
        f"- Dominio: `{module['domain']}`",
        f"- Tier: `{row.get('tier', module['tier'])}`",
        f"- Fase atual: `{row.get('phase', 'n/d')}`",
        f"- Data home: `{row.get('data_home', module['data_home'])}`",
        f"- Objetivo: {module['description_ptbr']}",
    ]
    if backlog_items:
        lines.append("- Backlog imediato:")
        for item in backlog_items:
            lines.append(f"  - {item}")
    return lines


def build_markdown(manifest: dict, modules_registry: dict, matrix: dict[str, dict[str, str]]) -> str:
    modules_by_code = {module["code"]: module for module in modules_registry["modules"]}
    lines: list[str] = []
    lines.append("# VALLEY MVP EXECUTION BACKLOG")
    lines.append("")
    lines.append("Este arquivo e gerado por `scripts/generate_valley_mvp_execution_artifacts.py`.")
    lines.append(f"Fonte canonica: `{manifest['source_spec']}` e `config/mvp/valley_mvp_manifest.v1.json`.")
    lines.append("")
    lines.append("## Resumo")
    lines.append(f"- Manifesto: `{manifest['manifest_name']}` v`{manifest['version']}`")
    lines.append(f"- Modo de execucao: `{manifest['execution_mode']}`")
    lines.append(f"- Objetivo: {manifest['objective']['summary']}")
    lines.append(f"- Principio central: {manifest['objective']['central_principle']}")
    lines.append("")
    lines.append("## Escopo MVP")
    lines.append("- Modulos incluidos:")
    for code in manifest["included_modules"]:
        module = modules_by_code[code]
        row = matrix.get(code, {})
        lines.append(
            f"  - `{code}` - {module['name']} | fase `{row.get('phase', 'n/d')}` | data home `{row.get('data_home', module['data_home'])}`"
        )
    lines.append("- Modulos fora do MVP:")
    for code in manifest["excluded_modules"]:
        module = modules_by_code[code]
        row = matrix.get(code, {})
        lines.append(
            f"  - `{code}` - {module['name']} | fase `{row.get('phase', 'n/d')}` | mantido fora do corte inicial"
        )
    lines.append("")
    lines.append("## Frente transversal de identidade unica")
    lines.append(manifest["cross_cutting_capabilities"]["unique_identity"]["summary"])
    for component in manifest["cross_cutting_capabilities"]["unique_identity"]["components"]:
        lines.append(f"### {component['label']}")
        lines.append(f"- Modo de entrega: `{component['delivery_mode']}`")
        lines.append(f"- Donos: {', '.join(f'`{item}`' for item in component['owners'])}")
        lines.append(f"- Evidencias base: {', '.join(f'`{item}`' for item in component['evidence_entities'])}")
        if component["event_topics"]:
            lines.append(f"- Eventos: {', '.join(f'`{item}`' for item in component['event_topics'])}")
        else:
            lines.append("- Eventos: `spec-first`, sem topico canonico fechado ainda")
        lines.append(f"- Objetivo: {component['objective']}")
        lines.append("")
    lines.append("## Fases de execucao")
    for phase in manifest["phases"]:
        lines.append(f"### {phase['label']}")
        lines.append(f"- Objetivo da fase: {phase['goal']}")
        if phase.get("modules"):
            lines.append("- Modulos desta fase:")
            for code in phase["modules"]:
                lines.extend(render_module_section(modules_by_code[code], matrix))
        if phase.get("cross_cutting_capabilities"):
            lines.append("- Capacidades transversais desta fase:")
            for capability in phase["cross_cutting_capabilities"]:
                lines.append(f"  - `{capability}`")
        if phase.get("runtime_rules"):
            lines.append("- Regras de runtime:")
            for rule in phase["runtime_rules"]:
                lines.append(f"  - {rule}")
        if phase.get("stock_marketplace_model"):
            model = phase["stock_marketplace_model"]
            lines.append("- Modelo visual/comercial do STOCK:")
            lines.append(
                f"  - Referencia de comportamento: {', '.join(model['reference_behavior'])}"
            )
            lines.append(f"  - Regra de identidade Valley: {model['valley_identity_rule']}")
            lines.append(f"  - Direcao visual: {model['visual_direction']}")
            lines.append("  - Superficies obrigatorias:")
            for surface in model["must_have_surfaces"]:
                lines.append(f"    - {surface}")
            if model.get("admin_api_integrations"):
                lines.append(
                    f"  - Integracoes configuraveis no admin: {', '.join(model['admin_api_integrations'])}"
                )
            if model.get("admin_api_fields"):
                lines.append("  - Campos de configuracao por integracao:")
                for field in model["admin_api_fields"]:
                    lines.append(f"    - {field}")
            if model.get("dropshipping_production_blueprint"):
                dropshipping = model["dropshipping_production_blueprint"]
                lines.append("  - Dropshipping inteligente em modo de producao:")
                lines.append(f"    - Spec: `{dropshipping['spec_path']}`")
                lines.append(f"    - Migration: `{dropshipping['database_migration']}`")
                lines.append(
                    f"    - Fornecedores API: {', '.join(dropshipping['supplier_apis'])}"
                )
                lines.append(
                    f"    - Fontes de preco: {', '.join(dropshipping['market_price_sources'])}"
                )
                lines.append("    - Capacidades obrigatorias:")
                for capability in dropshipping["required_capabilities"]:
                    lines.append(f"      - {capability}")
        lines.append("- Gates de sucesso:")
        for gate in phase["success_gates"]:
            lines.append(f"  - {gate}")
        lines.append("")
    lines.append("## Metricas de sucesso")
    for metric in manifest["metrics"]:
        lines.append(f"- {metric}")
    lines.append("")
    lines.append("## Regras de ouro")
    for rule in manifest["golden_rules"]:
        lines.append(f"- {rule}")
    lines.append("")
    lines.append("## Resultado esperado")
    for item in manifest["expected_result"]:
        lines.append(f"- {item}")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    manifest = load_json(MANIFEST_PATH)
    modules_registry = load_json(MODULES_PATH)
    matrix = parse_contract_matrix(CONTRACT_MATRIX_PATH)
    markdown = build_markdown(manifest, modules_registry, matrix)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(markdown, encoding="utf-8")
    print(f"Generated: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
