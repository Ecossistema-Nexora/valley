<!--
PROPOSITO: Registrar o uso de Superflex com Codex no workspace Valley.
CONTEXTO: Este documento orienta extensao, configuracao persistente e alinhamento com o fluxo de design.
REGRAS: Desativar analytics conforme politica local e manter handoff visual controlado pelo repo.
-->

# Superflex + Codex no VALLEY

## Objetivo

Configurar a extensao oficial `aquilalabs.superflex` de forma persistente no workspace do VALLEY, com uso alinhado ao Codex e ao fluxo de design do projeto.

## O que ficou persistido no repo

- Recomendacao da extensao em `.vscode/extensions.json`.
- Desativacao de analytics no workspace em `.vscode/settings.json`.
- Alinhamento de handoff visual em `.cursor/rules/design.mdc`.

## Extensao oficial

- Marketplace: `aquilalabs.superflex`
- Link direto: `https://marketplace.visualstudio.com/items?itemName=aquilalabs.superflex`
- Repositorio publico: `https://github.com/aquila-lab/superflex-vscode`

## Instalacao

No VS Code ou Cursor:

1. Abra `Extensions`.
2. Procure por `Superflex`.
3. Instale `Aquila Labs / Superflex`.

Ou por comando:

```powershell
code --install-extension aquilalabs.superflex
```

## Inicializacao

Segundo a documentacao publica da extensao, o fluxo basico e:

1. Abrir o projeto no editor.
2. Abrir o painel lateral do `Superflex`.
3. Usar `Ctrl+;` no Windows para focar a interface da extensao.
4. Fazer `Sign In` no proprio painel da extensao.
5. Opcionalmente conectar a conta Figma com `Superflex: Connect Figma Account`.

## Comandos relevantes

Pelos comandos publicados da extensao, os principais sao:

- `Superflex: Sign In`
- `Superflex: Sign Out`
- `Superflex: Settings`
- `Superflex: Connect Figma Account`
- `Superflex: Disconnect Figma Account`
- `Superflex: New Chat Thread`
- `Superflex: Refresh`

## Atalhos relevantes

- `Ctrl+;`: focar o input do chat do Superflex
- `Ctrl+M`: adicionar selecao atual ao chat

## Ajuste persistido

O workspace agora define:

```json
"superflex.analytics": false
```

Isso reduz coleta de analytics no contexto do repo.

## Como usar com Codex no VALLEY

O Superflex foi desenhado para Figma-to-code, image-to-code, codebase chat e diffs no editor. No VALLEY, o uso recomendado e:

1. Usar Superflex para explorar layout, estrutura, hierarquia e componentes.
2. Se o output vier em React, Vue, Next.js, Angular, HTML ou CSS, tratar isso como draft de implementacao.
3. Entregar o draft ao Codex para traduzir para a stack correta do repositorio:
   - Flutter para `frontend/flutter`
   - HTML/CSS/JS para a superficie `admin` quando o alvo for o painel web
4. Manter o fluxo institucional do projeto para design mais maduro:
   `Stitch -> Figma -> Flutter`

## Prompt base recomendado

```text
Design a production-ready Valley interface.
Use pt-BR content.
Preserve the Valley brand, avoid generic SaaS patterns, and keep actions real.
Return layout hierarchy, components, states, responsive notes, motion, and an implementation draft that Codex can translate to the target stack in this repo.
If the target is Flutter, describe widgets and state behavior instead of only web-specific code.
```

## Limites importantes

- A extensao publica suporte a login proprio, conta Figma, chat de codebase e diffs no editor.
- Nao encontrei nas configuracoes publicas da extensao um provider local configuravel via workspace como no SuperDesign.
- Por isso, a parte autenticada continua sendo feita no proprio painel do Superflex e nao foi versionada no repo.
