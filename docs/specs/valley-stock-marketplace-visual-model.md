# Valley Stock Marketplace Visual Model

## Diretriz

O modulo `STOCK` deve se comportar como um grande motor comercial inspirado em Mercado Livre, AliExpress e Shopee, mas com identidade visual propria da Valley.

Isso significa:

- grande catalogo
- busca forte
- ofertas e variacoes de produto
- reputacao de seller
- prova de estoque ou dropshipping
- avaliacao e perguntas
- checkout conectado a `PAY` e `PLUG`
- documento e comprovante via `DOCS`

Mas a interface nao deve copiar a identidade visual de nenhum concorrente.

## Identidade Valley Aplicada Ao Stock

### Visual

- fundo institucional em `night` e `cosmic`
- destaques em `violet` e `cyan`
- cards claros para leitura de produto
- selos de confianca com linguagem simples
- rating e reputacao sem poluicao visual
- foco em produto, preco, prazo e confianca

### Sensacao De Produto

O `STOCK` deve parecer:

- premium
- rapido
- confiavel
- organizado
- comercialmente agressivo
- menos barulhento que marketplaces populares

## Superficies Do Modulo

### Home Do Stock

Componentes esperados:

- busca principal
- categorias
- ofertas relampago controladas
- vitrine de sellers confiaveis
- produtos com margem validada
- recomendacoes da Helena quando habilitadas

### Listagem

Cada produto deve mostrar:

- imagem
- nome curto
- preco final
- prazo estimado
- seller score
- disponibilidade
- origem: estoque proprio, parceiro local ou dropshipping
- selo de competitividade Valley

### Pagina De Produto

Deve conter:

- galeria
- variacoes
- preco
- frete estimado quando existir
- regras de troca
- reputacao do seller
- perguntas e respostas
- prova documental quando aplicavel

### Seller Center

O seller precisa controlar:

- catalogo
- estoque
- preco e margem
- pedidos
- reputacao
- documentos
- pagamentos

## Regras Comerciais

1. Nao vender abaixo da margem minima calculada.
2. Nao prometer entrega subsidiada no MVP.
3. Separar preco do produto, taxa de pagamento e logistica.
4. Bloquear seller sem KYB suficiente.
5. Exigir reputacao minima para destaque.
6. Usar `PAY`, `PLUG` e `DOCS` em toda transacao oficial.

## Conexao Com O MVP

`STOCK` e a ponte entre oferta e receita.

No MVP ele deve alimentar:

- `MARKETPLACE`
- `PAY`
- `PLUG`
- `DOCS`
- `BUSINESS`
- `WMS`

O blueprint de producao do dropshipping inteligente fica em `docs/specs/valley-dropshipping-production-blueprint.md` e e parte do MVP a partir da fase de comercio.

## Integracoes Externas No Admin

O painel admin deve expor configuracao operacional para:

- Mercado Livre
- Amazon
- AliExpress
- Alibaba
- Magalu
- CJDropshipping
- Shopee

Cada integracao deve registrar ambiente, regiao/site, modo de autenticacao, base URL, client/app key, referencias de segredo, seller/store ID, webhook, escopos, cadencia de sincronizacao, margem minima e quais rotinas estao ativas: catalogo, pedidos, estoque e precos.

Credenciais reais nao devem ser salvas no painel ou em arquivo versionado. O padrao e salvar apenas referencias como `vault/marketplaces/shopee/access-token`.

## Diferenca Para Mercado Livre, AliExpress E Shopee

Valley nao deve competir copiando ruido visual, subsidio e guerra de cupom.

Valley deve competir por:

- confianca
- margem controlada
- reputacao clara
- checkout financeiro integrado
- seller onboarding simples
- identidade visual premium
- operacao sem prejuizo

## Requisitos Para Flutter

No Super APK, `STOCK` deve ter:

- aba de descoberta comercial
- busca persistente
- filtros por categoria, preco, prazo e score
- card de produto com selo Valley
- pagina de produto com CTA primario em `violet`
- status de seller em `cyan`
- alertas de risco em `warning` ou `danger`

## Regra Visual Final

O usuario pode lembrar da profundidade de catalogo de Mercado Livre, AliExpress ou Shopee, mas deve reconhecer imediatamente que esta dentro da Valley.
