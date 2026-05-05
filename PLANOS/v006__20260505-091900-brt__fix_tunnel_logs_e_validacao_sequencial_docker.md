# v006 - Fix Tunnel Logs E Validacao Sequencial Docker

## Resumo

- Corrigir o script `scripts/start_valley_admin_public.ps1` para nao quebrar quando os arquivos de log do cloudflared estiverem bloqueados por outro processo.
- Revalidar o admin publico.
- Reexecutar `apply-compose` e o builder Docker em sequencia para eliminar a corrida de migration observada quando ambos rodavam em paralelo.

## Checklist

- [x] Identificar o ponto de falha do script publico no reset de logs. Concluido em 2026-05-05 09:19:00 BRT.
- [x] Aplicar fallback seguro para arquivos de log bloqueados. Concluido em 2026-05-05 09:19:00 BRT.
- [x] Validar a sintaxe do script PowerShell apos o patch. Concluido em 2026-05-05 09:19:00 BRT.
- [x] Revalidar o runtime publico do admin. Concluido em 2026-05-05 09:19:00 BRT.
- [x] Executar `python scripts/valley_db_orchestrator.py apply-compose` com Docker responsivo. Concluido em 2026-05-05 09:19:00 BRT.
- [x] Executar `docker compose --profile builder run --rm builder` em sequencia, sem corrida com apply-compose. Concluido em 2026-05-05 09:19:00 BRT.

## Evidencias

- `scripts/start_valley_admin_public.ps1` ganhou fallback para trocar para um log com timestamp quando o arquivo padrao estiver lockado.
- A validacao sintatica do script PowerShell retornou `OK_PWSH_PARSE`.
- `python scripts/show_valley_public_urls.py` confirmou o admin publico saudavel em `https://admin.brasildesconto.com.br`.
- `python scripts/valley_db_orchestrator.py apply-compose` concluiu com PostgreSQL e MongoDB ativos e deployment status regenerado.
- A corrida previa em `020_v47_fix_tech_owner_coherence_trigger.sql` foi reproduzida apenas quando `apply-compose` e `builder` rodaram em paralelo.
- `docker compose --profile builder run --rm builder` concluiu com sucesso quando executado em sequencia.

## Bloqueios

- Nenhum bloqueio aberto depois da execucao sequencial.

## Proxima acao

- Se quiser blindar o fluxo para operadores futuros, o proximo passo coerente e encapsular a ordem correta em um unico script que rode `apply-compose` e so depois o builder.
