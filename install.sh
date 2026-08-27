#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/i18n.sh"

if [[ -n "${SBP_LANG:-}" ]]; then
  LANG_CODE="$SBP_LANG"
else
  echo "$(t warp_language_title)"
  echo "$(t warp_language_en)"
  echo "$(t warp_language_ru)"
  read -rp "$(t warp_language_prompt)" LANG_CHOICE
  case "$LANG_CHOICE" in
    2) LANG_CODE="ru" ;;
    *) LANG_CODE="en" ;;
  esac
fi

if [[ $EUID -ne 0 ]]; then
  echo "$(t must_run_as_root)"
  exit 1
fi
MARKER=/etc/sing-box/.install-in-progress
DONE_MARKER=/etc/sing-box/.install-done
INSTALL_STATE_DIR=/var/lib/sing-box-panel
INSTALL_STATE_FILE=$INSTALL_STATE_DIR/install-step
SING_BOX_REV_FILE=/usr/lib/sing-box-panel/sing-box-revision
SING_BOX_SHA_FILE=/usr/lib/sing-box-panel/sing-box-sha256
SING_BOX_BIN=/usr/local/lib/sing-box-panel/sing-box

# Do not let needrestart terminate the SSH session during package installation.
export NEEDRESTART_MODE=l

step() { echo; echo "=================================================="; echo "$1"; echo "=================================================="; }

RULESET_DEFAULT_BASE="https://unicorns.kz/sources"
GEOIP_RU_RELATIVE_PATH="geoip/geoip-ru.srs"
SING_BOX_REV="f3b0c775addeeaff256a2019ff71d32a5dce62b3"
SERVICE_WAIT_SECONDS=30
CERT_WAIT_SECONDS=180

maybe_start_tmux() {
  [[ -t 0 && -t 1 && -z "${TMUX:-}" && "${SBP_IN_TMUX:-0}" != "1" ]] || return 0
  echo
  read -rp "$(t tmux_offer)" answer
  [[ "${answer,,}" != "n" ]] || return 0
  if ! command -v tmux >/dev/null 2>&1; then
    echo "$(t tmux_installing)"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq tmux
  fi
  local tmux_cmd
  printf -v tmux_cmd 'cd %q && SBP_LANG=%q SBP_IN_TMUX=1 bash %q' "$SCRIPT_DIR" "$LANG_CODE" "$SCRIPT_DIR/install.sh"
  echo "$(t tmux_attach_hint)"
  echo "  tmux attach -t sing-box-install"
  exec tmux new-session -A -s sing-box-install "$tmux_cmd"
}

read_install_step() {
  local value=0
  [[ -f "$INSTALL_STATE_FILE" ]] && value=$(cat "$INSTALL_STATE_FILE" 2>/dev/null || printf '0')
  [[ "$value" =~ ^[0-9]+$ ]] || value=0
  printf '%s' "$value"
}

complete_install_step() {
  mkdir -p "$INSTALL_STATE_DIR"
  printf '%s\n' "$1" > "$INSTALL_STATE_FILE"
  INSTALL_STEP="$1"
}

sing_box_build_is_verified() {
  [[ -x "$SING_BOX_BIN" && -f "$SING_BOX_REV_FILE" && -f "$SING_BOX_SHA_FILE" ]] || return 1
  [[ "$(cat "$SING_BOX_REV_FILE")" == "$SING_BOX_REV" ]] || return 1
  [[ "$(sha256sum "$SING_BOX_BIN" | awk '{print $1}')" == "$(cat "$SING_BOX_SHA_FILE")" ]] || return 1
  "$SING_BOX_BIN" version | grep -qi v2ray
}

installation_failed() {
  local status=$?
  trap - ERR
  echo
  printf "$(t install_paused)\n" "$INSTALL_STEP"
  echo "$(t install_resume_command)"
  exit "$status"
}

normalize_ruleset_base() {
  local value="${1:-}"
  value="${value#http://}"
  value="${value#https://}"
  value="${value%/}"
  [[ "$value" =~ ^[A-Za-z0-9.-]+(:[0-9]+)?(/[A-Za-z0-9._~/-]+)?$ ]] || return 1
  [[ "$value" != *".."* && "$value" != *"//"* ]] || return 1
  printf 'https://%s' "$value"
}

ruleset_base_from_routing() {
  local file="${1:-}" url
  [[ -f "$file" ]] || return 1
  url=$(jq -r '.rule_set[]?.url // empty' "$file" 2>/dev/null | head -1)
  [[ -n "$url" ]] || return 1
  url="${url%%/geoip/*}"
  url="${url%%/geosite/*}"
  normalize_ruleset_base "$url"
}

existing_ru_rules_enabled() {
  local file
  for file in /opt/vpn/server-routing.json /opt/vpn/client-routing.json; do
    [[ -f "$file" ]] || continue
    if jq -e 'any(.rule_set[]?; .tag == "geoip-russia")' "$file" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 1
}

render_routing_template() {
  local source_file="$1" target_file="$2" ru_rules_enabled="$3" base_url="$4" outbound="$5"
  python3 - "$source_file" "$target_file" "$ru_rules_enabled" "$base_url" "$outbound" <<'PYEOF'
import json
import sys

source_file, target_file, enabled, base_url, outbound = sys.argv[1:6]
with open(source_file) as source:
    policy = json.load(source)

if enabled == "1":
    policy["rule_set"].append({
        "tag": "geoip-russia",
        "type": "remote",
        "format": "binary",
        "url": f"{base_url}/geoip/geoip-ru.srs",
        "download_detour": "direct",
    })
    policy["rules"].extend([
        {
            "domain_suffix": [".ru", ".su", ".рф", ".xn--p1ai"],
            "outbound": outbound,
        },
        {
            "rule_set": ["geoip-russia"],
            "outbound": outbound,
        },
    ])

with open(target_file, "w") as target:
    json.dump(policy, target, ensure_ascii=False, indent=2)
    target.write("\n")
PYEOF
}

validate_ruleset_binary() {
  local binary_file="$1" tmp_json
  [[ -s "$binary_file" ]] || return 1
  tmp_json=$(mktemp)
  if ! sing-box rule-set decompile "$binary_file" -o "$tmp_json" >/dev/null 2>&1; then
    rm -f "$tmp_json"
    return 1
  fi
  if ! jq empty "$tmp_json" >/dev/null 2>&1; then
    rm -f "$tmp_json"
    return 1
  fi
  rm -f "$tmp_json"
}

validate_ruleset_url() {
  local url="$1" resolve="${2:-}" tmp_binary
  local -a curl_args=(-4 -fsSL --max-time 30)
  [[ -n "$resolve" ]] && curl_args+=(--resolve "$resolve")
  tmp_binary=$(mktemp)
  if ! curl "${curl_args[@]}" -o "$tmp_binary" "$url"; then
    rm -f "$tmp_binary"
    printf -- "$(t ruleset_file_unavailable)\n" "$url" >&2
    return 1
  fi
  if ! validate_ruleset_binary "$tmp_binary"; then
    rm -f "$tmp_binary"
    printf -- "$(t ruleset_file_invalid)\n" "$url" >&2
    return 1
  fi
  rm -f "$tmp_binary"
}

validate_ruleset_storage() {
  validate_ruleset_url "${1}/${GEOIP_RU_RELATIVE_PATH}"
}

cleanup_failed_install() {
  echo
  echo "=================================================="
  echo "$(t rollback_header)"
  echo "=================================================="
  systemctl stop sing-box nginx-cert-reload.path warp-svc 2>/dev/null || true
  systemctl disable sing-box nginx-cert-reload.path warp-svc 2>/dev/null || true
  if dpkg-query -W -f='${Status}' cloudflare-warp 2>/dev/null | grep -q 'ok installed'; then
    DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq cloudflare-warp 2>/dev/null || true
  fi
  rm -rf /etc/sing-box /opt/vpn /root/clients
  rm -rf /var/lib/cloudflare-warp
  rm -rf "$INSTALL_STATE_DIR"
  rm -f /root/sb-panel /root/vpn-setup.sh /root/i18n.sh
  rm -f /etc/apt/sources.list.d/cloudflare-client.list
  rm -f /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
  rm -f /etc/nginx/sites-enabled/profiles /etc/nginx/sites-available/profiles
  rm -f /etc/nginx/sites-enabled/rulesets /etc/nginx/sites-available/rulesets
  rm -f /etc/nginx/conf.d/singbox-ua.conf
  rm -f /etc/systemd/system/sing-box.service
  rm -f /etc/systemd/system/sing-box.service.d/warp.conf
  rm -f /etc/systemd/system/sing-box.service.d/10-panel-binary.conf
  rmdir /etc/systemd/system/sing-box.service.d 2>/dev/null || true
  rm -f /etc/systemd/system/nginx-cert-reload.path /etc/systemd/system/nginx-cert-reload.service
  systemctl daemon-reload 2>/dev/null || true
  echo "$(t rollback_done)"
  echo "$(t rollback_binary_kept)"
}

update_existing_install() {
  echo "$(t update_started)"
  local replace_routing=0 replace_client_routing=0 ruleset_base="" ru_rules_enabled=""
  if [[ -f /etc/sing-box/vpn-panel.env ]]; then
    read -r ru_rules_enabled ruleset_base < <(
      set +u
      source /etc/sing-box/vpn-panel.env
      printf '%s %s\n' "${RU_RULES_ENABLED:-}" "${RULESET_BASE_URL:-}"
    )
  fi
  if [[ "$ru_rules_enabled" != "0" && "$ru_rules_enabled" != "1" ]]; then
    if existing_ru_rules_enabled; then
      ru_rules_enabled=1
    else
      ru_rules_enabled=0
    fi
  fi
  if [[ "$ru_rules_enabled" == "1" ]]; then
    if ! ruleset_base=$(normalize_ruleset_base "$ruleset_base" 2>/dev/null); then
      ruleset_base=$(ruleset_base_from_routing /opt/vpn/client-routing.json 2>/dev/null || \
        ruleset_base_from_routing /opt/vpn/server-routing.json 2>/dev/null || \
        printf '%s' "$RULESET_DEFAULT_BASE")
    fi
  else
    ruleset_base=""
  fi
  if [[ -f /opt/vpn/server-routing.json ]]; then
    printf "$(t routing_file_found)\n" "/opt/vpn/server-routing.json"
    echo "$(t routing_keep_option)"
    echo "$(t routing_replace_option)"
    local routing_choice
    read -rp "$(t prompt_choice_12_default1)" routing_choice
    case "${routing_choice:-1}" in
      1) replace_routing=0 ;;
      2) replace_routing=1 ;;
      *) echo "$(t invalid)"; return 1 ;;
    esac
  else
    replace_routing=1
  fi

  if [[ -f /opt/vpn/client-routing.json ]]; then
    printf "$(t client_routing_file_found)\n" "/opt/vpn/client-routing.json"
    echo "$(t client_routing_keep_option)"
    echo "$(t client_routing_replace_option)"
    local client_routing_choice
    read -rp "$(t prompt_choice_12_default1)" client_routing_choice
    case "${client_routing_choice:-1}" in
      1) replace_client_routing=0 ;;
      2) replace_client_routing=1 ;;
      *) echo "$(t invalid)"; return 1 ;;
    esac
  else
    replace_client_routing=1
  fi

  if [[ "$ru_rules_enabled" == "1" && \
        ( "$replace_routing" == "1" || "$replace_client_routing" == "1" ) ]]; then
    while true; do
      echo
      echo "$(t ruleset_intro)"
      local ruleset_base_input
      read -rp "$(printf "$(t prompt_ruleset_base)" "$ruleset_base")" ruleset_base_input
      ruleset_base_input=${ruleset_base_input:-$ruleset_base}
      if ! ruleset_base=$(normalize_ruleset_base "$ruleset_base_input"); then
        echo "$(t ruleset_base_invalid)"
        continue
      fi
      echo "$(t ruleset_checking_existing)"
      if validate_ruleset_storage "$ruleset_base"; then
        echo "$(t ruleset_existing_ready)"
        break
      fi
      echo "$(t ruleset_existing_retry)"
    done
  fi

  bash -n "$SCRIPT_DIR/vpn-setup.sh" "$SCRIPT_DIR/i18n.sh" "$SCRIPT_DIR/install-warp.sh"
  jq empty "$SCRIPT_DIR/templates/server-routing.json"
  jq empty "$SCRIPT_DIR/templates/client-routing.json"

  local stamp backup
  stamp=$(date +%Y%m%d%H%M%S)
  backup="/root/vpn-update-backup-${stamp}"
  install -d -m 0700 "$backup/root" "$backup/opt-vpn"
  [[ -f /root/vpn-setup.sh ]] && cp -a /root/vpn-setup.sh "$backup/root/"
  [[ -f /root/i18n.sh ]] && cp -a /root/i18n.sh "$backup/root/"
  local file
  for file in i18n.sh template.json template-legacy.json stats.proto server-template.json server-routing.json client-routing.json; do
    [[ -f "/opt/vpn/$file" ]] && cp -a "/opt/vpn/$file" "$backup/opt-vpn/"
  done
  [[ -f /etc/sing-box/config.json ]] && cp -a /etc/sing-box/config.json "$backup/config.json"
  install -d -m 0700 "$backup/client-layout"
  local env_file owner
  for env_file in /etc/sing-box/clients/*.env; do
    [[ -e "$env_file" ]] || continue
    owner=$(sed -n 's/^NAME="\([A-Za-z0-9_]*\)"$/\1/p' "$env_file" | head -1)
    [[ -n "$owner" && -d "/opt/vpn/$owner" && ! -e "$backup/client-layout/$owner" ]] || continue
    cp -a "/opt/vpn/$owner" "$backup/client-layout/$owner"
  done

  install -m 0755 "$SCRIPT_DIR/vpn-setup.sh" /root/vpn-setup.sh
  install -m 0644 "$SCRIPT_DIR/i18n.sh" /root/i18n.sh
  install -m 0644 "$SCRIPT_DIR/i18n.sh" /opt/vpn/i18n.sh
  install -m 0644 "$SCRIPT_DIR/templates/template.json" /opt/vpn/template.json
  install -m 0644 "$SCRIPT_DIR/templates/template-legacy.json" /opt/vpn/template-legacy.json
  install -m 0644 "$SCRIPT_DIR/templates/stats.proto" /opt/vpn/stats.proto
  install -m 0644 "$SCRIPT_DIR/templates/server-template.json" /opt/vpn/server-template.json
  if [[ "$replace_routing" == "1" ]]; then
    render_routing_template "$SCRIPT_DIR/templates/server-routing.json" /opt/vpn/server-routing.json \
      "$ru_rules_enabled" "$ruleset_base" "DIRECT_RULES"
    chmod 0644 /opt/vpn/server-routing.json
    echo "$(t routing_replaced)"
  else
    echo "$(t routing_kept)"
  fi
  if [[ "$replace_client_routing" == "1" ]]; then
    render_routing_template "$SCRIPT_DIR/templates/client-routing.json" /opt/vpn/client-routing.json \
      "$ru_rules_enabled" "$ruleset_base" "direct"
    chmod 0644 /opt/vpn/client-routing.json
    echo "$(t client_routing_replaced)"
  else
    echo "$(t client_routing_kept)"
  fi

  if ! VPN_CONFIG=/etc/sing-box/vpn-panel.env /root/vpn-setup.sh --rebuild-config; then
    [[ -f "$backup/root/vpn-setup.sh" ]] && cp -a "$backup/root/vpn-setup.sh" /root/vpn-setup.sh
    [[ -f "$backup/root/i18n.sh" ]] && cp -a "$backup/root/i18n.sh" /root/i18n.sh
    for file in i18n.sh template.json template-legacy.json stats.proto server-template.json server-routing.json client-routing.json; do
      [[ -f "$backup/opt-vpn/$file" ]] && cp -a "$backup/opt-vpn/$file" "/opt/vpn/$file"
    done
    [[ -f "$backup/config.json" ]] && cp -a "$backup/config.json" /etc/sing-box/config.json
    local saved_owner saved_name
    for saved_owner in "$backup/client-layout"/*; do
      [[ -d "$saved_owner" ]] || continue
      saved_name=$(basename "$saved_owner")
      rm -rf "/opt/vpn/clients/$saved_name" "/opt/vpn/$saved_name"
      cp -a "$saved_owner" "/opt/vpn/$saved_name"
    done
    rmdir /opt/vpn/clients 2>/dev/null || true
    systemctl restart --no-block sing-box || true
    printf "$(t update_failed_restored)\n" "$backup" >&2
    return 1
  fi

  printf "$(t update_completed)\n" "$backup"
}

if [[ -f "$DONE_MARKER" ]]; then
  printf "$(t done_marker_found)\n" "$(cat "$DONE_MARKER" 2>/dev/null)"
  echo "$(t existing_install_action)"
  echo "$(t existing_install_update)"
  echo "$(t existing_install_reinstall)"
  echo "$(t existing_install_cancel)"
  read -rp "$(t prompt_choice_012_default1)" EXISTING_ACTION
  case "${EXISTING_ACTION:-1}" in
    1)
      update_existing_install
      exit $?
      ;;
    2)
      echo "$(t done_marker_warning)"
      read -rp "$(t confirm_reinstall)" CONFIRM_REINSTALL
      if [[ "${CONFIRM_REINSTALL,,}" != "y" ]]; then
        echo "$(t reinstall_cancelled)"
        exit 0
      fi
      echo "$(t reinstall_proceeding)"
      cleanup_failed_install
      rm -f "$DONE_MARKER"
      ;;
    0)
      echo "$(t reinstall_cancelled)"
      exit 0
      ;;
    *)
      echo "$(t invalid)"
      exit 1
      ;;
  esac
fi

if [[ -f "$MARKER" ]]; then
  echo "$(t resuming_incomplete_install)"
fi

maybe_start_tmux
mkdir -p /etc/sing-box
touch "$MARKER"
INSTALL_STEP=$(read_install_step)
trap installation_failed ERR

if (( INSTALL_STEP < 1 )); then
  step "$(t step1)"
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    curl git build-essential wireguard-tools nginx libnginx-mod-stream jq qrencode python3 openssl dnsutils tmux
  complete_install_step 1
else
  printf "$(t step_skipped)\n" 1
fi

if (( INSTALL_STEP < 2 )); then
  step "$(t step2)"
  if ! command -v go >/dev/null 2>&1; then
    GOVER="go1.26.5"
    curl -sL --max-time 120 "https://go.dev/dl/${GOVER}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' > /etc/profile.d/go.sh
  fi
  export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
  go version
  complete_install_step 2
else
  printf "$(t step_skipped)\n" 2
fi
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

if (( INSTALL_STEP >= 3 )) && ! sing_box_build_is_verified; then
  echo "$(t build_checkpoint_invalid)"
  complete_install_step 2
fi

if (( INSTALL_STEP < 3 )); then
  step "$(t step3)"
  if sing_box_build_is_verified; then
    printf "$(t build_reused)\n" "$SING_BOX_REV"
  else
    mkdir -p /root/build
    SING_BOX_SOURCE_DIR="/root/build/sing-box-${SING_BOX_REV:0:12}"
    if [[ ! -d "$SING_BOX_SOURCE_DIR/.git" ]]; then
      git clone --filter=blob:none --no-checkout https://github.com/SagerNet/sing-box.git "$SING_BOX_SOURCE_DIR"
    fi
    git -C "$SING_BOX_SOURCE_DIR" fetch --depth 1 origin "$SING_BOX_REV"
    git -C "$SING_BOX_SOURCE_DIR" checkout --detach "$SING_BOX_REV"
    [[ "$(git -C "$SING_BOX_SOURCE_DIR" rev-parse HEAD)" == "$SING_BOX_REV" ]] || { echo "$(t build_revision_mismatch)"; exit 1; }
    (cd "$SING_BOX_SOURCE_DIR" && go build -v -trimpath \
      -tags "with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_v2ray_api,with_grpc,with_tailscale" \
      -o /root/build/sing-box-new ./cmd/sing-box)
    [[ -x /root/build/sing-box-new ]] || { echo "$(t build_failed)"; exit 1; }
    mkdir -p "$(dirname "$SING_BOX_BIN")" /usr/local/bin
    [[ -f "$SING_BOX_BIN" ]] && cp "$SING_BOX_BIN" "${SING_BOX_BIN}.bak" 2>/dev/null || true
    install -m 0755 /root/build/sing-box-new "$SING_BOX_BIN"
    ln -sfn "$SING_BOX_BIN" /usr/local/bin/sing-box
    "$SING_BOX_BIN" version | grep -qi v2ray || { echo "$(t v2ray_api_missing)"; exit 1; }
    mkdir -p "$(dirname "$SING_BOX_REV_FILE")"
    printf '%s\n' "$SING_BOX_REV" > "$SING_BOX_REV_FILE"
    sha256sum "$SING_BOX_BIN" | awk '{print $1}' > "$SING_BOX_SHA_FILE"
    echo "$(t build_success)"
  fi
  complete_install_step 3
else
  printf "$(t step_skipped)\n" 3
fi
mkdir -p /usr/local/bin
ln -sfn "$SING_BOX_BIN" /usr/local/bin/sing-box
SING_BOX_VERSION=$("$SING_BOX_BIN" version | sed -n '1s/^sing-box version //p')
SING_BOX_SHA256=$(sha256sum "$SING_BOX_BIN" | awk '{print $1}')

if (( INSTALL_STEP < 4 )); then
  step "$(t step4)"
  if ! command -v grpcurl >/dev/null 2>&1; then
    GRPCURL_VER="1.9.3"
    curl -sL --max-time 60 "https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VER}/grpcurl_${GRPCURL_VER}_linux_amd64.deb" -o /tmp/grpcurl.deb
    dpkg -i /tmp/grpcurl.deb || DEBIAN_FRONTEND=noninteractive apt-get install -f -y -qq
  fi
  grpcurl --version
  complete_install_step 4
else
  printf "$(t step_skipped)\n" 4
fi

if (( INSTALL_STEP < 5 )); then
  step "$(t step5)"
  cat > /etc/systemd/system/sing-box.service <<'UNIT'
[Unit]
Description=sing-box service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/lib/sing-box-panel/sing-box -D /var/lib/sing-box -C /etc/sing-box run
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
  mkdir -p /var/lib/sing-box
  systemctl daemon-reload
  complete_install_step 5
else
  printf "$(t step_skipped)\n" 5
fi

CONFIG_ENV=/etc/sing-box/vpn-panel.env
mkdir -p /etc/sing-box

if (( INSTALL_STEP < 6 )); then
step "$(t step6)"
if [[ -f "$CONFIG_ENV" ]]; then
  printf "$(t existing_config_found)\n" "$CONFIG_ENV"
  read -rp "$(t use_existing_skip)" reuse
  if [[ "${reuse,,}" == "n" ]]; then
    rm -f "$CONFIG_ENV"
  fi
fi

if [[ ! -f "$CONFIG_ENV" ]]; then
  echo "$(t fill_new_server_params)"
  DETECTED_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | cut -d' ' -f1)
  read -rp "$(printf "$(t prompt_ip_detected)" "${DETECTED_IP:-N/A}")" A_IP
  A_IP=${A_IP:-$DETECTED_IP}
  if [[ -z "$A_IP" ]]; then
    echo "$(t ip_autodetect_failed)"
    read -rp "$(t prompt_ip_manual)" A_IP
  fi
  read -rp "$(t prompt_domain)" A_DOMAIN
  read -rp "$(t prompt_email)" ACME_EMAIL
  read -rp "$(t prompt_wg_port)" WG_PORT; WG_PORT=${WG_PORT:-51820}
  read -rp "$(t prompt_hy2_port)" HY2_PORT; HY2_PORT=${HY2_PORT:-443}
  echo
  echo "$(t server_b_intro)"
  read -rp "$(t prompt_has_b)" HAS_B
  B_NEEDS_INSTALL=0
  if [[ "${HAS_B,,}" == "n" ]]; then
    B_NEEDS_INSTALL=1
    echo
    echo "$(t gen_b_secrets_notice1)"
    echo "$(t gen_b_secrets_notice2)"
    read -rp "$(t prompt_b_domain_new)" B_DOMAIN
    read -rp "$(t prompt_b_port_new)" B_PORT; B_PORT=${B_PORT:-443}
    B_PASS=$(openssl rand -base64 18 | tr -d '/+=')
    B_VLESS_UUID=$(sing-box generate uuid)
    B_RKEYS=$(sing-box generate reality-keypair)
    B_REALITY_PRIV=$(echo "$B_RKEYS" | grep '^PrivateKey:' | awk '{print $2}')
    B_REALITY_PUB=$(echo "$B_RKEYS" | grep '^PublicKey:' | awk '{print $2}')
    B_REALITY_SID=$(sing-box generate rand 8 --hex)
    echo
    echo "$(t b_reality_site_notice)"
    read -rp "$(t prompt_b_vless_dest_new)" B_VLESS_DEST
    B_VLESS_SNI="$B_VLESS_DEST"
  else
    read -rp "$(t prompt_b_domain_existing)" B_DOMAIN
    read -rp "$(t prompt_b_port_existing)" B_PORT; B_PORT=${B_PORT:-443}
    B_PASS=""; B_VLESS_UUID=""; B_REALITY_PUB=""; B_REALITY_SID=""; B_VLESS_DEST=""; B_VLESS_SNI=""
    while true; do
      read -rp "$(t prompt_b_has_hy2)" HAS_B_HY2
      if [[ "${HAS_B_HY2,,}" != "n" ]]; then
        read -rp "$(t prompt_b_pass)" B_PASS
      fi
      read -rp "$(t prompt_b_has_vless)" HAS_B_VLESS
      if [[ "${HAS_B_VLESS,,}" == "y" ]]; then
        read -rp "$(t prompt_b_vless_uuid)" B_VLESS_UUID
        read -rp "$(t prompt_b_reality_pub)" B_REALITY_PUB
        read -rp "$(t prompt_b_reality_sid)" B_REALITY_SID
        read -rp "$(t prompt_b_vless_dest_existing)" B_VLESS_DEST
        B_VLESS_SNI="$B_VLESS_DEST"
      fi
      if [[ -n "$B_PASS" || -n "$B_VLESS_UUID" ]]; then
        break
      fi
      echo "$(t err_no_transport_selected)"
    done
  fi
  echo
  read -rp "$(t prompt_profile_port)" PROFILE_PORT; PROFILE_PORT=${PROFILE_PORT:-8443}
  echo
  echo "$(t reality_a_notice1)"
  echo "$(t reality_a_notice2)"
  read -rp "$(t prompt_vless_dest_a)" VLESS_DEST
  VLESS_SNI="$VLESS_DEST"

  RU_RULES_ENABLED=0
  RULESET_BASE_URL=""
  while true; do
    echo
    echo "$(t ru_rules_question)"
    echo "$(t ru_rules_disabled_option)"
    echo "$(t ru_rules_enabled_option)"
    read -rp "$(t prompt_choice_12_default1)" RU_RULES_CHOICE
    case "${RU_RULES_CHOICE:-1}" in
      1) break ;;
      2) RU_RULES_ENABLED=1; break ;;
      *) echo "$(t invalid)" ;;
    esac
  done

  if [[ "$RU_RULES_ENABLED" == "1" ]]; then
    while true; do
      echo
      echo "$(t ruleset_intro)"
      read -rp "$(printf "$(t prompt_ruleset_base)" "$RULESET_DEFAULT_BASE")" RULESET_BASE_INPUT
      RULESET_BASE_INPUT=${RULESET_BASE_INPUT:-$RULESET_DEFAULT_BASE}
      if ! RULESET_BASE_URL=$(normalize_ruleset_base "$RULESET_BASE_INPUT"); then
        echo "$(t ruleset_base_invalid)"
        continue
      fi
      echo "$(t ruleset_checking_existing)"
      if validate_ruleset_storage "$RULESET_BASE_URL"; then
        echo "$(t ruleset_existing_ready)"
        break
      fi
      echo "$(t ruleset_existing_retry)"
    done
  fi

  cat > "$CONFIG_ENV" <<EOF
A_IP="$A_IP"
A_DOMAIN="$A_DOMAIN"
ACME_EMAIL="$ACME_EMAIL"
WG_PORT=$WG_PORT
WG_NET="10.10.0"
HY2_PORT=$HY2_PORT
B_DOMAIN="$B_DOMAIN"
B_PORT=$B_PORT
B_PASS="$B_PASS"
B_VLESS_UUID="$B_VLESS_UUID"
B_REALITY_PRIV="${B_REALITY_PRIV:-}"
B_REALITY_PUB="$B_REALITY_PUB"
B_REALITY_SID="$B_REALITY_SID"
B_VLESS_DEST="$B_VLESS_DEST"
B_VLESS_SNI="$B_VLESS_SNI"
PROFILE_HOST="$A_DOMAIN"
PROFILE_PORT=$PROFILE_PORT
VLESS_PORT=$HY2_PORT
VLESS_DEST="$VLESS_DEST"
VLESS_SNI="$VLESS_SNI"
AVAILABLE_PROXY_TYPES="hy2 vless"
WARP_ENABLED=0
WARP_PORT=40000
WARP_TAG="WARP"
RU_RULES_ENABLED=$RU_RULES_ENABLED
RULESET_BASE_URL="$RULESET_BASE_URL"
B_NEEDS_INSTALL=$B_NEEDS_INSTALL
LANG_CODE="$LANG_CODE"
EOF
  chmod 600 "$CONFIG_ENV"
  printf 'TO_B_DEFAULT="direct"\n' > /etc/sing-box/transport.env
  printf "$(t config_written)\n" "$CONFIG_ENV"
  echo "$(t initial_b_route_direct)"
fi

for WARP_MIGRATION in \
  'WARP_RU_ENABLED:WARP_ENABLED' \
  'WARP_RU_PORT:WARP_PORT' \
  'WARP_RU_TAG:WARP_TAG'
do
  OLD_KEY=${WARP_MIGRATION%%:*}
  NEW_KEY=${WARP_MIGRATION#*:}
  if ! grep -q "^${NEW_KEY}=" "$CONFIG_ENV" && grep -q "^${OLD_KEY}=" "$CONFIG_ENV"; then
    sed -i "s/^${OLD_KEY}=/${NEW_KEY}=/" "$CONFIG_ENV"
  else
    sed -i "/^${OLD_KEY}=/d" "$CONFIG_ENV"
  fi
done

if ! grep -q '^RU_RULES_ENABLED=' "$CONFIG_ENV"; then
  if existing_ru_rules_enabled; then
    echo 'RU_RULES_ENABLED=1' >> "$CONFIG_ENV"
  else
    echo 'RU_RULES_ENABLED=0' >> "$CONFIG_ENV"
  fi
fi
if ! grep -q '^RULESET_BASE_URL=' "$CONFIG_ENV"; then
  EXISTING_RU_RULES=$(set +u; source "$CONFIG_ENV"; printf '%s' "${RU_RULES_ENABLED:-0}")
  if [[ "$EXISTING_RU_RULES" == "1" ]]; then
    EXISTING_RULESET_BASE=$(ruleset_base_from_routing /opt/vpn/client-routing.json 2>/dev/null || \
      ruleset_base_from_routing /opt/vpn/server-routing.json 2>/dev/null || \
      printf '%s' "$RULESET_DEFAULT_BASE")
  else
    EXISTING_RULESET_BASE=""
  fi
  printf 'RULESET_BASE_URL="%s"\n' "$EXISTING_RULESET_BASE" >> "$CONFIG_ENV"
fi
sed -i \
  -e '/^RULESET_STORAGE_LOCAL=/d' \
  -e '/^FILES_DOMAIN=/d' \
  -e '/^FILES_INTERNAL_PORT=/d' \
  "$CONFIG_ENV"

complete_install_step 6
else
  printf "$(t step_skipped)\n" 6
fi

source "$CONFIG_ENV"

if [[ "${B_NEEDS_INSTALL:-0}" == "1" ]]; then
  if [[ -n "${B_INSTALL_PATH:-}" && -n "${B_BINARY_PATH:-}" && -f "$B_INSTALL_PATH" && -f "$B_BINARY_PATH" ]]; then
    printf "$(t generated_b_reused)\n" "$B_INSTALL_PATH"
  else
  echo
  echo "$(t generating_install_b)"
  mkdir -p /opt/vpn/profiles
  B_TOKEN=$(openssl rand -hex 8)
  B_INSTALL_PATH="/opt/vpn/profiles/install-b-${B_TOKEN}.sh"
  B_BINARY_PATH="/opt/vpn/profiles/sing-box-b-${B_TOKEN}"
  install -m 0755 "$SING_BOX_BIN" "$B_BINARY_PATH"

  cat > "$B_INSTALL_PATH" <<BEOF
#!/usr/bin/env bash
set -euo pipefail

if [[ \$EUID -ne 0 ]]; then
  echo "$(t b_must_run_as_root)"
  exit 1
fi

echo "$(t b_installing)"
apt-get update -qq
NEEDRESTART_MODE=l DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl gnupg dnsutils

B_DETECTED_IP=\$(curl -4 -fsS --max-time 10 https://ifconfig.me || hostname -I | awk '{print \$1}')
B_RESOLVED_IP=\$(dig +short "${B_DOMAIN}" @1.1.1.1 | tail -1)
if [[ -z "\$B_DETECTED_IP" || "\$B_RESOLVED_IP" != "\$B_DETECTED_IP" ]]; then
  printf "$(t b_dns_mismatch)\n" "${B_DOMAIN}" "\${B_RESOLVED_IP:-not resolved}" "\${B_DETECTED_IP:-unknown}"
  exit 1
fi

mkdir -p /etc/apt/keyrings
curl -fsSL https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc
chmod a+r /etc/apt/keyrings/sagernet.asc
cat > /etc/apt/sources.list.d/sagernet.sources <<'REPO'
Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
REPO
apt-get update -qq
NEEDRESTART_MODE=l DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sing-box

mkdir -p /usr/local/lib/sing-box-panel /usr/local/bin
curl -fsSL "https://${A_DOMAIN}:${PROFILE_PORT:-8443}/$(basename "$B_BINARY_PATH")" -o /usr/local/lib/sing-box-panel/sing-box.new
echo "${SING_BOX_SHA256}  /usr/local/lib/sing-box-panel/sing-box.new" | sha256sum -c -
install -m 0755 /usr/local/lib/sing-box-panel/sing-box.new /usr/local/lib/sing-box-panel/sing-box
rm -f /usr/local/lib/sing-box-panel/sing-box.new
ln -sfn /usr/local/lib/sing-box-panel/sing-box /usr/local/bin/sing-box
[[ "\$(sha256sum /usr/local/lib/sing-box-panel/sing-box | awk '{print \$1}')" == "${SING_BOX_SHA256}" ]]
apt-mark hold sing-box >/dev/null

mkdir -p /etc/systemd/system/sing-box.service.d
cat > /etc/systemd/system/sing-box.service.d/10-panel-binary.conf <<'OVERRIDE'
[Service]
ExecStart=
ExecStart=/usr/local/lib/sing-box-panel/sing-box -D /var/lib/sing-box -C /etc/sing-box run
OVERRIDE

mkdir -p /etc/sing-box

cat > /etc/sing-box/config.json <<CFGEOF
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [
    {
      "type": "hysteria2", "tag": "hy2-in", "listen": "::", "listen_port": ${B_PORT},
      "users": [ { "password": "${B_PASS}" } ],
      "tls": { "enabled": true, "server_name": "${B_DOMAIN}", "alpn": ["h3"],
               "acme": { "domain": ["${B_DOMAIN}"], "email": "${ACME_EMAIL}" } }
    },
    {
      "type": "vless", "tag": "vless-in", "listen": "::", "listen_port": ${B_PORT},
      "users": [ { "uuid": "${B_VLESS_UUID}", "flow": "xtls-rprx-vision" } ],
      "tls": { "enabled": true, "server_name": "${B_VLESS_SNI}",
        "reality": { "enabled": true,
          "handshake": { "server": "${B_VLESS_DEST}", "server_port": 443 },
          "private_key": "${B_REALITY_PRIV}",
          "short_id": ["${B_REALITY_SID}"] } }
    }
  ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ],
  "route": { "rules": [ { "action": "sniff" } ], "final": "direct" }
}
CFGEOF

/usr/local/lib/sing-box-panel/sing-box check -c /etc/sing-box/config.json
systemctl daemon-reload
systemctl enable sing-box
if ! systemctl restart sing-box; then
  echo "$(t b_service_failed)"
  journalctl -u sing-box -n 40 --no-pager || true
  exit 1
fi
for _ in \$(seq 1 ${SERVICE_WAIT_SECONDS}); do
  systemctl is-active --quiet sing-box && break
  sleep 1
done
if ! systemctl is-active --quiet sing-box; then
  echo "$(t b_service_failed)"
  journalctl -u sing-box -n 40 --no-pager || true
  exit 1
fi

echo
echo "=================================================="
echo "$(t b_configured)"
printf "$(t b_domain_label)\n" "${B_DOMAIN}"
printf "$(t b_port_label)\n" "${B_PORT}"
printf "$(t singbox_runtime_label)\n" "\$(/usr/local/lib/sing-box-panel/sing-box version | sed -n '1s/^sing-box version //p')" "${SING_BOX_REV}"
echo "=================================================="
echo
printf "$(t b_dns_reminder)\n" "${B_DOMAIN}" "${B_PORT}"
echo "$(t b_verify_from_a_reminder1)"
echo "$(t b_verify_from_a_reminder2)"
BEOF

  chmod +x "$B_INSTALL_PATH"

  sed -i \
    -e '/^B_INSTALL_PATH=/d' \
    -e '/^B_BINARY_PATH=/d' \
    "$CONFIG_ENV"
  printf 'B_INSTALL_PATH="%s"\nB_BINARY_PATH="%s"\n' "$B_INSTALL_PATH" "$B_BINARY_PATH" >> "$CONFIG_ENV"

  printf "$(t install_b_ready)\n" "$B_DOMAIN"
  echo
  echo "  curl -fsSL https://${A_DOMAIN}:${PROFILE_PORT:-8443}/$(basename "$B_INSTALL_PATH") | sudo bash"
  echo
  echo "$(t link_will_work_after)"
  fi
fi

if (( INSTALL_STEP < 7 )); then
  step "$(t step7)"
  RESOLVED=$(dig +short "$A_DOMAIN" @1.1.1.1 2>/dev/null | tail -1)
  if [[ "$RESOLVED" != "$A_IP" ]]; then
    printf "$(t dns_warning)\n" "$A_DOMAIN" "$RESOLVED" "$A_IP"
    echo "$(t dns_warning_hint)"
    read -rp "$(t prompt_continue_anyway)" cont
    [[ "${cont,,}" == "y" ]] || { echo "$(t aborted)"; exit 1; }
  fi
  complete_install_step 7
else
  printf "$(t step_skipped)\n" 7
fi

if (( INSTALL_STEP < 8 )); then
step "$(t step8)"
mkdir -p /opt/vpn/profiles /opt/vpn/traffic/daily /etc/sing-box/clients
install -d -m 0700 /opt/vpn/clients

cp "$SCRIPT_DIR/templates/template.json" /opt/vpn/template.json
cp "$SCRIPT_DIR/templates/template-legacy.json" /opt/vpn/template-legacy.json
cp "$SCRIPT_DIR/templates/stats.proto" /opt/vpn/stats.proto
cp "$SCRIPT_DIR/templates/server-template.json" /opt/vpn/server-template.json
render_routing_template "$SCRIPT_DIR/templates/server-routing.json" /opt/vpn/server-routing.json \
  "${RU_RULES_ENABLED:-0}" "${RULESET_BASE_URL:-}" "DIRECT_RULES"
render_routing_template "$SCRIPT_DIR/templates/client-routing.json" /opt/vpn/client-routing.json \
  "${RU_RULES_ENABLED:-0}" "${RULESET_BASE_URL:-}" "direct"
chmod 0644 /opt/vpn/server-routing.json /opt/vpn/client-routing.json

# удобные симлинки для навигации из /opt/vpn (не меняют реальные пути в коде)
ln -sf /etc/sing-box /opt/vpn/sing-box
ln -sf /etc/nginx /opt/vpn/nginx
cp "$SCRIPT_DIR/vpn-setup.sh" /root/vpn-setup.sh
cp "$SCRIPT_DIR/i18n.sh" /root/i18n.sh
cp "$SCRIPT_DIR/i18n.sh" /opt/vpn/i18n.sh
chmod 644 /opt/vpn/i18n.sh
chmod +x /root/vpn-setup.sh

if [[ -n "${WARP_INSTALL_PATH:-}" && "$WARP_INSTALL_PATH" == /opt/vpn/profiles/install-warp-*.sh && -f "$WARP_INSTALL_PATH" ]]; then
  printf "$(t generated_warp_reused)\n" "$WARP_INSTALL_PATH"
else
  WARP_TOKEN=$(openssl rand -hex 8)
  WARP_INSTALL_PATH="/opt/vpn/profiles/install-warp-${WARP_TOKEN}.sh"
  cp "$SCRIPT_DIR/install-warp.sh" "$WARP_INSTALL_PATH"
  chmod 755 "$WARP_INSTALL_PATH"
  sed -i '/^WARP_INSTALL_PATH=/d' "$CONFIG_ENV"
  printf 'WARP_INSTALL_PATH="%s"\n' "$WARP_INSTALL_PATH" >> "$CONFIG_ENV"
fi

cat > /root/sb-panel <<EOF
#!/usr/bin/env bash
VPN_CONFIG=$CONFIG_ENV exec /root/vpn-setup.sh "\$@"
EOF
chmod +x /root/sb-panel

echo "$(t building_initial_config)"
if ! VPN_CONFIG="$CONFIG_ENV" /root/vpn-setup.sh --rebuild-config; then
  echo "$(t singbox_start_failed)"
  journalctl -u sing-box -n 40 --no-pager || true
  exit 1
fi
for _ in $(seq 1 "$SERVICE_WAIT_SECONDS"); do
  systemctl is-active --quiet sing-box && break
  sleep 1
done
if ! systemctl is-active --quiet sing-box; then
  echo "$(t singbox_start_failed)"
  journalctl -u sing-box -n 40 --no-pager || true
  exit 1
fi

if [[ "${B_NEEDS_INSTALL:-0}" != "1" ]]; then
  echo
  if ! VPN_CONFIG="$CONFIG_ENV" /root/vpn-setup.sh --test-b-transports; then
    echo "$(t existing_b_transport_warning)"
  fi
else
  echo "$(t generated_b_transport_pending)"
fi
complete_install_step 8
else
  printf "$(t step_skipped)\n" 8
fi

if (( INSTALL_STEP < 9 )); then
step "$(t step9)"
cat > /etc/nginx/conf.d/singbox-ua.conf <<'NGINX'
map $http_user_agent $sb_variant {
    default "modern";
    "~sing-box[ /](0|1)\.([0-9]|1[01])(\.|\))"  "legacy";
}
map $request_uri $profile_key {
    ~^/(?<k>[A-Za-z0-9_]+)\.json  $k;
    default "-";
}
log_format profile_access
    '$time_iso8601 | ip=$remote_addr | key=$profile_key | variant=$sb_variant | ua="$http_user_agent"';
NGINX

CRT="/var/lib/sing-box/.local/share/certmagic/certificates/acme-v02.api.letsencrypt.org-directory/${A_DOMAIN}/${A_DOMAIN}.crt"
KEY="/var/lib/sing-box/.local/share/certmagic/certificates/acme-v02.api.letsencrypt.org-directory/${A_DOMAIN}/${A_DOMAIN}.key"

cat > /etc/nginx/sites-available/profiles <<NGINX2
server {
    listen ${PROFILE_PORT} ssl;
    listen [::]:${PROFILE_PORT} ssl;
    server_name ${A_DOMAIN};

    ssl_certificate     ${CRT};
    ssl_certificate_key ${KEY};
    ssl_protocols TLSv1.2 TLSv1.3;

    root /opt/vpn/profiles;
    autoindex off;
    default_type application/json;
    access_log /var/log/nginx/profile_access.log profile_access;

    location ~ ^/([A-Za-z0-9_]+)\.json\$ {
        set \$base \$1;
        rewrite ^ /\$base-\$sb_variant.json last;
    }
    location ~ ^/[A-Za-z0-9_]+-(legacy|modern)\.json\$ {
        try_files \$uri =404;
        add_header Cache-Control "no-store";
    }
    location ~ ^/install-(b|warp)-[a-f0-9]+\.sh$ {
        try_files \$uri =404;
        default_type text/x-shellscript;
        add_header Cache-Control "no-store";
    }
    location ~ ^/sing-box-b-[a-f0-9]+$ {
        try_files \$uri =404;
        default_type application/octet-stream;
        add_header Cache-Control "no-store";
    }
    location / { return 404; }
}
NGINX2

[[ -f /etc/nginx/sites-enabled/default ]] && rm -f /etc/nginx/sites-enabled/default
[[ -L /etc/nginx/sites-enabled/profiles ]] || ln -s /etc/nginx/sites-available/profiles /etc/nginx/sites-enabled/profiles

cat > /etc/systemd/system/nginx-cert-reload.path <<PATHUNIT
[Unit]
Description=Watch sing-box cert for nginx reload
[Path]
PathModified=${CRT}
[Install]
WantedBy=multi-user.target
PATHUNIT
cat > /etc/systemd/system/nginx-cert-reload.service <<SVCUNIT
[Unit]
Description=Reload nginx after cert change
[Service]
Type=oneshot
ExecStart=/usr/sbin/nginx -s reload
SVCUNIT
systemctl daemon-reload
systemctl enable --now nginx-cert-reload.path

echo "$(t waiting_for_certificate)"
for _ in $(seq 1 "$CERT_WAIT_SECONDS"); do
  [[ -s "$CRT" && -s "$KEY" ]] && break
  sleep 1
done
if [[ ! -s "$CRT" || ! -s "$KEY" ]]; then
  echo "$(t certificate_wait_failed)"
  journalctl -u sing-box -n 40 --no-pager || true
  exit 1
fi
nginx -t
if systemctl is-active --quiet nginx; then
  systemctl reload nginx
else
  systemctl start nginx
fi
for _ in $(seq 1 "$SERVICE_WAIT_SECONDS"); do
  systemctl is-active --quiet nginx && break
  sleep 1
done
if ! systemctl is-active --quiet nginx; then
  echo "$(t nginx_start_failed)"
  journalctl -u nginx -n 40 --no-pager || true
  exit 1
fi

if [[ -n "${B_INSTALL_PATH:-}" ]]; then
  B_INSTALL_CHECK=$(mktemp)
  if ! curl -fsS --noproxy '*' --resolve "${A_DOMAIN}:${PROFILE_PORT}:127.0.0.1" \
      "https://${A_DOMAIN}:${PROFILE_PORT}/$(basename "$B_INSTALL_PATH")" -o "$B_INSTALL_CHECK" || \
      ! cmp -s "$B_INSTALL_PATH" "$B_INSTALL_CHECK"; then
    rm -f "$B_INSTALL_CHECK"
    echo "$(t installer_publish_check_failed)"
    exit 1
  fi
  rm -f "$B_INSTALL_CHECK"
  echo "$(t installer_publish_ready)"
  B_BINARY_CHECK=$(mktemp)
  if ! curl -fsS --noproxy '*' --resolve "${A_DOMAIN}:${PROFILE_PORT}:127.0.0.1" \
      "https://${A_DOMAIN}:${PROFILE_PORT}/$(basename "$B_BINARY_PATH")" -o "$B_BINARY_CHECK" || \
      [[ "$(sha256sum "$B_BINARY_CHECK" | awk '{print $1}')" != "$SING_BOX_SHA256" ]]; then
    rm -f "$B_BINARY_CHECK"
    echo "$(t binary_publish_check_failed)"
    exit 1
  fi
  rm -f "$B_BINARY_CHECK"
  echo "$(t binary_publish_ready)"
fi

(crontab -l 2>/dev/null | grep -v 'cron-traffic' || true; echo "*/15 * * * * /usr/bin/bash /root/vpn-setup.sh --cron-traffic >/dev/null 2>&1") | crontab -

complete_install_step 9
else
  printf "$(t step_skipped)\n" 9
fi

rm -f "$MARKER"
rm -f "$INSTALL_STATE_FILE"
date > "$DONE_MARKER"
trap - ERR

step "$(t done_step)"
SUMMARY_FILE=/root/install-summary.txt
{
  echo
  echo "$(t final_notice)"
  printf "$(t singbox_runtime_label)\n" "$SING_BOX_VERSION" "$SING_BOX_REV"
  [[ "${B_NEEDS_INSTALL:-0}" == "1" ]] && echo "$(t singbox_b_same_binary)"
  echo
  echo "$(t final_firewall_header)"
  echo "$(t final_port_80)"
  printf "$(t final_port_wg)\n" "${WG_PORT}"
  printf "$(t final_port_hy2)\n" "${HY2_PORT}"
  printf "$(t final_port_profile)\n" "${PROFILE_PORT}"
  if [[ -n "${B_INSTALL_PATH:-}" ]]; then
    echo
    echo "=================================================="
    echo "$(t final_b_step_header)"
    echo "=================================================="
    echo
    echo "  curl -fsSL https://${A_DOMAIN}:${PROFILE_PORT}/$(basename "$B_INSTALL_PATH") | sudo bash"
    echo
    printf "$(t final_b_reminder_run1)\n" "$B_DOMAIN"
    printf "$(t final_b_reminder_run2)\n" "$B_PORT"
    echo
    echo "$(t final_b_verify_header)"
    echo "$(t final_b_verify_cmd1)"
    echo "$(t final_b_verify_cmd2)"
    echo
    echo "$(t final_step4_header)"
  else
    echo
    echo "$(t final_step2_header)"
  fi

  printf "$(t final_step2_body1)\n" "${PROFILE_PORT}"
  echo "$(t final_step2_body2)"
  echo "$(t final_step2_cmd1)"
  echo "$(t final_step2_cmd2)"
  echo
  echo "$(t final_step2_check1)"
  echo "$(t final_step2_check2)"
  echo
  echo "$(t final_management)"
  printf "$(t final_config_label)\n" "$CONFIG_ENV"

  echo
  echo "=================================================="
  echo "$(t final_warp_header)"
  echo "=================================================="
  echo
  echo "  curl -fsSL https://${A_DOMAIN}:${PROFILE_PORT}/$(basename "$WARP_INSTALL_PATH") -o /tmp/install-warp.sh"
  echo "  sudo bash /tmp/install-warp.sh"
  echo
  echo "$(t final_warp_note)"
} | tee "$SUMMARY_FILE"

echo
printf "$(t summary_saved)\n" "$SUMMARY_FILE"
