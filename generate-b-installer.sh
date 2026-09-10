#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/i18n.sh"

REQUESTED_LANG="${SBP_LANG:-en}"
LANG_CODE="$REQUESTED_LANG"
CONFIG_ENV="${1:-/etc/sing-box/vpn-panel.env}"
MODE="${2:-reuse}"
SING_BOX_BIN=/usr/local/lib/sing-box-panel/sing-box
SING_BOX_REV_FILE=/usr/lib/sing-box-panel/sing-box-revision
SERVICE_WAIT_SECONDS=30

if [[ $EUID -ne 0 ]]; then
  echo "$(t must_run_as_root)" >&2
  exit 1
fi
if [[ ! -f "$CONFIG_ENV" ]]; then
  printf "$(t b_generator_config_missing)\n" "$CONFIG_ENV" >&2
  exit 1
fi
if [[ ! -x "$SING_BOX_BIN" ]]; then
  printf "$(t b_generator_binary_missing)\n" "$SING_BOX_BIN" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_ENV"
# The installation config stores its original language; an explicit language
# chosen for this invocation must take precedence.
LANG_CODE="$REQUESTED_LANG"

GENERATED_NEW_B=0
if [[ "$MODE" == "new" ]]; then
  echo
  echo "$(t new_b_intro)"
  read -rp "$(t prompt_b_domain_new)" NEW_B_DOMAIN
  if [[ -z "$NEW_B_DOMAIN" ]]; then
    echo "$(t b_domain_required)" >&2
    exit 1
  fi
  read -rp "$(t prompt_b_port_new)" NEW_B_PORT
  NEW_B_PORT=${NEW_B_PORT:-443}
  if [[ ! "$NEW_B_PORT" =~ ^[0-9]+$ ]] || (( NEW_B_PORT < 1 || NEW_B_PORT > 65535 )); then
    echo "$(t b_port_invalid)" >&2
    exit 1
  fi
  read -rp "$(t prompt_b_vless_dest_new)" NEW_B_VLESS_DEST
  if [[ -z "$NEW_B_VLESS_DEST" ]]; then
    echo "$(t b_vless_dest_required)" >&2
    exit 1
  fi

  B_DOMAIN="$NEW_B_DOMAIN"
  B_PORT="$NEW_B_PORT"
  B_PASS=$(openssl rand -base64 18 | tr -d '/+=')
  B_VLESS_UUID=$("$SING_BOX_BIN" generate uuid)
  B_RKEYS=$("$SING_BOX_BIN" generate reality-keypair)
  B_REALITY_PRIV=$(printf '%s\n' "$B_RKEYS" | awk '/^PrivateKey:/ {print $2}')
  B_REALITY_PUB=$(printf '%s\n' "$B_RKEYS" | awk '/^PublicKey:/ {print $2}')
  B_REALITY_SID=$("$SING_BOX_BIN" generate rand 8 --hex)
  B_VLESS_DEST="$NEW_B_VLESS_DEST"
  B_VLESS_SNI="$NEW_B_VLESS_DEST"
  B_INSTALL_PATH=""
  B_BINARY_PATH=""
  GENERATED_NEW_B=1
fi

required=(A_DOMAIN B_DOMAIN B_PORT B_PASS ACME_EMAIL)
missing=()
for name in "${required[@]}"; do
  [[ -n "${!name:-}" ]] || missing+=("$name")
done
if (( ${#missing[@]} )); then
  printf "$(t b_generator_params_missing)\n" "${missing[*]}" >&2
  exit 1
fi

# Older A installations may have been configured with Hysteria2 as their only
# A -> B transport. Reproduce that setup as-is. If VLESS data exists, require
# the complete private endpoint data before publishing a B installer.
vless_vars=(B_VLESS_UUID B_VLESS_SNI B_VLESS_DEST B_REALITY_PRIV B_REALITY_SID)
vless_present=0
vless_missing=()
for name in "${vless_vars[@]}"; do
  if [[ -n "${!name:-}" ]]; then
    ((vless_present += 1))
  else
    vless_missing+=("$name")
  fi
done
if (( vless_present > 0 && ${#vless_missing[@]} > 0 )); then
  printf "$(t b_generator_params_missing)\n" "${vless_missing[*]}" >&2
  exit 1
fi

B_VLESS_INBOUND=""
B_PORT_LABEL_KEY=b_port_hy2_label
if (( vless_present == ${#vless_vars[@]} )); then
  B_PORT_LABEL_KEY=b_port_label
  B_VLESS_INBOUND=$(cat <<VLESS
,
    {
      "type": "vless", "tag": "vless-in", "listen": "::", "listen_port": ${B_PORT},
      "users": [ { "uuid": "${B_VLESS_UUID}", "flow": "xtls-rprx-vision" } ],
      "tls": { "enabled": true, "server_name": "${B_VLESS_SNI}",
        "reality": { "enabled": true,
          "handshake": { "server": "${B_VLESS_DEST}", "server_port": 443 },
          "private_key": "${B_REALITY_PRIV}",
          "short_id": ["${B_REALITY_SID}"] } }
    }
VLESS
)
fi

if [[ "$MODE" == "new" ]]; then
  B_POST_INSTALL_TEXT="$(t b_standalone_ready)"
else
  B_POST_INSTALL_TEXT="$(t b_verify_from_a_reminder1)
$(t b_verify_from_a_reminder2)"
fi

PROFILE_PORT="${PROFILE_PORT:-8443}"
SING_BOX_SHA256=$(sha256sum "$SING_BOX_BIN" | awk '{print $1}')
SING_BOX_REV=$(cat "$SING_BOX_REV_FILE" 2>/dev/null || printf 'unknown')

if [[ "$GENERATED_NEW_B" == "0" && -n "${B_INSTALL_PATH:-}" && -n "${B_BINARY_PATH:-}" && -f "$B_INSTALL_PATH" && -f "$B_BINARY_PATH" ]]; then
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
curl -fsSL "https://${A_DOMAIN}:${PROFILE_PORT}/$(basename "$B_BINARY_PATH")" -o /usr/local/lib/sing-box-panel/sing-box.new
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
    }${B_VLESS_INBOUND}
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
printf "$(t "$B_PORT_LABEL_KEY")\n" "${B_PORT}"
printf "$(t singbox_runtime_label)\n" "\$(/usr/local/lib/sing-box-panel/sing-box version | sed -n '1s/^sing-box version //p')" "${SING_BOX_REV}"
echo "=================================================="
echo
printf "$(t b_dns_reminder)\n" "${B_DOMAIN}" "${B_PORT}"
printf '%s\n' "${B_POST_INSTALL_TEXT}"
BEOF

  chmod 0755 "$B_INSTALL_PATH"
  if [[ "$GENERATED_NEW_B" == "0" ]]; then
    sed -i \
      -e '/^B_INSTALL_PATH=/d' \
      -e '/^B_BINARY_PATH=/d' \
      "$CONFIG_ENV"
    printf 'B_INSTALL_PATH="%s"\nB_BINARY_PATH="%s"\n' "$B_INSTALL_PATH" "$B_BINARY_PATH" >> "$CONFIG_ENV"
  fi
fi

printf "$(t install_b_ready)\n" "$B_DOMAIN"
echo
echo "  curl -fsSL https://${A_DOMAIN}:${PROFILE_PORT}/$(basename "$B_INSTALL_PATH") | sudo bash"
echo
if [[ "$MODE" == "fresh" ]]; then
  echo "$(t link_will_work_after)"
fi
if [[ "$GENERATED_NEW_B" == "1" ]]; then
  echo "$(t new_b_a_unchanged)"
fi
