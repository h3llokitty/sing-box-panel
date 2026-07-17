#!/usr/bin/env bash
set -euo pipefail

### ── ПАРАМЕТРЫ (загружаются из config.env) ──────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/i18n.sh"
CONFIG_FILE="${VPN_CONFIG:-$SCRIPT_DIR/config.env}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  printf -- "$(t config_not_found)\n" "$CONFIG_FILE"
  echo "$(t config_not_found_hint)"
  exit 1
fi
source "$CONFIG_FILE"

: "${A_IP:?A_IP not set in config.env}"
: "${A_DOMAIN:?A_DOMAIN not set in config.env}"
: "${ACME_EMAIL:?ACME_EMAIL not set in config.env}"
: "${WG_PORT:=51820}"
: "${WG_NET:=10.10.0}"
: "${HY2_PORT:=443}"
: "${B_DOMAIN:?B_DOMAIN not set in config.env}"
: "${B_PORT:=443}"
: "${B_PASS:?B_PASS not set in config.env}"
: "${PROFILE_HOST:=$A_DOMAIN}"
: "${PROFILE_PORT:=8443}"
: "${VLESS_PORT:=443}"
: "${VLESS_DEST:?VLESS_DEST not set in config.env}"
: "${VLESS_SNI:=$VLESS_DEST}"
: "${VLESS_INTERNAL_PORT_PRIMARY:=20000}"
: "${AVAILABLE_PROXY_TYPES:=hy2 vless}"
### ─────────────────────────────────────────────────────────

AIPS_SPLIT='"0.0.0.0/5","8.0.0.0/7","11.0.0.0/8","12.0.0.0/6","16.0.0.0/4","32.0.0.0/3","64.0.0.0/2","128.0.0.0/3","160.0.0.0/5","168.0.0.0/6","172.0.0.0/12","172.32.0.0/11","172.64.0.0/10","172.128.0.0/9","173.0.0.0/8","174.0.0.0/7","176.0.0.0/4","192.0.0.0/9","192.128.0.0/11","192.160.0.0/13","192.169.0.0/16","192.170.0.0/15","192.172.0.0/14","192.176.0.0/12","192.192.0.0/10","193.0.0.0/8","194.0.0.0/7","196.0.0.0/6","200.0.0.0/5","208.0.0.0/4","::/0"'
AIPS_FULL='"0.0.0.0/0","::/0"'

DIR=/etc/sing-box
REALITY_DOMAINS_FILE=$DIR/reality-domains.env
BASE=$DIR/base.env
CLI=$DIR/clients
WGD=$DIR/clients/wg
HYD=$DIR/clients/hy2
CONFIG=$DIR/config.json
TEMPLATE=/opt/vpn/template.json
TEMPLATE_LEGACY=/opt/vpn/template-legacy.json
PROFILES=/opt/vpn/profiles
CONFDIR=/root/clients
mkdir -p "$CLI" "$PROFILES" "$CONFDIR"
TRAFFIC_DIR=/opt/vpn/traffic
TRAFFIC_DAILY="$TRAFFIC_DIR/daily"
TRAFFIC_STATE="$TRAFFIC_DIR/state.env"
TRAFFIC_TOTALS="$TRAFFIC_DIR/totals.env"
GRPC_PROTO=/opt/vpn/stats.proto
mkdir -p "$TRAFFIC_DIR" "$TRAFFIC_DAILY"


# список всех VLESS-доменов: "domain:internal_port", первая строка всегда основной (из config.env)
list_vless_domains() {
  echo "${VLESS_DEST}:__primary__"
  [[ -f "$REALITY_DOMAINS_FILE" ]] && cat "$REALITY_DOMAINS_FILE"
}

next_internal_port() {
  local used n
  used=$( { [[ -f "$REALITY_DOMAINS_FILE" ]] && cut -d: -f2 "$REALITY_DOMAINS_FILE"; } 2>/dev/null )
  for n in $(seq 20001 20099); do
    echo "$used" | grep -qx "$n" || { echo "$n"; return; }
  done
  echo "ERR"; return 1
}


write_nginx_stream() {
  local map_entries="" vd_line vd_dom vd_port first=1
  local -a vd_all
  mapfile -t vd_all < <(list_vless_domains)
  for vd_line in "${vd_all[@]}"; do
    vd_dom="${vd_line%%:*}"
    vd_port="${vd_line##*:}"
    [[ "$vd_port" == "__primary__" ]] && vd_port="$VLESS_INTERNAL_PORT_PRIMARY"
    map_entries="${map_entries}    ${vd_dom} 127.0.0.1:${vd_port};\n"
  done

  mkdir -p /etc/nginx/stream.d
  {
    echo "map \$ssl_preread_server_name \$vless_backend {"
    printf "%b" "$map_entries"
    echo "    default 127.0.0.1:${VLESS_INTERNAL_PORT_PRIMARY};"
    echo "}"
    echo
    echo "server {"
    echo "    listen ${VLESS_PORT};"
    echo "    listen [::]:${VLESS_PORT};"
    echo "    ssl_preread on;"
    echo "    proxy_pass \$vless_backend;"
    echo "}"
  } > /etc/nginx/stream.d/vless-reality.conf

  if ! grep -q "stream.d/\*.conf" /etc/nginx/nginx.conf 2>/dev/null; then
    if ! grep -q "^stream {" /etc/nginx/nginx.conf 2>/dev/null; then
      printf '\nstream {\n    include /etc/nginx/stream.d/*.conf;\n}\n' >> /etc/nginx/nginx.conf
    fi
  fi

  local cert_path="/var/lib/sing-box/.local/share/certmagic/certificates/acme-v02.api.letsencrypt.org-directory/${A_DOMAIN}/${A_DOMAIN}.crt"
  if [[ -f "$cert_path" ]]; then
    nginx -t && systemctl restart nginx
  else
    printf -- "$(t cert_not_ready_yet)\n" "${A_DOMAIN}"
  fi
}

ensure_base() {
  [[ -f "$BASE" ]] && return
  umask 077
  local ap au psk obfs rpriv rpub rsid
  ap=$(wg genkey); au=$(echo "$ap" | wg pubkey)
  psk=$(wg genpsk); obfs=$(openssl rand -base64 18 | tr -d '/+=')
  local rkeys; rkeys=$(sing-box generate reality-keypair)
  rpriv=$(echo "$rkeys" | grep '^PrivateKey:' | awk '{print $2}')
  rpub=$(echo "$rkeys" | grep '^PublicKey:' | awk '{print $2}')
  rsid=$(sing-box generate rand 8 --hex)
  printf 'A_PRIV="%s"\nA_PUB="%s"\nWG_PSK="%s"\nHY2_OBFS="%s"\nREALITY_PRIV="%s"\nREALITY_PUB="%s"\nREALITY_SID="%s"\n' \
    "$ap" "$au" "$psk" "$obfs" "$rpriv" "$rpub" "$rsid" > "$BASE"
}

next_wg_ip() {
  local used n
  used=$( { grep -rh '^IP=' "$CLI"/*.env "$WGD"/*.env 2>/dev/null || true; } | sed 's/IP=//' )
  for n in $(seq 2 254); do echo "$used" | grep -qx "$n" || { echo "$n"; return; }; done
  echo "ERR"; return 1
}

rebuild_config() {
  source "$BASE"
  local peers="" pf=1 users="" uf=1 v2users="" vf=1 vlusers="" vlf=1 f WG_PUB IP PASS VLESS_UUID keyname
  for f in "$CLI"/*.env; do
    [[ -e "$f" ]] || continue
    WG_PUB=""; IP=""; PASS=""; VLESS_UUID=""; source "$f"
    keyname=$(basename "$f" .env)
    if [[ -n "$WG_PUB" ]]; then
      [[ $pf -eq 0 ]] && peers+=","
      peers+="{ \"public_key\": \"$WG_PUB\", \"pre_shared_key\": \"$WG_PSK\", \"allowed_ips\": [\"${WG_NET}.${IP}/32\"] }"; pf=0
    fi
    if [[ -n "$PASS" ]]; then
      [[ $uf -eq 0 ]] && users+=","
      users+="{ \"name\": \"$keyname\", \"password\": \"$PASS\" }"; uf=0
      [[ $vf -eq 0 ]] && v2users+=","
      v2users+="\"$keyname\""; vf=0
    fi
    if [[ -n "$VLESS_UUID" ]]; then
      [[ $vlf -eq 0 ]] && vlusers+=","
      vlusers+="{ \"name\": \"$keyname\", \"uuid\": \"$VLESS_UUID\", \"flow\": \"xtls-rprx-vision\" }"; vlf=0
    fi
  done
  [[ -z "$users" ]] && users='{ "password": "__none__" }'
  local vless_inbound="" vd_line vd_dom vd_port
  local -a vd_all
  mapfile -t vd_all < <(list_vless_domains)
  if [[ -n "$vlusers" ]]; then
    for vd_line in "${vd_all[@]}"; do
      vd_dom="${vd_line%%:*}"
      vd_port="${vd_line##*:}"
      [[ "$vd_port" == "__primary__" ]] && vd_port="$VLESS_INTERNAL_PORT_PRIMARY"
      vless_inbound="${vless_inbound},
    { \"type\": \"vless\", \"tag\": \"vless-in-${vd_dom}\", \"listen\": \"127.0.0.1\", \"listen_port\": ${vd_port},
      \"users\": [ ${vlusers} ],
      \"tls\": { \"enabled\": true, \"server_name\": \"${vd_dom}\",
        \"reality\": { \"enabled\": true,
          \"handshake\": { \"server\": \"${vd_dom}\", \"server_port\": 443 },
          \"private_key\": \"${REALITY_PRIV}\",
          \"short_id\": [\"${REALITY_SID}\"] } } }"
    done
  fi
  local b_vless_outbound="" b_opts="\"direct\",\"hy2-out\""
  local transport_file=/etc/sing-box/transport.env
  local TO_B_DEFAULT="hy2-out"
  [[ -f "$transport_file" ]] && source "$transport_file"
  if [[ -n "${B_VLESS_UUID:-}" ]]; then
    b_vless_outbound=",
    { \"type\": \"vless\", \"tag\": \"vless-out-b\", \"server\": \"${B_DOMAIN}\", \"server_port\": ${B_PORT},
      \"uuid\": \"${B_VLESS_UUID}\", \"flow\": \"xtls-rprx-vision\",
      \"tls\": { \"enabled\": true, \"server_name\": \"${B_VLESS_SNI}\",
        \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" },
        \"reality\": { \"enabled\": true, \"public_key\": \"${B_REALITY_PUB}\", \"short_id\": \"${B_REALITY_SID}\" } } }"
    b_opts="${b_opts},\"vless-out-b\""
  fi
  # default должен быть среди реально доступных outbound'ов, иначе откатываемся на hy2-out
  case ",${b_opts}," in
    *"\"${TO_B_DEFAULT}\""*) : ;;
    *) TO_B_DEFAULT="hy2-out" ;;
  esac
  local b_selector=",
    { \"type\": \"selector\", \"tag\": \"to-b\",
      \"outbounds\": [ ${b_opts} ],
      \"default\": \"${TO_B_DEFAULT}\" }"
  local b_final="to-b"
  cat > "$CONFIG" <<SRV
{
  "log": { "level": "info", "timestamp": true },
  "dns": { "servers": [ { "type": "udp", "tag": "dns-direct", "server": "1.1.1.1" } ], "final": "dns-direct" },
  "inbounds": [
    { "type": "hysteria2", "tag": "hy2-in", "listen": "::", "listen_port": ${HY2_PORT},
      "users": [ ${users} ],
      "obfs": { "type": "salamander", "password": "${HY2_OBFS}" },
      "tls": { "enabled": true, "server_name": "${A_DOMAIN}", "alpn": ["h3"],
               "acme": { "domain": ["${A_DOMAIN}"], "email": "${ACME_EMAIL}" } } }${vless_inbound}
  ],
  "endpoints": [
    { "type": "wireguard", "tag": "wg-in", "system": false, "mtu": 1408,
      "address": ["${WG_NET}.1/24"], "private_key": "${A_PRIV}", "listen_port": ${WG_PORT},
      "peers": [ ${peers} ] }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "hysteria2", "tag": "hy2-out", "server": "${B_DOMAIN}", "server_port": ${B_PORT},
      "password": "${B_PASS}", "tls": { "enabled": true, "server_name": "${B_DOMAIN}", "alpn": ["h3"] } }${b_vless_outbound}${b_selector}
  ],
  "route": { "rules": [ { "action": "sniff" }, { "protocol": "dns", "action": "hijack-dns" } ], "final": "${b_final}" },
  "experimental": {
    "v2ray_api": {
      "listen": "127.0.0.1:8080",
      "stats": {
        "enabled": true,
        "outbounds": ["hy2-out"],
        "users": [ ${v2users} ]
      }
    }
  }
}
SRV
  sing-box check -c "$CONFIG" && echo "config OK"
  systemctl enable --now sing-box >/dev/null 2>&1 || true
  systemctl restart sing-box
  echo "$(t singbox_restarted)"

  # пересобрать все выданные клиентские профили (актуализирует теги/логику у всех разом)
  local rf rkey
  for rf in "$CLI"/*.env; do
    [[ -e "$rf" ]] || continue
    rkey=$(basename "$rf" .env)
    gen_profile_quiet "$rkey" >/dev/null 2>&1 || true
  done
  printf -- "$(t client_profiles_rebuilt)\n" "$(ls "$CLI"/*.env 2>/dev/null | wc -l)"

  write_nginx_stream
}

wg_endpoint_json() {
  [[ -z "${AIPS:-}" ]] && AIPS="$AIPS_FULL"
  cat <<WG
{ "type": "wireguard", "tag": "${A_DOMAIN}_${PROFILE}_wg", "system": false, "mtu": 1280,
  "address": ["${WG_NET}.${IP}/24"], "private_key": "${WG_PRIV}",
  "peers": [ { "address": "${A_IP}", "port": ${WG_PORT}, "public_key": "${A_PUB}",
    "pre_shared_key": "${WG_PSK}", "allowed_ips": [${AIPS}], "persistent_keepalive_interval": 25 } ] }
WG
}
hy2_outbound_json() {
  cat <<HY
{ "type": "hysteria2", "tag": "${A_DOMAIN}_${PROFILE}_hy2", "server": "${A_DOMAIN}", "server_port": ${HY2_PORT},
  "password": "${PASS}", "obfs": { "type": "salamander", "password": "${HY2_OBFS}" },
  "tls": { "enabled": true, "server_name": "${A_DOMAIN}", "alpn": ["h3"] } }
HY
}

# генерирует ОДИН блок для конкретного домена: $1=домен
vless_outbound_json_for_domain() {
  local dom="$1"
  cat <<VL
{ "type": "vless", "tag": "${dom}_${PROFILE}_vless", "server": "${A_DOMAIN}", "server_port": ${VLESS_PORT},
  "uuid": "${VLESS_UUID}", "flow": "xtls-rprx-vision",
  "tls": { "enabled": true, "server_name": "${dom}",
    "utls": { "enabled": true, "fingerprint": "chrome" },
    "reality": { "enabled": true, "public_key": "${REALITY_PUB}", "short_id": "${REALITY_SID}" } } }
VL
}

# печатает блоки для ВСЕХ активных доменов, через запятую с переносом (для вставки в массив outbounds)
vless_outbound_json() {
  local vd_line vd_dom first=1
  local -a vd_all
  mapfile -t vd_all < <(list_vless_domains)
  for vd_line in "${vd_all[@]}"; do
    vd_dom="${vd_line%%:*}"
    [[ $first -eq 0 ]] && printf ',\n'
    vless_outbound_json_for_domain "$vd_dom"
    first=0
  done
}

# список тегов VLESS (по одному на домен) — нужен для selector/urltest
vless_tags() {
  local vd_line vd_dom
  local -a vd_all
  mapfile -t vd_all < <(list_vless_domains)
  for vd_line in "${vd_all[@]}"; do
    vd_dom="${vd_line%%:*}"
    echo "${vd_dom}_${PROFILE}_vless"
  done
}

outbound_json_for() {
  case "$1" in
    hy2) hy2_outbound_json ;;
    vless) vless_outbound_json ;;
    *) printf -- "$(t unknown_proxy_type)\n" "$1" >&2; return 1 ;;
  esac
}

client_proxy_types() {
  local types=""
  if [[ -n "${PASS:-}" ]]; then types+="hy2 "; fi
  if [[ -n "${VLESS_UUID:-}" ]]; then types+="vless "; fi
  echo "$types"
}


# по типу прокси-протокола строит полный тег с доменом (WG/Hy2 -> A_DOMAIN, VLESS -> VLESS_DEST)
proxy_tag_for() {  # $1 = wg | hy2 | vless
  case "$1" in
    wg)    echo "${A_DOMAIN}_${PROFILE}_wg" ;;
    hy2)   echo "${A_DOMAIN}_${PROFILE}_hy2" ;;
    vless) echo "${VLESS_DEST}_${PROFILE}_vless" ;;
    *) echo "${PROFILE}_${1}" ;;
  esac
}

urltest_json() {
  local opts="" first=1 tag count=0
  if [[ -n "${WG_PUB:-}" ]]; then
    tag=$(proxy_tag_for wg)
    opts+="\"${tag}\""
    first=0
    count=$((count+1))
  fi
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    [[ $first -eq 0 ]] && opts+=","
    opts+="\"${tag}\""
    first=0
    count=$((count+1))
  done < <(all_proxy_tags)
  [[ $count -lt 2 ]] && return 1
  cat <<UT
{ "type": "urltest", "tag": "auto",
  "outbounds": [ ${opts} ],
  "url": "https://www.gstatic.com/generate_204",
  "interval": "5m",
  "tolerance": 200 }
UT
}

# все теги proxy-протоколов клиента: hy2 -> 1 тег, vless -> N тегов (по числу доменов)
all_proxy_tags() {
  local pt tag
  for pt in $(client_proxy_types); do
    if [[ "$pt" == "vless" ]]; then
      vless_tags
    else
      echo "${A_DOMAIN}_${PROFILE}_${pt}"
    fi
  done
}

selector_json() {
  local opts="" first=1 def_tag="" tag has_proxy=0
  if [[ -n "${WG_PUB:-}" ]]; then
    tag=$(proxy_tag_for wg)
    opts+="\"${tag}\""
    first=0
    def_tag="${tag}"
  fi
  while IFS= read -r tag; do
    [[ -z "$tag" ]] && continue
    has_proxy=1
    [[ $first -eq 0 ]] && opts+=","
    opts+="\"${tag}\""
    first=0
    def_tag="${tag}"
  done < <(all_proxy_tags)
  if [[ $has_proxy -eq 1 ]]; then
    [[ $first -eq 0 ]] && opts+=","
    opts+="\"auto\""
    first=0
    def_tag="auto"
  fi
  cat <<SEL
{ "type": "selector", "tag": "Select",
  "outbounds": [ ${opts} ],
  "default": "${def_tag}" }
SEL
}

gen_wg_conf() {
  [[ -z "${AIPS:-}" ]] && AIPS="$AIPS_FULL"
  local caips; caips=$(echo "$AIPS" | tr -d '"')
  local path="$CONFDIR/${KEY}.conf"
  umask 077
  cat > "$path" <<CONF
[Interface]
PrivateKey = ${WG_PRIV}
Address = ${WG_NET}.${IP}/24
DNS = 1.1.1.1
MTU = 1280

[Peer]
PublicKey = ${A_PUB}
PresharedKey = ${WG_PSK}
AllowedIPs = ${caips}
Endpoint = ${A_IP}:${WG_PORT}
PersistentKeepalive = 25
CONF
  echo "$path"
}

gen_profile() {
  local wg="" sel base tail proxies="" pt block first=1
  if [[ -n "${WG_PUB:-}" ]]; then wg=$(wg_endpoint_json); fi
  for pt in $(client_proxy_types); do
    block=$(outbound_json_for "$pt")
    [[ $first -eq 0 ]] && proxies+=",
"
    proxies+="$block"
    first=0
  done
  local ut; ut=$(urltest_json) || ut=""
  sel=$(selector_json)
  if [[ -n "$proxies" && -n "$ut" ]]; then
    tail="${proxies},
${ut},
${sel}"
  elif [[ -n "$proxies" ]]; then
    tail="${proxies},
${sel}"
  else
    tail="${sel}"
  fi
  base="$PROFILES/${KEY}_${TOKEN}"

  python3 - "$TEMPLATE" "${base}-modern.json" <<PYEOF
import sys, json
tmpl, out = sys.argv[1], sys.argv[2]
wg = """$wg"""; tail = """$tail"""
s = open(tmpl).read()
s = s.replace("__WG_ENDPOINT__", wg.strip())
s = s.replace("__OUTBOUND_TAIL__", tail.strip())
json.loads(s)
open(out,"w").write(s)
PYEOF
  local modern_ok=1
  if [[ $? -ne 0 ]]; then echo "$(t json_error_modern)"; rm -f "${base}-modern.json"; modern_ok=0
  elif ! sing-box check -c "${base}-modern.json" >/dev/null 2>&1; then
    echo "$(t modern_check_failed)"
    sing-box check -c "${base}-modern.json" 2>&1 | grep -v WARN | head -4
    rm -f "${base}-modern.json"; modern_ok=0
  fi

  python3 - "$TEMPLATE_LEGACY" "${base}-legacy.json" <<PYEOF
import sys, json
tmpl, out = sys.argv[1], sys.argv[2]
wg = """$wg"""; tail = """$tail"""
s = open(tmpl).read()
s = s.replace("__WG_ENDPOINT__", wg.strip())
s = s.replace("__OUTBOUND_TAIL__", tail.strip())
json.loads(s)
open(out,"w").write(s)
PYEOF
  local legacy_ok=1
  if [[ $? -ne 0 ]]; then echo "$(t json_error_legacy)"; rm -f "${base}-legacy.json"; legacy_ok=0; fi

  if [[ $modern_ok -eq 0 && $legacy_ok -eq 0 ]]; then
    echo "$(t both_variants_failed)"; return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    for f in "${base}-modern.json" "${base}-legacy.json"; do
      [[ -f "$f" ]] && { jq . "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"; }
    done
  fi
  chmod 644 "${base}-modern.json" "${base}-legacy.json" 2>/dev/null

  printf -- "$(t modern_result)\n" "$([[ $modern_ok -eq 1 ]] && t ok_word || t failed_see_above)"
  printf -- "$(t legacy_result)\n" "$([[ $legacy_ok -eq 1 ]] && t ok_word || t no_word)"

  local url enc
  url="https://${PROFILE_HOST}:${PROFILE_PORT}/${KEY}_${TOKEN}.json"
  enc=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$url")
  echo "$(t url_ua_label)"
  echo "    $url"
  echo "$(t link_label)"
  echo "    sing-box://import-remote-profile?url=${enc}#${NAME// /_}"
  command -v qrencode >/dev/null 2>&1 && { echo "$(t qr_label)"; qrencode -t ansiutf8 "sing-box://import-remote-profile?url=${enc}#${NAME// /_}"; }
}

gen_profile_quiet() {  # $1 = ключ клиента, только пересобрать файлы, без вывода блоков
  source "$BASE"
  NAME=""; PROFILE=""; WG_PRIV=""; WG_PUB=""; IP=""; PASS=""; VLESS_UUID=""; AIPS=""; TOKEN=""
  source "$CLI/$1.env"
  local KEY="$1"
  gen_profile
}

emit_client() {
  source "$BASE"
  NAME=""; PROFILE=""; WG_PRIV=""; WG_PUB=""; IP=""; PASS=""; VLESS_UUID=""; AIPS=""; TOKEN=""
  source "$CLI/$1.env"
  local KEY="$1"
  printf -- "$(t client_header)\n" "${NAME}" "${PROFILE}"
  if [[ -n "$WG_PUB" ]]; then
    echo "IP: ${WG_NET}.${IP}"
    local cf; cf=$(gen_wg_conf)
    printf -- "$(t wg_conf_label)\n" "$cf"
    echo
    echo "$(t block_wg_endpoint)"
    wg_endpoint_json | (jq . 2>/dev/null || cat)
    echo
  fi
  local pt
  for pt in $(client_proxy_types); do
    if [[ "$pt" == "vless" ]]; then
      local vd_line vd_dom
      local -a vd_all
      mapfile -t vd_all < <(list_vless_domains)
      for vd_line in "${vd_all[@]}"; do
        vd_dom="${vd_line%%:*}"
        printf -- "$(t block_vless_outbound_domain)\n" "${vd_dom}"
        vless_outbound_json_for_domain "$vd_dom" | (jq . 2>/dev/null || cat)
        echo
      done
    else
      printf -- "$(t block_outbound_generic)\n" "${pt}"
      outbound_json_for "$pt" | (jq . 2>/dev/null || cat)
      echo
    fi
  done
  local ut_preview; ut_preview=$(urltest_json 2>/dev/null) || ut_preview=""
  if [[ -n "$ut_preview" ]]; then
    echo "$(t block_urltest)"
    echo "$ut_preview" | (jq . 2>/dev/null || cat)
    echo
  fi
  echo "$(t block_selector)"
  selector_json | (jq . 2>/dev/null || cat)
  echo
  echo "$(t profile_url_label)"
  gen_profile
}

list_names() {
  NAMES=(); local seen=" " f nm
  for f in "$CLI"/*.env; do
    [[ -e "$f" ]] || continue
    nm=$( . "$f"; printf '%s' "$NAME" )
    [[ "$seen" == *" $nm "* ]] || { NAMES+=("$nm"); seen+="$nm "; }
  done
}

devices_of() {
  DEVS=(); DEVPROF=(); local f n pr
  for f in "$CLI"/*.env; do
    [[ -e "$f" ]] || continue
    n=$( . "$f"; printf '%s' "$NAME" )
    [[ "$n" == "$1" ]] || continue
    pr=$( . "$f"; printf '%s' "$PROFILE" )
    DEVS+=("$f"); DEVPROF+=("$pr")
  done
}

create_client() {
  ensure_base
  local name dev key
  local -a CREATED=()
  read -rp "$(t prompt_owner_name)" name
  [[ "$name" =~ ^[A-Za-z0-9_]+$ ]] || { echo "$(t err_name_format)"; return; }
  while true; do
    read -rp "$(t prompt_device_name)" dev
    [[ "$dev" =~ ^[A-Za-z0-9_]+$ ]] || { echo "$(t err_device_format)"; continue; }
    key="${name}_${dev}"
    if [[ -f "$CLI/$key.env" ]]; then
      printf -- "$(t key_already_exists)\n" "$key"
    else
      echo "$(t transport_header)"
      echo "$(t transport_opt_both)"
      echo "$(t transport_opt_wg_only)"
      printf -- "$(t transport_opt_proxy_only)\n" "${AVAILABLE_PROXY_TYPES}"
      local pr; read -rp "$(t prompt_choice_13)" pr
      local want_wg=1 want_proxy=1
      case "$pr" in
        2) want_proxy=0 ;;
        3) want_wg=0 ;;
      esac

      local aips="" ip="" priv="" pub="" pass="" token m
      token=$(openssl rand -hex 8)

      if [[ $want_wg -eq 1 ]]; then
        echo "$(t wg_routing_header)"; echo "$(t wg_routing_full)"; echo "$(t wg_routing_split)"
        read -rp "$(t prompt_choice_12)" m
        case "$m" in 2) aips="$AIPS_SPLIT";; *) aips="$AIPS_FULL";; esac
        ip=$(next_wg_ip); [[ "$ip" == "ERR" ]] && { echo "$(t no_ip_available)"; return; }
        priv=$(wg genkey); pub=$(echo "$priv" | wg pubkey)
      fi
      local vless_uuid=""
      if [[ $want_proxy -eq 1 ]]; then
        pass=$(openssl rand -base64 18 | tr -d '/+=')
        vless_uuid=$(sing-box generate uuid)
      fi

      umask 077
      {
        printf 'NAME="%s"\nPROFILE="%s"\nTOKEN="%s"\n' "$name" "$dev" "$token"
        if [[ $want_wg -eq 1 ]]; then
          printf 'WG_PRIV="%s"\nWG_PUB="%s"\nIP=%s\n' "$priv" "$pub" "$ip"
          printf "AIPS=%s\n" "'$aips'"
        fi
        if [[ $want_proxy -eq 1 ]]; then
          printf 'PASS="%s"\nVLESS_UUID="%s"\n' "$pass" "$vless_uuid"
        fi
      } > "$CLI/$key.env"

      local proto_label
      if [[ $want_wg -eq 1 && $want_proxy -eq 1 ]]; then proto_label="WG+Proxy(${AVAILABLE_PROXY_TYPES})"
      elif [[ $want_wg -eq 1 ]]; then proto_label="WG"
      else proto_label="Proxy(${AVAILABLE_PROXY_TYPES})"; fi
      printf -- "$(t device_created)\n" "$dev" "$proto_label"
      CREATED+=("$key")
    fi
    read -rp "$(t prompt_add_another_device)" a
    [[ "${a,,}" == "y" ]] || break
  done
  rebuild_config
  echo
  if [[ ${#CREATED[@]} -eq 0 ]]; then
    echo "$(t no_new_devices)"
  else
    echo "$(t created_devices_header)"
    local k
    for k in "${CREATED[@]}"; do echo; emit_client "$k"; done
  fi
}

show_client() {
  list_names
  if [[ ${#NAMES[@]} -eq 0 ]]; then echo "$(t no_clients)"; return; fi
  echo "$(t owners_header)"
  local j
  for ((j=0; j<${#NAMES[@]}; j++)); do
    devices_of "${NAMES[$j]}"
    printf -- "$(t owner_line)\n" "$((j+1))" "${NAMES[$j]}" "${#DEVS[@]}"
  done
  local n; read -rp "$(t prompt_owner_number)" n
  [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#NAMES[@]} )) || { echo "$(t invalid)"; return; }
  local owner="${NAMES[$((n-1))]}"
  devices_of "$owner"
  printf -- "$(t devices_header)\n" "$owner"
  for ((j=0; j<${#DEVS[@]}; j++)); do printf -- "$(t device_line)\n" "$((j+1))" "${DEVPROF[$j]}"; done
  local d; read -rp "$(t prompt_device_number_all)" d
  [[ "$d" =~ ^[0-9]+$ ]] || { echo "$(t invalid)"; return; }
  if [[ "$d" == "0" ]]; then
    for ((j=0; j<${#DEVS[@]}; j++)); do echo; emit_client "$(basename "${DEVS[$j]}" .env)"; done
  else
    (( d>=1 && d<=${#DEVS[@]} )) || { echo "$(t invalid)"; return; }
    echo; emit_client "$(basename "${DEVS[$((d-1))]}" .env)"
  fi
}

revoke_client() {
  list_names
  if [[ ${#NAMES[@]} -eq 0 ]]; then echo "$(t no_clients)"; return; fi
  echo "$(t owners_header)"
  local j
  for ((j=0; j<${#NAMES[@]}; j++)); do
    devices_of "${NAMES[$j]}"
    printf -- "$(t owner_line)\n" "$((j+1))" "${NAMES[$j]}" "${#DEVS[@]}"
  done
  local n; read -rp "$(t prompt_owner_number)" n
  [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#NAMES[@]} )) || { echo "$(t invalid)"; return; }
  local owner="${NAMES[$((n-1))]}"
  devices_of "$owner"
  printf -- "$(t devices_header)\n" "$owner"
  for ((j=0; j<${#DEVS[@]}; j++)); do printf -- "$(t device_line)\n" "$((j+1))" "${DEVPROF[$j]}"; done
  printf -- "$(t whole_owner_option)\n" "$owner"
  local d; read -rp "$(t prompt_what_to_revoke)" d
  [[ "$d" =~ ^[0-9]+$ ]] || { echo "$(t invalid)"; return; }
  if [[ "$d" == "0" ]]; then
    read -rp "$(printf -- "$(t prompt_delete_all_devices)" "$owner")" a
    [[ "${a,,}" == "y" ]] || { echo "$(t cancelled)"; return; }
    for ((j=0; j<${#DEVS[@]}; j++)); do
      local pr="${DEVPROF[$j]}"
      rm -f "${DEVS[$j]}" "$PROFILES/${owner}_${pr}_"*.json "$CONFDIR/${owner}_${pr}.conf"
    done
    printf -- "$(t owner_deleted)\n" "$owner"
  else
    (( d>=1 && d<=${#DEVS[@]} )) || { echo "$(t invalid)"; return; }
    local key; key=$(basename "${DEVS[$((d-1))]}" .env)
    read -rp "$(printf -- "$(t prompt_delete_device)" "$key")" a
    [[ "${a,,}" == "y" ]] || { echo "$(t cancelled)"; return; }
    rm -f "$CLI/$key.env" "$PROFILES/${key}_"*.json "$CONFDIR/${key}.conf"
    printf -- "$(t device_deleted)\n" "$key"
  fi
  rebuild_config
}

fetch_stats_raw() {
  grpcurl -plaintext -import-path "$(dirname "$GRPC_PROTO")" -proto "$(basename "$GRPC_PROTO")" \
    -d '{"pattern": "", "reset": false}' \
    127.0.0.1:8080 v2ray.core.app.stats.command.StatsService/QueryStats 2>/dev/null
}

traffic_update() {
  if [[ ! -f "$GRPC_PROTO" ]]; then printf -- "$(t stats_proto_missing)\n" "$GRPC_PROTO"; return 1; fi
  if ! command -v grpcurl >/dev/null 2>&1; then echo "$(t grpcurl_not_installed)"; return 1; fi
  local raw; raw=$(fetch_stats_raw)
  if [[ -z "$raw" ]]; then echo "$(t stats_fetch_failed)"; return 1; fi
  local rawfile; rawfile=$(mktemp)
  printf '%s' "$raw" > "$rawfile"
  local today; today=$(date +%Y-%m-%d)

  python3 - "$TRAFFIC_STATE" "$TRAFFIC_TOTALS" "$rawfile" "$TRAFFIC_DAILY/$today.env" <<'PYEOF'
import json, sys, re, os

state_path, totals_path, raw_path, daily_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
raw = open(raw_path).read()
data = json.loads(raw) if raw.strip() else {"stat": []}

def load_kv(path):
    d = {}
    if os.path.exists(path):
        for line in open(path):
            line = line.strip()
            if not line or "=" not in line:
                continue
            k, v = line.split("=", 1)
            d[k] = int(v)
    return d

state = load_kv(state_path)
totals = load_kv(totals_path)
daily = load_kv(daily_path)

for item in data.get("stat", []):
    name = item.get("name", "")
    val = int(item.get("value", 0))
    m = re.match(r"^(?:user|outbound)>>>(.+)>>>traffic>>>(uplink|downlink)$", name)
    if not m:
        continue
    key, direction = m.group(1), m.group(2)
    skey = f"{key}:{direction}"
    prev = state.get(skey, 0)
    delta = (val - prev) if val >= prev else val
    totals[skey] = totals.get(skey, 0) + delta
    daily[skey] = daily.get(skey, 0) + delta
    state[skey] = val

with open(state_path, "w") as f:
    for k, v in state.items():
        f.write(f"{k}={v}\n")
with open(totals_path, "w") as f:
    for k, v in totals.items():
        f.write(f"{k}={v}\n")
with open(daily_path, "w") as f:
    for k, v in daily.items():
        f.write(f"{k}={v}\n")
PYEOF
  rm -f "$rawfile"
  echo "$raw" > "$TRAFFIC_DIR/last_raw.json" 2>/dev/null
}

human_bytes() {
  python3 -c "
b=$1
for u in ['B','KB','MB','GB','TB']:
    if b < 1024:
        print(f'{b:.1f} {u}' if u!='B' else f'{int(b)} {u}')
        break
    b/=1024
else:
    print(f'{b:.1f} PB')
"
}

traffic_aggregate() {
  local lbl_total lbl_total_word lbl_no_traffic lbl_by_client
  lbl_total=$(t server_total_label)
  lbl_total_word=$(t total_word)
  lbl_no_traffic=$(t no_client_traffic)
  lbl_by_client=$(t by_client_header)
  python3 - "$TRAFFIC_TOTALS" "$TRAFFIC_DAILY" "$1" "$lbl_total" "$lbl_total_word" "$lbl_no_traffic" "$lbl_by_client" <<'PYEOF'
import sys, os, glob
from datetime import date, timedelta

totals_path, daily_dir, mode = sys.argv[1], sys.argv[2], sys.argv[3]
lbl_total, lbl_total_word, lbl_no_traffic, lbl_by_client = sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7]

def load_kv(path):
    d = {}
    if os.path.exists(path):
        for line in open(path):
            line = line.strip()
            if not line or "=" not in line: continue
            k, v = line.split("=", 1)
            d[k] = d.get(k, 0) + int(v)
    return d

if mode == "totals":
    data = load_kv(totals_path)
else:
    n = int(mode)
    data = {}
    today = date.today()
    for i in range(n):
        day = today - timedelta(days=i)
        fpath = os.path.join(daily_dir, f"{day.isoformat()}.env")
        for k, v in load_kv(fpath).items():
            data[k] = data.get(k, 0) + v

def human(b):
    for u in ['B','KB','MB','GB','TB']:
        if b < 1024:
            return f"{b:.1f} {u}" if u != 'B' else f"{int(b)} {u}"
        b /= 1024
    return f"{b:.1f} PB"

total_up = data.get("hy2-out:uplink", 0)
total_dn = data.get("hy2-out:downlink", 0)
print(f"  {lbl_total}: \u2191 {human(total_up)}  \u2193 {human(total_dn)}  ({lbl_total_word}: {human(total_up+total_dn)})")
print()

clients = {}
for k, v in data.items():
    if k == "hy2-out:uplink" or k == "hy2-out:downlink":
        continue
    key, direction = k.rsplit(":", 1)
    clients.setdefault(key, {"uplink": 0, "downlink": 0})[direction] = v

if not clients:
    print(lbl_no_traffic)
else:
    print(lbl_by_client)
    for key, d in sorted(clients.items(), key=lambda x: -(x[1].get('uplink',0)+x[1].get('downlink',0))):
        up, dn = d.get('uplink',0), d.get('downlink',0)
        if "_" in key:
            owner, profile = key.split("_", 1)
            label = f"{owner} / {profile}  [tag: {key}]"
        else:
            label = f"{key}  [tag: {key}]"
        print(f"    {label}: \u2191 {human(up)}  \u2193 {human(dn)}  ({lbl_total_word}: {human(up+dn)})")
PYEOF
}

traffic_menu() {
  traffic_update
  echo "$(t period_header)"
  echo "$(t period_today)"
  echo "$(t period_7days)"
  echo "$(t period_alltime)"
  local c; read -rp "$(t prompt_choice_13_short)" c
  case "$c" in
    1) echo "$(t period_result_today)"; traffic_aggregate 1 ;;
    2) echo "$(t period_result_7days)"; traffic_aggregate 7 ;;
    3) echo "$(t period_result_alltime)"; traffic_aggregate totals ;;
    *) echo "$(t invalid)" ;;
  esac
}

service_menu() {
  local LOG=/var/log/nginx/profile_access.log
  echo "$(t service_header)"
  echo "$(t svc_opt_client_logs)"
  echo "$(t svc_opt_version_stats)"
  echo "$(t svc_opt_live_log)"
  echo "$(t svc_opt_rebuild)"
  echo "$(t svc_opt_traffic)"
  echo "$(t svc_opt_transport)"
  echo "$(t svc_opt_reality)"
  local c; read -rp "$(t prompt_choice_17)" c
  case "$c" in
    1)
      list_names
      if [[ ${#NAMES[@]} -eq 0 ]]; then echo "$(t no_clients)"; return; fi
      local j
      for ((j=0; j<${#NAMES[@]}; j++)); do
        devices_of "${NAMES[$j]}"
        printf -- "$(t owner_line)\n" "$((j+1))" "${NAMES[$j]}" "${#DEVS[@]}"
      done
      local n; read -rp "$(t prompt_owner_number)" n
      [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#NAMES[@]} )) || { echo "$(t invalid)"; return; }
      local owner="${NAMES[$((n-1))]}"
      devices_of "$owner"
      printf -- "$(t devices_header)\n" "$owner"
      for ((j=0; j<${#DEVS[@]}; j++)); do printf -- "$(t device_line)\n" "$((j+1))" "${DEVPROF[$j]}"; done
      local d; read -rp "$(t prompt_device_number)" d
      [[ "$d" =~ ^[0-9]+$ ]] && (( d>=1 && d<=${#DEVS[@]} )) || { echo "$(t invalid)"; return; }
      local key; key=$(basename "${DEVS[$((d-1))]}" .env)
      grep "key=${key}_" "$LOG" || echo "$(t no_requests_found)"
      ;;
    2)
      echo "$(t version_stats_header)"
      grep -o 'variant=[a-z]*' "$LOG" | sort | uniq -c
      ;;
    3)
      echo "$(t live_log_header)"
      tail -f "$LOG"
      ;;
    4)
      rebuild_config
      ;;
    5)
      traffic_menu
      ;;
    6)
      transport_menu
      ;;
    7)
      reality_domains_menu
      ;;
    *) echo "$(t invalid)" ;;
  esac
}

reality_domains_menu() {
  echo "$(t reality_domains_header)"
  echo "$(t rd_opt_list)"
  echo "$(t rd_opt_add)"
  echo "$(t rd_opt_remove)"
  local c; read -rp "$(t prompt_choice_13_short)" c
  case "$c" in
    1)
      echo "$(t active_reality_domains)"
      local vd_line vd_dom vd_port i=1
      local -a vd_all
      mapfile -t vd_all < <(list_vless_domains)
      for vd_line in "${vd_all[@]}"; do
        vd_dom="${vd_line%%:*}"; vd_port="${vd_line##*:}"
        if [[ "$vd_port" == "__primary__" ]]; then
          printf -- "$(t rd_primary_label)\n" "$i" "$vd_dom"
        else
          printf -- "$(t rd_internal_port_label)\n" "$i" "$vd_dom" "$vd_port"
        fi
        i=$((i+1))
      done
      ;;
    2)
      read -rp "$(t prompt_new_reality_domain)" new_dom
      [[ -z "$new_dom" ]] && { echo "$(t empty_input)"; return; }
      if list_vless_domains | cut -d: -f1 | grep -qx "$new_dom"; then
        printf -- "$(t domain_already_in_list)\n" "$new_dom"; return
      fi
      local newport; newport=$(next_internal_port)
      [[ "$newport" == "ERR" ]] && { echo "$(t no_free_internal_ports)"; return; }
      echo "${new_dom}:${newport}" >> "$REALITY_DOMAINS_FILE"
      printf -- "$(t domain_added)\n" "$new_dom" "$newport"
      echo "$(t rebuilding_config_and_profiles)"
      rebuild_config
      ;;
    3)
      local vd_line vd_dom vd_port i=1
      local -a vd_all vd_removable
      mapfile -t vd_all < <(list_vless_domains)
      echo "$(t domains_primary_not_removable)"
      for vd_line in "${vd_all[@]}"; do
        vd_dom="${vd_line%%:*}"; vd_port="${vd_line##*:}"
        [[ "$vd_port" == "__primary__" ]] && continue
        printf -- "$(t device_line)\n" "$i" "$vd_dom"
        vd_removable+=("$vd_dom")
        i=$((i+1))
      done
      if [[ ${#vd_removable[@]} -eq 0 ]]; then echo "$(t nothing_to_remove)"; return; fi
      local n; read -rp "$(t prompt_number_to_remove)" n
      [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#vd_removable[@]} )) || { echo "$(t invalid)"; return; }
      local target="${vd_removable[$((n-1))]}"
      read -rp "$(printf -- "$(t prompt_delete_domain)" "$target")" a
      [[ "${a,,}" == "y" ]] || { echo "$(t cancelled)"; return; }
      grep -v "^${target}:" "$REALITY_DOMAINS_FILE" > "${REALITY_DOMAINS_FILE}.tmp" 2>/dev/null || true
      mv -f "${REALITY_DOMAINS_FILE}.tmp" "$REALITY_DOMAINS_FILE" 2>/dev/null || true
      printf -- "$(t domain_removed)\n" "$target"
      rebuild_config
      ;;
    *) echo "$(t invalid)" ;;
  esac
}

transport_menu() {
  local transport_file=/etc/sing-box/transport.env
  local TO_B_DEFAULT="hy2-out"
  [[ -f "$transport_file" ]] && source "$transport_file"

  source "$BASE"
  local opts=("direct" "hy2-out")
  local labels=("$(t transport_label_direct)" "$(t transport_label_hy2)")
  if [[ -n "${B_VLESS_UUID:-}" ]]; then
    opts+=("vless-out-b")
    labels+=("$(t transport_label_vless)")
  fi

  printf -- "$(t transport_ab_header)\n" "${TO_B_DEFAULT}"
  local i
  for ((i=0; i<${#opts[@]}; i++)); do
    printf -- "$(t device_line)\n" "$((i+1))" "${labels[$i]}"
  done
  local n; read -rp "$(printf -- "$(t prompt_choice_1n)" "${#opts[@]}")" n
  [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#opts[@]} )) || { echo "$(t invalid)"; return; }

  local chosen="${opts[$((n-1))]}"
  printf 'TO_B_DEFAULT="%s"\n' "$chosen" > "$transport_file"
  printf -- "$(t transport_switched)\n" "$chosen"
  rebuild_config
}

edit_client() {
  ensure_base
  list_names
  if [[ ${#NAMES[@]} -eq 0 ]]; then echo "$(t no_clients)"; return; fi
  echo "$(t owners_header)"
  local j
  for ((j=0; j<${#NAMES[@]}; j++)); do
    devices_of "${NAMES[$j]}"
    printf -- "$(t owner_line)\n" "$((j+1))" "${NAMES[$j]}" "${#DEVS[@]}"
  done
  local n; read -rp "$(t prompt_owner_number)" n
  [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#NAMES[@]} )) || { echo "$(t invalid)"; return; }
  local owner="${NAMES[$((n-1))]}"
  devices_of "$owner"

  printf -- "$(t action_for_owner)\n" "$owner"
  echo "$(t edit_opt_rename_owner)"
  echo "$(t edit_opt_rename_device)"
  echo "$(t edit_opt_change_transport)"
  echo "$(t edit_opt_cancel)"
  local act; read -rp "$(t prompt_choice_03)" act
  [[ "$act" == "0" ]] && { echo "$(t cancelled)"; return; }
  [[ "$act" =~ ^[1-3]$ ]] || { echo "$(t invalid)"; return; }

  if [[ "$act" == "1" ]]; then
    read -rp "$(t prompt_new_owner_name)" new_name
    [[ "$new_name" =~ ^[A-Za-z0-9_]+$ ]] || { echo "$(t err_name_format)"; return; }
    local f dev_name newkey oldkey renamed=0
    for f in "${DEVS[@]}"; do
      NAME=""; PROFILE=""; source "$f"
      dev_name="$PROFILE"
      oldkey=$(basename "$f" .env)
      newkey="${new_name}_${dev_name}"
      if [[ -f "$CLI/$newkey.env" && "$newkey" != "$oldkey" ]]; then
        printf -- "$(t skip_already_exists)\n" "$oldkey" "$newkey"
        continue
      fi
      sed -i "s/^NAME=\".*\"/NAME=\"$new_name\"/" "$f"
      if [[ "$newkey" != "$oldkey" ]]; then
        mv "$f" "$CLI/$newkey.env"
        rm -f "$PROFILES/${oldkey}_"*.json "$CONFDIR/${oldkey}.conf"
      fi
      renamed=$((renamed+1))
    done
    printf -- "$(t devices_renamed)\n" "$renamed"
    rebuild_config
    return
  fi

  printf -- "$(t devices_header)\n" "$owner"
  for ((j=0; j<${#DEVS[@]}; j++)); do printf -- "$(t device_line)\n" "$((j+1))" "${DEVPROF[$j]}"; done
  local d; read -rp "$(t prompt_device_number)" d
  [[ "$d" =~ ^[0-9]+$ ]] && (( d>=1 && d<=${#DEVS[@]} )) || { echo "$(t invalid)"; return; }
  local oldfile="${DEVS[$((d-1))]}"
  local oldkey; oldkey=$(basename "$oldfile" .env)

  local ONAME="" OPROFILE="" OWG_PRIV="" OWG_PUB="" OIP="" OPASS="" OVLESS_UUID="" OAIPS="" OTOKEN=""
  NAME=""; PROFILE=""; WG_PRIV=""; WG_PUB=""; IP=""; PASS=""; VLESS_UUID=""; AIPS=""; TOKEN=""
  source "$oldfile"
  ONAME="$NAME"; OPROFILE="$PROFILE"; OWG_PRIV="$WG_PRIV"; OWG_PUB="$WG_PUB"; OIP="$IP"
  OPASS="$PASS"; OVLESS_UUID="$VLESS_UUID"; OAIPS="$AIPS"; OTOKEN="$TOKEN"

  local new_name="$ONAME" new_dev="$OPROFILE"

  if [[ "$act" == "2" ]]; then
    read -rp "$(t prompt_new_device_name)" new_dev
    [[ "$new_dev" =~ ^[A-Za-z0-9_]+$ ]] || { echo "$(t err_device_format)"; return; }
  elif [[ "$act" == "3" ]]; then
    local cur=""
    [[ -n "$OWG_PUB" ]] && cur+="WG "
    [[ -n "$OPASS" ]] && cur+="hy2 "
    [[ -n "$OVLESS_UUID" ]] && cur+="vless "
    [[ -z "$cur" ]] && cur="$(t none_word)"
    printf -- "$(t current_transport)\n" "$cur"
    echo "$(t transport_header)"
    echo "$(t transport_opt_both)"
    echo "$(t transport_opt_wg_only)"
    printf -- "$(t transport_opt_proxy_only)\n" "${AVAILABLE_PROXY_TYPES}"
    echo "$(t edit_opt_cancel)"
    local pr; read -rp "$(t prompt_choice_03)" pr
    [[ -z "$pr" || "$pr" == "0" ]] && { echo "$(t cancelled)"; return; }
    [[ "$pr" =~ ^[1-3]$ ]] || { echo "$(t invalid)"; return; }
    local want_wg=1 want_proxy=1
    case "$pr" in
      2) want_proxy=0 ;;
      3) want_wg=0 ;;
    esac

    if [[ $want_wg -eq 1 && -z "$OWG_PUB" ]]; then
      echo "$(t wg_routing_header)"; echo "$(t wg_routing_full)"; echo "$(t wg_routing_split)"
      local m; read -rp "$(t prompt_choice_12)" m
      case "$m" in 2) OAIPS="$AIPS_SPLIT";; *) OAIPS="$AIPS_FULL";; esac
      local newip; newip=$(next_wg_ip); [[ "$newip" == "ERR" ]] && { echo "$(t no_ip_available)"; return; }
      OWG_PRIV=$(wg genkey); OWG_PUB=$(echo "$OWG_PRIV" | wg pubkey); OIP="$newip"
    elif [[ $want_wg -eq 0 ]]; then
      OWG_PRIV=""; OWG_PUB=""; OIP=""; OAIPS=""
      rm -f "$CONFDIR/${oldkey}.conf"
    fi

    if [[ $want_proxy -eq 1 && -z "$OPASS" ]]; then
      OPASS=$(openssl rand -base64 18 | tr -d '/+=')
      OVLESS_UUID=$(sing-box generate uuid)
    elif [[ $want_proxy -eq 0 ]]; then
      OPASS=""; OVLESS_UUID=""
    fi
  fi

  local newkey="${new_name}_${new_dev}"
  if [[ "$newkey" != "$oldkey" && -f "$CLI/$newkey.env" ]]; then
    printf -- "$(t key_already_exists_cancel)\n" "$newkey"; return
  fi

  umask 077
  {
    printf 'NAME="%s"\nPROFILE="%s"\nTOKEN="%s"\n' "$new_name" "$new_dev" "$OTOKEN"
    if [[ -n "$OWG_PUB" ]]; then
      printf 'WG_PRIV="%s"\nWG_PUB="%s"\nIP=%s\n' "$OWG_PRIV" "$OWG_PUB" "$OIP"
      printf "AIPS=%s\n" "'$OAIPS'"
    fi
    if [[ -n "$OPASS" ]]; then
      printf 'PASS="%s"\n' "$OPASS"
      [[ -n "$OVLESS_UUID" ]] && printf 'VLESS_UUID="%s"\n' "$OVLESS_UUID"
    fi
  } > "$CLI/$newkey.env.tmp"

  if [[ "$newkey" != "$oldkey" ]]; then
    mv "$CLI/$newkey.env.tmp" "$CLI/$newkey.env"
    rm -f "$oldfile"
    rm -f "$PROFILES/${oldkey}_"*.json "$CONFDIR/${oldkey}.conf"
  else
    mv "$CLI/$newkey.env.tmp" "$CLI/$newkey.env"
  fi

  rebuild_config
  echo
  echo "$(t updated_current_state)"
  emit_client "$newkey"
}

if [[ "${1:-}" == "--cron-traffic" ]]; then
  traffic_update
  exit 0
fi

while true; do
  echo
  printf -- "$(t main_menu_header)\n" "${A_DOMAIN}" "${A_IP}"
  echo "$(t main_opt_create)"
  echo "$(t main_opt_edit)"
  echo "$(t main_opt_revoke)"
  echo "$(t main_opt_show)"
  echo "$(t main_opt_service)"
  echo "$(t main_opt_exit)"
  read -rp "$(t prompt_choice_05)" c
  case "$c" in
    1) create_client ;;
    2) edit_client ;;
    3) revoke_client ;;
    4) show_client ;;
    5) service_menu ;;
    0) echo "$(t bye)"; break ;;
    *) echo "$(t unknown_option)" ;;
  esac
done
