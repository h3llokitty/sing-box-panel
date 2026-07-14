#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/i18n.sh"

echo "Select language / Выберите язык:"
echo "  1) English (default)"
echo "  2) Русский"
read -rp "[1-2, Enter=1]: " LANG_CHOICE
case "$LANG_CHOICE" in
  2) LANG_CODE="ru" ;;
  *) LANG_CODE="en" ;;
esac

if [[ $EUID -ne 0 ]]; then
  echo "$(t must_run_as_root)"
  exit 1
fi
MARKER=/etc/sing-box/.install-in-progress
DONE_MARKER=/etc/sing-box/.install-done

step() { echo; echo "=================================================="; echo "$1"; echo "=================================================="; }

cleanup_failed_install() {
  echo
  echo "=================================================="
  echo "$(t rollback_header)"
  echo "=================================================="
  systemctl stop sing-box nginx-cert-reload.path 2>/dev/null || true
  systemctl disable sing-box nginx-cert-reload.path 2>/dev/null || true
  rm -rf /etc/sing-box /opt/vpn /root/clients
  rm -f /root/sb-panel /root/vpn-setup.sh
  rm -f /etc/nginx/sites-enabled/profiles /etc/nginx/sites-available/profiles
  rm -f /etc/nginx/conf.d/singbox-ua.conf
  rm -f /etc/systemd/system/sing-box.service
  rm -f /etc/systemd/system/nginx-cert-reload.path /etc/systemd/system/nginx-cert-reload.service
  systemctl daemon-reload 2>/dev/null || true
  echo "$(t rollback_done)"
  echo "$(t rollback_binary_kept)"
}

if [[ -f "$DONE_MARKER" ]]; then
  printf "$(t done_marker_found)\n" "$(cat "$DONE_MARKER" 2>/dev/null)"
  echo "$(t done_marker_warning)"
  read -rp "$(t confirm_reinstall)" CONFIRM_REINSTALL
  if [[ "${CONFIRM_REINSTALL,,}" != "y" ]]; then
    echo "$(t reinstall_cancelled)"
    exit 0
  fi
  echo "$(t reinstall_proceeding)"
  cleanup_failed_install
  rm -f "$DONE_MARKER"
fi

if [[ -f "$MARKER" ]]; then
  echo "$(t resuming_incomplete_install)"
  cleanup_failed_install
fi

mkdir -p /etc/sing-box
touch "$MARKER"
trap 'if [[ -f "$MARKER" ]]; then cleanup_failed_install; fi' ERR

step "$(t step1)"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  curl git build-essential wireguard-tools nginx libnginx-mod-stream jq qrencode python3 openssl dnsutils

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

step "$(t step3)"
mkdir -p /root/build
if [[ ! -d /root/build/sing-box ]]; then
  git clone --depth 1 https://github.com/SagerNet/sing-box.git /root/build/sing-box
fi
cd /root/build/sing-box
go build -v -trimpath \
  -tags "with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_v2ray_api,with_grpc,with_tailscale" \
  -o /root/build/sing-box-new \
  ./cmd/sing-box

if [[ ! -x /root/build/sing-box-new ]]; then
  echo "$(t build_failed)"
  exit 1
fi
[[ -f /usr/bin/sing-box ]] && cp /usr/bin/sing-box /usr/bin/sing-box.bak 2>/dev/null || true
cp /root/build/sing-box-new /usr/bin/sing-box
chmod +x /usr/bin/sing-box
sing-box version | grep -i v2ray || { echo "$(t v2ray_api_missing)"; exit 1; }
echo "$(t build_success)"

step "$(t step4)"
if ! command -v grpcurl >/dev/null 2>&1; then
  GRPCURL_VER="1.9.3"
  curl -sL --max-time 60 "https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VER}/grpcurl_${GRPCURL_VER}_linux_amd64.deb" -o /tmp/grpcurl.deb
  dpkg -i /tmp/grpcurl.deb || apt-get install -f -y -qq
fi
grpcurl --version

step "$(t step5)"
cat > /etc/systemd/system/sing-box.service <<'UNIT'
[Unit]
Description=sing-box service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/sing-box -D /var/lib/sing-box -C /etc/sing-box run
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
mkdir -p /var/lib/sing-box
systemctl daemon-reload

step "$(t step6)"
CONFIG_ENV=/etc/sing-box/vpn-panel.env
mkdir -p /etc/sing-box

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
    read -rp "$(t prompt_b_pass)" B_PASS
    read -rp "$(t prompt_b_has_vless)" HAS_B_VLESS
    if [[ "${HAS_B_VLESS,,}" == "y" ]]; then
      read -rp "$(t prompt_b_vless_uuid)" B_VLESS_UUID
      read -rp "$(t prompt_b_reality_pub)" B_REALITY_PUB
      read -rp "$(t prompt_b_reality_sid)" B_REALITY_SID
      read -rp "$(t prompt_b_vless_dest_existing)" B_VLESS_DEST
      B_VLESS_SNI="$B_VLESS_DEST"
    else
      B_VLESS_UUID=""; B_REALITY_PUB=""; B_REALITY_SID=""; B_VLESS_DEST=""; B_VLESS_SNI=""
    fi
  fi
  echo
  read -rp "$(t prompt_profile_port)" PROFILE_PORT; PROFILE_PORT=${PROFILE_PORT:-8443}
  echo
  echo "$(t reality_a_notice1)"
  echo "$(t reality_a_notice2)"
  read -rp "$(t prompt_vless_dest_a)" VLESS_DEST
  VLESS_SNI="$VLESS_DEST"

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
LANG_CODE="$LANG_CODE"
EOF
  chmod 600 "$CONFIG_ENV"
  printf "$(t config_written)\n" "$CONFIG_ENV"
fi

if [[ "${B_NEEDS_INSTALL:-0}" == "1" ]]; then
  echo
  echo "$(t generating_install_b)"
  mkdir -p /opt/vpn/profiles
  B_TOKEN=$(openssl rand -hex 8)
  B_INSTALL_PATH="/opt/vpn/profiles/install-b-${B_TOKEN}.sh"

  cat > "$B_INSTALL_PATH" <<BEOF
#!/usr/bin/env bash
set -euo pipefail

if [[ \$EUID -ne 0 ]]; then
  echo "$(t b_must_run_as_root)"
  exit 1
fi

echo "$(t b_installing)"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl gnupg

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
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq sing-box

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

sing-box check -c /etc/sing-box/config.json
systemctl daemon-reload
systemctl enable --now sing-box
systemctl restart sing-box

echo
echo "=================================================="
echo "$(t b_configured)"
printf "$(t b_domain_label)\n" "${B_DOMAIN}"
printf "$(t b_port_label)\n" "${B_PORT}"
echo "=================================================="
echo
printf "$(t b_dns_reminder)\n" "${B_DOMAIN}" "${B_PORT}"
BEOF

  chmod +x "$B_INSTALL_PATH"

  printf "$(t install_b_ready)\n" "$B_DOMAIN"
  echo
  echo "  curl -sL https://${A_DOMAIN}:${PROFILE_PORT:-8443}/$(basename "$B_INSTALL_PATH") | sudo bash"
  echo
  echo "$(t link_will_work_after)"
fi

source "$CONFIG_ENV"

step "$(t step7)"
RESOLVED=$(dig +short "$A_DOMAIN" @1.1.1.1 2>/dev/null | tail -1)
if [[ "$RESOLVED" != "$A_IP" ]]; then
  printf "$(t dns_warning)\n" "$A_DOMAIN" "$RESOLVED" "$A_IP"
  echo "$(t dns_warning_hint)"
  read -rp "$(t prompt_continue_anyway)" cont
  [[ "${cont,,}" == "y" ]] || { echo "$(t aborted)"; exit 1; }
fi

step "$(t step8)"
mkdir -p /opt/vpn/profiles /opt/vpn/traffic/daily /root/clients /etc/sing-box/clients

cp "$SCRIPT_DIR/templates/template.json" /opt/vpn/template.json
cp "$SCRIPT_DIR/templates/template-legacy.json" /opt/vpn/template-legacy.json
cp "$SCRIPT_DIR/templates/stats.proto" /opt/vpn/stats.proto
cp "$SCRIPT_DIR/vpn-setup.sh" /root/vpn-setup.sh
cp "$SCRIPT_DIR/i18n.sh" /root/i18n.sh
chmod +x /root/vpn-setup.sh

cat > /root/sb-panel <<EOF
#!/usr/bin/env bash
VPN_CONFIG=$CONFIG_ENV exec /root/vpn-setup.sh "\$@"
EOF
chmod +x /root/sb-panel

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
    location ~ ^/install-b-[a-f0-9]+\.sh$ {
        try_files \$uri =404;
        default_type text/x-shellscript;
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

# nginx мог быть остановлен на предыдущих шагах (или его конфиг изменился впервые) —
# reload не поднимает остановленный сервис, поэтому явно restart
nginx -t && systemctl restart nginx

(crontab -l 2>/dev/null | grep -v 'cron-traffic' || true; echo "*/15 * * * * /usr/bin/bash /root/vpn-setup.sh --cron-traffic >/dev/null 2>&1") | crontab -

rm -f "$MARKER"
date > "$DONE_MARKER"
trap - ERR

step "$(t done_step)"
echo
echo "$(t final_notice)"
echo
echo "$(t final_firewall_header)"
echo "$(t final_port_80)"
printf "$(t final_port_wg)\n" "${WG_PORT}"
printf "$(t final_port_hy2)\n" "${HY2_PORT}"
printf "$(t final_port_profile)\n" "${PROFILE_PORT}"
echo
echo "$(t final_step2_header)"
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

if [[ -n "${B_INSTALL_PATH:-}" ]]; then
  echo
  echo "=================================================="
  echo "$(t final_b_reminder_header)"
  echo "=================================================="
  echo
  echo "  curl -sL https://${A_DOMAIN}:${PROFILE_PORT}/$(basename "$B_INSTALL_PATH") | sudo bash"
  echo
  printf "$(t final_b_reminder_run1)\n" "$B_DOMAIN"
  printf "$(t final_b_reminder_run2)\n" "$B_PORT"
fi
