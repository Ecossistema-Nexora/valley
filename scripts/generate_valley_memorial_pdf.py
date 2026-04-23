#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from html import escape
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "output" / "pdf"
OUTPUT_MD = OUTPUT_DIR / "VALLEY_MEMORIAL_DESCRITIVO_COMPLETO_DO_DESENVOLVIMENTO.md"
OUTPUT_PDF = OUTPUT_DIR / "VALLEY_MEMORIAL_DESCRITIVO_COMPLETO_DO_DESENVOLVIMENTO.pdf"
MODULES_JSON = ROOT / "config" / "modules_v47.json"
CONTRACTS_MD = ROOT / "output" / "module-roadmap" / "VALLEY_MODULE_CONTRACTS.md"
ROADMAP_MD = ROOT / "output" / "module-roadmap" / "VALLEY_MODULE_ROADMAP.md"
DEPLOYMENT_MD = ROOT / "output" / "deployment" / "VALLEY_DEPLOYMENT_STATUS.md"
PROD_MODE_MD = ROOT / "output" / "deployment" / "VALLEY_PRODUCTION_MODE.md"
VISION_MD = ROOT / "docs" / "specs" / "valley_vision.md"
HELENA_MD = ROOT / "docs" / "specs" / "valley-helena-master-spec.md"
POSTGRES_DIR = ROOT / "database" / "postgres"
MONGO_DIR = ROOT / "database" / "mongodb"
PRIORITY_DOMAINS_DIR = ROOT / "database" / "domain-delivery" / "priority-domains"
SNAPSHOTS_DIR = ROOT / "output" / "snapshots"


DOMAIN_LABELS = {
    "platform_developer": "Platform and Developer",
    "logistics_erp_operations": "Logistics, ERP and Operations",
    "commerce_fintech_assets": "Commerce, Fintech and Assets",
    "ai_memory_operations": "AI, Memory and Operations",
    "media_social_growth": "Media, Social and Growth",
    "city_mobility_security": "City, Mobility and Security",
    "frontier_iot_energy": "Frontier, IoT and Energy",
    "services_health_human": "Services, Health and Human Care",
    "education_work_social": "Education, Work and Social",
}


DOMAIN_SUMMARY = {
    "platform_developer": "Infraestrutura de API, documentos, recibos, integrações e base SaaS do ecossistema.",
    "logistics_erp_operations": "ERP, WMS, estoque, tracking, food, delivery e gestao de frota.",
    "commerce_fintech_assets": "Wallet, marketplace, adquirencia, afiliacao, financas e ativos digitais ou patrimoniais.",
    "ai_memory_operations": "Agenda inteligente, memoria operacional, chat e consultoria assistida Helena.",
    "media_social_growth": "Social, creators, ads, media, influenciadores e gamificacao.",
    "city_mobility_security": "Legal, eventos, mobilidade, protecao, turismo e govtech.",
    "frontier_iot_energy": "IoT, bio, casa inteligente, energia P2P e experiencias AR.",
    "services_health_human": "Servicos profissionais, saude, farmacia, mente, fitness e vet.",
    "education_work_social": "Educacao, jobs e impacto social.",
}


MIGRATION_GROUPS = [
    ("001-002", "Nucleo absoluto", "users, wallets, led_cards, pj_profiles, rider_profiles, orders, transactions e equity_ledger."),
    ("003-007", "Comentario, controle e automacao", "Comentarios institucionais, control plane, backlog, automation e metadados base."),
    ("008-014", "Camada transversal de dominio", "Commerce, legal, city ops, services/health, assets, tourism, bio e energy."),
    ("015-017", "Registry, backlog e pacotes", "Blueprints, backlog executavel e domain delivery packages."),
    ("018-026", "DDL de negocio por dominio", "Platform, logistics, city security, commerce, AI, media e frontier em estrutura operacional dedicada."),
    ("027-031", "Guardrails e correcoes", "Helena identity, pricing rules, aliases de catalogo e correcoes de reward/account status."),
    ("032", "Mobility production schema", "Schema mobility com cost_benchmarks, user_routes, realtime_buffer e view operacional."),
]


KEY_ARTIFACTS = [
    "database/postgres/001_core_identity_wallets.sql",
    "database/postgres/002_financial_ledger_equity_orders.sql",
    "database/postgres/017_v47_priority_domain_delivery_packages.sql",
    "database/postgres/024_v47_ai_memory_operations_business_ddl.sql",
    "database/postgres/027_v47_helena_identity_pricing_guardrails.sql",
    "database/postgres/032_v47_mobility_production_schema.sql",
    "database/mongodb/001_ai_social_telemetry.mongo.js",
    "database/mongodb/003_v47_field_ops_security_agenda.mongo.js",
    "scripts/valley_db_orchestrator.py",
    "docker-compose.yml",
    "output/deployment/VALLEY_DEPLOYMENT_STATUS.md",
    "output/deployment/VALLEY_PRODUCTION_MODE.md",
    "docs/specs/valley_vision.md",
    "docs/specs/valley-helena-master-spec.md",
    "output/pdf/VALLEY_MANUAL_ONLINE.pdf",
    "output/pdf/VALLEY_MEMORANDO_ESTRUTURADO_MODULOS_ECONOMIA.pdf",
]


def load_modules() -> list[dict]:
    return json.loads(MODULES_JSON.read_text(encoding="utf-8"))["modules"]


def parse_contract_matrix() -> dict[str, dict[str, str]]:
    data: dict[str, dict[str, str]] = {}
    text = CONTRACTS_MD.read_text(encoding="utf-8")
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        parts = [part.strip() for part in line.strip().strip("|").split("|")]
        if len(parts) != 7 or parts[0] in {"No", "---:"}:
            continue
        code = parts[1].strip("`")
        data[code] = {
            "phase": parts[4].strip("`"),
            "data_home": parts[5].strip("`"),
            "compliance": parts[6],
        }
    return data


def parse_deployment_status() -> dict[str, str]:
    text = DEPLOYMENT_MD.read_text(encoding="utf-8")
    generated = re.search(r"Gerado em UTC: `([^`]+)`", text)
    checks = re.search(r"Total de checagens: `([^`]+)`", text)
    failures = re.search(r"Falhas ou pendencias: `([^`]+)`", text)
    return {
        "generated_at": generated.group(1) if generated else "n/d",
        "checks": checks.group(1) if checks else "n/d",
        "failures": failures.group(1) if failures else "n/d",
    }


def build_styles():
    styles = getSampleStyleSheet()
    styles["Title"].fontName = "Helvetica-Bold"
    styles["Title"].fontSize = 21
    styles["Title"].leading = 26
    styles["Title"].alignment = TA_CENTER
    styles["Title"].textColor = colors.HexColor("#12312B")
    styles["Title"].spaceAfter = 16

    styles["Heading1"].fontName = "Helvetica-Bold"
    styles["Heading1"].fontSize = 15
    styles["Heading1"].leading = 18
    styles["Heading1"].textColor = colors.HexColor("#16463D")
    styles["Heading1"].spaceBefore = 12
    styles["Heading1"].spaceAfter = 7

    styles["Heading2"].fontName = "Helvetica-Bold"
    styles["Heading2"].fontSize = 11
    styles["Heading2"].leading = 14
    styles["Heading2"].textColor = colors.HexColor("#245B4F")
    styles["Heading2"].spaceBefore = 8
    styles["Heading2"].spaceAfter = 5

    styles["BodyText"].fontName = "Helvetica"
    styles["BodyText"].fontSize = 9
    styles["BodyText"].leading = 12
    styles["BodyText"].textColor = colors.HexColor("#1E2423")
    styles["BodyText"].spaceAfter = 4

    styles.add(
        ParagraphStyle(
            name="Small",
            parent=styles["BodyText"],
            fontSize=8,
            leading=10,
            textColor=colors.HexColor("#465650"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="Caption",
            parent=styles["BodyText"],
            fontSize=8,
            leading=10,
            alignment=TA_CENTER,
            textColor=colors.HexColor("#51615C"),
        )
    )
    return styles


def add_paragraph(story: list, text: str, style) -> None:
    story.append(Paragraph(escape(text), style))


def add_table(story: list, rows: list[list[str]], widths: list[float]) -> None:
    table = Table(rows, colWidths=widths, repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#16463D")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 8),
                ("LEADING", (0, 0), (-1, -1), 10),
                ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#B9C9C2")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.HexColor("#F5F8F6"), colors.white]),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(table)
    story.append(Spacer(1, 0.12 * inch))


def collect_state():
    modules = load_modules()
    matrix = parse_contract_matrix()
    deployment = parse_deployment_status()
    postgres_files = sorted(path.name for path in POSTGRES_DIR.glob("*.sql"))
    mongo_files = sorted(path.name for path in MONGO_DIR.glob("*.js"))
    priority_domains = sorted(path.name for path in PRIORITY_DOMAINS_DIR.iterdir() if path.is_dir())
    snapshot_dirs = sorted(path.name for path in SNAPSHOTS_DIR.iterdir() if path.is_dir()) if SNAPSHOTS_DIR.exists() else []
    pdf_outputs = sorted(path.name for path in OUTPUT_DIR.glob("*.pdf")) if OUTPUT_DIR.exists() else []

    tier_counts = Counter(module["tier"] for module in modules)
    domain_counts = Counter(module["domain"] for module in modules)
    phase_counts = Counter(matrix[module["code"]]["phase"] for module in modules if module["code"] in matrix)
    home_counts = Counter(matrix[module["code"]]["data_home"] for module in modules if module["code"] in matrix)

    by_domain: dict[str, list[dict]] = defaultdict(list)
    for module in modules:
        enriched = {
            **module,
            "phase": matrix.get(module["code"], {}).get("phase", "n/d"),
            "data_home": matrix.get(module["code"], {}).get("data_home", module["data_home"]),
            "compliance": matrix.get(module["code"], {}).get("compliance", ""),
        }
        by_domain[module["domain"]].append(enriched)

    return {
        "modules": modules,
        "by_domain": dict(by_domain),
        "tier_counts": tier_counts,
        "domain_counts": domain_counts,
        "phase_counts": phase_counts,
        "home_counts": home_counts,
        "postgres_files": postgres_files,
        "mongo_files": mongo_files,
        "priority_domains": priority_domains,
        "snapshot_dirs": snapshot_dirs,
        "pdf_outputs": pdf_outputs,
        "deployment": deployment,
    }


def build_markdown(state: dict) -> str:
    lines: list[str] = []
    lines.append("# Memorial Descritivo Completo Do Desenvolvimento - Valley")
    lines.append("")
    lines.append("Base consolidada em 21/04/2026 a partir dos artefatos reais do repositorio.")
    lines.append("")
    lines.append("## Resumo executivo")
    lines.append(f"- 47 modulos registrados e organizados em 9 dominios.")
    lines.append(f"- 32 migrations PostgreSQL declaradas e 4 scripts MongoDB declarados.")
    lines.append(f"- Cobertura atual por fase: VALIDATE={state['phase_counts'].get('VALIDATE', 0)}, BUILD={state['phase_counts'].get('BUILD', 0)}, DATA_CONTRACT={state['phase_counts'].get('DATA_CONTRACT', 0)}.")
    lines.append(f"- Cobertura atual por data home: postgres={state['home_counts'].get('postgres', 0)}, postgres_mongo={state['home_counts'].get('postgres_mongo', 0)}, mongo={state['home_counts'].get('mongo', 0)}.")
    lines.append(f"- 7 dominios prioritarios ja empacotados em database/domain-delivery/priority-domains.")
    lines.append(f"- Relatorio operacional atual: {state['deployment']['checks']} checagens e {state['deployment']['failures']} falhas ou pendencias.")
    lines.append("")
    lines.append("## O que ja foi desenvolvido")
    lines.append("### 1. Nucleo de dados e arquitetura")
    lines.append("- Espinha dorsal `users -> wallets -> orders/transactions/equity` materializada em migrations relacionais.")
    lines.append("- Separacao hibrida formal entre PostgreSQL para identidade, dinheiro, contratos e servicos oficiais; e MongoDB para memoria, social, telemetria e payload volumoso.")
    lines.append("- Control plane institucional para module catalog, backlog, pacotes de dominio e contratos de evento.")
    lines.append("")
    lines.append("### 2. Banco PostgreSQL")
    for code_range, title, summary in MIGRATION_GROUPS:
        lines.append(f"- {code_range}: {title}. {summary}")
    lines.append("")
    lines.append("Arquivos declarados:")
    for file_name in state["postgres_files"]:
        lines.append(f"- database/postgres/{file_name}")
    lines.append("")
    lines.append("### 3. Banco MongoDB")
    lines.append("- Validators e colecoes base para AI, social, telemetria, field ops, wellness e frontier.")
    for file_name in state["mongo_files"]:
        lines.append(f"- database/mongodb/{file_name}")
    lines.append("")
    lines.append("### 4. Modulos e governanca")
    lines.append("- 47 pastas de modulo presentes com README.md, STATUS.md e CONTRACT.md.")
    lines.append("- Roadmap, matriz de contratos, backlog e plano de entrega prioritario gerados em output/module-roadmap/.")
    lines.append("")
    lines.append("### 5. Pacotes de dominio")
    lines.append("- Dominios priorizados com ddl_complement.sql, operational_seed.sql e contratos de evento JSON.")
    for domain in state["priority_domains"]:
        lines.append(f"- {domain}")
    lines.append("")
    lines.append("### 6. Automacao e esteira")
    lines.append("- Orquestrador central em scripts/valley_db_orchestrator.py com check, report, compose-up, apply-compose, seed-compose, smoke-compose, snapshot-compose, snapshot-verify e restore-compose.")
    lines.append("- Compose local com PostgreSQL, MongoDB e painel admin.")
    lines.append("- Documentos de modo producao local, acesso externo e checklist de primeira conexao.")
    lines.append("")
    lines.append("### 7. Evidencias operacionais")
    lines.append(f"- Relatorio em output/deployment/VALLEY_DEPLOYMENT_STATUS.md gerado em {state['deployment']['generated_at']}.")
    lines.append(f"- Snapshots presentes em output/snapshots/: {', '.join(state['snapshot_dirs']) if state['snapshot_dirs'] else 'nenhum snapshot encontrado'}.")
    lines.append(f"- PDFs ja gerados: {', '.join(state['pdf_outputs']) if state['pdf_outputs'] else 'nenhum PDF encontrado'}.")
    lines.append("")
    lines.append("### 8. Frentes institucionais recentes")
    lines.append("- Valley Vision consolidando macroarquitetura, ondas e mapa institucional do ecossistema.")
    lines.append("- Valley Helena Master Spec fechando baseline e governanca de AGENDA, ADVISOR e CHAT.")
    lines.append("- Mobility production schema fechando cost_benchmarks, user_routes, realtime_buffer e view operacional.")
    lines.append("")
    lines.append("## Inventario dos dominios e modulos")
    for domain in DOMAIN_LABELS:
        lines.append(f"### {DOMAIN_LABELS[domain]}")
        lines.append(DOMAIN_SUMMARY[domain])
        for module in state["by_domain"].get(domain, []):
            lines.append(
                f"- {module['number']:02d}. {module['code']} - {module['name']} | fase {module['phase']} | data home {module['data_home']} | {module['description_ptbr']}"
            )
        lines.append("")
    lines.append("## Estado operacional atual")
    lines.append("- O repositorio esta pronto para operacao local controlada e validada.")
    lines.append("- Ainda nao existe, dentro deste worktree, uma infraestrutura remota completa com TLS, secret manager, backup agendado e rotacao automatica para chamar de producao remota plena.")
    lines.append("- O modo de producao atual e local/endurecido, com runbook e evidencias de snapshot e validacao.")
    lines.append("")
    lines.append("## Principais entregas ja materializadas")
    for artifact in KEY_ARTIFACTS:
        lines.append(f"- {artifact}")
    lines.append("")
    lines.append("## Gaps e proximos passos")
    lines.append("- Empacotar institucionalmente os dominios services_health_human e education_work_social.")
    lines.append("- Promover modulos ainda em BUILD e DATA_CONTRACT para DDL e regra operacional fechada.")
    lines.append("- Definir stack de producao remota com segredo centralizado, backup, observabilidade e politica de deploy.")
    lines.append("- Continuar evolucao da frente Helena com explainability, consentimento rastreavel e retention canonica.")
    lines.append("- Continuar a frente mobility com benchmarking operacional por rota e buffer em tempo real.")
    lines.append("")
    return "\n".join(lines)


def build_story(state: dict, styles) -> list:
    story: list = []
    story.append(Spacer(1, 0.55 * inch))
    story.append(Paragraph("Memorial Descritivo Completo Do Desenvolvimento", styles["Title"]))
    story.append(Paragraph("Valley - consolidado a partir dos artefatos reais do repositorio", styles["Caption"]))
    story.append(Spacer(1, 0.12 * inch))
    story.append(Paragraph("Objetivo: registrar de forma institucional tudo que ja foi efetivamente desenvolvido, documentado, validado e empacotado no worktree atual.", styles["Caption"]))
    story.append(PageBreak())

    story.append(Paragraph("Resumo Executivo", styles["Heading1"]))
    add_paragraph(story, f"47 modulos organizados em 9 dominios, com 32 migrations PostgreSQL, 4 scripts MongoDB e 7 dominios prioritarios ja empacotados fisicamente.", styles["BodyText"])
    add_paragraph(story, f"Cobertura por fase: VALIDATE={state['phase_counts'].get('VALIDATE', 0)}, BUILD={state['phase_counts'].get('BUILD', 0)}, DATA_CONTRACT={state['phase_counts'].get('DATA_CONTRACT', 0)}.", styles["BodyText"])
    add_paragraph(story, f"Relatorio operacional atual: {state['deployment']['checks']} checagens e {state['deployment']['failures']} falhas ou pendencias.", styles["BodyText"])

    summary_rows = [
        ["Indicador", "Valor"],
        ["Modulos", "47"],
        ["Dominios", "9"],
        ["Migrations PostgreSQL", str(len(state["postgres_files"]))],
        ["Scripts MongoDB", str(len(state["mongo_files"]))],
        ["Dominios prioritarios empacotados", str(len(state["priority_domains"]))],
        ["Checks operacionais", state["deployment"]["checks"]],
        ["Falhas ou pendencias", state["deployment"]["failures"]],
    ]
    add_table(story, summary_rows, [3.3 * inch, 2.7 * inch])

    story.append(Paragraph("Arquitetura e Banco De Dados", styles["Heading1"]))
    add_paragraph(story, "O desenvolvimento ja materializou um backbone hibrido com no central em users e wallets, mais orders, transactions e equity_ledger como trilha oficial de operacao.", styles["BodyText"])
    add_paragraph(story, "PostgreSQL carrega identidade, dinheiro, contratos, pedidos, compliance e servicos oficiais. MongoDB carrega AI memory, social, telemetria, sensores e payload volumoso.", styles["BodyText"])

    migration_rows = [["Faixa", "Bloco", "Descricao"]]
    migration_rows.extend([[a, b, c] for a, b, c in MIGRATION_GROUPS])
    add_table(story, migration_rows, [0.7 * inch, 1.7 * inch, 4.1 * inch])

    story.append(Paragraph("Arquivos PostgreSQL Declarados", styles["Heading2"]))
    for file_name in state["postgres_files"]:
        add_paragraph(story, f"- {file_name}", styles["Small"])

    story.append(Paragraph("Arquivos MongoDB Declarados", styles["Heading2"]))
    for file_name in state["mongo_files"]:
        add_paragraph(story, f"- {file_name}", styles["Small"])

    story.append(PageBreak())
    story.append(Paragraph("Governanca Modular E Pacotes", styles["Heading1"]))
    add_paragraph(story, "O worktree contem 47 pastas de modulo com README, STATUS e CONTRACT, alem de roadmap, matriz de contratos, backlog e plano de execucao automatizado.", styles["BodyText"])
    add_paragraph(story, "Os dominios prioritarios ja empacotados possuem ddl_complement.sql, operational_seed.sql e contratos de evento JSON, formando o primeiro circuito institucional de entrega.", styles["BodyText"])

    phase_rows = [["Fase", "Quantidade"]]
    for phase in ["VALIDATE", "BUILD", "DATA_CONTRACT"]:
        phase_rows.append([phase, str(state["phase_counts"].get(phase, 0))])
    add_table(story, phase_rows, [3.0 * inch, 3.0 * inch])

    add_paragraph(story, "Dominios prioritarios presentes em database/domain-delivery/priority-domains:", styles["BodyText"])
    for domain in state["priority_domains"]:
        add_paragraph(story, f"- {domain}", styles["Small"])

    story.append(Paragraph("Inventario De Dominios E Modulos", styles["Heading1"]))
    for domain in DOMAIN_LABELS:
        story.append(Paragraph(DOMAIN_LABELS[domain], styles["Heading2"]))
        add_paragraph(story, DOMAIN_SUMMARY[domain], styles["BodyText"])
        for module in state["by_domain"].get(domain, []):
            add_paragraph(
                story,
                f"{module['number']:02d}. {module['code']} - fase {module['phase']} - {module['data_home']} - {module['description_ptbr']}",
                styles["Small"],
            )

    story.append(PageBreak())
    story.append(Paragraph("Automacao, Evidencias E Estado Operacional", styles["Heading1"]))
    add_paragraph(story, "A esteira ja foi institucionalizada com o script scripts/valley_db_orchestrator.py, cobrindo check, report, compose-up, apply, seed, smoke, snapshot, verify e restore.", styles["BodyText"])
    add_paragraph(story, f"O relatorio atual foi gerado em {state['deployment']['generated_at']} e registrou {state['deployment']['checks']} checagens com {state['deployment']['failures']} falhas ou pendencias.", styles["BodyText"])
    add_paragraph(story, "O modo de producao documentado hoje e producao local controlada. O proprio repositorio registra que ainda faltam banco remoto endurecido, TLS, secret manager, backup automatizado e politica de rotacao para classificar como producao remota plena.", styles["BodyText"])

    evid_rows = [["Evidencia", "Estado atual"]]
    evid_rows.append(["Snapshots", ", ".join(state["snapshot_dirs"]) if state["snapshot_dirs"] else "nenhum snapshot encontrado"])
    evid_rows.append(["PDFs gerados", ", ".join(state["pdf_outputs"]) if state["pdf_outputs"] else "nenhum PDF encontrado"])
    evid_rows.append(["Documento de producao", "output/deployment/VALLEY_PRODUCTION_MODE.md"])
    evid_rows.append(["Relatorio de deployment", "output/deployment/VALLEY_DEPLOYMENT_STATUS.md"])
    add_table(story, evid_rows, [1.8 * inch, 4.2 * inch])

    story.append(Paragraph("Frentes Institucionais Recentes", styles["Heading1"]))
    add_paragraph(story, "Valley Vision consolidou o mapa executivo do ecossistema, suas ondas, hubs e regras de empacotamento.", styles["BodyText"])
    add_paragraph(story, "Valley Helena Master Spec consolidou a camada mestra de AGENDA, ADVISOR e CHAT, descrevendo consentimento, explainability, retention e memory promotion.", styles["BodyText"])
    add_paragraph(story, "A migration 032 fechou a frente mobility production com benchmark de rota, buffer em tempo real e view operacional para cidade, mobilidade e seguranca.", styles["BodyText"])

    story.append(Paragraph("Principais Artefatos Ja Materializados", styles["Heading1"]))
    for artifact in KEY_ARTIFACTS:
        add_paragraph(story, f"- {artifact}", styles["Small"])

    story.append(PageBreak())
    story.append(Paragraph("Conclusao E Proximos Passos", styles["Heading1"]))
    add_paragraph(story, "O que ja foi desenvolvido vai muito alem de um conjunto de ideias: ha schema relacional, schema NoSQL, modulo canonico, contratos, backlog, seeds, automacao, relatorios operacionais, snapshots e documentacao executiva.", styles["BodyText"])
    add_paragraph(story, "Os proximos passos naturais sao empacotar os dois dominios ainda fora do circuito formal, promover modulos BUILD/DATA_CONTRACT para estrutura de negocio fechada e endurecer a trilha de producao remota.", styles["BodyText"])
    add_paragraph(story, "Este memorial descreve o estado efetivamente materializado no repositorio, nao apenas a visao futura.", styles["BodyText"])

    return story


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    state = collect_state()
    OUTPUT_MD.write_text(build_markdown(state), encoding="utf-8")
    styles = build_styles()
    story = build_story(state, styles)
    doc = SimpleDocTemplate(
        str(OUTPUT_PDF),
        pagesize=A4,
        leftMargin=0.6 * inch,
        rightMargin=0.6 * inch,
        topMargin=0.6 * inch,
        bottomMargin=0.6 * inch,
        title="Memorial Descritivo Completo Do Desenvolvimento - Valley",
        author="Codex - Valley",
    )
    doc.build(story)
    print(f"Markdown: {OUTPUT_MD}")
    print(f"PDF: {OUTPUT_PDF}")


if __name__ == "__main__":
    main()
