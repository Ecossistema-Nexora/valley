# Valley v47 - Plano Economico para 100 Mil

> **Função:** Define a viabilidade financeira e as regras de governança para o crescimento sustentável.
> **Conexões:** Estabelece os guardrails para a Helena (IA) e as taxas operacionais que alimentam o módulo PAY.

## Resumo executivo

O Valley v47 possui 47 modulos canonicos em 9 dominios. A leitura economica principal e que o ecossistema completo atravessa um vale da morte inicial: com 1.000 ou 10.000 usuarios, o stack inteiro tende a operar deficitario porque os custos fixos de plataforma, IA, atendimento, compliance, pagamentos e operacao fisica chegam antes da densidade de receita.

O ponto de equilibrio do ecossistema completo aparece perto de 100.000 usuarios, com MAU estimado em 48.000, desde que `PAY`, `PLUG`, `BUSINESS`, `DOCS` e `MARKETPLACE` carreguem as jornadas principais. A partir de 1.000.000 usuarios, a margem passa a ser robusta porque SaaS, pagamentos, antecipacao e servicos financeiros subsidiam IA e operacao fisica.

## Diretriz de rollout

O MVP nao deve ligar os 47 modulos de uma vez. A primeira onda operacional e o Combo de Ouro:

- `PAY`
- `PLUG`
- `BUSINESS`
- `DOCS`
- `MARKETPLACE`

Essa onda deve maximizar ARPU desde o primeiro dia, reduzindo dependencia de frete subsidiado e de consumo irrestrito de IA. `REPLY`, `STOCK` e `WMS` entram como suporte operacional quando forem necessarios para estoque, ERP e seller operations. `FOOD`, `DELIVERY` e `MOBILITY` so devem escalar em microzonas com densidade e piso economico aprovados.

## Pilares de margem

`PAY` e `PLUG` sao o coracao financeiro. Sem captura de fluxo transacional, MDR, Pix, antecipacao, conciliacao e float, a margem do ecossistema quebra.

`BUSINESS`, `REPLY` e `DOCS` trazem previsibilidade. Assinatura, implantacao, add-ons fiscais, recibos, contratos e carimbos digitais sao os fluxos que protegem caixa mensal.

`FOOD`, `DELIVERY` e `MOBILITY` sao frentes sensiveis. Elas exigem densidade por microzona, payout sustentavel e bloqueio de rota abaixo do piso. Subsidiar frete ou corrida sem lastro destrói margem.

## Guardrails obrigatorios para Helena

- Helena nao pode emitir recompensa sem fonte pagadora. Pepitas, cashback e bonus devem ser financiados por lojista, campanha de `ADS`, budget de afiliacao ou verba promocional registrada.
- Tarefas pesadas de IA devem ir para fila assincrona. Chat livre ilimitado nao e permitido no modelo agressivo de preco.
- Cada plano deve ter limite de uso de IA, janela de rate limit e politica de degradacao para resposta leve.
- Helena deve travar ou escalar para revisao qualquer corrida, entrega ou rota abaixo do piso economico.
- A execucao automatica deve permanecer em modo seguro: leitura, triagem, status e documentacao podem seguir automaticos; pagamentos, deploys, comandos shell, banco de dados e acoes destrutivas exigem revisao.

## Benchmarks de preco

| Frente | Benchmark Brasil 2026 | Faixa alvo Valley |
| --- | --- | --- |
| Food / Delivery | iFood: 12% a 23% + taxas | 8% a 18%, condicionado a densidade |
| Marketplace | Mercado Livre: 10% a 19% | 9% a 14%, por categoria e risco |
| Pagamentos | Pix 0,49% / Debito 1,99% | Pix 0,39% / Debito 1,49% |
| Mobility | Uber: taxa variavel | 10% a 15%, com piso por rota |
| SaaS / ERP | Bling: R$ 55 a R$ 120 | R$ 49 a R$ 199 por plano |

## Regra de decisao

Antes de ativar uma frente nova, a Helena deve responder:

1. A frente aumenta TPV, assinatura ou margem financeira do Combo de Ouro?
2. Existe fonte pagadora para recompensa, frete, rider ou IA?
3. Existe piso economico por SKU, rota ou plano?
4. Existe registro auditavel em `PAY`, `PLUG`, `DOCS` ou `BUSINESS`?
5. A operacao funciona em uma microzona ou segmento antes de escalar nacionalmente?

Se a resposta for negativa, o modulo fica em modo vitrine, fila, demo ou validacao, sem operacao real subsidiada.
