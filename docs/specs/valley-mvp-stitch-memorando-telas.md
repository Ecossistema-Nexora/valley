# Memorando Descritivo Para Stitch - Valley MVP

## Finalidade

Este documento descreve todas as telas do MVP Valley que devem ser geradas no Stitch by Google como um novo template visual. O objetivo nao e criar uma landing page. O objetivo e gerar uma experiencia real de super app, pronta para Flutter Web + Android, com foco em transacao, identidade, estoque, marketplace e chat.

O MVP deve parecer produto final premium, nao painel tecnico, nao prototipo e nao backoffice exposto ao usuario comum.

## Corte Do MVP

Telas ativas nesta rodada:

- `Home principal / Command Center`
- `Dock universal de modulos`
- `Seletor de modulos visiveis na home`
- `Marketplace`
- `Detalhe de produto`
- `Midia de produto`
- `Checkout preparado`
- `Confirmacao e comprovante`
- `Area do cliente`
- `Pedidos e rastreio`
- `Extrato`
- `Stock`
- `Importacao / sincronizacao de catalogo`
- `Pricing / margem / estoque`
- `Chat`
- `Conversa`
- `Feed contextual`
- `Helena overlay`
- `Identidade: Face ID, Voice ID e Identity Score`
- `Perfil e preferencias`
- `Estados de loading, vazio, sucesso e erro`

Modulos preparados, mas nao expostos como produto completo nesta rodada:

- `PAY`: aparece como contrato visual de carteira, extrato e checkout, mas sem ativar uma carteira completa.
- `PLUG`: aparece como metodo de captura preparado no checkout.
- `DOCS`: aparece como comprovante, recibo e checksum de pedido.
- `BUSINESS`: aparece como onboarding empresarial leve e seller profile.
- `REPLY`: aparece como compras / ordens internas conectadas ao Stock.
- `WMS`: aparece como leitura simplificada de hub, estoque e endereco.

Fora do template MVP completo:

- `FOOD`
- `DELIVERY`
- `MOBILITY`
- `SOCIAL`
- `GAMING`
- `IOT`

Eles podem aparecer no dock como modulos futuros ou desativados, mas o Stitch nao deve criar jornadas completas para eles neste template.

## Direcao Visual Obrigatoria

Criar um cockpit modular premium para o Valley:

- base escura sofisticada com `Night` e `Cosmic`
- acento principal em violeta para compra e decisao
- acento ciano para confianca, status, identidade e operacao
- superficies de vidro sutis, sem excesso de brilho
- cards com raio moderado, leitura clara e hierarquia forte
- iconografia minimalista e consistente
- textos curtos, maduros e operacionais
- sem linguagem de admin tecnico
- sem JSON, logs, debug, console, placeholders ou badges de desenvolvimento
- sem hero de marketing
- primeira tela deve ser o produto em uso

Tokens de marca:

- Night: `#07051F`
- Cosmic: `#151047`
- Violet: `#6F2CFF`
- Lilac: `#BB8CFF`
- Cyan: `#20C8F3`
- Snow: `#FFFFFF`
- Ink: `#121827`

## Arquitetura De Navegacao

O template deve seguir esta estrutura:

- Topbar fixa com marca Valley, busca global, atalhos contextuais, notificacoes, perfil e status de identidade.
- Sidebar em desktop com grupos: Inicio, Marketplace, Stock, Chat, Identidade, Cliente.
- Bottom navigation em mobile com: Inicio, Market, Stock, Chat, Cliente.
- Dock flutuante universal com os modulos do ecossistema, recolhivel e arrastavel.
- Helena como overlay persistente, minimizada em estrela da marca e expansivel em painel curto.
- Todas as telas principais devem funcionar em desktop, tablet e mobile.

## Componentes Globais

### Topbar

Conteudo:

- logomarca Valley
- titulo contextual da tela atual
- busca global
- botao de filtros quando aplicavel
- botao de notificacoes
- botao de perfil
- chip de status de identidade

Botoes:

- `Buscar`: aplica busca global em produtos, pedidos, conversas e modulos.
- `Limpar busca`: remove query atual.
- `Notificacoes`: abre painel de alertas.
- `Perfil`: abre area do cliente.
- `Identidade`: abre tela de Face ID / Voice ID / Score.

Interconexoes:

- Busca em Home leva para Marketplace, Stock, Chat ou pedido encontrado.
- Perfil leva para Area do Cliente.
- Identidade leva para tela de confianca.
- Notificacoes podem abrir pedido, checkout pendente, alerta de estoque ou conversa.

### Dock Universal

Conteudo:

- estado recolhido como botao circular premium
- estado expandido com chips de modulos
- destaque do modulo ativo
- tooltip com nome e finalidade do modulo

Botoes:

- `Abrir dock`: expande lista de modulos.
- `Recolher dock`: volta ao botao compacto.
- `Selecionar modulo`: abre o modulo se estiver ativo.
- `Editar home`: abre seletor de modulos visiveis.

Interconexoes:

- `MARKETPLACE` abre catalogo.
- `STOCK` abre operacao de catalogo e estoque.
- `CHAT` abre inbox.
- `IDENTIDADE` abre score e biometricos.
- Modulos fora do MVP mostram estado `Em preparacao` com acao `Receber aviso`, sem criar jornada completa.

### Helena Overlay

Conteudo:

- estrela Valley minimizada
- estado de humor discreto: calmo, foco, alerta, sucesso
- microfone
- texto curto de resposta
- sugestoes acionaveis

Botoes:

- `Abrir Helena`: expande painel.
- `Minimizar`: retorna para estrela.
- `Microfone`: inicia comando de voz.
- `Enviar`: envia comando digitado.
- `Parar audio`: interrompe fala.

Funcoes:

- navegar para Marketplace, Stock, Chat, Cliente e Identidade
- aplicar busca por voz
- abrir produto sugerido
- explicar status de pedido
- explicar score de identidade
- alertar quando uma acao estiver fora do MVP

Interconexoes:

- Helena pode abrir qualquer tela ativa.
- Em checkout, Helena explica composicao de preco e comprovante.
- Em Stock, Helena sugere produto sem margem, sem estoque ou com oportunidade de preco.
- Em Chat, Helena sugere resposta curta ou resume conversa.

## Telas Do MVP

### 1. Splash / Inicializacao

Objetivo:

Apresentar a marca Valley de forma premium enquanto o app carrega dados essenciais.

Conteudo:

- logo Valley centralizada
- fundo Night com leve profundidade
- indicador discreto de carregamento

Botoes:

- nenhum botao obrigatorio

Funcoes:

- carregar manifest do MVP
- validar sessao local
- preparar rota inicial

Interconexoes:

- sessao existente leva para Home
- sessao ausente leva para Login / Entrada
- falha de rede leva para estado de erro recuperavel

### 2. Login / Entrada

Objetivo:

Permitir entrada segura e rapida sem parecer fluxo bancario pesado.

Conteudo:

- logo Valley
- campo de e-mail, telefone ou documento
- campo de senha ou PIN
- opcao de entrar com biometria quando disponivel
- link para criar conta

Botoes:

- `Entrar`: valida credenciais e leva para Home.
- `Criar conta`: abre onboarding.
- `Usar Face ID`: abre confirmacao biometrica.
- `Recuperar acesso`: abre fluxo de recuperacao.

Funcoes:

- autenticar usuario
- detectar conta PF, PJ ou seller
- iniciar biometria se disponivel

Interconexoes:

- sucesso leva para Home.
- nova conta leva para Onboarding.
- acesso sensivel pode exigir Face ID ou Voice ID.

### 3. Onboarding De Conta

Objetivo:

Criar identidade unica do usuario e preparar marketplace, chat e compras.

Conteudo:

- escolha de perfil: PF, Empresa/Seller, Operador
- dados basicos
- aceite de termos
- etapa de seguranca
- indicacao clara de progresso

Botoes:

- `Continuar`: avanca etapa.
- `Voltar`: retorna etapa.
- `Salvar e sair`: salva rascunho.
- `Ativar seguranca`: abre Face ID / Voice ID.

Funcoes:

- criar usuario canonico
- definir tipo de perfil
- iniciar trilha de KYC/KYB leve
- preparar Identity Score

Interconexoes:

- PF vai para Home.
- Empresa/Seller vai para Onboarding Empresarial.
- Ativacao de seguranca vai para Identidade.

### 4. Onboarding Empresarial / Seller

Objetivo:

Permitir que uma empresa entre no MVP como seller ou operador de catalogo.

Conteudo:

- CNPJ ou documento empresarial
- nome da loja
- categoria principal
- dados de contato
- politica de margem minima
- status de validacao

Botoes:

- `Validar empresa`: consulta dados e atualiza status.
- `Adicionar loja`: cria storefront.
- `Importar catalogo`: leva para Stock Importacao.
- `Pular por agora`: volta para Home com perfil incompleto.

Funcoes:

- criar perfil PJ
- preparar loja no Marketplace
- ligar empresa ao Stock
- acionar Identity Score para aprovacao

Interconexoes:

- loja aprovada aparece no Marketplace.
- importacao abre tela Stock Importacao.
- pendencia abre Identidade ou Docs conforme necessidade.

### 5. Home Principal / Command Center

Objetivo:

Ser a primeira tela real do produto, com acesso rapido ao que gera valor: comprar, vender, gerir estoque e conversar.

Conteudo:

- topbar premium
- bloco de continuidade do usuario
- cards dos modulos ativos: Marketplace, Stock, Chat
- cards de identidade e score
- vitrine curta de ofertas
- alertas de estoque e margem
- ultimas conversas
- pedidos recentes
- dock universal
- Helena overlay

Botoes:

- `Comprar agora`: abre Marketplace.
- `Gerir estoque`: abre Stock.
- `Abrir chat`: abre Chat.
- `Ver pedidos`: abre Area do Cliente.
- `Editar home`: abre Seletor de Modulos.
- `Ativar Face ID`: abre Identidade.
- `Ver extrato`: abre Extrato.

Funcoes:

- resumir atividade atual
- mostrar valor imediato do MVP
- permitir personalizacao da home
- apresentar status de confianca e operacao

Interconexoes:

- produto em destaque abre Detalhe de Produto.
- alerta de estoque abre Stock Pricing / Estoque.
- conversa recente abre Conversa.
- pedido recente abre Pedido / Rastreio.
- score abre Identidade.

### 6. Seletor De Modulos Visiveis Na Home

Objetivo:

Permitir que o usuario escolha quais modulos aparecem na Home sem perder acesso ao dock universal.

Conteudo:

- lista de modulos ativos
- lista de modulos preparados
- chips selecionaveis
- preview compacto da home

Botoes:

- `Salvar`: persiste selecao.
- `Restaurar padrao`: volta para Marketplace, Stock e Chat.
- `Selecionar todos ativos`: marca telas ativas.
- `Fechar`: retorna para Home.

Funcoes:

- controlar composicao da Home
- preservar acesso via dock
- evitar configuracao escondida

Interconexoes:

- altera Home imediatamente.
- nao altera disponibilidade do Dock.

### 7. Busca Global

Objetivo:

Encontrar rapidamente produtos, SKUs, conversas, pedidos e modulos.

Conteudo:

- campo de busca
- sugestoes recentes
- resultados agrupados por Produto, Estoque, Conversa, Pedido e Modulo

Botoes:

- `Buscar`: aplica termo.
- `Limpar`: remove termo.
- `Filtrar`: abre filtros.
- `Abrir resultado`: navega para item.

Funcoes:

- busca federada no MVP
- reduzir dependencia de menus

Interconexoes:

- produto leva para Detalhe.
- SKU leva para Stock.
- conversa leva para Conversa.
- pedido leva para Pedido.
- modulo leva para a tela correspondente.

### 8. Marketplace / Catalogo

Objetivo:

Apresentar catalogo premium com comportamento reconhecivel de marketplace, sem copiar identidade visual de concorrentes.

Conteudo:

- busca principal
- filtros por categoria, preco, avaliacao, disponibilidade e seller score
- vitrine de ofertas
- grid de produtos com foto realista
- selo Valley
- preco
- desconto
- frete/entrega estimada
- avaliacao e seller score
- video disponivel quando houver

Botoes:

- `Comprar`: leva ao Checkout.
- `Ver detalhes`: abre Detalhe de Produto.
- `Assistir video`: abre Midia de Produto.
- `Favoritar`: salva item.
- `Compartilhar`: abre sheet de compartilhamento.
- `Filtrar`: abre filtros.
- `Ordenar`: alterna relevancia, preco, score ou novidades.

Funcoes:

- descobrir produtos
- comparar ofertas
- iniciar compra
- validar disponibilidade
- exibir confianca do seller

Interconexoes:

- produto vem do Stock.
- compra alimenta Checkout.
- seller score vem de Identidade + Marketplace.
- comprovante final vem de Docs.
- extrato vem da trilha financeira preparada.

### 9. Detalhe De Produto

Objetivo:

Permitir decisao de compra com informacao suficiente, midia rica e confianca operacional.

Conteudo:

- galeria de imagens
- video do produto
- nome, marca e categoria
- preco e condicoes
- variacoes
- disponibilidade
- origem do estoque/hub
- seller score
- descricao
- tags
- produtos relacionados

Botoes:

- `Comprar agora`: abre Checkout.
- `Adicionar ao carrinho`: adiciona item ao carrinho/resumo.
- `Assistir video`: abre Midia.
- `Perguntar no chat`: abre Chat com contexto do produto.
- `Favoritar`: salva produto.
- `Voltar`: retorna ao catalogo anterior.

Funcoes:

- apresentar produto
- acionar checkout
- manter contexto entre marketplace, chat e cliente

Interconexoes:

- `Comprar agora` abre Checkout.
- `Perguntar no chat` cria conversa com produto anexado.
- `Origem do estoque` abre detalhe operacional do Stock quando usuario for seller/operador.

### 10. Midia De Produto

Objetivo:

Mostrar foto e video de produto de forma premium e util para conversao.

Conteudo:

- video player ou frame de video
- imagens alternativas
- titulo do produto
- preco resumido
- CTA fixo inferior

Botoes:

- `Play/Pause`: controla video.
- `Comprar`: abre Checkout.
- `Detalhes`: volta ao Detalhe de Produto.
- `Fechar`: retorna tela anterior.

Funcoes:

- aumentar confianca visual
- preservar caminho de compra

Interconexoes:

- abre a partir de Marketplace ou Detalhe.
- compra volta para Checkout com item preservado.

### 11. Carrinho / Resumo Rapido

Objetivo:

Consolidar itens antes do pagamento, sem criar friccao excessiva.

Conteudo:

- lista de itens
- quantidade
- variacao
- subtotal
- estimativa de entrega
- desconto ou cupom
- resumo de taxas

Botoes:

- `Continuar comprando`: volta ao Marketplace.
- `Finalizar compra`: abre Checkout.
- `Remover`: remove item.
- `Alterar quantidade`: atualiza item.
- `Aplicar cupom`: valida desconto.

Funcoes:

- preparar checkout
- validar disponibilidade
- aplicar desconto com fonte pagadora registrada

Interconexoes:

- Marketplace adiciona item.
- Checkout consome carrinho.
- Stock valida estoque e margem.

### 12. Checkout Preparado

Objetivo:

Fechar a intencao de compra com confianca, mantendo PAY desativado como produto completo e usando PLUG/DOCS apenas como contrato visual preparado.

Conteudo:

- resumo do pedido
- endereco ou forma de entrega
- metodo preparado: Plug / cartao / wallet futura
- taxa e total
- status de Identity Score
- aceite curto
- previsao de comprovante Docs

Botoes:

- `Confirmar pedido`: cria pedido e leva para Confirmacao.
- `Alterar entrega`: edita entrega.
- `Alterar metodo`: abre selecao de metodo preparado.
- `Ver detalhes de taxas`: abre breakdown.
- `Ativar Face ID`: abre Identidade quando exigido.
- `Cancelar`: volta ao Carrinho.

Funcoes:

- validar estoque
- validar risco minimo
- preparar transacao
- gerar pedido
- preparar comprovante

Interconexoes:

- se Identity Score baixo, abre Identidade.
- pedido confirmado abre Confirmacao.
- comprovante abre Docs/Recibo.
- total alimenta Extrato.

### 13. Confirmacao E Comprovante

Objetivo:

Dar certeza ao usuario de que o pedido foi criado e que existe prova rastreavel.

Conteudo:

- status de sucesso
- numero do pedido
- total
- metodo usado/preparado
- checksum visual do comprovante
- resumo de entrega
- proxima acao

Botoes:

- `Ver pedido`: abre Pedido / Rastreio.
- `Abrir comprovante`: abre Recibo Docs.
- `Continuar comprando`: volta ao Marketplace.
- `Falar com suporte`: abre Chat.

Funcoes:

- encerrar compra com confianca
- gerar prova visual
- encaminhar continuidade

Interconexoes:

- pedido aparece em Area do Cliente.
- comprovante aparece em Extrato/Docs.
- suporte abre conversa contextualizada.

### 14. Recibo / Docs Leve

Objetivo:

Mostrar recibo e checksum como prova simples, sem criar um modulo Docs completo.

Conteudo:

- identificador do pedido
- valor
- data
- seller
- comprador
- checksum
- status do documento

Botoes:

- `Compartilhar`: abre compartilhamento.
- `Baixar PDF`: acao visual preparada.
- `Copiar checksum`: copia hash.
- `Voltar ao pedido`: retorna ao Pedido.

Funcoes:

- comprovar operacao
- reduzir disputa
- preparar integracao futura com Docs completo

Interconexoes:

- abre de Confirmacao, Pedido ou Extrato.

### 15. Area Do Cliente

Objetivo:

Centralizar perfil, pedidos, identidade e suporte do usuario.

Conteudo:

- avatar e nome
- status KYC/KYB
- status Face ID / Voice ID
- Identity Score resumido
- pedidos recentes
- atalhos de suporte
- beneficios/recompensas se houver fonte pagadora

Botoes:

- `Editar perfil`: abre Preferencias.
- `Ver pedidos`: abre lista de Pedidos.
- `Ver identidade`: abre Identidade.
- `Abrir suporte`: abre Chat.
- `Ver extrato`: abre Extrato.

Funcoes:

- dar controle ao usuario
- expor confianca sem jargao tecnico
- centralizar retomada

Interconexoes:

- pedido abre Rastreio.
- identidade abre Face ID/Voice ID/Score.
- suporte abre Chat.

### 16. Pedidos E Rastreio

Objetivo:

Permitir acompanhamento do pedido sem ativar Delivery/Mobility como modulo completo.

Conteudo:

- lista de pedidos
- status do pedido
- linha do tempo simples
- previsao de entrega
- itens do pedido
- comprovante
- suporte

Botoes:

- `Detalhes`: abre detalhe do pedido.
- `Abrir comprovante`: abre Recibo.
- `Falar com suporte`: abre Chat.
- `Comprar novamente`: volta ao Detalhe de Produto ou Marketplace.

Funcoes:

- acompanhar compra
- reduzir suporte manual
- expor continuidade

Interconexoes:

- pedido nasce no Checkout.
- comprovante vem de Recibo.
- suporte abre conversa com pedido anexado.

### 17. Extrato

Objetivo:

Exibir movimentacoes relacionadas a pedidos e transacoes preparadas, sem expor Pay completo.

Conteudo:

- saldo/resumo visual quando aplicavel
- lista de eventos financeiros
- status: autorizado, liquidado, pendente, estornado
- valor
- origem
- documento vinculado

Botoes:

- `Filtrar`: filtra por periodo/status.
- `Abrir comprovante`: abre Recibo.
- `Ver pedido`: abre Pedido.
- `Exportar`: acao visual preparada.

Funcoes:

- dar transparencia
- preparar Pay futuro
- conectar ordem, recibo e evento financeiro

Interconexoes:

- pedido confirmado gera evento.
- recibo vincula checksum.
- suporte pode abrir Chat.

### 18. Stock / Cockpit De Catalogo

Objetivo:

Mostrar produtos, estoque, margem e operacao de dropshipping como superficie principal do MVP.

Conteudo:

- resumo de SKUs ativos
- alertas de estoque
- alertas de margem
- produtos pausados
- hubs ou origem de estoque
- cards de produto operacional
- fila de sincronizacao

Botoes:

- `Importar produtos`: abre Importacao.
- `Sincronizar`: atualiza catalogo.
- `Reprecificar`: abre Pricing.
- `Pausar item`: pausa produto.
- `Publicar no Marketplace`: liga produto a vitrine.
- `Ver item`: abre Detalhe.

Funcoes:

- gerir catalogo
- validar margem
- manter disponibilidade
- publicar produtos no Marketplace

Interconexoes:

- produtos publicados aparecem no Marketplace.
- produto sem margem abre Pricing.
- produto sem estoque fica pausado.
- sincronizacao alimenta WMS leve e catalogo.

### 19. Stock Importacao / Sincronizacao

Objetivo:

Permitir importacao e sincronizacao controlada de fornecedores e fontes de preco.

Conteudo:

- fornecedores: AliExpress, Alibaba, CJDropshipping
- fontes de preco: Mercado Livre, Amazon, Shopee, Magalu
- status de autenticacao
- frequencia de sincronizacao
- margem minima
- cache TTL
- fallback scraping controlado
- bloqueio de IA externa para consultas

Botoes:

- `Conectar fornecedor`: abre formulario de integracao.
- `Sincronizar agora`: roda sync.
- `Salvar regra`: salva politica.
- `Testar conexao`: valida integracao.
- `Pausar rotina`: desativa sync.

Funcoes:

- preparar importacao
- controlar fonte externa
- preservar margem
- evitar custo de IA desnecessario

Interconexoes:

- sync bem sucedido cria itens no Stock.
- itens aprovados podem ir ao Marketplace.
- falhas geram alerta na Home e no Stock.

### 20. Stock Pricing / Margem / Disponibilidade

Objetivo:

Dar controle de preco, margem e pausa automatica sem virar planilha tecnica.

Conteudo:

- produto selecionado
- custo do fornecedor
- preco concorrente
- preco sugerido
- margem minima
- status de competitividade
- decisao de pricing append-only como linha visual de historico

Botoes:

- `Aplicar preco sugerido`: atualiza preco.
- `Pausar produto`: remove da vitrine.
- `Publicar`: disponibiliza no Marketplace.
- `Ver historico`: abre timeline de decisoes.
- `Voltar ao Stock`: retorna cockpit.

Funcoes:

- proteger margem
- impedir venda sem estoque
- registrar decisao operacional

Interconexoes:

- atualizacao afeta Marketplace.
- historico alimenta auditoria futura.
- alerta aparece na Home.

### 21. WMS Leve / Hub De Estoque

Objetivo:

Mostrar localizacao operacional e disponibilidade sem criar WMS completo.

Conteudo:

- hub/armazem
- endereco operacional
- quantidade disponivel
- reservado
- em transferencia
- SLA
- alertas

Botoes:

- `Ver produtos do hub`: filtra Stock.
- `Reservar`: acao preparada.
- `Reportar divergencia`: abre Chat/operacao.
- `Voltar`: retorna Stock.

Funcoes:

- explicar origem do produto
- reduzir venda sem estoque
- preparar WMS futuro

Interconexoes:

- Stock consome disponibilidade.
- Marketplace mostra origem resumida.
- divergencia abre Chat.

### 22. Chat / Inbox

Objetivo:

Centralizar conversas pessoais, profissionais, suporte e contexto de compras.

Conteudo:

- lista de conversas
- filtros por tipo: suporte, pedido, seller, Helena
- preview da ultima mensagem
- status de leitura
- produto ou pedido anexado quando houver

Botoes:

- `Nova conversa`: inicia conversa.
- `Abrir`: abre Conversa.
- `Filtrar`: muda tipo.
- `Arquivar`: remove da lista principal.
- `Buscar`: busca conversa.

Funcoes:

- suporte ao usuario
- canal de contexto para produto e pedido
- interface de contexto Helena dual

Interconexoes:

- Detalhe de Produto pode abrir conversa com produto.
- Pedido pode abrir suporte com pedido anexado.
- Helena pode criar resumo ou sugestao.

### 23. Conversa

Objetivo:

Permitir atendimento e conversa com contexto real, sem parecer chat generico.

Conteudo:

- header com contato, pedido ou produto
- mensagens
- anexos de produto/pedido
- sugestoes da Helena
- composer
- estados de envio, entregue e lido

Botoes:

- `Enviar`: envia mensagem.
- `Anexar`: adiciona produto, pedido ou comprovante.
- `Usar sugestao`: aplica texto da Helena.
- `Ver produto`: abre Detalhe.
- `Ver pedido`: abre Pedido.
- `Finalizar atendimento`: marca conversa resolvida.

Funcoes:

- atendimento contextual
- comunicacao entre comprador, seller e suporte
- continuidade da jornada

Interconexoes:

- anexos abrem suas telas de origem.
- conversa pode levar a Checkout quando produto for anexado.
- comprovante abre Recibo.

### 24. Feed Contextual

Objetivo:

Mostrar atividades e conteudos curtos ligados ao MVP, sem ativar Social completo.

Conteudo:

- cards de produto
- novidades de catalogo
- atualizacoes de pedidos
- recomendacoes leves
- eventos de seller

Botoes:

- `Abrir produto`: abre Detalhe.
- `Comprar`: abre Checkout.
- `Salvar`: guarda item.
- `Compartilhar`: abre compartilhamento.

Funcoes:

- descoberta
- continuidade
- recomendacao controlada

Interconexoes:

- produtos vêm de Marketplace/Stock.
- compra vai para Checkout.
- conversa pode ser aberta a partir do card.

### 25. Identidade / Confianca

Objetivo:

Mostrar Face ID, Voice ID e Identity Score como camada de confianca, nao como modulo separado artificial.

Conteudo:

- status Face ID
- status Voice ID
- Identity Score explicavel
- fatores positivos e pendencias
- eventos recentes de seguranca
- acoes sensiveis protegidas

Botoes:

- `Ativar Face ID`: inicia cadastro biometrico.
- `Ativar Voice ID`: inicia validacao vocal leve.
- `Revisar pendencias`: mostra fatores de risco.
- `Confirmar operacao`: valida identidade para checkout ou seller.
- `Voltar`: retorna origem.

Funcoes:

- reduzir fraude
- desbloquear checkout sensivel
- aprovar seller
- explicar risco sem numero magico

Interconexoes:

- Login pode chamar Face ID.
- Checkout pode exigir Identity Score.
- Onboarding Seller pode exigir revisao.
- Area do Cliente mostra resumo.

### 26. Preferencias / Perfil

Objetivo:

Permitir ajustes essenciais sem criar tela administrativa.

Conteudo:

- dados pessoais
- dados de empresa quando houver
- preferencias de notificacao
- seguranca
- modulos visiveis na home
- privacidade

Botoes:

- `Salvar`: grava alteracoes.
- `Editar dados`: habilita campos.
- `Gerenciar modulos`: abre Seletor.
- `Seguranca`: abre Identidade.
- `Sair`: encerra sessao.

Funcoes:

- manter perfil
- controlar experiencia
- acionar seguranca

Interconexoes:

- modulos visiveis alteram Home.
- seguranca abre Identidade.
- empresa abre Onboarding Empresarial se incompleta.

### 27. Notificacoes

Objetivo:

Expor alertas relevantes sem virar centro de logs.

Conteudo:

- pedido atualizado
- produto sem estoque
- margem insuficiente
- conversa nova
- identidade pendente
- comprovante pronto

Botoes:

- `Abrir`: navega para origem.
- `Marcar como lida`: atualiza estado.
- `Limpar`: remove notificacoes lidas.

Funcoes:

- orientar proxima acao
- reduzir perda de venda
- reduzir suporte

Interconexoes:

- pedido abre Pedidos.
- estoque abre Stock.
- conversa abre Chat.
- identidade abre Identidade.
- comprovante abre Recibo.

### 28. Estados Do Produto

Objetivo:

Garantir que o template pareca final mesmo quando nao houver dados.

Estados obrigatorios:

- loading
- vazio
- sucesso
- erro
- bloqueado por identidade
- fora do MVP

Botoes por estado:

- Loading: sem botao primario, apenas skeleton refinado.
- Vazio: `Adicionar primeiro item`, `Importar catalogo` ou `Explorar marketplace`.
- Sucesso: `Ver resultado`, `Continuar`.
- Erro: `Tentar novamente`, `Falar com suporte`.
- Bloqueado: `Verificar identidade`.
- Fora do MVP: `Receber aviso`, `Voltar ao inicio`.

Interconexoes:

- erro de checkout pode abrir Chat.
- vazio de Stock abre Importacao.
- bloqueio abre Identidade.
- fora do MVP volta para Home/Dock.

## Fluxos Principais

### Fluxo A - Compra

Home -> Marketplace -> Detalhe de Produto -> Checkout -> Confirmacao -> Recibo -> Pedido -> Extrato.

Botoes centrais:

- `Comprar agora`
- `Confirmar pedido`
- `Abrir comprovante`
- `Ver pedido`
- `Ver extrato`

### Fluxo B - Seller / Estoque

Home -> Onboarding Empresarial -> Stock Importacao -> Stock Cockpit -> Pricing -> Publicar no Marketplace -> Marketplace.

Botoes centrais:

- `Validar empresa`
- `Importar produtos`
- `Sincronizar agora`
- `Aplicar preco sugerido`
- `Publicar no Marketplace`

### Fluxo C - Suporte Contextual

Pedido ou Produto -> Chat -> Conversa -> Anexo de pedido/produto -> Resolucao.

Botoes centrais:

- `Perguntar no chat`
- `Falar com suporte`
- `Anexar`
- `Ver pedido`
- `Finalizar atendimento`

### Fluxo D - Identidade

Login/Checkout/Seller -> Identidade -> Face ID ou Voice ID -> Identity Score atualizado -> retorna para tela de origem.

Botoes centrais:

- `Ativar Face ID`
- `Ativar Voice ID`
- `Confirmar operacao`
- `Voltar para compra`

### Fluxo E - Helena

Qualquer tela -> Helena -> comando por voz/texto -> navegacao, busca, explicacao ou sugestao -> tela alvo.

Botoes centrais:

- `Abrir Helena`
- `Microfone`
- `Enviar`
- `Usar sugestao`
- `Minimizar`

## Regras De Copy

Usar textos curtos e maduros. Exemplos de tom:

- `Comprar agora`
- `Gerir estoque`
- `Confirmar pedido`
- `Abrir comprovante`
- `Ativar Face ID`
- `Falar com suporte`
- `Publicar no Marketplace`
- `Aplicar preco sugerido`
- `Modulo em preparacao`

Evitar:

- linguagem tecnica
- mensagens de sistema
- nomes de banco de dados
- logs
- JSON
- "debug"
- "em desenvolvimento"
- textos longos explicando a interface

## Regras Responsivas

Desktop:

- sidebar fixa
- topbar ampla
- grid de produtos e paineis lado a lado
- dock flutuante horizontal
- Helena no canto inferior direito

Tablet:

- sidebar recolhivel
- grid com menos colunas
- dock preservado
- Helena minimizada por padrao

Mobile:

- bottom navigation
- topbar compacta
- cards em pilha
- CTA principal fixo quando houver checkout/produto
- dock recolhido por padrao
- Helena como estrela flutuante pequena

## Prompt Mestre Para Colar No Stitch

Crie um template visual completo para o MVP do Valley, um super app premium em Flutter Web + Android. Nao crie landing page. A primeira tela deve ser o aplicativo em uso.

O MVP ativo inclui Home/Command Center, Dock universal de modulos, Marketplace, Detalhe de Produto, Midia de Produto, Carrinho, Checkout preparado, Confirmacao, Recibo/Docs leve, Area do Cliente, Pedidos/Rastreio, Extrato, Stock, Importacao de Catalogo, Pricing/Margem/Estoque, WMS leve, Chat, Conversa, Feed Contextual, Identidade com Face ID/Voice ID/Identity Score, Perfil/Preferencias, Notificacoes, Helena overlay e estados de loading/vazio/sucesso/erro.

Use uma linguagem visual premium, escura, sofisticada e altamente usavel: Night `#07051F`, Cosmic `#151047`, Violet `#6F2CFF`, Lilac `#BB8CFF`, Cyan `#20C8F3`, Snow `#FFFFFF`, Ink `#121827`. O design deve parecer produto final maduro, com superficies de vidro sutis, acentos ciano/violeta controlados, fotos e videos realistas de produtos, cards refinados, hierarquia forte e navegacao clara.

Crie telas coordenadas para desktop, tablet e mobile. Em desktop use sidebar, topbar e dock flutuante. Em mobile use bottom navigation, topbar compacta, dock recolhido e Helena minimizada como estrela Valley. Helena deve poder expandir para um painel curto com microfone, resposta e sugestoes acionaveis.

Detalhe os botoes e estados principais: Comprar agora, Ver detalhes, Assistir video, Adicionar ao carrinho, Confirmar pedido, Abrir comprovante, Ver pedido, Ver extrato, Importar produtos, Sincronizar agora, Reprecificar, Aplicar preco sugerido, Publicar no Marketplace, Abrir chat, Enviar, Anexar, Usar sugestao, Ativar Face ID, Ativar Voice ID, Editar home, Salvar, Tentar novamente e Falar com suporte.

Nao desenhe Food, Delivery, Mobility, Social, Gaming ou IoT como jornadas completas neste template. Eles podem aparecer apenas como modulos futuros/desativados no dock com estado "Em preparacao". PAY, PLUG, DOCS, BUSINESS, REPLY e WMS devem aparecer como contratos visuais preparados, mas nao como produtos completos ativados.

O resultado deve mostrar interconexoes claras: Home leva para Marketplace, Stock, Chat, Cliente e Identidade; Marketplace leva para Detalhe, Midia, Carrinho e Checkout; Checkout gera Confirmacao, Recibo, Pedido e Extrato; Stock alimenta Marketplace e controla margem/estoque; Chat recebe contexto de produto e pedido; Identidade desbloqueia operacoes sensiveis; Helena navega, busca, explica e sugere acoes em qualquer tela.

Evite qualquer aparencia de dashboard tecnico, admin interno, prototipo, placeholder, log, JSON, DevTools ou texto de desenvolvimento. O template precisa parecer uma interface comercial pronta para validacao com usuarios reais.
