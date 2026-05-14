# Manual de Ambiente - valley (Codex Cloud)

## Objetivo
Este manual explica como manter sincronizadas as variáveis de ambiente e segredos do projeto no ambiente **valley**, com foco em segurança, estabilidade e redução de custo operacional.

## Arquivo de referência
- `tmp/runtime/codex-cloud-secrets.env`

Esse arquivo funciona como **template técnico** e checklist de variáveis obrigatórias para o runtime local e para o painel remoto do Codex Cloud.

## Processo de atualização
1. Atualize o template local com as chaves necessárias (sem segredos reais).
2. Acesse o painel do Codex Cloud em **Ambientes > valley**.
3. Cadastre/atualize os valores reais das variáveis de ambiente e segredos.
4. Reinicie/deploy do ambiente para aplicar as novas variáveis.
5. Valide logs e health-check após o deploy.

## Checklist rápido de validação pós-deploy
- Confirmar conexão com PostgreSQL sem erro de autenticação.
- Confirmar conexão com Redis sem timeout.
- Validar emissão/validação de JWT em rota protegida.
- Verificar ingestão de erros no Sentry.
- Revisar consumo de recursos para evitar custo desnecessário (pool, timeout e flags).

## Plano de rollback (baixo risco)
1. Reaplicar no painel Codex Cloud o último conjunto estável de variáveis.
2. Executar novo deploy/restart do ambiente `valley`.
3. Revalidar os 5 checks do bloco de pós-deploy.
4. Registrar causa raiz e ajuste definitivo neste manual.

## Boas práticas
- Nunca commitar segredos reais.
- Usar valores mínimos necessários por ambiente.
- Rotacionar chaves periodicamente.
- Revisar flags para desligar recursos não usados e reduzir custo.
- Definir dono técnico por integração para acelerar incidentes.

## Integrações impactadas
- API de produtos
- Banco PostgreSQL
- Redis
- Autenticação JWT
- Observabilidade (Sentry/logs)

## Mapa de responsabilidade operacional
- Produto/API: valida `PRODUCT_API_BASE_URL` e contratos de integração.
- Plataforma/Backend: valida `DATABASE_URL`, `DB_POOL_MIN` e `DB_POOL_MAX`.
- Plataforma/Runtime: valida `REDIS_URL`, `RUNTIME_TIMEOUT_MS` e feature flags.
- Segurança: valida `JWT_SECRET`, `JWT_EXPIRES_IN` e `ENCRYPTION_KEY`.
- Observabilidade: valida `SENTRY_DSN` e `LOG_LEVEL`.

## Referência cruzada para manutenção contínua
- Manual operacional de segredos: `tmp/runtime/codex-cloud-secrets.env`.
- Este documento deve ser atualizado sempre que novas integrações exigirem variáveis adicionais.

## Runbook de incidente Cloudflare Tunnel (Erro 1033)

### Cenário
O erro **1033** acontece quando o hostname publicado no Cloudflare (por exemplo `admin.brasildesconto.com.br`) está associado a um Tunnel, mas o conector `cloudflared` não está saudável, sem rota ativa, ou com regra de roteamento incorreta.

### Objetivo desta rotina
Restabelecer rapidamente o tráfego do painel administrativo com menor custo operacional possível, priorizando:
- recuperação sem downtime prolongado;
- verificação orientada por evidências (logs e status);
- prevenção de reincidência.

### Integrações envolvidas
- **Cloudflare Zero Trust / Tunnel**: camada de entrada pública e roteamento.
- **Serviço de origem do admin**: aplicação interna atrás do Tunnel.
- **DNS do domínio**: CNAME/registro gerenciado para o hostname publicado.


### Automação de triagem (recomendado)
Para acelerar a resposta inicial com menor custo operacional, execute o script versionado:

```bash
./scripts/check_cloudflare_tunnel_1033.sh admin.brasildesconto.com.br
```

Esse script consolida validações de DNS, HTTP e status local do `cloudflared`, reduzindo retrabalho manual e padronizando o diagnóstico entre operadores.


### O script faz balanceamento de carga?
Não. O `scripts/check_cloudflare_tunnel_1033.sh` é uma automação de **diagnóstico/triagem** e não altera recursos no Cloudflare.

Ele ajuda a identificar rapidamente se há sintomas de indisponibilidade (DNS/HTTP/processo local), mas o balanceamento de carga precisa ser configurado no painel da Cloudflare (Zero Trust com múltiplos conectores e/ou Cloudflare Load Balancer, conforme arquitetura).

### Automação com autocorreção (DNS + token/API + restart local)
Além da triagem, o script agora suporta **remediação opcional** para reduzir tempo de indisponibilidade:

- valida token de API da Cloudflare (`/user/tokens/verify`);
- corrige/cria CNAME do hostname via API (quando variáveis forem fornecidas);
- permite restart automático local do `cloudflared` (quando habilitado).

Exemplo (modo diagnóstico):
```bash
./scripts/check_cloudflare_tunnel_1033.sh admin.brasildesconto.com.br diagnose
```

Exemplo (modo remediação):
```bash
CF_API_TOKEN=*** CF_ZONE_ID=*** CF_TUNNEL_CNAME_TARGET=SEU-TUNNEL-ID.cfargotunnel.com AUTO_RESTART_CLOUDFLARED=true ./scripts/check_cloudflare_tunnel_1033.sh admin.brasildesconto.com.br remediate
```

Integração e custo:
- Priorizar **2+ conectores cloudflared** para HA com menor custo recorrente.
- Usar **Cloudflare Load Balancer** somente quando houver requisito real de múltiplas origens com health-check avançado.

### Passo a passo de diagnóstico e correção
1. **Confirmar status do Tunnel no Zero Trust**
   - Acesse `Cloudflare Dashboard > Zero Trust > Networks > Tunnels`.
   - Verifique se o Tunnel associado ao `admin.brasildesconto.com.br` está como **Healthy** e com conectores online.

2. **Validar mapeamento de Public Hostname**
   - No Tunnel correto, revise `Public Hostnames`.
   - Confirme regra exata:
     - Hostname: `admin.brasildesconto.com.br`
     - Service: URL interna correta (ex.: `http://localhost:3000` ou serviço interno real).
   - Corrija porta/protocolo se houver divergência.

3. **Checar processo cloudflared na origem**
   - Em servidor Linux com systemd:
     ```bash
     sudo systemctl status cloudflared
     sudo journalctl -u cloudflared -n 200 --no-pager
     ```
   - Se estiver parado/falho:
     ```bash
     sudo systemctl restart cloudflared
     sudo systemctl enable cloudflared
     ```

4. **Validar credenciais e arquivo de configuração do Tunnel**
   - Conferir se o `credentials-file` do Tunnel existe e corresponde ao UUID correto.
   - Revisar `config.yml` do cloudflared com entradas de `tunnel`, `credentials-file` e `ingress`.

5. **Testar resolução e resposta externa**
   - Testar DNS:
     ```bash
     dig +short admin.brasildesconto.com.br
     ```
   - Testar HTTP:
     ```bash
     curl -I https://admin.brasildesconto.com.br
     ```
   - Resultado esperado: não retornar 1033.

6. **Aplicar mitigação de alta disponibilidade (opcional e recomendada)**
   - Subir **2+ conectores cloudflared** para o mesmo Tunnel em hosts/instâncias distintas.
   - Isso reduz risco de indisponibilidade por falha única e segue a recomendação exibida pelo próprio Cloudflare.

### Checklist de fechamento do incidente
- Tunnel em estado Healthy com pelo menos 1 conector online.
- Hostname público apontando para serviço interno correto.
- `curl -I` sem erro 1033.
- Registro no manual com causa raiz e ação preventiva.

### Causas raiz mais comuns (referência rápida)
- Serviço `cloudflared` parado após reboot/atualização.
- Token/credencial inválido ou arquivo movido.
- Ingress com hostname correto, mas service/porta errados.
- Alteração DNS sem alinhamento com o Tunnel.

### Ação preventiva mensal (redução de custo + confiabilidade)
- Revisar somente os túneis ativos e remover túneis órfãos.
- Padronizar monitoramento de uptime do hostname crítico.
- Manter template único de configuração por ambiente para evitar retrabalho.
