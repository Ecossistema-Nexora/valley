<!--
PROPOSITO: Reunir contexto para solicitar aumento de quota da API CJDropshipping.
CONTEXTO: O Valley usa a CJ como fornecedor real para catalogo, estoque e importacao incremental.
REGRAS: Nao versionar CPF, documentos pessoais, tokens, API keys ou anexos sensiveis.
-->

# Briefing Persistente: Pedido de Aumento de Quota da API CJDropshipping

## Objetivo

Este documento reúne as informações necessárias para pedir ao ChatGPT que elabore um e-mail detalhado, em inglês, para a CJDropshipping solicitando aumento de quota da API acima do limite diário de 1.000 chamadas por interface.

Destinatário indicado pela documentação oficial da CJ:

`developer@cjdropshipping.com`

## Responsável pelo Pedido

- Nome do responsável: Anderson Carvalho Nazarete
- Identificação pessoal: inserir manualmente apenas se a CJDropshipping exigir no atendimento.

Observação de segurança: não versionar CPF, documento pessoal, prints com dados sensíveis, tokens, API keys ou credenciais no repositório. Esses dados devem entrar somente no e-mail final ou em anexo privado enviado diretamente à CJDropshipping.

## Contexto do Valley

O **Valley** está integrando a CJDropshipping como fornecedor real para catálogo, estoque, importação incremental, cálculo operacional e posterior envio de pedidos. A integração faz parte do fluxo de marketplace/dropshipping do Valley, com foco em catálogo amplo, checkout real e operação responsável sobre APIs de fornecedores.

Script interno relacionado:

`scripts/import_real_stock_catalog.py`

Plano operacional relacionado:

`PLANOS/v033__20260507-030102-brt__gate_producao_apk_cliente_catalogo_10k.md`

## Evidência Local do Problema

Durante a execução do fluxo de importação real de catálogo, os logs do Valley indicaram bloqueio por limite diário da CJDropshipping:

```text
Too Many Requests / daily request limit (1000 times/day)
```

O plano v033 registra explicitamente:

```text
O runtime do fornecedor retornou mensagem de limite diario CJDropshipping `Too Many Requests` / `daily request limit (1000 times/day)`.
```

Impacto direto no Valley:

- O catálogo ficou abaixo da meta operacional de 10.000+ itens.
- A importação incremental precisa continuar em ciclos sem violar limites da API.
- O projeto precisa de quota maior para cobrir mais categorias, atualizar estoque e reduzir dependência de importação lenta em vários dias.

## Confirmações Oficiais Encontradas

### Limite diário

A documentação oficial informa que usuários não verificados possuem limite diário de **1.000 chamadas por dia por interface**. Ao atingir o limite, a API retorna erro `Too Many Requests`.

Fonte:

https://developers.cjdropshipping.cn/en/api/api2/standard/limit.html

### Como pedir aumento

A documentação oficial orienta solicitar aumento de limite por e-mail para:

`developer@cjdropshipping.com`

Materiais exigidos pela CJ:

- Demo da integração, preferencialmente gravação de tela, cobrindo o fluxo completo desde consulta de produtos até envio de pedidos para CJ Store Orders.
- Screenshot do backend da loja mostrando claramente o nome da loja.
- CJdropshipping User ID, por exemplo `CJXXXXXXX`.
- Conta com e-mail verificado e WhatsApp vinculado.
- Informações do solicitante: cenário de uso da API e dados de identidade do solicitante, seja empresa registrada ou desenvolvedor individual.

Fonte:

https://developers.cjdropshipping.cn/en/api/api2/standard/limit.html

### Limites de frequência por segundo

A documentação oficial também informa:

- Base: máximo de 10 requisições por segundo por IP.
- Interfaces sem login: máximo de 30 requisições por segundo.
- Free ou sales level 0/1: 1 req/s.
- Plus ou sales level 2: 2 req/s.
- Prime ou sales level 3: 4 req/s.
- Advanced ou sales level 4/5: 6 req/s.

Fonte:

https://developers.cjdropshipping.cn/en/api/api2/standard/limit.html

### Settings de quota da conta

A API possui endpoint oficial de settings que retorna dados como `quotaLimits`, `quotaType`, `qpsLimit` e perfil da conta, indicando que a quota é controlada por conta/chave/configuração.

Fonte:

https://developers.cjdropshipping.cn/en/api/api2/api/setting.html

### Códigos de erro

A documentação oficial lista erros relacionados a excesso de chamadas e quota usada:

- `1600200`: Too much request.
- `1600201`: Quota has been used up.

Fonte:

https://developers.cjdropshipping.cn/en/api/api2/standard/ps-code.html

### Página oficial da API CJ

A página pública da CJ apresenta a API como integração para importar produtos massivos para lojas e plataformas, com listagem automática, conexão e mecanismo de webhook para sincronização.

Fonte:

https://cjdropship.com/cj-api/

## Dados Que Anderson Precisa Preencher Antes do Envio

- CJ User ID: `[PREENCHER]`
- Conta/e-mail CJDropshipping: `[PREENCHER]`
- WhatsApp vinculado à conta CJ: `[PREENCHER]`
- Nome da loja: `[PREENCHER]`
- Plataforma da loja: `[Shopify / WooCommerce / plataforma própria / outra]`
- Domínio da loja: `[PREENCHER]`
- Domínio/API backend do Valley: `[PREENCHER]`
- Link para demo em vídeo da integração: `[PREENCHER]`
- Link para prints do painel da loja mostrando o nome da loja: `[PREENCHER]`
- Link para prints/logs do erro de limite diário: `[PREENCHER]`
- Nome do responsável: Anderson Carvalho Nazarete
- Tipo do solicitante: `[empresa / desenvolvedor individual]`
- Empresa ou registro, se aplicável: `[PREENCHER]`
- Documento pessoal, somente se exigido pela CJ e enviado por canal privado: `[PREENCHER MANUALMENTE NO E-MAIL FINAL]`

## Pedido Técnico e Comercial

Solicitar aumento inicial para:

**10.000+ chamadas/itens por dia**

O e-mail deve explicar que o Valley precisa importar, validar e manter atualizado um catálogo grande da CJDropshipping, respeitando os limites técnicos de QPS, evitando chamadas redundantes e mantendo um fluxo responsável de sincronização.

Também deve perguntar explicitamente:

- Existe plano **VIP**, conta verificada, conta Prime/Advanced, acesso empresarial, API key dedicada ou acordo comercial para quota maior?
- Existe quota dedicada para importação de catálogo em larga escala?
- Existe alguma opção de quota muito alta ou ilimitada, mesmo que dependa de aprovação comercial/técnica?
- Após a verificação da conta, qual quota diária e qual QPS podem ser liberados para o caso do Valley?

## Compromissos Técnicos do Valley

O e-mail deve afirmar que o Valley adotará:

- Paginação incremental controlada.
- Cache local de produtos e respostas já processadas.
- Deduplicação de produtos já importados.
- Rate limiting por segundo compatível com o nível de conta aprovado.
- Backoff exponencial apenas para falhas transitórias.
- Pausa automática ao detectar `Too Many Requests` ou quota diária esgotada.
- Jobs agendados em vez de sincronização agressiva em tempo real.
- Separação entre importação completa, atualização de preço/estoque e envio de pedidos.
- Monitoramento de erros `1600200`, `1600201` e mensagens de quota.
- Redução de chamadas repetidas contra endpoints de produto, estoque, frete e pedidos.

## Prompt Para Encaminhar ao ChatGPT

Copie o conteúdo abaixo para o ChatGPT e peça a geração do e-mail final:

```markdown
Você é um redator técnico-comercial bilíngue. Escreva um e-mail profissional em inglês para a equipe de desenvolvedores da CJDropshipping solicitando aumento de quota da API.

Destinatário: developer@cjdropshipping.com

Responsável: Anderson Carvalho Nazarete

Contexto:
O Valley está integrando a CJDropshipping como fornecedor real para catálogo, estoque e pedidos dentro de um ecossistema marketplace/dropshipping. O processo automatizado de importação usa paginação, cache local, deduplicação e rate limiting responsável. O script interno relacionado é `scripts/import_real_stock_catalog.py`.

Problema:
Durante a importação real de catálogo, o Valley recebeu erro de limite diário:

`Too Many Requests / daily request limit (1000 times/day)`

A documentação oficial da CJDropshipping confirma que usuários não verificados possuem limite diário de 1.000 chamadas por dia por interface e orienta solicitar aumento pelo e-mail developer@cjdropshipping.com.

Fontes oficiais:
- Access Frequency Restrictions: https://developers.cjdropshipping.cn/en/api/api2/standard/limit.html
- Settings / quotaLimits / qpsLimit: https://developers.cjdropshipping.cn/en/api/api2/api/setting.html
- Global Error Codes: https://developers.cjdropshipping.cn/en/api/api2/standard/ps-code.html
- CJ API official page: https://cjdropship.com/cj-api/

Pedido:
Solicitar aumento inicial para 10.000+ chamadas/itens por dia para permitir importação e sincronização de catálogo em larga escala.

Compromissos técnicos:
O Valley usará paginação incremental, cache local, deduplicação, rate limiting por segundo conforme o nível aprovado da conta, backoff responsável, jobs agendados, pausa automática em `Too Many Requests`, e monitoramento dos erros `1600200` e `1600201`.

Perguntas que o e-mail deve fazer explicitamente:
1. Existe plano VIP, conta verificada, Prime/Advanced, acesso empresarial, API key dedicada ou acordo comercial para quota maior?
2. Existe quota dedicada para importação de catálogo em larga escala?
3. Existe alguma opção de quota muito alta ou ilimitada, mesmo sujeita a aprovação comercial/técnica?
4. Após a verificação, qual quota diária e qual QPS podem ser liberados para o caso do Valley?

Campos que devem aparecer no e-mail para preenchimento antes do envio:
- CJ User ID: [PREENCHER]
- CJ account email: [PREENCHER]
- WhatsApp bound to CJ account: [PREENCHER]
- Store name: [PREENCHER]
- Store platform: [PREENCHER]
- Store domain: [PREENCHER]
- Valley backend/API domain: [PREENCHER]
- Integration demo video link: [PREENCHER]
- Store backend screenshot link: [PREENCHER]
- Daily limit error screenshot/log link: [PREENCHER]
- Applicant type: [company / individual developer]
- Company registration or applicant identity information, if requested by CJ: [PREENCHER EM CANAL PRIVADO]

Gere:
- Subject line
- E-mail completo em inglês
- Tom profissional, objetivo e cordial
- Lista de anexos/links
- Pedido claro de próximos passos para verificação e aumento de quota
```

## Observação Final

Não há evidência oficial de opção ilimitada pública. A documentação confirma aumento mediante verificação/contato, mas não promete quota ilimitada. Por isso, o e-mail deve perguntar sobre quota muito alta ou dedicada sem afirmar que ela existe.
