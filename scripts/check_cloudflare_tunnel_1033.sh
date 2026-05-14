#!/usr/bin/env bash
# check_cloudflare_tunnel_1033.sh
#
# Objetivo:
#   Automatizar diagnóstico e correções de primeiro nível para incidente Cloudflare Tunnel 1033,
#   com foco em restauração rápida do tráfego e redução de custo operacional.
#
# Para que serve:
#   - Modo diagnose: verifica DNS, HTTP e saúde local do cloudflared.
#   - Modo remediate: tenta autocorreção segura (restart local + ajuste DNS via API Cloudflare).
#
# Integrações:
#   - Cloudflare API (DNS e validação de token): usa CF_API_TOKEN + CF_ZONE_ID.
#   - Cloudflare Tunnel: usa CF_TUNNEL_CNAME_TARGET para apontar CNAME do hostname.
#   - Host local (systemd/cloudflared): reinicia serviço quando autorizado.
#
# Justificativa:
#   - Padroniza resposta operacional em incidentes recorrentes.
#   - Evita ações manuais dispersas no dashboard em momentos críticos.
#   - Mantém trilha clara do que foi verificado/corrigido.

set -euo pipefail

HOSTNAME_TO_CHECK="${1:-admin.brasildesconto.com.br}"
ACTION="${2:-diagnose}" # diagnose | remediate
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-12}"
AUTO_RESTART_CLOUDFLARED="${AUTO_RESTART_CLOUDFLARED:-false}"

# Variáveis opcionais para autocorreção via API Cloudflare
CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_ZONE_ID="${CF_ZONE_ID:-}"
CF_TUNNEL_CNAME_TARGET="${CF_TUNNEL_CNAME_TARGET:-}"

print_section() { printf '\n========== %s ==========' "$1"; printf '\n'; }
warn() { printf '[AVISO] %s\n' "$1"; }
ok() { printf '[OK] %s\n' "$1"; }
fail() { printf '[FALHA] %s\n' "$1"; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { fail "Comando obrigatório não encontrado: $1"; exit 1; }
}

api_call() {
  local method="$1" url="$2" data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -sS --max-time "$TIMEOUT_SECONDS" -X "$method" "$url" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "$data"
  else
    curl -sS --max-time "$TIMEOUT_SECONDS" -X "$method" "$url" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json"
  fi
}

check_dns() {
  print_section "Diagnóstico DNS"
  if command -v dig >/dev/null 2>&1; then
    DNS_RESULT="$(dig +short "$HOSTNAME_TO_CHECK" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/ *$//')"
    if [[ -n "$DNS_RESULT" ]]; then ok "DNS respondeu: $DNS_RESULT"; else fail "Sem resposta DNS para $HOSTNAME_TO_CHECK"; fi
  else
    warn "Comando dig não encontrado; pulando verificação DNS."
  fi
}

check_http() {
  print_section "Diagnóstico HTTP"
  require_cmd curl
  HTTP_HEADERS="$(curl -sS -I --max-time "$TIMEOUT_SECONDS" "https://$HOSTNAME_TO_CHECK" || true)"
  if [[ -z "$HTTP_HEADERS" ]]; then
    fail "Sem resposta HTTP em https://$HOSTNAME_TO_CHECK"
    return 1
  fi
  printf '%s\n' "$HTTP_HEADERS"
  if printf '%s' "$HTTP_HEADERS" | grep -qi 'HTTP/.* 530'; then
    fail "Cloudflare retornou HTTP 530 (origem/túnel indisponível ou sem resolução)."
    return 1
  elif printf '%s' "$HTTP_HEADERS" | grep -qi 'error 1033\|cloudflare tunnel error'; then
    fail "Sinal de erro 1033 detectado no endpoint público."
    return 1
  fi
  ok "Sem padrão de erro 1033/530 no endpoint público."
}

check_local_cloudflared() {
  print_section "Processo local cloudflared"
  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl indisponível; ambiente pode não ser systemd."
    return 0
  fi
  if ! systemctl list-unit-files | grep -q '^cloudflared\.service'; then
    warn "Serviço cloudflared não encontrado neste host."
    return 0
  fi
  if systemctl is-active --quiet cloudflared; then
    ok "Serviço cloudflared está ativo no host local."
    return 0
  fi
  fail "Serviço cloudflared está inativo no host local."
  if [[ "$ACTION" == "remediate" && "$AUTO_RESTART_CLOUDFLARED" == "true" ]]; then
    warn "Tentando restart automático do cloudflared (AUTO_RESTART_CLOUDFLARED=true)."
    systemctl restart cloudflared || true
    sleep 2
    if systemctl is-active --quiet cloudflared; then ok "cloudflared reiniciado com sucesso."; else fail "Falha no restart automático do cloudflared."; fi
  else
    warn "Para auto-restart, execute com ACTION=remediate e AUTO_RESTART_CLOUDFLARED=true."
  fi
}

validate_token() {
  print_section "Validação de token/API Cloudflare"
  if [[ -z "$CF_API_TOKEN" ]]; then warn "CF_API_TOKEN ausente; pulando validação de API."; return 1; fi
  require_cmd curl
  require_cmd jq
  local resp success
  resp="$(api_call GET "https://api.cloudflare.com/client/v4/user/tokens/verify" || true)"
  success="$(printf '%s' "$resp" | jq -r '.success // false')"
  if [[ "$success" == "true" ]]; then
    ok "Token Cloudflare válido."
    return 0
  fi
  fail "Token Cloudflare inválido/expirado; renovar credencial de API é necessário."
  return 1
}

ensure_dns_cname() {
  print_section "Autocorreção DNS (Cloudflare API)"
  if [[ -z "$CF_API_TOKEN" || -z "$CF_ZONE_ID" || -z "$CF_TUNNEL_CNAME_TARGET" ]]; then
    warn "Variáveis incompletas para DNS automático (CF_API_TOKEN, CF_ZONE_ID, CF_TUNNEL_CNAME_TARGET)."
    return 1
  fi
  require_cmd jq
  local list_resp rec_id rec_content payload upsert_resp success
  list_resp="$(api_call GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=CNAME&name=$HOSTNAME_TO_CHECK")"
  rec_id="$(printf '%s' "$list_resp" | jq -r '.result[0].id // empty')"
  rec_content="$(printf '%s' "$list_resp" | jq -r '.result[0].content // empty')"

  payload="$(jq -nc --arg name "$HOSTNAME_TO_CHECK" --arg content "$CF_TUNNEL_CNAME_TARGET" '{type:"CNAME",name:$name,content:$content,ttl:60,proxied:true}')"
  if [[ -n "$rec_id" ]]; then
    if [[ "$rec_content" == "$CF_TUNNEL_CNAME_TARGET" ]]; then
      ok "DNS CNAME já está correto: $HOSTNAME_TO_CHECK -> $CF_TUNNEL_CNAME_TARGET"
      return 0
    fi
    upsert_resp="$(api_call PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$rec_id" "$payload")"
  else
    upsert_resp="$(api_call POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" "$payload")"
  fi

  success="$(printf '%s' "$upsert_resp" | jq -r '.success // false')"
  if [[ "$success" == "true" ]]; then
    ok "DNS automático aplicado com sucesso para $HOSTNAME_TO_CHECK."
  else
    fail "Falha ao aplicar DNS automático. Verifique permissões do token e zone id."
  fi
}

print_section "Contexto"
printf 'Hostname analisado: %s\n' "$HOSTNAME_TO_CHECK"
printf 'Ação: %s\n' "$ACTION"
printf 'Data UTC: %s\n' "$(date -u +'%Y-%m-%d %H:%M:%S UTC')"

check_dns
check_http || true
check_local_cloudflared
validate_token || true

if [[ "$ACTION" == "remediate" ]]; then
  ensure_dns_cname || true
fi

print_section "Próximas ações recomendadas"
printf '%s\n' "1) Confirmar Tunnel em Zero Trust > Networks > Tunnels (Healthy + conectores online)."
printf '%s\n' "2) Manter 2+ conectores cloudflared por tunnel para alta disponibilidade sem custo de LB dedicado."
printf '%s\n' "3) Usar Cloudflare Load Balancer apenas quando houver múltiplas origens distintas e necessidade de health-check L7 avançado."
