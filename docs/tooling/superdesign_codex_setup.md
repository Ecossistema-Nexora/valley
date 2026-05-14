<!--
PROPOSITO: Registrar o uso de SuperDesign com Codex no workspace Valley.
CONTEXTO: Este documento orienta instalacao, persistencia no repo e handoff de conceitos visuais.
REGRAS: Manter artefatos locais fora do git e alinhar geracoes visuais ao fluxo oficial Valley.
-->

# SuperDesign + Codex no VALLEY

## Objetivo

Configurar a extensao oficial `SuperdesignDev.superdesign-official` para gerar conceitos visuais no editor e repassar a implementacao ao Codex dentro do fluxo do VALLEY.

## O que ficou persistido no repo

- Recomendacao da extensao em `.vscode/extensions.json`.
- Isolamento de artefatos locais da extensao em `.gitignore` para `.superdesign/`.
- Regra de handoff em `.cursor/rules/design.mdc` para manter as geracoes alinhadas ao produto.

## Instalacao

Instale a extensao oficial:

- Marketplace: `SuperdesignDev.superdesign-official`
- Link direto: `https://marketplace.visualstudio.com/items?itemName=SuperdesignDev.superdesign-official`

No VS Code ou Cursor:

1. Abra Extensions.
2. Procure por `Superdesign`.
3. Instale `Superdesign Dev`.

## Inicializacao no workspace

Depois da instalacao, execute estes comandos da extensao:

1. `Superdesign: Initialize Superdesign`
2. `Superdesign: Show Chat Sidebar`
3. `Superdesign: Open Canvas View`
4. `Superdesign: Open Settings`

Os designs gerados ficam em `.superdesign/` no root do workspace.

## Configuracao de modelo

Pelas configuracoes publicadas da extensao, os providers suportados hoje sao:

- `anthropic`
- `openai`
- `openrouter`
- `claude-code`

Para uso com stack OpenAI compativel:

1. Abra `Superdesign: Open Settings`.
2. Defina `AI Model Provider` como `openai`.
3. Preencha `OpenAI Api Key`.
4. Se estiver usando um endpoint compativel customizado, preencha `OpenAI Url`.

Observacao: nao encontrei nas configuracoes publicas da extensao um provider nomeado `codex`. O caminho suportado e usar `openai` como provider compativel e fazer o handoff de implementacao para o Codex no editor.

## Fluxo recomendado no VALLEY

1. Gerar o mock ou componente no SuperDesign.
2. Refinar o prompt ate a estrutura visual ficar correta.
3. Copiar o handoff para o Codex implementar no Flutter.
4. Manter o alinhamento com `.cursor/rules/design.mdc`.
5. Seguir o padrao do projeto: `Stitch -> Figma -> Flutter` quando o trabalho exigir maturidade maior de design.

## Prompt base para usar com o SuperDesign

```text
Design a Flutter-first responsive screen for Valley.
Brand direction: bold, intentional, premium, no generic SaaS patterns.
Use pt-BR content.
Keep the home modular and context-aware.
Do not show PAY indicators when PAY is inactive.
Helena must remain circular with Valley star identity, draggable, and discreet.
Return layout, components, states, motion, tokens, and a Codex-ready Flutter implementation handoff.
```

## Verificacao rapida

- A recomendacao da extensao aparece em `.vscode/extensions.json`.
- O workspace ignora `.superdesign/` no versionamento.
- A regra `.cursor/rules/design.mdc` passou a existir para orientar o handoff visual.
