<!--
PROPOSITO: Definir o blueprint de release mobile e web responsivo do Valley.
CONTEXTO: Este documento orienta APK, runtime publico, fallback embarcado e superficies mobile.
REGRAS: Usar rotas publicas oficiais, preservar identidade Valley e evitar textos tecnicos para usuario final.
-->

# Valley Mobile Release Blueprint

Criado em BRT: 2026-05-12

## Objetivo

Gerar a versão mobile release do Valley para Android e Web responsivo, usando `https://brasildesconto.com.br` como base pública oficial. O aplicativo deve funcionar fora da rede local, com Cloudflare como rota externa e catálogo embarcado para abertura offline quando a rede estiver indisponível.

## Regras Obrigatórias

- Idioma obrigatório: português do Brasil.
- Nome do produto: Valley.
- Assistente: Helena.
- Moeda/token quando necessário: V-Coin.
- Base pública oficial: `https://brasildesconto.com.br`.
- Não usar Tailscale, IP local, LAN, `localhost` ou `127.0.0.1` como rota de release.
- O app deve tentar Cloudflare primeiro e depois usar dados embarcados.
- Não exibir textos técnicos como MVP, fallback local, ambiente dev, logs ou debug para usuário final.

## Grupo Admin

Telas mobile:
- Login admin.
- Painel executivo.
- Workspaces por módulo.
- Catálogo e STOCK.
- Marketplace e integrações.
- Financeiro, checkout e repasses.
- Lojistas e usuários.
- Sandbox e flags operacionais.

Ações:
- Abrir módulo.
- Aprovar publicação.
- Bloquear item.
- Sincronizar catálogo.
- Exportar relatório.
- Copiar link público.
- Abrir ERP do lojista.

Estados:
- Produção.
- Integração ativa.
- Integração pendente.
- Publicado.
- Em revisão.
- Bloqueado.
- Sem permissão.

## Grupo Lojista

Telas mobile:
- Login lojista.
- ERP central.
- PDV.
- Pedidos.
- Produtos.
- Estoque.
- Inventário com leitor de código de barras e QR Code.
- Armazém.
- Transportadora, CD e cross docking.
- Logística e entrega final.
- Financeiro.
- Fiscal.
- Contábil.
- Campanhas.
- Clientes.
- Atendimento.
- Equipe.
- Segurança.
- Configurações.

Ações:
- Abrir caixa.
- Fechar caixa.
- Publicar produto.
- Escanear volume.
- Escanear produto.
- Adicionar quantidade.
- Subtrair quantidade.
- Registrar avaria.
- Lançar baixa.
- Lançar alta.
- Receber carga.
- Mover para doca.
- Montar rota.
- Confirmar entrega.
- Gerar relatório.

Estados:
- Loja ativa.
- Cadastro incompleto.
- Checkout pendente.
- Sincronização em andamento.
- Produto encontrado.
- Produto não encontrado.
- Divergência detectada.
- Em conferência.
- Em rota.
- Entregue.
- Devolução iniciada.
- Sem permissão.

## Grupo Usuário

Telas mobile:
- Home pública.
- Busca e catálogo.
- Detalhe do produto.
- Carrinho.
- Checkout.
- Pagamento.
- Sucesso da compra.
- Rastreio.
- Minha conta.
- Minhas compras.
- Devoluções e trocas.
- Notificações.
- Atendimento.
- Clube e pontos.

Ações:
- Buscar.
- Filtrar.
- Ver produto.
- Comprar.
- Entrar.
- Cadastrar.
- Escolher endereço.
- Confirmar pagamento.
- Acompanhar pedido.
- Solicitar troca.
- Abrir atendimento.

Estados:
- Catálogo carregado.
- Compra em andamento.
- Pagamento aprovado.
- Pedido em separação.
- Pedido em rota.
- Pedido entregue.
- Produto indisponível.
- Sem conexão com dados embarcados.

## Navegação Mobile

- Top bar compacta com logo Valley, busca e perfil.
- Navegação inferior por grupos principais quando for usuário final.
- Para admin e lojista, usar chips horizontais, atalhos em grid e barras de ação contextuais.
- Tabelas devem virar cards compactos.
- Filtros devem virar chips e accordions.
- Botões devem ser curtos, reais e orientados a ação.

## Dados Embarcados

- Catálogo STOCK real sanitizado.
- Dados fictícios do Marketplace: lojistas, serviços e produtos.
- Módulos Valley.
- Manifesto de rotas públicas.
- Estados de fallback offline com texto de negócio.

## Critério de Release

- APK ABI gerado com `--split-per-abi`.
- Base pública Cloudflare configurada.
- Catálogo abre fora da rede local.
- Portal público, admin, lojista e usuário documentados com links clicáveis.
- PDF ABNT entregue junto com APK.
