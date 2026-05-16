<!--
PROPOSITO: Persistir o design system visual por persona e componentes compartilhados Valley.
CONTEXTO: O usuario trouxe a fundacao visual com Design_System, Components, dialeto PT-BR e paletas por Admin/Lojista/Usuario/Entregador.
REGRAS: Transformar a diretriz em contrato repo-bound para Stitch, Figma e Flutter, sem perguntar qual persona priorizar.
-->

# v066 - Persona Design System Components

## Resumo

Formalizar a fundacao visual Valley por persona e criar componentes compartilhados de interface para as superficies mobile/web futuras.

## Checklist

- [x] Persistir tokens estruturados por persona em `config/design`.
- [x] Atualizar `docs/specs/valley_stitch_design_system_v060.md`.
- [x] Criar componentes Flutter compartilhados para TopAppBar, BottomNavBar e NavigationDrawer.
- [x] Atualizar contrato JSON Stitch/Figma/Flutter com a nova fonte de design.
- [x] Validar JSON/Dart format e recalcular planos.

## Diretriz Visual

- Admin: fundo preto, acentos neon, governanca e controle.
- Lojista / ERP: ciano produtivo, densidade operacional e foco empresarial.
- Usuario: fundo claro, consumo, Helena e jornada fluida.
- Entregador: chumbo, alto contraste e legibilidade em transito.

## Bloqueios

- `flutter analyze lib\src\ui\valley_shared_components.dart --no-pub` excedeu 180s sem diagnostico; processo Dart encerrado. `dart format` e `python -m json.tool` passaram.
