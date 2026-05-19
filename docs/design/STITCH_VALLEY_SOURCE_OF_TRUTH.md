PROPOSITO: Registrar a decisao mandataria de fonte da verdade visual e funcional para paineis web e APK Valley.
CONTEXTO: A entrega Stitch v060 foi gerada no projeto privado, publicada localmente e aplicada no admin/Flutter.
REGRAS: Usar Stitch `20260516_valley_erp_v060` como fonte obrigatoria, manter segredos fora do git e nao reintroduzir pacotes 20260513 como produto ativo.

# Stitch Valley Source Of Truth

## Decisao

A entrega Stitch `20260516_valley_erp_v060` passa a ser a fonte da verdade obrigatoria para:

- paineis web em `admin/`;
- ERP lojista executavel;
- trilhas mobile embarcadas no APK;
- handoff Figma versionado;
- release publico de galeria e manifesto.

Os pacotes `20260513_valley_erp` e `20260513_valley_erp_v2` ficam obsoletos e nao devem alimentar painel web, APK ou release novo.

## Artefatos Canonicos

- Configuracao persistente: `config/design/valley_stitch_source_of_truth.json`.
- Manifesto publico: `admin/stitch/20260516_valley_erp_v060/manifest.json`.
- Galeria publica: `admin/stitch/20260516_valley_erp_v060/`.
- Flutter asset: `frontend/flutter/assets/data/valley_stitch_source_of_truth.json`.
- Painel executavel: `admin/app.js` e `admin/index.html`.
- APK/Web Flutter: `frontend/flutter/lib/src/ui/valley_product_shell.dart`.
- Inventario: `docs/design/stitch_valley_erp_v060_inventory.json`.
- Publicacao: `docs/design/STITCH_VALLEY_V060_PUBLICATION.md`.

## Regra De Publicacao

1. Toda tela nova deve apontar para uma chave Stitch v060 do manifesto.
2. Web/admin deve validar manifesto e DOM local antes de release.
3. APK release final deve ser gerado pelo fluxo `END-USER-BUILD` quando solicitado.
4. Figma deve consumir o handoff v060 versionado antes de novas codificacoes grandes.


## Regra definitiva APK Valley Rider (Stitch)

- Fonte da verdade obrigatória: `projects/8342788809405803455`
- URL de referência: `https://stitch.withgoogle.com/projects/8342788809405803455`
- Escopo: APK Valley Rider (fluxos de entregador, logística, roteirização, status de corrida, comprovantes e suporte).
- Regra de evolução: se o template Stitch incluir novas tabelas, campos, passos de fluxo ou componentes de tela, o projeto deve sofrer adequação (migrations, contratos de API e UI) para manter alinhamento total.
- Política de dados: modelo de banco orientado ao Stitch Rider (stitch-first), priorizando compatibilidade com menor custo de manutenção e rollout incremental.
