# Valley ERP Desktop Windows

Escopo exclusivo: ERP do lojista local para Windows Desktop (.exe).

## Regras mandatórias

- O lojista gerencia apenas estoque físico local.
- Integrações de importação e dropshipping ficam bloqueadas e ocultas para perfis Merchant.
- O layout é desktop-first widescreen 16:9, com sidebar retrátil, tabelas densas, atalhos de teclado e notificações no canto inferior direito.
- O splash deve exibir `valley_desktop_opening_final_animated.mp4` uma única vez antes do login.
- Login, dashboard e relatórios usam `VALLEY-ERP.png`.
- Telas internas usam `VALLEY-BOTON` como âncora visual discreta.

## Módulos do fluxo completo

1. Login com splash obrigatório.
2. Dashboard operacional.
3. Produtos, variações e categorias locais.
4. Estoque físico local.
5. Ordens de venda.
6. Gestão de frete físico.
7. Concessão manual de pepitas na conclusão da venda: 1, 10 ou 100 pepitas, equivalentes a R$3, R$30 ou R$300.
8. Relatórios master.
9. Configurações locais do ERP.

## Build

```bash
npm install
npm run tauri:build
```

O pacote Windows deve gerar instalador NSIS e executável desktop.
