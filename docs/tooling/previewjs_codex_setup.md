<!--
PROPOSITO: Registrar o uso de Preview.js com Codex no workspace Valley.
CONTEXTO: Este documento explica extensao, limites, estado de manutencao e persistencia no repo.
REGRAS: Nao tratar ferramenta descontinuada como dependencia critica e manter handoff visual documentado.
-->

# Preview.js + Codex no VALLEY

## Objetivo

Registrar de forma persistente o uso da extensao oficial `zenclabs.previewjs` no workspace do VALLEY e deixar claro onde ela ajuda e onde ela nao se aplica neste repo.

## Extensao oficial

- Marketplace: `zenclabs.previewjs`
- Link direto: `https://marketplace.visualstudio.com/items?itemName=zenclabs.previewjs`
- Documentacao: `https://previewjs.com/docs`

## Estado atual da ferramenta

Na documentacao publica atual, o projeto informa que **nao esta mais sendo mantido**. A extensao continua publicada, mas nao deve ser tratada como dependencia estrategica de longo prazo.

## O que ficou persistido no repo

- Recomendacao da extensao em `.vscode/extensions.json`.
- Regra de handoff atualizada em `.cursor/rules/design.mdc`.
- Este runbook em `docs/tooling/previewjs_codex_setup.md`.

## O que o Preview.js suporta

Segundo o Marketplace e a documentacao publica, o foco da extensao e:

- React
- Preact
- Solid
- Svelte
- Vue
- Storybook stories

Ela funciona para abrir previews instantaneos de componentes de UI compativeis dentro do editor.

## Limite importante neste repo

O VALLEY hoje e majoritariamente:

- Flutter em `frontend/flutter`
- HTML/CSS/JS puro em `admin`

Isso significa:

- Preview.js **nao** e ferramenta primaria para as telas Flutter.
- Preview.js **nao** substitui o build real do produto em `admin/product`.
- Preview.js so passa a ser util aqui se surgir uma superficie de componentes React/Vue/Solid/Svelte/Preact versionada no repo.

## Instalacao

No VS Code ou Cursor:

1. Abra `Extensions`.
2. Procure por `Preview.js`.
3. Instale `Zenc Labs / Preview.js`.

Ou por comando:

```powershell
code --install-extension zenclabs.previewjs
```

## Configuracao de projeto compativel

Se voce criar uma superficie compativel no futuro, a configuracao canonica publicada e:

1. Criar `preview.config.js` ao lado do `package.json`.
2. Opcionalmente criar `__previewjs__/Wrapper.tsx` para CSS global, providers e contexto.

Exemplo minimo:

```javascript
// preview.config.js
import { defineConfig } from "@previewjs/config";

export default defineConfig({
  publicDir: "public",
  wrapper: {
    path: "__previewjs__/Wrapper.tsx",
    componentName: "Wrapper",
  },
});
```

## Fluxo recomendado no VALLEY

1. Use Preview.js apenas em subprojetos JS de componentes, se eles existirem.
2. Use o preview para inspecionar estados visuais e contratos de props.
3. Entregue o resultado ao Codex para traduzir para a stack alvo real do repo.
4. Para superfícies principais do produto, preserve a regra do projeto:
   `Stitch -> Figma -> Flutter`

## Comandos uteis

- Abrir preview da extensao a partir de um componente suportado.
- Ajustar `preview.config.js` e `__previewjs__/Wrapper.tsx` quando houver contexto global.
- Validar a tela final do produto pelo build real, nao pelo preview isolado.

## Recomendacao pragmatica

Para o estado atual do VALLEY, Preview.js entra como ferramenta secundaria e opcional. O caminho principal de entrega continua sendo Flutter para produto e build/publish real para `admin/product`.
