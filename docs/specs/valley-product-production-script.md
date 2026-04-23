# Valley Product Production Script

## Objetivo
Este script define a versao de simulacao mais realista do Valley em modo produto final para usuario, com:

- tela inicial premium
- Helena sempre ativa em overlay
- 47 modulos com telas principais e telas adjacentes
- fluxos sem botoes mortos
- dados ficticios persistentes e coerentes
- direcao pronta para Stitch, Figma e implementacao Flutter

## Fonte obrigatoria
- Toda tela nasce primeiro no Stitch.
- Figma entra como camada de inspecao, handoff e refinamento.
- Flutter implementa a versao funcional Web + Android.

## Regras de produto
- Nada de DevTools visivel.
- Nada de logs visiveis.
- Nada de placeholders tecnicos.
- Toda acao clicavel leva a uma tela, modal, detalhe, checkout, conversa, feed, mapa ou confirmacao.
- Toda tela deve parecer pronta para uso real.
- Toda simulacao usa dados ficticios consistentes com a narrativa de produto.

## Regra de massa de dados
- Cada um dos 47 modulos deve possuir 100 registros ficticios centrais.
- Total base: 4.700 registros principais.
- Cada modulo tambem deve herdar ou compor dados auxiliares conforme o tipo:
  - perfis
  - cards
  - ofertas
  - conversas
  - pedidos
  - transacoes
  - feeds
  - alertas
  - mapas
  - documentos
  - extratos

## Script da tela inicial
### Topbar
- Marca Valley no topo com leitura premium.
- Campo de busca global com resultado para modulos, itens, perfis, pedidos e conversas.
- Atalhos vivos para notificacoes, carteira, perfil e Helena.
- Estado contextual:
  - online
  - entrega em andamento
  - pedido ativo
  - consulta agendada

### Hero principal
- Hero curto e forte.
- Headline com orientacao de produto e continuidade.
- CTA primario:
  - continuar jornada atual
- CTA secundario:
  - explorar modulos
- CTA terciario:
  - falar com Helena

### Blocos centrais da home
- resumo financeiro
- pedidos em curso
- atalhos para Marketplace, Food e Mobility
- continuidade de conversa
- feed ativo
- recomendacoes de Helena
- historico recente
- favoritos do usuario

### Dock flutuante
- flutua somente com o app aberto
- arraste horizontal
- expandir lista de modulos
- recolher automaticamente apos selecao
- nunca cobre a Helena

## Script da Helena
### Estado mandatario
- Helena sempre visivel em overlay flutuante.
- Nunca some da sessao.
- Pode alternar entre expandida e minimizada.

### Helena expandida
- rosto animado com emocao:
  - calm
  - happy
  - focus
  - alert
- voz ativa em portugues brasileiro
- fala contextual ao abrir modulos, detalhes, checkout, chat, feed e extrato
- botao de fala ativo
- mensagem viva conforme a tela

### Helena minimizada
- forma obrigatoria: estrela da logomarca Valley
- pequena, brilhante, reconhecivel
- toque para expandir
- sem desaparecer do overlay

### Gatilhos de emocao
- `happy`: sucesso de compra, pedido concluido, conversa respondida
- `focus`: detalhe de produto, mapa de corrida, leitura de documento
- `calm`: home, extrato, agenda, perfil
- `alert`: erro de pagamento, estoque baixo, documento pendente, alerta de seguranca

### Falas de referencia
- home: "Helena ativa. Sua experiencia Valley esta pronta."
- detalhe: "Abrindo detalhes completos com video, descricao e proximos passos."
- checkout: "Checkout pronto. Revise e finalize quando quiser."
- mobility: "Veiculo localizado. A rota ja esta tracada."
- food: "Ofertas atualizadas. O tempo medio de entrega esta visivel."
- chat: "Conversa pronta. O contexto foi mantido."
- extrato: "Seu historico financeiro foi atualizado."

## Regra de interacao global
- Todo card abre detalhe.
- Todo detalhe abre acao primaria.
- Toda acao primaria gera:
  - checkout
  - pedido
  - mapa
  - conversa
  - comprovante
  - confirmacao
- Toda lista abre detalhe contextual.
- Toda notificacao abre sua origem real.
- Todo modulo tem:
  - tela principal
  - pelo menos 3 telas adjacentes
  - CTA principal
  - CTA secundario
  - retorno para home

## Matriz dos 47 modulos
Cada linha abaixo representa a tela principal do modulo e a sequencia minima adjacente obrigatoria.

| Codigo | Modulo | Tela principal | Telas adjacentes obrigatorias | CTA vivos | Base ficticia minima |
|---|---|---|---|---|---|
| `REPLY` | Valley REPLY | cockpit ERP/WMS | rotina, centro de pedidos, painel operacional, detalhe de ordem | abrir rotina, aprovar, exportar | 100 rotinas |
| `STOCK` | Valley Stock | estoque premium | detalhe de item, lote, hub, transferencia | movimentar, reservar, reabastecer | 100 SKUs |
| `LOG` | Valley Log | rastreio inteligente | detalhe de envio, linha do tempo, prova de entrega, conversa | rastrear, falar com suporte | 100 entregas |
| `FOOD` | Valley Food | vitrine de ofertas | detalhe de restaurante, detalhe de prato, carrinho, checkout | pedir, repetir, acompanhar | 100 ofertas |
| `DELIVERY` | Valley Delivery | painel de couriers | pedido ativo, rota, detalhe do entregador, comprovante | chamar, acompanhar, confirmar | 100 corridas |
| `WMS` | Valley WMS | operacao de armazem | corredor, lote, coleta, conferencia | alocar, separar, concluir | 100 operacoes |
| `MARKETPLACE` | Valley Marketplace | catalogo premium | detalhe do produto, video, checkout, comprovante | comprar, salvar, ver video | 100 listings |
| `PAY` | Valley Pay | carteira e saldo | pix, transferencia, cartao, comprovante | pagar, transferir, receber | 100 transacoes |
| `FLEET` | Valley Fleet | frota e telemetria | veiculo, rota, manutencao, alerta | abrir veiculo, agendar, corrigir | 100 veiculos |
| `SERVICES` | Valley Services | servicos sob demanda | vitrine de profissionais, agenda, checkout, conversa | contratar, reagendar, avaliar | 100 servicos |
| `DIGITAL` | Valley Digital | ativos digitais | detalhe do ativo, compra, historico, carteira | comprar, listar, transferir | 100 ativos |
| `REAL_ESTATE` | Valley Real Estate | imoveis tokenizados | detalhe do imovel, simulacao, proposta, documento | investir, visitar, consultar | 100 unidades |
| `HEALTH` | Valley Health | cuidado preditivo | consulta, exame, prontuario, checkout | agendar, falar, pagar | 100 registros |
| `EDU` | Valley Edu | trilhas educacionais | curso, aula, modulo, certificacao | iniciar, continuar, concluir | 100 trilhas |
| `TECH` | Valley Tech | builder de produtos | stack, projeto, recurso, deploy | abrir projeto, contratar, publicar | 100 assets |
| `JOBS` | Valley Jobs | matchmaking | vaga, candidatura, conversa, agenda | candidatar, favoritar, conversar | 100 vagas |
| `NEWS_PODCAST` | Valley News & Podcast | feed editorial | episodio, artigo, player, salvar | ouvir, ler, compartilhar | 100 midias |
| `ADS` | Valley Ads | campanhas locais | campanha, criativo, publico, relatorio | publicar, editar, pausar | 100 campanhas |
| `INFLUENCERS` | Valley Influencers | hub de creators | creator, campanha, comissao, conversa | contratar, acompanhar, pagar | 100 creators |
| `SOCIAL` | Valley Social | feed social | perfil, post, video, comentarios | curtir, comentar, abrir perfil | 100 posts |
| `FITNESS` | Valley Fitness | jornada fitness | treino, desafio, historico, recompensa | iniciar, registrar, compartilhar | 100 treinos |
| `PHARMACY` | Valley Pharmacy | farmacia inteligente | produto, receita, carrinho, checkout | comprar, enviar receita, repetir | 100 itens |
| `VET` | Valley Vet | cuidado pet | pet profile, consulta, vacina, historico | agendar, pagar, conversar | 100 registros |
| `TOURISM` | Valley Tourism | experiencias locais | detalhe da experiencia, reserva, mapa, comprovante | reservar, salvar, compartilhar | 100 experiencias |
| `EVENTS` | Valley Events | tickets seguros | evento, ingresso, checkout, QR | comprar, transferir, entrar | 100 eventos |
| `MOBILITY` | Valley Mobility | chamar veiculo com mapa | origem/destino, rota, ETA, motorista | chamar, cancelar, compartilhar rota | 100 corridas |
| `SECURITY` | Valley Security | seguranca pessoal | SOS, biometria, historico, contato seguro | acionar, monitorar, registrar | 100 alertas |
| `GOV` | Valley Gov | portal cidadao | servico, protocolo, documento, comprovante | solicitar, acompanhar, baixar | 100 protocolos |
| `LEGAL` | Valley Legal | contratos e mediacao | contrato, disputa, mediacao, assinatura | abrir caso, assinar, consultar | 100 casos |
| `CHARITY` | Valley Charity | doacao transparente | causa, checkout, impacto, comprovante | doar, compartilhar, acompanhar | 100 causas |
| `INSURANCE` | Valley Insurance | protecao sob demanda | plano, cotacao, checkout, sinistro | contratar, renovar, acionar | 100 apolices |
| `GAMING` | Valley Gaming | hub gamificado | jogo, desafio, ranking, recompensa | jogar, entrar, resgatar | 100 desafios |
| `IOT` | Valley IoT | dispositivos conectados | device, automacao, evento, historico | ligar, configurar, automatizar | 100 devices |
| `BIO` | Valley Bio | sustentabilidade | acao verde, coleta, impacto, historico | solicitar, acompanhar, validar | 100 eventos |
| `HOME` | Valley Home | automacao residencial | ambiente, cena, device, rotina | ativar, editar, automatizar | 100 rotinas |
| `ENERGY` | Valley Energy | grid inteligente | consumo, troca, oferta, extrato | vender, comprar, acompanhar | 100 leituras |
| `SPACE` | Valley Space | anchors AR | mapa espacial, ponto, experiencia, detalhe | abrir, explorar, salvar | 100 anchors |
| `AGENDA` | Valley Agenda | memoria e listas | agenda diaria, tarefa, lembrete, detalhe | criar, concluir, reagendar | 100 itens |
| `ADVISOR` | Valley Advisor | consultoria IA | card de recomendacao, plano, detalhe, conversa | seguir, pedir ajuda, executar | 100 conselhos |
| `FINANCAS` | Valley Financas | PFM e micro negocio | caixa, extrato, meta, relatorio | registrar, analisar, pagar | 100 lancamentos |
| `MENTE` | Valley Mente | saude mental | check-in, sessao, historico, conteudo | iniciar, registrar, conversar | 100 registros |
| `BUSINESS` | Valley Business | ERP integrado | empresa, rotina, fiscal, resumo | abrir painel, aprovar, exportar | 100 entidades |
| `PLUG` | Valley Plug | maquininha e tap-to-pay | pagamento, recibo, taxa, comprovante | cobrar, estornar, compartilhar | 100 cobrancas |
| `UP` | Valley Up | afiliados | campanha, link, comissao, extrato | divulgar, acompanhar, sacar | 100 campanhas |
| `MEDIA` | Valley Media | painel de criadores | conteudo, analitico, campanha, payout | publicar, impulsionar, sacar | 100 conteudos |
| `CHAT` | Valley Chat | inbox premium | lista, conversa, anexo, historico | abrir, responder, fixar | 100 conversas |
| `DOCS` | Valley Docs | fabrica documental | template, editor, preview, assinatura | gerar, revisar, baixar | 100 documentos |

## Telas adjacentes obrigatorias por tipo
### Produto
- listagem
- detalhe
- video
- checkout
- comprovante

### Servico
- vitrine
- detalhe
- agenda
- checkout
- conversa

### Financeiro
- saldo
- extrato
- detalhe da transacao
- comprovante
- acao de pagamento

### Mobilidade e logistica
- mapa
- rota
- ETA
- perfil do condutor
- comprovante

### Social e conteudo
- feed
- detalhe do post
- perfil
- comentarios
- compartilhamento

### Documental
- lista
- detalhe
- preview
- assinatura
- download

## Script de simulacao realista
### Usuario entra no app
1. Home abre com Helena ja ativa.
2. Helena fala a situacao atual do usuario.
3. Busca global responde modulos, itens, pedidos e conversas.
4. Dock oferece todos os 47 modulos.

### Usuario abre Marketplace
1. Vitrine premium exibe 100 itens do modulo.
2. Card abre detalhe.
3. Video abre player.
4. Botao de compra abre checkout.
5. Checkout gera confirmacao.
6. Confirmacao alimenta extrato e feed.

### Usuario abre Food
1. Tela mostra ofertas e restaurantes.
2. Seleciona item.
3. Abre detalhe do prato.
4. Adiciona ao carrinho.
5. Checkout fecha pedido.
6. Pedido abre acompanhamento com ETA.

### Usuario abre Mobility
1. Tela abre mapa com origem e destino.
2. Mostra rota e ETA.
3. Usuario chama veiculo.
4. App abre tela do motorista.
5. Corrida gera timeline e comprovante.

### Usuario abre Chat
1. Lista de conversas com perfis e status.
2. Conversa abre com contexto.
3. Helena ajusta emocao para foco.
4. CTA contextual pode abrir item, documento ou pagamento.

### Usuario abre Pay
1. Saldo e extrato aparecem.
2. Detalhe de transacao abre modal ou tela.
3. Transferencia gera comprovante.
4. Helena anuncia confirmacao.

## Dados ficticios minimos por modulo
- 100 registros centrais por modulo
- 100 perfis vinculados distribuidos globalmente
- 100 entradas de feed por modulo quando houver natureza social ou promocional
- 100 registros de conversa agregados nos modulos que exigem mensageria
- 100 lancamentos financeiros agregados nos modulos com pagamento
- 100 pontos de mapa ou rota nos modulos logisticos

## Regra anti-botao-morto
Todo botao deve apontar para exatamente um destes destinos:
- abrir tela
- abrir modal
- abrir detalhe
- abrir player
- abrir checkout
- abrir conversa
- abrir comprovante
- abrir mapa
- abrir documento
- executar confirmacao com feedback visivel

Se nao houver backend real ainda, o botao deve:
- atualizar estado da interface
- registrar acao no servidor demo
- refletir efeito em feed, historico, extrato, pedido ou timeline

## Resultado esperado
Ao final, a simulacao deve parecer um produto ja operacional:
- com massa de dados rica
- com Helena viva
- com 47 modulos navegaveis
- com jornadas encadeadas
- com feedback visual e narrativo consistente
- sem qualquer sensacao de prototipo quebrado
