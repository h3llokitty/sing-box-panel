#!/usr/bin/env bash
set -euo pipefail

### ── ПАРАМЕТРЫ (загружаются из config.env) ──────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${VPN_CONFIG:-$SCRIPT_DIR/config.env}"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Не найден config.env (искал: $CONFIG_FILE)"
  echo "Скопируй config.env.example -> config.env и заполни своими значениями."
  exit 1
fi
source "$CONFIG_FILE"

: "${A_IP:?A_IP не задан в config.env}"
: "${A_DOMAIN:?A_DOMAIN не задан в config.env}"
: "${ACME_EMAIL:?ACME_EMAIL не задан в config.env}"
: "${WG_PORT:=51820}"
: "${WG_NET:=10.10.0}"
: "${HY2_PORT:=443}"
: "${B_DOMAIN:?B_DOMAIN не задан в config.env}"
: "${B_PORT:=443}"
: "${B_PASS:?B_PASS не задан в config.env}"
: "${PROFILE_HOST:=$A_DOMAIN}"
: "${PROFILE_PORT:=8443}"
: "${VLESS_PORT:=443}"
: "${VLESS_DEST:?VLESS_DEST не задан в config.env}"
: "${VLESS_SNI:=$VLESS_DEST}"
: "${AVAILABLE_PROXY_TYPES:=hy2 vless}"
### ─────────────────────────────────────────────────────────

AIPS_SPLIT='"0.0.0.0/5","8.0.0.0/7","11.0.0.0/8","12.0.0.0/6","16.0.0.0/4","32.0.0.0/3","64.0.0.0/2","128.0.0.0/3","160.0.0.0/5","168.0.0.0/6","172.0.0.0/12","172.32.0.0/11","172.64.0.0/10","172.128.0.0/9","173.0.0.0/8","174.0.0.0/7","176.0.0.0/4","192.0.0.0/9","192.128.0.0/11","192.160.0.0/13","192.169.0.0/16","192.170.0.0/15","192.172.0.0/14","192.176.0.0/12","192.192.0.0/10","193.0.0.0/8","194.0.0.0/7","196.0.0.0/6","200.0.0.0/5","208.0.0.0/4","::/0"'
AIPS_FULL='"0.0.0.0/0","::/0"'

DIR=/etc/sing-box
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
  local vless_inbound=""
  if [[ -n "$vlusers" ]]; then
    vless_inbound=",
    { \"type\": \"vless\", \"tag\": \"vless-in\", \"listen\": \"::\", \"listen_port\": ${VLESS_PORT},
      \"users\": [ ${vlusers} ],
      \"tls\": { \"enabled\": true, \"server_name\": \"${VLESS_SNI}\",
        \"reality\": { \"enabled\": true,
          \"handshake\": { \"server\": \"${VLESS_DEST}\", \"server_port\": 443 },
          \"private_key\": \"${REALITY_PRIV}\",
          \"short_id\": [\"${REALITY_SID}\"] } } }"
  fi
  local b_vless_outbound="" b_selector="" b_final="hy2-out"
  if [[ -n "${B_VLESS_UUID:-}" ]]; then
    b_vless_outbound=",
    { \"type\": \"vless\", \"tag\": \"vless-out-b\", \"server\": \"${B_DOMAIN}\", \"server_port\": ${B_PORT},
      \"uuid\": \"${B_VLESS_UUID}\", \"flow\": \"xtls-rprx-vision\",
      \"tls\": { \"enabled\": true, \"server_name\": \"${B_VLESS_SNI}\",
        \"utls\": { \"enabled\": true, \"fingerprint\": \"chrome\" },
        \"reality\": { \"enabled\": true, \"public_key\": \"${B_REALITY_PUB}\", \"short_id\": \"${B_REALITY_SID}\" } } }"
    b_selector=",
    { \"type\": \"selector\", \"tag\": \"to-b\",
      \"outbounds\": [ \"hy2-out\", \"vless-out-b\" ],
      \"default\": \"hy2-out\" }"
    b_final="to-b"
  fi
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
  echo "sing-box перезапущен."
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

vless_outbound_json() {
  cat <<VL
{ "type": "vless", "tag": "${VLESS_DEST}_${PROFILE}_vless", "server": "${A_DOMAIN}", "server_port": ${VLESS_PORT},
  "uuid": "${VLESS_UUID}", "flow": "xtls-rprx-vision",
  "tls": { "enabled": true, "server_name": "${VLESS_SNI}",
    "utls": { "enabled": true, "fingerprint": "chrome" },
    "reality": { "enabled": true, "public_key": "${REALITY_PUB}", "short_id": "${REALITY_SID}" } } }
VL
}

outbound_json_for() {
  case "$1" in
    hy2) hy2_outbound_json ;;
    vless) vless_outbound_json ;;
    *) echo "неизвестный proxy type: $1" >&2; return 1 ;;
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
  local opts="" first=1 pt count=0 tag
  if [[ -n "${WG_PUB:-}" ]]; then
    tag=$(proxy_tag_for wg)
    opts+="\"${tag}\""
    first=0
    count=$((count+1))
  fi
  for pt in $(client_proxy_types); do
    tag=$(proxy_tag_for "$pt")
    [[ $first -eq 0 ]] && opts+=","
    opts+="\"${tag}\""
    first=0
    count=$((count+1))
  done
  [[ $count -lt 2 ]] && return 1
  cat <<UT
{ "type": "urltest", "tag": "auto",
  "outbounds": [ ${opts} ],
  "url": "https://www.gstatic.com/generate_204",
  "interval": "5m",
  "tolerance": 200 }
UT
}

selector_json() {
  local opts="" first=1 def_tag="" pt has_proxy=0 tag
  if [[ -n "${WG_PUB:-}" ]]; then
    tag=$(proxy_tag_for wg)
    opts+="\"${tag}\""
    first=0
    def_tag="${tag}"
  fi
  for pt in $(client_proxy_types); do
    has_proxy=1
    tag=$(proxy_tag_for "$pt")
    [[ $first -eq 0 ]] && opts+=","
    opts+="\"${tag}\""
    first=0
  done
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
  if [[ $? -ne 0 ]]; then echo "  ОШИБКА JSON (modern)"; rm -f "${base}-modern.json"; modern_ok=0
  elif ! sing-box check -c "${base}-modern.json" >/dev/null 2>&1; then
    echo "  modern не прошёл sing-box check:"
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
  if [[ $? -ne 0 ]]; then echo "  ОШИБКА JSON (legacy)"; rm -f "${base}-legacy.json"; legacy_ok=0; fi

  if [[ $modern_ok -eq 0 && $legacy_ok -eq 0 ]]; then
    echo "  Оба варианта не сгенерились, URL не выдан."; return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    for f in "${base}-modern.json" "${base}-legacy.json"; do
      [[ -f "$f" ]] && { jq . "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"; }
    done
  fi
  chmod 644 "${base}-modern.json" "${base}-legacy.json" 2>/dev/null

  echo "  modern: $([[ $modern_ok -eq 1 ]] && echo OK || echo "нет (см. выше)")"
  echo "  legacy: $([[ $legacy_ok -eq 1 ]] && echo OK || echo "нет")"

  local url enc
  url="https://${PROFILE_HOST}:${PROFILE_PORT}/${KEY}_${TOKEN}.json"
  enc=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$url")
  echo "  URL (авто по User-Agent):"
  echo "    $url"
  echo "  link:"
  echo "    sing-box://import-remote-profile?url=${enc}#${NAME// /_}"
  command -v qrencode >/dev/null 2>&1 && { echo "  QR:"; qrencode -t ansiutf8 "sing-box://import-remote-profile?url=${enc}#${NAME// /_}"; }
}

emit_client() {
  source "$BASE"
  NAME=""; PROFILE=""; WG_PRIV=""; WG_PUB=""; IP=""; PASS=""; VLESS_UUID=""; AIPS=""; TOKEN=""
  source "$CLI/$1.env"
  local KEY="$1"
  echo "=== Клиент: ${NAME}  (profile: ${PROFILE}) ==="
  if [[ -n "$WG_PUB" ]]; then
    echo "IP: ${WG_NET}.${IP}"
    local cf; cf=$(gen_wg_conf)
    echo ".conf (WireGuard app): $cf"
    echo
    echo "--- блок WG endpoint (sing-box) ---"
    wg_endpoint_json | (jq . 2>/dev/null || cat)
    echo
  fi
  local pt
  for pt in $(client_proxy_types); do
    echo "--- блок ${pt} outbound (sing-box) ---"
    outbound_json_for "$pt" | (jq . 2>/dev/null || cat)
    echo
  done
  local ut_preview; ut_preview=$(urltest_json 2>/dev/null) || ut_preview=""
  if [[ -n "$ut_preview" ]]; then
    echo "--- urltest (auto) ---"
    echo "$ut_preview" | (jq . 2>/dev/null || cat)
    echo
  fi
  echo "--- selector ---"
  selector_json | (jq . 2>/dev/null || cat)
  echo
  echo "URL-профиль sing-box:"
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
  read -rp "Имя владельца (напр. kitty): " name
  [[ "$name" =~ ^[A-Za-z0-9_]+$ ]] || { echo "имя: латиница/цифры/_"; return; }
  while true; do
    read -rp "Профиль/устройство (напр. phone): " dev
    [[ "$dev" =~ ^[A-Za-z0-9_]+$ ]] || { echo "профиль: латиница/цифры/_"; continue; }
    key="${name}_${dev}"
    if [[ -f "$CLI/$key.env" ]]; then
      echo "$key уже есть"
    else
      echo "Транспорт:"
      echo "  1) оба (WG + Proxy)"
      echo "  2) только WG"
      echo "  3) только Proxy (${AVAILABLE_PROXY_TYPES})"
      local pr; read -rp "Выбор [1-3, Enter=1]: " pr
      local want_wg=1 want_proxy=1
      case "$pr" in
        2) want_proxy=0 ;;
        3) want_wg=0 ;;
      esac

      local aips="" ip="" priv="" pub="" pass="" token m
      token=$(openssl rand -hex 8)

      if [[ $want_wg -eq 1 ]]; then
        echo "Маршрутизация WG:"; echo "  1) весь трафик"; echo "  2) кроме приватных сетей"
        read -rp "Выбор [1-2, Enter=1]: " m
        case "$m" in 2) aips="$AIPS_SPLIT";; *) aips="$AIPS_FULL";; esac
        ip=$(next_wg_ip); [[ "$ip" == "ERR" ]] && { echo "нет IP"; return; }
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
      echo "  + устройство $dev создано ($proto_label)."
      CREATED+=("$key")
    fi
    read -rp "Добавить ещё устройство этому владельцу? [y/N] " a
    [[ "${a,,}" == "y" ]] || break
  done
  rebuild_config
  echo
  if [[ ${#CREATED[@]} -eq 0 ]]; then
    echo "Новых устройств не создано."
  else
    echo "Готово. Созданные в этом запуске устройства:"
    local k
    for k in "${CREATED[@]}"; do echo; emit_client "$k"; done
  fi
}

show_client() {
  list_names
  if [[ ${#NAMES[@]} -eq 0 ]]; then echo "Клиентов нет."; return; fi
  echo "Владельцы:"
  local j
  for ((j=0; j<${#NAMES[@]}; j++)); do
    devices_of "${NAMES[$j]}"
    printf "  %d) %s  (%d устр.)\n" "$((j+1))" "${NAMES[$j]}" "${#DEVS[@]}"
  done
  local n; read -rp "Номер владельца: " n
  [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#NAMES[@]} )) || { echo "неверно"; return; }
  local owner="${NAMES[$((n-1))]}"
  devices_of "$owner"
  echo "Устройства '$owner':"
  for ((j=0; j<${#DEVS[@]}; j++)); do printf "  %d) %s\n" "$((j+1))" "${DEVPROF[$j]}"; done
  local d; read -rp "Номер устройства (0 — все): " d
  [[ "$d" =~ ^[0-9]+$ ]] || { echo "неверно"; return; }
  if [[ "$d" == "0" ]]; then
    for ((j=0; j<${#DEVS[@]}; j++)); do echo; emit_client "$(basename "${DEVS[$j]}" .env)"; done
  else
    (( d>=1 && d<=${#DEVS[@]} )) || { echo "неверно"; return; }
    echo; emit_client "$(basename "${DEVS[$((d-1))]}" .env)"
  fi
}

revoke_client() {
  list_names
  if [[ ${#NAMES[@]} -eq 0 ]]; then echo "Клиентов нет."; return; fi
  echo "Владельцы:"
  local j
  for ((j=0; j<${#NAMES[@]}; j++)); do
    devices_of "${NAMES[$j]}"
    printf "  %d) %s  (%d устр.)\n" "$((j+1))" "${NAMES[$j]}" "${#DEVS[@]}"
  done
  local n; read -rp "Номер владельца: " n
  [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#NAMES[@]} )) || { echo "неверно"; return; }
  local owner="${NAMES[$((n-1))]}"
  devices_of "$owner"
  echo "Устройства '$owner':"
  for ((j=0; j<${#DEVS[@]}; j++)); do printf "  %d) %s\n" "$((j+1))" "${DEVPROF[$j]}"; done
  echo "  0) ВЕСЬ владелец '$owner' целиком"
  local d; read -rp "Что отозвать: " d
  [[ "$d" =~ ^[0-9]+$ ]] || { echo "неверно"; return; }
  if [[ "$d" == "0" ]]; then
    read -rp "Удалить ВСЕ устройства '$owner'? [y/N] " a
    [[ "${a,,}" == "y" ]] || { echo "отмена"; return; }
    for ((j=0; j<${#DEVS[@]}; j++)); do
      local pr="${DEVPROF[$j]}"
      rm -f "${DEVS[$j]}" "$PROFILES/${owner}_${pr}_"*.json "$CONFDIR/${owner}_${pr}.conf"
    done
    echo "Владелец '$owner' удалён целиком."
  else
    (( d>=1 && d<=${#DEVS[@]} )) || { echo "неверно"; return; }
    local key; key=$(basename "${DEVS[$((d-1))]}" .env)
    read -rp "Удалить устройство '$key'? [y/N] " a
    [[ "${a,,}" == "y" ]] || { echo "отмена"; return; }
    rm -f "$CLI/$key.env" "$PROFILES/${key}_"*.json "$CONFDIR/${key}.conf"
    echo "Устройство '$key' удалено."
  fi
  rebuild_config
}

fetch_stats_raw() {
  grpcurl -plaintext -import-path "$(dirname "$GRPC_PROTO")" -proto "$(basename "$GRPC_PROTO")" \
    -d '{"pattern": "", "reset": false}' \
    127.0.0.1:8080 v2ray.core.app.stats.command.StatsService/QueryStats 2>/dev/null
}

traffic_update() {
  if [[ ! -f "$GRPC_PROTO" ]]; then echo "нет $GRPC_PROTO — статистика недоступна"; return 1; fi
  if ! command -v grpcurl >/dev/null 2>&1; then echo "grpcurl не установлен"; return 1; fi
  local raw; raw=$(fetch_stats_raw)
  if [[ -z "$raw" ]]; then echo "не удалось получить статистику (v2ray_api недоступен)"; return 1; fi
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
  python3 - "$TRAFFIC_TOTALS" "$TRAFFIC_DAILY" "$1" <<'PYEOF'
import sys, os, glob
from datetime import date, timedelta

totals_path, daily_dir, mode = sys.argv[1], sys.argv[2], sys.argv[3]

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
print(f"  СЕРВЕР ВСЕГО (WG+Proxy): \u2191 {human(total_up)}  \u2193 {human(total_dn)}  (\u0432\u0441\u0435\u0433\u043e: {human(total_up+total_dn)})")
print()

clients = {}
for k, v in data.items():
    if k == "hy2-out:uplink" or k == "hy2-out:downlink":
        continue
    key, direction = k.rsplit(":", 1)
    clients.setdefault(key, {"uplink": 0, "downlink": 0})[direction] = v

if not clients:
    print("  (нет клиентского трафика за этот период)")
else:
    print("  По клиентам v2ray:")
    for key, d in sorted(clients.items(), key=lambda x: -(x[1].get('uplink',0)+x[1].get('downlink',0))):
        up, dn = d.get('uplink',0), d.get('downlink',0)
        if "_" in key:
            owner, profile = key.split("_", 1)
            label = f"{owner} / {profile}  [tag: {key}]"
        else:
            label = f"{key}  [tag: {key}]"
        print(f"    {label}: \u2191 {human(up)}  \u2193 {human(dn)}  (\u0432\u0441\u0435\u0433\u043e: {human(up+dn)})")
PYEOF
}

traffic_menu() {
  traffic_update
  echo "Период:"
  echo "  1) сегодня"
  echo "  2) 7 дней"
  echo "  3) всего"
  local c; read -rp "Выбор [1-3]: " c
  case "$c" in
    1) echo "=== За сегодня ==="; traffic_aggregate 1 ;;
    2) echo "=== За 7 дней ==="; traffic_aggregate 7 ;;
    3) echo "=== За всё время ==="; traffic_aggregate totals ;;
    *) echo "неверно" ;;
  esac
}

service_menu() {
  local LOG=/var/log/nginx/profile_access.log
  echo "Сервис:"
  echo "  1) обращения конкретного клиента"
  echo "  2) статистика modern/legacy"
  echo "  3) живой мониторинг (tail -f, Ctrl+C для выхода)"
  echo "  4) пересобрать и перезапустить конфиг"
  echo "  5) статистика трафика"
  local c; read -rp "Выбор [1-5]: " c
  case "$c" in
    1)
      list_names
      if [[ ${#NAMES[@]} -eq 0 ]]; then echo "Клиентов нет."; return; fi
      local j
      for ((j=0; j<${#NAMES[@]}; j++)); do
        devices_of "${NAMES[$j]}"
        printf "  %d) %s  (%d устр.)\n" "$((j+1))" "${NAMES[$j]}" "${#DEVS[@]}"
      done
      local n; read -rp "Номер владельца: " n
      [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#NAMES[@]} )) || { echo "неверно"; return; }
      local owner="${NAMES[$((n-1))]}"
      devices_of "$owner"
      echo "Устройства '$owner':"
      for ((j=0; j<${#DEVS[@]}; j++)); do printf "  %d) %s\n" "$((j+1))" "${DEVPROF[$j]}"; done
      local d; read -rp "Номер устройства: " d
      [[ "$d" =~ ^[0-9]+$ ]] && (( d>=1 && d<=${#DEVS[@]} )) || { echo "неверно"; return; }
      local key; key=$(basename "${DEVS[$((d-1))]}" .env)
      grep "key=${key}_" "$LOG" || echo "Обращений не найдено."
      ;;
    2)
      echo "Статистика по версиям (все клиенты):"
      grep -o 'variant=[a-z]*' "$LOG" | sort | uniq -c
      ;;
    3)
      echo "Живой мониторинг (Ctrl+C для выхода):"
      tail -f "$LOG"
      ;;
    4)
      rebuild_config
      ;;
    5)
      traffic_menu
      ;;
    *) echo "неверно" ;;
  esac
}

edit_client() {
  ensure_base
  list_names
  if [[ ${#NAMES[@]} -eq 0 ]]; then echo "Клиентов нет."; return; fi
  echo "Владельцы:"
  local j
  for ((j=0; j<${#NAMES[@]}; j++)); do
    devices_of "${NAMES[$j]}"
    printf "  %d) %s  (%d устр.)\n" "$((j+1))" "${NAMES[$j]}" "${#DEVS[@]}"
  done
  local n; read -rp "Номер владельца: " n
  [[ "$n" =~ ^[0-9]+$ ]] && (( n>=1 && n<=${#NAMES[@]} )) || { echo "неверно"; return; }
  local owner="${NAMES[$((n-1))]}"
  devices_of "$owner"

  echo "Действие для '$owner':"
  echo "  1) переименовать владельца (все устройства)"
  echo "  2) переименовать устройство"
  echo "  3) изменить транспорт устройства"
  echo "  0) отмена"
  local act; read -rp "Выбор [0-3]: " act
  [[ "$act" == "0" ]] && { echo "отмена"; return; }
  [[ "$act" =~ ^[1-3]$ ]] || { echo "неверно"; return; }

  if [[ "$act" == "1" ]]; then
    read -rp "Новое имя владельца: " new_name
    [[ "$new_name" =~ ^[A-Za-z0-9_]+$ ]] || { echo "имя: латиница/цифры/_"; return; }
    local f dev_name newkey oldkey renamed=0
    for f in "${DEVS[@]}"; do
      NAME=""; PROFILE=""; source "$f"
      dev_name="$PROFILE"
      oldkey=$(basename "$f" .env)
      newkey="${new_name}_${dev_name}"
      if [[ -f "$CLI/$newkey.env" && "$newkey" != "$oldkey" ]]; then
        echo "  пропуск $oldkey: '$newkey' уже существует"
        continue
      fi
      sed -i "s/^NAME=\".*\"/NAME=\"$new_name\"/" "$f"
      if [[ "$newkey" != "$oldkey" ]]; then
        mv "$f" "$CLI/$newkey.env"
        rm -f "$PROFILES/${oldkey}_"*.json "$CONFDIR/${oldkey}.conf"
      fi
      renamed=$((renamed+1))
    done
    echo "Переименовано устройств: $renamed"
    rebuild_config
    return
  fi

  echo "Устройства '$owner':"
  for ((j=0; j<${#DEVS[@]}; j++)); do printf "  %d) %s\n" "$((j+1))" "${DEVPROF[$j]}"; done
  local d; read -rp "Номер устройства: " d
  [[ "$d" =~ ^[0-9]+$ ]] && (( d>=1 && d<=${#DEVS[@]} )) || { echo "неверно"; return; }
  local oldfile="${DEVS[$((d-1))]}"
  local oldkey; oldkey=$(basename "$oldfile" .env)

  local ONAME="" OPROFILE="" OWG_PRIV="" OWG_PUB="" OIP="" OPASS="" OVLESS_UUID="" OAIPS="" OTOKEN=""
  NAME=""; PROFILE=""; WG_PRIV=""; WG_PUB=""; IP=""; PASS=""; VLESS_UUID=""; AIPS=""; TOKEN=""
  source "$oldfile"
  ONAME="$NAME"; OPROFILE="$PROFILE"; OWG_PRIV="$WG_PRIV"; OWG_PUB="$WG_PUB"; OIP="$IP"
  OPASS="$PASS"; OVLESS_UUID="$VLESS_UUID"; OAIPS="$AIPS"; OTOKEN="$TOKEN"

  local new_name="$ONAME" new_dev="$OPROFILE"

  if [[ "$act" == "2" ]]; then
    read -rp "Новое имя устройства: " new_dev
    [[ "$new_dev" =~ ^[A-Za-z0-9_]+$ ]] || { echo "устройство: латиница/цифры/_"; return; }
  elif [[ "$act" == "3" ]]; then
    local cur=""
    [[ -n "$OWG_PUB" ]] && cur+="WG "
    [[ -n "$OPASS" ]] && cur+="hy2 "
    [[ -n "$OVLESS_UUID" ]] && cur+="vless "
    [[ -z "$cur" ]] && cur="(нет)"
    echo "Текущий транспорт: $cur"
    echo "Транспорт:"
    echo "  1) оба (WG + Proxy)"
    echo "  2) только WG"
    echo "  3) только Proxy (${AVAILABLE_PROXY_TYPES})"
    echo "  0) отмена"
    local pr; read -rp "Выбор [0-3]: " pr
    [[ -z "$pr" || "$pr" == "0" ]] && { echo "отмена"; return; }
    [[ "$pr" =~ ^[1-3]$ ]] || { echo "неверно"; return; }
    local want_wg=1 want_proxy=1
    case "$pr" in
      2) want_proxy=0 ;;
      3) want_wg=0 ;;
    esac

    if [[ $want_wg -eq 1 && -z "$OWG_PUB" ]]; then
      echo "Маршрутизация WG:"; echo "  1) весь трафик"; echo "  2) кроме приватных сетей"
      local m; read -rp "Выбор [1-2, Enter=1]: " m
      case "$m" in 2) OAIPS="$AIPS_SPLIT";; *) OAIPS="$AIPS_FULL";; esac
      local newip; newip=$(next_wg_ip); [[ "$newip" == "ERR" ]] && { echo "нет IP"; return; }
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
    echo "'$newkey' уже существует, отмена"; return
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
  echo "Обновлено. Текущее состояние:"
  emit_client "$newkey"
}

if [[ "${1:-}" == "--cron-traffic" ]]; then
  traffic_update
  exit 0
fi

while true; do
  echo
  echo "=== VPN manager (A: ${A_DOMAIN} / ${A_IP}) ==="
  echo "1) создать клиента"
  echo "2) редактировать клиента"
  echo "3) отозвать клиента"
  echo "4) показать клиента"
  echo "5) сервис"
  echo "0) выход"
  read -rp "Выбор [0-5]: " c
  case "$c" in
    1) create_client ;;
    2) edit_client ;;
    3) revoke_client ;;
    4) show_client ;;
    5) service_menu ;;
    0) echo "Пока!"; break ;;
    *) echo "неизвестный пункт" ;;
  esac
done
