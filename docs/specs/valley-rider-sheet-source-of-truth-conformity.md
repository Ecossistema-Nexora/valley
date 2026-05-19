# Valley Rider — Conformidade Absoluta com Sheet/Stitch

Escopo exclusivo deste documento: **Valley Rider**.

Este contrato torna o payload gerado pelo Sheet/Stitch a fonte da verdade operacional para o APK Rider, sem apagar nada do que já existia no Rider e sem transformar o Rider em ERP.

## 1. Princípio central

O Sheet/Stitch é a origem canônica dos dados operacionais de loja, venda, frete físico e pepitas. O APK Rider deve consumir o que for necessário para executar logística de campo:

- entrega originada por venda local;
- ponto de coleta;
- ponto de entrega;
- status do frete;
- comprovante;
- status pós-entrega;
- pepitas vinculadas à conclusão da venda quando aplicável.

O Rider não deve exibir telas administrativas do lojista, cadastros completos de produto, margem, custo interno, fornecedores, integrações externas ou ferramentas de gestão desktop.

## 2. Banco aplicado

Arquivo aplicado:

`database/postgres/037_sheet_source_of_truth_rider_mirror.sql`

Tabelas principais:

- `sheet_source_documents`
- `sheet_local_stores`
- `sheet_local_categories`
- `sheet_product_variants`
- `sheet_physical_stock_positions`
- `sheet_sales`
- `sheet_sale_items`
- `sheet_physical_freights`
- `sheet_pepita_gifts`
- `sheet_to_rider_mirror_jobs`

Views canônicas para Rider:

- `sheet_rider_delivery_truth_view`
- `sheet_rider_pepita_truth_view`

## 3. Espelhamento para Rider

O APK Rider deve usar a cadeia:

1. Sheet gera venda/frete.
2. Sistema grava `sheet_sales` e `sheet_physical_freights`.
3. Sistema cria ou atualiza `orders` e `delivery_shipments`.
4. Sistema cria registro em `sheet_to_rider_mirror_jobs`.
5. Rider consulta `delivery_shipments` e views `sheet_rider_*_truth_view`.
6. Rider executa coleta/entrega.
7. Rider grava eventos em `delivery_shipment_events`.
8. Comprovante grava `document_records`.
9. Sheet/frete é atualizado por sincronização de retorno.

## 4. O que o Rider pode exibir

- Número da venda.
- Loja/origem.
- Endereço de coleta.
- Endereço de entrega.
- Status do frete.
- Código de rastreio.
- Janela de coleta.
- Valor declarado quando necessário para cuidado operacional.
- Quantidade de pacotes quando informado.
- Comprovante de entrega.
- Pepitas concedidas ao cliente apenas como informação pós-entrega, quando isso fizer parte do fluxo de encerramento.

## 5. O que o Rider não pode exibir

- Preço de custo.
- Margem estimada.
- Custo interno do frete para a loja.
- Taxas da plataforma.
- Configurações desktop.
- Atalhos de teclado.
- Tabelas administrativas densas.
- Ferramentas de categoria/produto/estoque.
- Integrações externas ocultas para merchant.

## 6. Telas Rider espelhadas a partir do Sheet

As telas do APK Rider devem incluir:

1. Home mapa-first.
2. Card de entrega originada do sheet.
3. Detalhe da venda/frete espelhado.
4. Coleta.
5. Entrega.
6. Comprovante.
7. Histórico.
8. Ganhos.
9. Status de pepitas pós-entrega.
10. Incidente/SOS.

## 7. Critérios de aceite

- Nenhum campo do sheet é descartado; campos não usados pelo Rider permanecem no banco.
- O Rider só exibe campos relevantes à logística.
- O sheet é rastreável por `sheet_source_documents`.
- Toda entrega espelhada tem fila em `sheet_to_rider_mirror_jobs`.
- Toda conclusão do Rider retroalimenta `delivery_shipments` e pode atualizar `sheet_physical_freights`.
- BR-PRO-001 continua ativa: o Rider não recebe custos internos ou margens.
