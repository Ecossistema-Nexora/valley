<!--
PROPOSITO: Documentar v030 20260505 214500 brt nomenclatura valley helena vcoin no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho PLANOS/v030__20260505-214500-brt__nomenclatura_valley_helena_vcoin.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# Nomenclatura canonica Valley, Helena e V-Coin

## Resumo

Remover a nomenclatura de produto antiga das superficies atuais do Valley. A regra passa a ser:

- Produto/ecossistema: `Valley`
- Assistente/camada de IA: `Helena`
- Token/moeda: `V-Coin`

Referencias tecnicas ao repositorio GitHub `Ecossistema-Nexora/valley` ficam como excecao obrigatoria enquanto este for o remote canonico do projeto.

## Checklist

- [x] Registrar a correcao como plano persistente.
- [x] Criar politica versionada de termos canonicos.
- [x] Criar verificador local para bloquear referencias antigas fora das excecoes tecnicas.
- [x] Atualizar geradores, docs, contratos, seeds e superficies atuais com `Valley`, `Helena` e `V-Coin`.
- [x] Validar varredura de termos e JSON/TOML principais.
- [x] Registrar evidencias e fechar o plano.

## Evidencias

- Pedido direto: "nao existe mais referencia a nexora nem persona nem $NEX agora e Valley Helena e V-Coin".
- Excecao tecnica: o workspace continua preso ao remote `https://github.com/Ecossistema-Nexora/valley.git` por configuracao canonica do projeto.
- Politica criada em `config/brand/VALLEY_BRAND_TERMS.json`.
- Verificador criado em `scripts/check_valley_brand_terms.ps1`.
- Varredura final: `scripts/check_valley_brand_terms.ps1 -Json` retornou `ok=true` em `2026-05-06T01:08:02Z`.
- Validacoes estruturais: JSON principal parseado, TOML da configuracao Codex parseado, `scripts/check_valley_mcp_config.ps1` retornou `ok=true`, `python scripts/valley_db_orchestrator.py check` retornou OK e `dart format --output=none lib/src/ui/valley_product_shell.dart` passou sem alteracoes.

## Bloqueios

- Nao ha bloqueio para texto, geradores e seeds.
- Renome de coluna aplicada em banco ja provisionado exige migracao explicita; nos arquivos fonte, a nomenclatura sera atualizada para novos ambientes.

## Resultado

Plano concluido em `2026-05-05 22:08:02 BRT`.
