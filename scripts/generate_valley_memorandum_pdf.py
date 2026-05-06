#!/usr/bin/env python3
from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date
from html import escape
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
MODULES_FILE = ROOT / "config" / "modules_v47.json"
OUTPUT_DIR = ROOT / "output" / "pdf"
OUTPUT_PDF = OUTPUT_DIR / "VALLEY_MEMORANDO_ESTRUTURADO_MODULOS_ECONOMIA.pdf"
OUTPUT_MD = OUTPUT_DIR / "VALLEY_MEMORANDO_ESTRUTURADO_MODULOS_ECONOMIA.md"
CONSULT_DATE = date(2026, 4, 21)


@dataclass(frozen=True)
class Scenario:
    users: int
    active_rate: float
    monthly_revenue_brl: float
    monthly_variable_cost_brl: float
    monthly_fixed_cost_brl: float

    @property
    def mau(self) -> int:
        return int(round(self.users * self.active_rate))

    @property
    def contribution_brl(self) -> float:
        return self.monthly_revenue_brl - self.monthly_variable_cost_brl

    @property
    def operating_result_brl(self) -> float:
        return self.contribution_brl - self.monthly_fixed_cost_brl

    @property
    def contribution_margin(self) -> float:
        if not self.monthly_revenue_brl:
            return 0.0
        return self.contribution_brl / self.monthly_revenue_brl

    @property
    def operating_margin(self) -> float:
        if not self.monthly_revenue_brl:
            return 0.0
        return self.operating_result_brl / self.monthly_revenue_brl

    @property
    def revenue_per_user(self) -> float:
        return self.monthly_revenue_brl / self.users

    @property
    def service_cost_per_user(self) -> float:
        return self.monthly_variable_cost_brl / self.users


DOMAIN_LABELS = {
    "logistics_erp_operations": "Logistics, ERP and Operations",
    "commerce_fintech_assets": "Commerce, Fintech and Assets",
    "media_social_growth": "Media, Social and Growth",
    "city_mobility_security": "City, Mobility and Security",
    "frontier_iot_energy": "Frontier, IoT and Energy",
    "ai_memory_operations": "AI, Memory and Operations",
    "services_health_human": "Services, Health and Human Care",
    "education_work_social": "Education, Work and Social",
    "platform_developer": "Platform and Developer",
}


DOMAIN_INTROS = {
    "logistics_erp_operations": (
        "Cluster com receita hibrida de SaaS, taxa operacional e fulfillment. "
        "Fecha bem em REPLY, BUSINESS e WMS; FOOD, DELIVERY e FLEET exigem densidade e fee explicito."
    ),
    "commerce_fintech_assets": (
        "Melhor frente de margem do ecossistema quando PAY e PLUG capturam o fluxo financeiro. "
        "A disciplina aqui e separar take rate, processamento e afiliacao para nao corroer margem."
    ),
    "media_social_growth": (
        "Monetiza via ads, creator commerce, boost e campanha. Social puro nao deve nascer como centro de lucro; "
        "precisa de attach em ADS, MEDIA e UP."
    ),
    "city_mobility_security": (
        "Cluster misto: LEGAL, EVENTS e SECURITY ajudam a financiar a frente; MOBILITY e TOURISM pedem "
        "pricing dinamico e zonas densas para nao virar subsidio."
    ),
    "frontier_iot_energy": (
        "Melhor viabilidade em contratos B2B e B2B2C, com hardware, instalacao, monitoramento e brokerage. "
        "Varejo massivo cedo demais tende a consumir caixa."
    ),
    "ai_memory_operations": (
        "Receita principalmente de assinatura premium, seat corporativo e automacao assistida. "
        "Custo de IA precisa ser limitado por plano, fila e politicas de uso."
    ),
    "services_health_human": (
        "Funciona melhor com booking fee, plano profissional, teleatendimento pago e bundles com PAY, DOCS e DELIVERY. "
        "LGPD sensivel e compliance puxam custo."
    ),
    "education_work_social": (
        "Edu, Jobs e Charity ganham mais quando conectados a empregabilidade, employer plan e sponsorship. "
        "Nao sao o primeiro motor de margem do stack."
    ),
    "platform_developer": (
        "E a camada que mais ajuda a dar previsibilidade de caixa ao ecossistema via assinatura, API e documento transacional. "
        "Ajuda a financiar frentes pesadas de mobilidade, IA e operacao fisica."
    ),
}


MODULE_NOTES = {
    "REPLY": {
        "mechanics": "Fornecedor > pedido > ordem de servico > faturamento > fechamento do ERP/WMS.",
        "rules": "Aprovacao formal, rastreio fiscal, auditoria de compra e segregacao de responsabilidade.",
        "game": "Comprar certo, sem pendencia e sem retrabalho, parece limpar uma fase inteira.",
        "profit": "Assinatura SaaS, implantacao, integracao, BPO operacional e add-ons fiscais.",
        "cost": "Suporte, integrações, regras fiscais, customer success e manutencao de workflow.",
    },
    "STOCK": {
        "mechanics": "Sincroniza catalogo, fornecedor, margem e status de dropshipping em fluxo continuo.",
        "rules": "Governanca de catalogo, conciliacao com fornecedor e guarda de margem minima.",
        "game": "E a caca da oferta boa de verdade; produto ruim derruba o combo.",
        "profit": "Margem sobre catalogo, rebate de fornecedor, vitrine patrocinada e fee de seller.",
        "cost": "Integracao de catalogo, devolucao, atendimento, conciliacao e fraude de supply.",
    },
    "LOG": {
        "mechanics": "Ingere checkpoints de entrega, tracking e anomalias de rota em tempo quase real.",
        "rules": "Cadeia de custodia, dedupe de eventos e padrao canonico de status.",
        "game": "Cada checkpoint fechado e uma etapa vencida da missao logistica.",
        "profit": "Fee por tracking premium, API para parceiros e bundle com DELIVERY e FLEET.",
        "cost": "Telemetria, storage, observabilidade, integrações com transportadoras e suporte.",
    },
    "FOOD": {
        "mechanics": "Pedido > preparo > split de pagamento > despacho > entrega com prova operacional.",
        "rules": "SLA de cozinha, alergenicos, split auditavel e delivery fee explicita.",
        "game": "Pedir certo, rapido e sem erro de dieta da sensacao de combo fechado.",
        "profit": "Comissao por pedido, fee logistica, midia local, assinatura de restaurante e PAY.",
        "cost": "Last mile, atendimento, chargeback, fraude promocional e operacao de entrega.",
    },
    "DELIVERY": {
        "mechanics": "Coleta urbana, roteirizacao, prova de entrega e reconciliacao do courier.",
        "rules": "Janela prometida, prova de entrega, responsabilidade do entregador e monitoramento.",
        "game": "Cada entrega concluida limpa a fila e melhora o placar operacional.",
        "profit": "Fee por entrega, tarifa expressa, contrato B2B e bundle com MARKETPLACE e FOOD.",
        "cost": "Payout do entregador, reentrega, suporte em tempo real, seguro e antifraude.",
    },
    "WMS": {
        "mechanics": "Endereco de estoque, contagem ciclica, sensor, reposicao e conferencia.",
        "rules": "Inventario auditavel, temperatura controlada e ajuste por variancia.",
        "game": "Deposito redondo e mapa sem ponto vermelho.",
        "profit": "Assinatura de operacao, fee de armazenagem, picking/packing e integracoes ERP.",
        "cost": "Infra fisica, sensores, inventario, suporte operacional e perdas.",
    },
    "FLEET": {
        "mechanics": "Veiculo + telemetria + manutencao + disponibilidade operacional.",
        "rules": "Bloqueio por manutencao critica, compliance do veiculo e rastreio continuo.",
        "game": "Veiculo saudavel fica no verde e nao perde corrida nem entrega.",
        "profit": "Assinatura de frota, monitoramento, contrato B2B e manutencao programada.",
        "cost": "Telemetria, conectividade, manutencao, inspeções e suporte de campo.",
    },
    "BUSINESS": {
        "mechanics": "Onboarding da empresa > rotina contabil/fiscal > caixa > fechamento.",
        "rules": "RBAC, trilha tributaria, segregacao financeira e auditoria.",
        "game": "Empresa organizada vira painel sem incendio nem surpresa.",
        "profit": "Assinatura SaaS, bundle com PAY/PLUG/DOCS e servicos financeiros.",
        "cost": "Suporte consultivo, integrações fiscais, treinamento e sucesso do cliente.",
    },
    "MARKETPLACE": {
        "mechanics": "Seller publica > cliente compra > pedido valida > split liquida.",
        "rules": "KYB do seller, governanca de listing, anti-fraude e politica de disputa.",
        "game": "Vitrine boa e reputacao alta fazem a conversao subir de nivel.",
        "profit": "Take rate, ads, seller plan, servicos financeiros e afiliacao via UP.",
        "cost": "Fraude, chargeback, catalogo, moderacao comercial e suporte.",
    },
    "PAY": {
        "mechanics": "Abre wallet, registra ledger, splita pagamento e reconcilia saldo.",
        "rules": "KYC/AML, limites, append-only e segregacao de fundos.",
        "game": "Saldo, meta e cashback funcionam como barra de progresso do dinheiro.",
        "profit": "MDR, Pix, saque, antecipacao, float e fee de infraestrutura financeira.",
        "cost": "PSP, fraude, chargeback, KYC, compliance e suporte financeiro.",
    },
    "DIGITAL": {
        "mechanics": "Colecao > mint > transferencia > royalty > prova de posse.",
        "rules": "Custodia, rastreabilidade de posse, direitos autorais e auditoria de royalties.",
        "game": "Ativo raro e movimentado aumenta status do criador.",
        "profit": "Mint fee, royalty, curadoria premium e mercado secundario.",
        "cost": "Custodia, suporte de ativo, moderacao de propriedade intelectual e infra.",
    },
    "REAL_ESTATE": {
        "mechanics": "Cadastro do imovel > due diligence > listing > proposta > contrato > settlement.",
        "rules": "Suitability, due diligence, contrato forte e prova documental.",
        "game": "Cada cota parece conquista patrimonial desbloqueada.",
        "profit": "Fee de originação, comissao de venda, tokenizacao e contrato digital.",
        "cost": "Juridico, diligencia, onboarding regulatorio e atendimento premium.",
    },
    "INSURANCE": {
        "mechanics": "Cotacao > apolice > monitoramento > claim > liquidacao.",
        "rules": "Underwriting, auditoria de claim e rastreio de risco.",
        "game": "Usuario ativa um escudo antes do problema aparecer.",
        "profit": "Comissao de corretagem, embedded insurance e upsell de protecao.",
        "cost": "Sinistro, antifraude, integrações com seguradoras e suporte.",
    },
    "FINANCAS": {
        "mechanics": "Metas, round-up, fechamento de caixa e leitura de saude financeira.",
        "rules": "Privacidade, trilha de metas, reconciliacao e consentimento de uso.",
        "game": "Cada troco guardado e meta batida vira pequena vitoria.",
        "profit": "Assinatura premium, fee de automacao financeira e cross-sell com PAY.",
        "cost": "IA leve, integrações, suporte financeiro e observabilidade.",
    },
    "PLUG": {
        "mechanics": "Terminal ou tap-to-pay > autorizacao > settlement > conciliacao.",
        "rules": "Fronteira PCI, MDR auditavel e controle de repasse.",
        "game": "Vender e ver o dinheiro cair rapido acelera o giro do lojista.",
        "profit": "MDR, aluguel ou taxa de uso, antecipacao e bundle com BUSINESS.",
        "cost": "Adquirencia, hardware, suporte, chargeback e compliance.",
    },
    "UP": {
        "mechanics": "Link rastreado > clique > conversao > atribuicao > comissao.",
        "rules": "Anti-fraude, atribuicao auditavel e pagamento rastreado.",
        "game": "Indicar certo vira pontuacao em dinheiro.",
        "profit": "Fee de rede, seller-funded commission e pacote de growth.",
        "cost": "Comissoes, antifraude, atribuição e payout do afiliado.",
    },
    "SOCIAL": {
        "mechanics": "Post > moderacao > reputacao > distribuicao local.",
        "rules": "Privacidade, moderacao comunitaria, denuncias e seguranca.",
        "game": "Quem ajuda ganha moral; quem bagunca perde espaco.",
        "profit": "Ads, boost de publicacao, creator commerce e dados agregados permitidos.",
        "cost": "CDN, storage, moderacao, seguranca e suporte ao usuario.",
    },
    "ADS": {
        "mechanics": "Campanha > impressao > clique > conversao > reward ou comprovacao.",
        "rules": "Consentimento geografico, cap de exposicao e atribuicao financeira.",
        "game": "Campanha boa pinga recompensa como combo de acertos.",
        "profit": "Fee de campanha, CPM/CPA, geofencing premium e budget de rewards.",
        "cost": "Attribution, antifraude, storage, creator payout e suporte.",
    },
    "INFLUENCERS": {
        "mechanics": "Qualifica creator > puxa metricas > conecta campanha > calcula comissao.",
        "rules": "Disclosure, brand safety, trilha de comissao e reputacao.",
        "game": "Criador sobe de nivel quando entrega audiencia que converte.",
        "profit": "Comissao sobre venda, fee de campanha e assinatura de creator studio.",
        "cost": "Payout, verificação de metricas, moderacao e suporte comercial.",
    },
    "MEDIA": {
        "mechanics": "Upload > publicacao > monetizacao > distribuicao > payout.",
        "rules": "Direito autoral, payout auditavel e seguranca de marca.",
        "game": "Conteudo rendendo vira placar vivo do criador.",
        "profit": "Assinatura creator, revenue share, boost e comercializacao de audiencia.",
        "cost": "Storage, transcoding, CDN, moderacao e suporte.",
    },
    "NEWS_PODCAST": {
        "mechanics": "Pauta > revisao > publicacao > distribuicao de audio e texto.",
        "rules": "Governanca editorial, copyright e trilha de aprovacao.",
        "game": "Programacao rodando parece temporada liberando episodios.",
        "profit": "Patrocinio, branded content, assinatura e ads.",
        "cost": "Producao, edicao, storage, distribuicao e moderacao editorial.",
    },
    "GAMING": {
        "mechanics": "Missao > progresso > reward > ranking > resgate.",
        "rules": "Reward auditavel, moderacao, controles etarios e funding da campanha.",
        "game": "Aqui a gamificacao e literal: missao, barra de progresso e premio.",
        "profit": "Patrocinio, season pass, eventos e rewards financiados por parceiros.",
        "cost": "Premiacao, antifraude, moderacao, servidor e suporte.",
    },
    "LEGAL": {
        "mechanics": "Contrato > assinatura > hash > mediacao > trilha juridica.",
        "rules": "Validade juridica, fallback seguro, trilha de auditoria e prova de aceite.",
        "game": "Missao validada e documento carimbado sem perder papel.",
        "profit": "Assinatura de contratos, fee por documento, mediacao e API juridica.",
        "cost": "Infra documental, certificacao, suporte juridico e compliance.",
    },
    "EVENTS": {
        "mechanics": "Programa > emite ticket > valida entrada > liquida escrow.",
        "rules": "Ingresso imutavel, anti-fraude, chargeback controlado e repasse auditavel.",
        "game": "Ingresso confiavel parece item raro autenticado.",
        "profit": "Taxa por ingresso, fee de escrow, destaque de evento e PAY.",
        "cost": "Chargeback, antifraude, suporte de evento e validacao.",
    },
    "MOBILITY": {
        "mechanics": "Solicitacao > precificacao por rota > corrida > checkpoint > pagamento.",
        "rules": "Piso economico por rota, accountability do rider e score de seguranca.",
        "game": "Corrida vira percurso com etapas vencidas e previsibilidade.",
        "profit": "Take rate por corrida, assinatura de frota, servicos B2B e PAY.",
        "cost": "Incentivo de rider, monitoramento, suporte em tempo real e seguro.",
    },
    "SECURITY": {
        "mechanics": "SOS > validacao de contexto > resposta > fechamento de incidente.",
        "rules": "Cadeia de custodia, hashing de biometria e acesso restrito.",
        "game": "Botao de escudo; rapidez e confianca contam mais que volume.",
        "profit": "Assinatura de seguranca, pacote premium, B2B e integracao com device.",
        "cost": "Monitoramento, resposta humana, armazenamento seguro e auditoria.",
    },
    "TOURISM": {
        "mechanics": "Experiencia > booking > check-in > conclusao > avaliacao.",
        "rules": "Accountability do guia, auditoria de booking e politicas de cancelamento.",
        "game": "Explorar a cidade vira colecao de experiencias.",
        "profit": "Fee por reserva, destaque, seguro opcional e bundle com EVENTS/MOBILITY.",
        "cost": "Atendimento, refund, antifraude, suporte ao guia e curadoria.",
    },
    "GOV": {
        "mechanics": "Solicitacao do cidadao > fila > atendimento > resolucao com SLA.",
        "rules": "Auditabilidade publica, identidade do cidadao e trilha do servico.",
        "game": "Pedido publico deixa de sumir e passa a ter fila visivel.",
        "profit": "Contrato B2G, licenca de plataforma, servicos de implantacao e DOCS.",
        "cost": "Compliance, seguranca, atendimento institucional e integrações publicas.",
    },
    "IOT": {
        "mechanics": "Provisiona device > recebe sensor > detecta falha > aciona evento.",
        "rules": "Rastreio do device, retenção de telemetria e controle de acesso.",
        "game": "Cada sensor online e uma luz verde no painel.",
        "profit": "Assinatura de monitoramento, hardware, API e contratos B2B.",
        "cost": "Conectividade, hardware, reposicao, suporte de campo e storage.",
    },
    "BIO": {
        "mechanics": "Programa ambiental > coleta > comprova impacto > liquida incentivo.",
        "rules": "Cadeia de custodia ambiental, auditoria de impacto e evidencias.",
        "game": "Reciclar deixa de ser invisivel e vira resultado contado.",
        "profit": "Patrocinio ESG, fee de certificacao, logística reversa e dados de impacto.",
        "cost": "Coleta, auditoria, campo, integrações e suporte.",
    },
    "HOME": {
        "mechanics": "Vincula device > executa cena > registra evento > alerta se necessario.",
        "rules": "Acesso domestico, segurança do device e log de automacao.",
        "game": "Casa responde na hora e da sensacao de controle total.",
        "profit": "Assinatura de automacao, hardware, monitoramento e cross-sell com SECURITY.",
        "cost": "Devices, conectividade, suporte de instalacao e cloud.",
    },
    "ENERGY": {
        "mechanics": "Registra ativo > mede geracao > casa oferta e demanda > liquida settlement.",
        "rules": "Medicao rastreavel, liquidação imutavel e compliance de rede.",
        "game": "Produzir e trocar energia vira jogo serio de eficiencia.",
        "profit": "Brokerage, assinatura de monitoramento e fee de settlement.",
        "cost": "Medicao, integrações reguladas, hardware e suporte.",
    },
    "SPACE": {
        "mechanics": "Cria ancora AR > publica camada > visita ponto > mede interacao.",
        "rules": "Privacidade de localizacao, seguranca do conteudo e autoria rastreada.",
        "game": "O bairro ganha fases e pontos secretos.",
        "profit": "Patrocinio de local, media imersiva e experiences premium.",
        "cost": "Render, storage, moderacao, suporte e criacao de experiencia.",
    },
    "AGENDA": {
        "mechanics": "Cria item > recorrencia > lembrete > conclusao > liga memoria util.",
        "rules": "Consentimento, retention pessoal e source_module rastreavel.",
        "game": "Sua rotina vai dando check e aliviando carga mental.",
        "profit": "Assinatura premium, plano familia, add-on corporativo e automacao.",
        "cost": "Mensageria, storage, sincronizacao e suporte.",
    },
    "ADVISOR": {
        "mechanics": "Insight > explicacao minima > proposta de acao > aceite > execucao assistida.",
        "rules": "Explainability, consentimento, boundary de contexto Helena e trilha de aceite.",
        "game": "Funciona como copiloto que sugere o melhor proximo passo.",
        "profit": "Assinatura premium, seat B2B, fee consultivo e automacao paga.",
        "cost": "Tokens de IA, observabilidade, revisao humana e compliance.",
    },
    "CHAT": {
        "mechanics": "Conversa > persistencia > promocao controlada para memoria ou agenda.",
        "rules": "Separacao pessoal/profissional, retention e classificacao de sensibilidade.",
        "game": "Conversar vai montando contexto util sem virar bagunca.",
        "profit": "Bundle premium, seat corporativo e automacao assistida.",
        "cost": "Mensageria, IA leve, armazenamento e moderacao.",
    },
    "SERVICES": {
        "mechanics": "Prestador aprovado > booking > atendimento > fechamento > split.",
        "rules": "Validacao do prestador, no-show, dispute flow e split auditavel.",
        "game": "Prestador bom acumula reputacao e agenda cheia.",
        "profit": "Comissao por fechamento, assinatura pro, lead pago e DOCS.",
        "cost": "Suporte, verificação, chargeback, fraude e customer success.",
    },
    "HEALTH": {
        "mechanics": "Perfil > triagem > plano de cuidado > consulta > follow-up.",
        "rules": "LGPD sensivel, consentimento granular e trilha clinica.",
        "game": "Cuidado vira trilha continua, nao consulta isolada.",
        "profit": "Teleconsulta, assinatura familiar, employer plan e marketplace clinico.",
        "cost": "Compliance, atendimento especializado, integrações e suporte.",
    },
    "FITNESS": {
        "mechanics": "Sessao > meta > validacao > reward > integracao com saude.",
        "rules": "Antifraude de atividade, consentimento de wearable e funding do premio.",
        "game": "Mexeu o corpo, ganhou progresso de verdade.",
        "profit": "Assinatura fitness, sponsorship e reward financiado por parceiros.",
        "cost": "Validacao, rewards, integrações com device e suporte.",
    },
    "PHARMACY": {
        "mechanics": "Pedido > receita > dispensacao > entrega > comprovacao.",
        "rules": "Controlados, receita valida, trilha de dispensacao e compliance.",
        "game": "Remedio certo no fluxo certo evita erro e atrito.",
        "profit": "Margem sobre pedido, fee de entrega, assinatura e parceria com farmacias.",
        "cost": "Compliance, controle de estoque, entrega, suporte e antifraude.",
    },
    "VET": {
        "mechanics": "Pet > caso clinico > atendimento > prescricao > follow-up.",
        "rules": "Consentimento do tutor, historico clinico e trilha de medicamento.",
        "game": "Cuidar do pet vira jornada acompanhada.",
        "profit": "Consulta, assinatura pet, farmacia vet e servicos parceiros.",
        "cost": "Atendimento, prontuario, suporte e integrações clinicas.",
    },
    "MENTE": {
        "mechanics": "Agenda sessao > conduz atendimento > registra follow-up seguro.",
        "rules": "Confidencialidade terapêutica, LGPD sensivel e acesso minimo.",
        "game": "O avancar vem da constancia, nao da pressao.",
        "profit": "Teleterapia, assinatura, employer plan e bundles com HEALTH.",
        "cost": "Profissionais, compliance, storage seguro e suporte.",
    },
    "EDU": {
        "mechanics": "Trilha > matricula > modulo > certificacao > reward de conclusao.",
        "rules": "Certificado rastreavel, governanca de conteudo e reward auditavel.",
        "game": "Estudar desbloqueia conquista, nao so diploma.",
        "profit": "Assinatura, curso premium, patrocinio e parceria empregadora.",
        "cost": "Conteudo, suporte, plataforma, certificacao e moderacao.",
    },
    "JOBS": {
        "mechanics": "Vaga > candidatura > matching > shortlist > contratacao.",
        "rules": "Privacidade do candidato, explicabilidade do matching e anti-vies.",
        "game": "Quando encaixa bem, parece matchmaking certeiro.",
        "profit": "Employer plan, fee por vaga, fee por contratacao e DOCS.",
        "cost": "Matching, suporte, verificação e customer success B2B.",
    },
    "CHARITY": {
        "mechanics": "Causa > capta doacao > aprova repasse > presta contas.",
        "rules": "Ledger social imutavel, auditoria da doacao e rastreio do impacto.",
        "game": "Doar deixa de ser fe cega e vira impacto visivel.",
        "profit": "Patrocinio institucional, fee administrativo opcional e white-label social.",
        "cost": "Compliance, auditoria, suporte e prestacao de contas.",
    },
    "TECH": {
        "mechanics": "Provisiona cliente > chaveia integracao > entrega webhook/API > monitora uso.",
        "rules": "Hash de segredo, replay seguro e limites por cliente.",
        "game": "Integracao saudavel e painel sem erro piscando.",
        "profit": "Assinatura API, uso por volume, setup fee e conectores premium.",
        "cost": "Infra, observabilidade, suporte tecnico e segurança.",
    },
    "DOCS": {
        "mechanics": "Gera documento > assina > carimba hash > armazena prova.",
        "rules": "Imutabilidade documental, checksum e trilha de assinatura.",
        "game": "Cada documento fechado vira carimbo de concluido do sistema.",
        "profit": "Fee por documento, assinatura, storage juridico e API.",
        "cost": "Processamento, armazenamento, assinatura e compliance.",
    },
}


BENCHMARK_ROWS = [
    [
        "Food / Delivery",
        "iFood: Basico 12% + 3,2%; Entrega 23% + 3,2%; mensalidade R$110 ou R$150 acima do gatilho.",
        "Valley: 8%-10% com entrega propria; 16%-18% quando a logistica e Valley.",
    ],
    [
        "Marketplace",
        "Mercado Livre: Classico entre 10% e 14%; Premium entre 15% e 19%.",
        "Valley: 9%-12% padrao; 12%-14% em categorias com risco maior.",
    ],
    [
        "Pagamentos",
        "Mercado Pago Point: Pix 0,49%, debito 1,99%, credito 30d 3,03%; Stone promocional: debito 0,74%, credito 1x 2,99%.",
        "Valley Pay/Plug: Pix 0,69%-0,89%; debito 1,49%-1,89%; credito 30d 2,99%-3,49%.",
    ],
    [
        "Mobility",
        "Uber informa taxa de servico variavel por viagem e preco dinamico por oferta e demanda.",
        "Valley: 10%-12% carro, 8%-10% moto, sempre com piso economico por rota.",
    ],
    [
        "Eventos / Turismo",
        "Sympla: 10% para eventos pagos e a partir de 15% em lugar marcado.",
        "Valley: 6%-8% ticketing padrao; 8%-10% quando houver escrow, docs e risco.",
    ],
    [
        "SaaS Comercio / ERP",
        "Nuvemshop: R$69, R$164 e R$449; Bling: R$55 e R$120 nas faixas iniciais.",
        "Valley Business/Tech: R$49 entrada, R$99 crescimento e R$199 escala.",
    ],
    [
        "Docs / Legal",
        "Clicksign: R$39, R$59 e R$85; Docusign: R$45 e R$105 nos planos iniciais.",
        "Valley Docs/Legal: R$29-R$49 por mes e excedente controlado por documento.",
    ],
]


SCENARIOS = [
    Scenario(users=1_000, active_rate=0.35, monthly_revenue_brl=12_000, monthly_variable_cost_brl=7_000, monthly_fixed_cost_brl=180_000),
    Scenario(users=10_000, active_rate=0.40, monthly_revenue_brl=130_000, monthly_variable_cost_brl=70_000, monthly_fixed_cost_brl=260_000),
    Scenario(users=100_000, active_rate=0.48, monthly_revenue_brl=1_450_000, monthly_variable_cost_brl=600_000, monthly_fixed_cost_brl=820_000),
    Scenario(users=1_000_000, active_rate=0.52, monthly_revenue_brl=15_000_000, monthly_variable_cost_brl=5_200_000, monthly_fixed_cost_brl=4_100_000),
    Scenario(users=100_000_000, active_rate=0.55, monthly_revenue_brl=1_420_000_000, monthly_variable_cost_brl=430_000_000, monthly_fixed_cost_brl=170_000_000),
]


ASSUMPTIONS = [
    "Modelo mensal, nao anual, para comparar escala com a mesma lente operacional.",
    "Registro canonico local: V47, com 47 modulos e 9 dominios.",
    "Precos Valley deliberadamente abaixo dos benchmarks oficiais consultados em 21/04/2026.",
    "PAY e PLUG capturam a maior parte das jornadas transacionais; sem isso a margem do ecossistema quebra.",
    "Rewards, Pepitas e campanhas de gaming precisam ser financiados por merchant ou anunciante, nao pelo caixa geral.",
    "FOOD, DELIVERY e MOBILITY operam em microzonas densas, sem subsidio cego de frete ou corrida.",
    "Custos de IA, cloud, antifraude e suporte sao inferencias de planejamento; nao sao proposta comercial de fornecedor.",
]


DIAGNOSIS = [
    "A conta nao fecha em 1.000 e 10.000 usuarios se a Valley insistir em ligar o stack V47 inteiro com precos muito abaixo do mercado.",
    "O ponto de equilibrio do ecossistema completo com precificacao agressiva aparece perto de 100.000 usuarios, desde que PAY, PLUG, DOCS e BUSINESS estejam acoplados aos fluxos principais.",
    "A partir de 1.000.000 usuarios, a margem melhora de forma relevante porque SaaS, pagamentos e documentos financiam a operacao fisica e parte da IA.",
    "Em 100.000.000 usuarios, o modelo so permanece saudavel se Valley operar por clusters, contratos B2B/B2G e attach financeiro alto; caso contrario a complexidade destrói margem.",
]


IMPROVEMENTS = [
    "Fazer rollout por ondas. Abrir primeiro PAY, PLUG, BUSINESS, DOCS, MARKETPLACE e EVENTS; so depois escalar FOOD, DELIVERY, MOBILITY e IA pesada.",
    "Separar comissao, processamento e logistica na precificacao. Headline barata com custo escondido corrói margem e confianca.",
    "Aplicar piso economico por rota e por SKU. O repo ja caminha nessa direcao com guardrails de competividade e benchmark por rota.",
    "Empacotar BUSINESS + PAY + PLUG + DOCS para aumentar ARPU e reduzir dependencia de take rate baixo.",
    "Limitar IA por plano e usar fila assincrona em tarefas caras. Chat livre e ilimitado nao fecha a conta.",
    "Financiar gamificacao por parceiro. Reward sem funding externo nao e crescimento, e passivo promocional.",
]


REFERENCES = [
    {
        "title": "iFood - Planos para restaurantes",
        "summary": "Pagina oficial consultada em 21/04/2026 com Basico 12% + 3,2%, Entrega 23% + 3,2% e mensalidades de R$110/R$150 acima do gatilho de faturamento.",
        "url": "https://parceiros.ifood.com.br/restaurante/planos-ifood",
    },
    {
        "title": "iFood - taxa minima por entrega",
        "summary": "Pagina institucional publicada em 29/08/2025 informando R$7 para bicicleta e R$7,50 para moto/carro.",
        "url": "https://institucional.ifood.com.br/entregadores/taxa-de-entrega-ifood/",
    },
    {
        "title": "Mercado Livre - custo para vender um produto",
        "summary": "Ajuda oficial consultada em 21/04/2026 com Classico entre 10% e 14% e Premium entre 15% e 19%, dependendo de valor e categoria.",
        "url": "https://www.mercadolivre.com.br/ajuda/870",
    },
    {
        "title": "Mercado Pago - tarifas Point",
        "summary": "Ajuda oficial consultada em 21/04/2026 com Pix 0,49%, debito 1,99% e credito 30 dias em 3,03% no exemplo padrao.",
        "url": "https://www.mercadopago.com.br/ajuda/quanto-custa-receber-pagamentos-com-o-point_2660",
    },
    {
        "title": "Stone - taxas promocionais",
        "summary": "Pagina oficial consultada em 21/04/2026 com exemplo promocional de 0,74% no debito e 2,99% no credito 1x para novos clientes elegiveis.",
        "url": "https://www.stone.com.br/",
    },
    {
        "title": "Sympla - quanto custa",
        "summary": "Pagina oficial consultada em 21/04/2026 com taxa zero para evento gratuito, 10% para evento pago e a partir de 15% em lugar marcado.",
        "url": "https://produtores.sympla.com.br/quanto-custa/",
    },
    {
        "title": "Uber - marketplace pricing",
        "summary": "Paginas oficiais consultadas em 21/04/2026 afirmando que o preco ao usuario e antecipado, a taxa de servico varia por viagem e o preco dinamico responde a oferta e demanda.",
        "url": "https://www.uber.com/br/pt-br/marketplace/pricing/",
    },
    {
        "title": "Nuvemshop - planos e precos",
        "summary": "Pagina oficial consultada em 21/04/2026 com planos de R$69, R$164 e R$449 por mes.",
        "url": "https://www.nuvemshop.com.br/planos-e-precos",
    },
    {
        "title": "Bling - atualizacao de 2026",
        "summary": "Ajuda oficial consultada em 21/04/2026 com Cobalto em R$55 e Titanio Faixa 1 em R$120 apos ajuste de abril de 2026.",
        "url": "https://ajuda.bling.com.br/hc/pt-br/articles/30224184866583-Altera%C3%A7%C3%A3o-nos-planos-e-pre%C3%A7os-do-Bling-em-abril-de-2026",
    },
    {
        "title": "Clicksign - planos",
        "summary": "Pagina oficial consultada em 21/04/2026 com Start em R$39, Plus em R$59 e Automacao em R$85, alem de excedentes por documento.",
        "url": "https://www.clicksign.com/planos-e-precos-juridico",
    },
    {
        "title": "Docusign - preco de assinatura eletronica",
        "summary": "Pagina oficial consultada em 21/04/2026 com plano Pessoal a partir de R$45 e Padrao a partir de R$105 por mes.",
        "url": "https://www.docusign.com/pt-br/blog/assinatura-eletronica-quanto-custa",
    },
]


def load_modules() -> list[dict]:
    data = json.loads(MODULES_FILE.read_text(encoding="utf-8"))
    return data["modules"]


def build_styles():
    styles = getSampleStyleSheet()

    styles["Title"].fontName = "Helvetica-Bold"
    styles["Title"].fontSize = 21
    styles["Title"].leading = 26
    styles["Title"].textColor = colors.HexColor("#12312B")
    styles["Title"].alignment = TA_CENTER
    styles["Title"].spaceAfter = 14

    styles["Heading1"].fontName = "Helvetica-Bold"
    styles["Heading1"].fontSize = 15
    styles["Heading1"].leading = 19
    styles["Heading1"].textColor = colors.HexColor("#16463D")
    styles["Heading1"].spaceBefore = 12
    styles["Heading1"].spaceAfter = 7

    styles["Heading2"].fontName = "Helvetica-Bold"
    styles["Heading2"].fontSize = 11.5
    styles["Heading2"].leading = 15
    styles["Heading2"].textColor = colors.HexColor("#245B4F")
    styles["Heading2"].spaceBefore = 8
    styles["Heading2"].spaceAfter = 5

    styles["BodyText"].fontName = "Helvetica"
    styles["BodyText"].fontSize = 9
    styles["BodyText"].leading = 12
    styles["BodyText"].textColor = colors.HexColor("#1E2423")
    styles["BodyText"].spaceAfter = 4

    styles.add(
        ParagraphStyle(
            name="Small",
            parent=styles["BodyText"],
            fontSize=8,
            leading=10,
            textColor=colors.HexColor("#32423C"),
        )
    )
    styles.add(
        ParagraphStyle(
            name="Caption",
            parent=styles["BodyText"],
            fontSize=8,
            leading=10,
            textColor=colors.HexColor("#51615C"),
            alignment=TA_CENTER,
        )
    )
    return styles


def brl(value: float) -> str:
    text = f"{value:,.2f}"
    return "R$ " + text.replace(",", "X").replace(".", ",").replace("X", ".")


def pct(value: float) -> str:
    return f"{value * 100:.1f}%".replace(".", ",")


def add_paragraph(story: list, text: str, style) -> None:
    story.append(Paragraph(escape(text), style))


def add_table(story: list, rows: list[list[str]], col_widths: list[float]) -> None:
    table = Table(rows, colWidths=col_widths, repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#16463D")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                ("FONTSIZE", (0, 0), (-1, -1), 8),
                ("LEADING", (0, 0), (-1, -1), 10),
                ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#B9C9C2")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.HexColor("#F5F8F6"), colors.white]),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(table)
    story.append(Spacer(1, 0.12 * inch))


def scenario_rows() -> list[list[str]]:
    rows = [[
        "Usuarios",
        "MAU",
        "Receita mensal",
        "Custo variavel",
        "Custo fixo",
        "Resultado",
        "Status",
    ]]
    for scenario in SCENARIOS:
        rows.append(
            [
                f"{scenario.users:,}".replace(",", "."),
                f"{scenario.mau:,}".replace(",", "."),
                brl(scenario.monthly_revenue_brl),
                brl(scenario.monthly_variable_cost_brl),
                brl(scenario.monthly_fixed_cost_brl),
                brl(scenario.operating_result_brl),
                "Fecha" if scenario.operating_result_brl > 0 else "Nao fecha",
            ]
        )
    return rows


def benchmark_rows() -> list[list[str]]:
    rows = [["Frente", "Benchmark oficial no Brasil", "Faixa-alvo Valley"]]
    rows.extend(BENCHMARK_ROWS)
    return rows


def build_markdown(modules: list[dict]) -> str:
    lines: list[str] = []
    lines.append("# Memorando Estruturado - Modulos, Monetizacao, Custos e Escala Valley")
    lines.append("")
    lines.append("Data de consolidacao: 21/04/2026")
    lines.append("Base canonica local: registro V47 com 47 modulos e 9 dominios.")
    lines.append("")
    lines.append("## Escopo")
    lines.append("Este memorando descreve cada modulo, sua mecanica operacional, regras, gamificacao em linguagem popular, monetizacao, custos principais e uma simulacao de escala para 1.000, 10.000, 100.000, 1.000.000 e 100.000.000 usuarios.")
    lines.append("")
    lines.append("## Premissas de simulacao")
    for item in ASSUMPTIONS:
        lines.append(f"- {item}")
    lines.append("")
    lines.append("## Benchmarks oficiais e alvo competitivo Valley")
    for row in BENCHMARK_ROWS:
        lines.append(f"### {row[0]}")
        lines.append(f"Benchmark oficial: {row[1]}")
        lines.append(f"Alvo Valley: {row[2]}")
        lines.append("")
    lines.append("## Simulacao de escala")
    for scenario in SCENARIOS:
        lines.append(f"### {scenario.users:,} usuarios".replace(",", "."))
        lines.append(f"MAU estimado: {scenario.mau:,}".replace(",", "."))
        lines.append(f"Receita mensal: {brl(scenario.monthly_revenue_brl)}")
        lines.append(f"Custo variavel mensal: {brl(scenario.monthly_variable_cost_brl)}")
        lines.append(f"Custo fixo mensal: {brl(scenario.monthly_fixed_cost_brl)}")
        lines.append(f"Margem de contribuicao: {pct(scenario.contribution_margin)}")
        lines.append(f"Margem operacional: {pct(scenario.operating_margin)}")
        lines.append(f"Resultado mensal: {brl(scenario.operating_result_brl)}")
        lines.append(f"Status: {'Fecha' if scenario.operating_result_brl > 0 else 'Nao fecha'}")
        lines.append("")
    lines.append("## Leitura executiva")
    for item in DIAGNOSIS:
        lines.append(f"- {item}")
    lines.append("")
    current_domain = None
    for module in modules:
        domain = module["domain"]
        if domain != current_domain:
            lines.append(f"## Dominio: {DOMAIN_LABELS[domain]}")
            lines.append(DOMAIN_INTROS[domain])
            lines.append("")
            current_domain = domain
        notes = MODULE_NOTES[module["code"]]
        lines.append(f"### {module['number']:02d}. {module['code']} - {module['name']}")
        lines.append(f"Objetivo: {module['description_ptbr']}")
        lines.append(f"Mecanica: {notes['mechanics']}")
        lines.append(f"Regras: {notes['rules']}")
        lines.append(f"Gamificacao popular: {notes['game']}")
        lines.append(f"Como a Valley lucra: {notes['profit']}")
        lines.append(f"Principais custos: {notes['cost']}")
        lines.append("")
    lines.append("## Opcoes de correcao e melhoria")
    for item in IMPROVEMENTS:
        lines.append(f"- {item}")
    lines.append("")
    lines.append("## Referencias")
    for ref in REFERENCES:
        lines.append(f"### {ref['title']}")
        lines.append(ref["summary"])
        lines.append(ref["url"])
        lines.append("")
    return "\n".join(lines)


def build_story(modules: list[dict], styles) -> list:
    story: list = []
    story.append(Spacer(1, 0.6 * inch))
    story.append(Paragraph("Memorando Estruturado Valley", styles["Title"]))
    story.append(Paragraph("Modulos, mecanica, regras, gamificacao, monetizacao, custos e simulacao de escala", styles["Caption"]))
    story.append(Spacer(1, 0.15 * inch))
    story.append(Paragraph("Consolidado em 21/04/2026 a partir do registro canonico V47 do repo e de benchmarks oficiais do mercado brasileiro.", styles["Caption"]))
    story.append(PageBreak())

    story.append(Paragraph("Escopo", styles["Heading1"]))
    add_paragraph(
        story,
        "Este memorando descreve os 47 modulos canonicos do ecossistema Valley, detalha mecanica operacional, regras de uso, gamificacao em linguagem popular, como a Valley captura receita e quais custos puxam margem.",
        styles["BodyText"],
    )
    add_paragraph(
        story,
        "A simulacao economica abaixo e mensal e compara cinco niveis de base instalada: 1.000, 10.000, 100.000, 1.000.000 e 100.000.000 usuarios.",
        styles["BodyText"],
    )

    story.append(Paragraph("Premissas de Simulacao", styles["Heading1"]))
    for item in ASSUMPTIONS:
        add_paragraph(story, f"- {item}", styles["BodyText"])

    story.append(Paragraph("Benchmarks Oficiais e Faixa-Alvo Valley", styles["Heading1"]))
    add_table(story, benchmark_rows(), [1.35 * inch, 3.1 * inch, 2.55 * inch])

    story.append(Paragraph("Simulacao de Escala", styles["Heading1"]))
    add_table(story, scenario_rows(), [1.0 * inch, 0.75 * inch, 1.25 * inch, 1.15 * inch, 1.05 * inch, 1.0 * inch, 0.65 * inch])
    add_paragraph(story, "Leitura: em 1.000 e 10.000 usuarios o stack V47 completo nao fecha com preco agressivo. O ponto de equilibrio aparece perto de 100.000 usuarios desde que PAY, PLUG, DOCS e BUSINESS carreguem as jornadas principais.", styles["Small"])

    story.append(Paragraph("Leitura Executiva", styles["Heading1"]))
    for item in DIAGNOSIS:
        add_paragraph(story, f"- {item}", styles["BodyText"])

    current_domain = None
    for module in modules:
        domain = module["domain"]
        if domain != current_domain:
            story.append(PageBreak())
            story.append(Paragraph(f"Dominio - {DOMAIN_LABELS[domain]}", styles["Heading1"]))
            add_paragraph(story, DOMAIN_INTROS[domain], styles["BodyText"])
            current_domain = domain
        notes = MODULE_NOTES[module["code"]]
        story.append(Paragraph(f"{module['number']:02d}. {module['code']} - {module['name']}", styles["Heading2"]))
        add_paragraph(story, f"Objetivo: {module['description_ptbr']}", styles["BodyText"])
        add_paragraph(story, f"Mecanica: {notes['mechanics']}", styles["BodyText"])
        add_paragraph(story, f"Regras: {notes['rules']}", styles["BodyText"])
        add_paragraph(story, f"Gamificacao popular: {notes['game']}", styles["BodyText"])
        add_paragraph(story, f"Como a Valley lucra: {notes['profit']}", styles["BodyText"])
        add_paragraph(story, f"Principais custos: {notes['cost']}", styles["BodyText"])

    story.append(PageBreak())
    story.append(Paragraph("Opcoes de Correcao e Melhoria", styles["Heading1"]))
    for item in IMPROVEMENTS:
        add_paragraph(story, f"- {item}", styles["BodyText"])

    story.append(Paragraph("Referencias Oficiais", styles["Heading1"]))
    for ref in REFERENCES:
        story.append(Paragraph(ref["title"], styles["Heading2"]))
        add_paragraph(story, ref["summary"], styles["BodyText"])
        add_paragraph(story, ref["url"], styles["Small"])

    return story


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    modules = load_modules()
    markdown = build_markdown(modules)
    OUTPUT_MD.write_text(markdown, encoding="utf-8")

    styles = build_styles()
    story = build_story(modules, styles)
    doc = SimpleDocTemplate(
        str(OUTPUT_PDF),
        pagesize=A4,
        leftMargin=0.6 * inch,
        rightMargin=0.6 * inch,
        topMargin=0.6 * inch,
        bottomMargin=0.6 * inch,
        title="Memorando Estruturado Valley",
        author="Codex - Valley",
    )
    doc.build(story)
    print(f"Markdown: {OUTPUT_MD}")
    print(f"PDF: {OUTPUT_PDF}")


if __name__ == "__main__":
    main()
