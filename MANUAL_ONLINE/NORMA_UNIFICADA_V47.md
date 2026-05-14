<!--
PROPOSITO: Documentar NORMA UNIFICADA V47 no escopo operacional do Valley.
CONTEXTO: Este arquivo registra orientacoes, decisoes ou plano associado ao caminho MANUAL_ONLINE/NORMA_UNIFICADA_V47.md.
REGRAS: Manter informacao rastreavel, preservar nomenclatura Valley e atualizar ao mudar a rotina correspondente.
-->

# Norma Unificada V47

Esta norma consolida os PDFs oficiais do Valley Omniverse e resolve conflitos de diretriz pela regra que mais protege estabilidade, seguranca, continuidade de entrega, privacidade e coerencia arquitetural.

## Hierarquia De Decisao

1. Seguranca, privacidade, integridade do repositorio e conformidade legal vencem autonomia, velocidade ou conveniencia.
2. Contratos canonicos de dados vencem preferencias locais de implementacao.
3. Continuidade de entrega com estado real reportado vence simulacao de saude ou promessa otimista.
4. Automacao deve existir, mas nunca para vazar segredo, misturar dominios sensiveis ou corromper trilha auditavel.
5. Quando dois caminhos forem possiveis, torna-se norma o que maximiza mantenabilidade documentada e reduz retrabalho.

## Fontes Canonicas

1. `Valley Omniverse — Regras Consolidadas do Codex.pdf`
2. `Valley Omniverse – Regras Consolidadas para o Gemini Code Assist (v47).pdf`
3. `Painel Web Admin — Especificação Consolidada (v47).pdf`
4. `Esquema Consolidado do Valley Omniverse v47.pdf`
5. `Valley Omniverse v47 – Esquema de Banco de Dados.pdf`
6. `Valley Omniverse v47 – Esquema de Banco de Dados  2.pdf`
7. `Valley Omniverse – Mapeamento de Módulos (v47).pdf`
8. `Índice Oficial Valley Omniverse.pdf`
9. `Valley Omniverse – Papéis de Gemini, Code Assist e Codex e Integração de IA.pdf`

## Regras Tornadas Norma

### 1. Regra Suprema De Conflito

Quando houver contradicao entre autonomia irrestrita e seguranca operacional, vale seguranca operacional com entrega continua.

Quando houver contradicao entre velocidade e clareza arquitetural, vale clareza arquitetural documentada.

Quando houver contradicao entre automacao hostil ao ambiente e automacao controlada via esteira, vale a esteira controlada.

### 2. Dados E Limites

`users.user_id` e `wallets` continuam como nucleo absoluto.

Dados de saude mental, score financeiro e informacoes sensiveis ficam em ring-fence; admin nao acessa conteudo bruto, apenas metadado minimo e trilha autorizada.

Ledgers financeiros, equity, claims, eventos juridicos e auditorias operacionais permanecem append-only.

### 3. Painel Admin

Todo modulo deve aparecer no painel admin com:

- identidade tecnica;
- status e checklist;
- docs de operacao;
- dependencias e integracoes;
- acoes administrativas;
- trilha de automacao.

O painel admin deixa de ser um artefato manual e passa a ser gerado automaticamente pela esteira.

### 4. Tooling E Execucao

O runtime canonico de banco local e o `builder` no Docker Compose. Isso vira norma porque evita dependencia fraca de `psql` e `mongosh` no host.

Host tooling continua util para edicao e observabilidade, mas a execucao de release e aplicacao de banco prioriza o Compose.

Toda falha de Docker, Compose, bridge, token ou extensao deve ser reportada como bloqueio real; nao pode ser mascarada como saudavel.

### 5. IA E Orquestracao

Codex decide e integra.

Gemini sugere, analisa e aponta melhorias.

Code Assist opera como executor assistivo de codigo e ajustes.

Sugestao de IA so vira norma local quando respeita esta hierarquia:

1. seguranca e privacidade;
2. contratos de dados e arquitetura core-first;
3. estabilidade do repositorio e da esteira;
4. utilidade operacional para admin e times internos.

### 6. Builds E Producao

Builds de producao devem ser minimos, sem ferramentas de debug ou coletores de log de desenvolvimento.

Segredos nao entram em settings, JSON de repo, docs ou artefatos de painel.

Toda automacao nova precisa deixar trilha visivel em `MANUAL_ONLINE`, `config/` ou `tmp/`.

## Aplicacao Pratica No Workspace

- O painel admin passa a ser refletido por `admin/valley_admin_data.js`.
- O builder Compose passa a ser o executor padrao de release do banco.
- O workspace passa a ter manifestos formais para extensoes, ferramentas, perfis de terminal e squad de agentes.
- A configuracao local deve privilegiar comandos nao interativos, caminhos absolutos e estado documentado.
