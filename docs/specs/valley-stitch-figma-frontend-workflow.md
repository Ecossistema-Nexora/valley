# Valley Stitch + Figma Front-end Workflow

## Objetivo

Todo layout front-end novo do Valley deve partir do Stitch by Google como gerador primario de design, com Figma como camada de inspecao, handoff e refinamento visual. A implementacao final continua em Flutter para manter uma base unica Web + Android.

## Fonte de design

- Stitch app: https://stitch.withgoogle.com/
- Stitch MCP: `https://stitch.googleapis.com/mcp`
- Figma MCP: `https://mcp.figma.com/mcp`
- Figma VS Code extension: `figma.figma-vscode-extension`

## Politica operacional

- Nunca committe `STITCH_API_KEY`, tokens OAuth ou credenciais Figma.
- Use `.env` local para `STITCH_API_KEY` ou o prompt seguro em `.vscode/mcp.json`.
- Antes de alterar layout Flutter, gere ou revise a direcao visual no Stitch.
- Quando houver arquivo Figma, use Figma para inspecionar espacamento, hierarquia, assets e componentes.
- Implementacoes Flutter devem respeitar `frontend/flutter/lib/valley_brand_theme.dart`.

## Tese visual persistente

Visual thesis: cockpit modular premium, escuro e luminoso, com textura de vidro, energia fintech e navegacao de super app.

Content plan: primeiro viewport com command center, metricas operacionais, selecao de modulos da home e dock universal de acesso aos 47 modulos.

Interaction thesis: entrada fade/slide, dock horizontal com destaque do modulo ativo e toggles persistentes para compor a tela inicial sem reabrir configuracoes.

## Prompt base para Stitch

```text
Design a sophisticated Flutter super-app home screen for Valley/Nexora.
The interface must be a premium modular command center with a dark cosmic fintech mood, glass dock, cyan/violet accents, and a flexible home composition.
Users can select which modules appear on the home screen, while a persistent dock gives access to all 47 modules.
Prioritize responsive web and Android layouts, strong hierarchy, compact operational copy, clear module states, and an elegant onboarding-ready first screen.
Avoid generic SaaS cards, purple-only design, cluttered dashboards, and decorative elements that do not help navigation.
```

## Checklist de aceitacao

- A home permite escolher quais modulos aparecem na inicial.
- O dock universal mostra todos os modulos e permite acesso rapido.
- A selecao do usuario e persistida localmente.
- O layout funciona em desktop e mobile.
- O codigo nao depende de segredo no runtime do app.
