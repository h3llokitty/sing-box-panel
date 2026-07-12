#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Запусти через sudo/root: sudo bash install.sh"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARKER=/etc/sing-box/.install-in-progress
DONE_MARKER=/etc/sing-box/.install-done

step() { echo; echo "=================================================="; echo "$1"; echo "=================================================="; }

cleanup_failed_install() {
  echo
  echo "=================================================="
  echo "УСТАНОВКА НЕ ЗАВЕРШИЛАСЬ (ошибка). Откатываю изменения..."
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
  echo "Откат завершён. Запусти install.sh ещё раз, чтобы попробовать заново."
  echo "(sing-box бинарник в /usr/bin/sing-box и Go оставлены — переустановка будет быстрее)"
}

if [[ -f "$DONE_MARKER" ]]; then
  echo "Обнаружена ЗАВЕРШЁННАЯ предыдущая установка (от $(cat "$DONE_MARKER" 2>/dev/null))."
  echo "Повторная установка удалит ВСЕХ существующих клиентов и все секреты сервера."
  read -rp "Точно хочешь переустановить с нуля? [y/N] " CONFIRM_REINSTALL
  if [[ "${CONFIRM_REINSTALL,,}" != "y" ]]; then
    echo "Отменено. Для управления клиентами используй: /root/sb-panel"
    exit 0
  fi
  echo "Ок, сношу текущую установку перед переустановкой..."
  cleanup_failed_install
  rm -f "$DONE_MARKER"
fi

if [[ -f "$MARKER" ]]; then
  echo "Обнаружена незавершённая предыдущая установка — выполняю откат перед повторной попыткой."
  cleanup_failed_install
fi

mkdir -p /etc/sing-box
touch "$MARKER"
trap 'if [[ -f "$MARKER" ]]; then cleanup_failed_install; fi' ERR

step "1/9 — базовые пакеты"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  curl git build-essential wireguard-tools nginx libnginx-mod-stream jq qrencode python3 openssl dnsutils

step "2/9 — установка Go (нужен для сборки sing-box)"
if ! command -v go >/dev/null 2>&1; then
  GOVER="go1.26.5"
  curl -sL --max-time 120 "https://go.dev/dl/${GOVER}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
  rm -rf /usr/local/go
  tar -C /usr/local -xzf /tmp/go.tar.gz
  echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' > /etc/profile.d/go.sh
fi
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
go version

step "3/9 — сборка sing-box из исходников (with_v2ray_api) — это займёт несколько минут"
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
  echo "Сборка sing-box не удалась, прерываю установку."
  exit 1
fi
[[ -f /usr/bin/sing-box ]] && cp /usr/bin/sing-box /usr/bin/sing-box.bak 2>/dev/null || true
cp /root/build/sing-box-new /usr/bin/sing-box
chmod +x /usr/bin/sing-box
sing-box version | grep -i v2ray || { echo "with_v2ray_api не найден в сборке!"; exit 1; }
echo "sing-box собран успешно."

step "4/9 — установка grpcurl"
if ! command -v grpcurl >/dev/null 2>&1; then
  GRPCURL_VER="1.9.3"
  curl -sL --max-time 60 "https://github.com/fullstorydev/grpcurl/releases/download/v${GRPCURL_VER}/grpcurl_${GRPCURL_VER}_linux_amd64.deb" -o /tmp/grpcurl.deb
  dpkg -i /tmp/grpcurl.deb || apt-get install -f -y -qq
fi
grpcurl --version

step "5/9 — systemd unit для sing-box"
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

step "6/9 — параметры сервера"
CONFIG_ENV=/etc/sing-box/vpn-panel.env
mkdir -p /etc/sing-box

if [[ -f "$CONFIG_ENV" ]]; then
  echo "Найден существующий $CONFIG_ENV."
  read -rp "Использовать его и пропустить вопросы? [Y/n] " reuse
  if [[ "${reuse,,}" == "n" ]]; then
    rm -f "$CONFIG_ENV"
  fi
fi

if [[ ! -f "$CONFIG_ENV" ]]; then
  echo "Заполни параметры нового сервера A:"
  DETECTED_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I 2>/dev/null | cut -d' ' -f1)
  read -rp "  IP этого сервера (A_IP) [${DETECTED_IP:-неизвестно}]: " A_IP
  A_IP=${A_IP:-$DETECTED_IP}
  if [[ -z "$A_IP" ]]; then
    echo "Не удалось определить IP автоматически, введи вручную."
    read -rp "  IP этого сервера (A_IP): " A_IP
  fi
  read -rp "  Домен этого сервера (A_DOMAIN, напр. h3.example.com): " A_DOMAIN
  read -rp "  Email для ACME/Let's Encrypt: " ACME_EMAIL
  read -rp "  WireGuard порт [51820]: " WG_PORT; WG_PORT=${WG_PORT:-51820}
  read -rp "  Hysteria2 порт [443]: " HY2_PORT; HY2_PORT=${HY2_PORT:-443}
  echo
  echo "Сервер B (выходной узел, к которому A подключается):"
  read -rp "  Уже есть настроенный сервер B? [Y/n] " HAS_B
  B_NEEDS_INSTALL=0
  if [[ "${HAS_B,,}" == "n" ]]; then
    B_NEEDS_INSTALL=1
    echo
    echo "Сгенерирую секреты для B — после установки A получишь ссылку на install-b.sh,"
    echo "которую нужно будет выполнить на самом сервере B."
    read -rp "  Домен, который будет у сервера B (B_DOMAIN): " B_DOMAIN
    read -rp "  Порт Hysteria2/VLESS на B [443]: " B_PORT; B_PORT=${B_PORT:-443}
    B_PASS=$(openssl rand -base64 18 | tr -d '/+=')
    B_VLESS_UUID=$(sing-box generate uuid)
    B_RKEYS=$(sing-box generate reality-keypair)
    B_REALITY_PRIV=$(echo "$B_RKEYS" | grep '^PrivateKey:' | awk '{print $2}')
    B_REALITY_PUB=$(echo "$B_RKEYS" | grep '^PublicKey:' | awk '{print $2}')
    B_REALITY_SID=$(sing-box generate rand 8 --hex)
    echo
    echo "Сайт для маскировки VLESS+Reality НА СЕРВЕРЕ B (может отличаться от A_DOMAIN):"
    read -rp "  Домен для Reality на B (B_VLESS_DEST): " B_VLESS_DEST
    B_VLESS_SNI="$B_VLESS_DEST"
  else
    read -rp "  Домен сервера B (B_DOMAIN): " B_DOMAIN
    read -rp "  Порт сервера B [443]: " B_PORT; B_PORT=${B_PORT:-443}
    read -rp "  Пароль Hysteria2 на сервере B (B_PASS): " B_PASS
    read -rp "  Есть ли на B также VLESS+Reality? [y/N] " HAS_B_VLESS
    if [[ "${HAS_B_VLESS,,}" == "y" ]]; then
      read -rp "  UUID VLESS на B (B_VLESS_UUID): " B_VLESS_UUID
      read -rp "  Public key Reality на B (B_REALITY_PUB): " B_REALITY_PUB
      read -rp "  Short ID Reality на B (B_REALITY_SID): " B_REALITY_SID
      read -rp "  Домен маскировки Reality на B (B_VLESS_DEST): " B_VLESS_DEST
      B_VLESS_SNI="$B_VLESS_DEST"
    else
      B_VLESS_UUID=""; B_REALITY_PUB=""; B_REALITY_SID=""; B_VLESS_DEST=""; B_VLESS_SNI=""
    fi
  fi
  echo
  read -rp "  Порт раздачи профилей (nginx) [8443]: " PROFILE_PORT; PROFILE_PORT=${PROFILE_PORT:-8443}
  echo
  echo "VLESS+Reality на сервере A — сайт для маскировки (проверь через RealiTLScanner или openssl s_client,"
  echo "нужен реальный сайт с TLS 1.3, лучше глобальный сервис типа microsoft.com/apple.com):"
  read -rp "  Домен для Reality на A (VLESS_DEST): " VLESS_DEST
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
EOF
  chmod 600 "$CONFIG_ENV"
  echo "Записано в $CONFIG_ENV"
fi

if [[ "${B_NEEDS_INSTALL:-0}" == "1" ]]; then
  echo
  echo "Генерирую install-b.sh для сервера B..."
  mkdir -p /opt/vpn/profiles
  B_TOKEN=$(openssl rand -hex 8)
  B_INSTALL_PATH="/opt/vpn/profiles/install-b-${B_TOKEN}.sh"

  cat > "$B_INSTALL_PATH" <<BEOF
#!/usr/bin/env bash
set -euo pipefail

if [[ \$EUID -ne 0 ]]; then
  echo "Запусти через sudo/root: sudo bash install-b.sh"
  exit 1
fi

echo "Установка sing-box (выходной узел B)..."
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
echo "Сервер B настроен."
echo "  Домен:  ${B_DOMAIN}"
echo "  Порт:   ${B_PORT} (Hysteria2 + VLESS+Reality на одном порту, TCP/UDP)"
echo "=================================================="
echo
echo "Убедись, что DNS ${B_DOMAIN} указывает на этот сервер,"
echo "и порт ${B_PORT} (TCP+UDP) и 80/TCP (для ACME) открыты в фаерволе."
BEOF

  chmod +x "$B_INSTALL_PATH"

  echo "install-b.sh готов. Выполни на сервере B (после того как настроишь DNS для $B_DOMAIN):"
  echo
  echo "  curl -sL https://${A_DOMAIN}:${PROFILE_PORT:-8443}/$(basename "$B_INSTALL_PATH") | sudo bash"
  echo
  echo "(ссылка будет рабочей после завершения установки A и запуска nginx)"
fi

source "$CONFIG_ENV"

step "7/9 — DNS-проверка"
RESOLVED=$(dig +short "$A_DOMAIN" @1.1.1.1 2>/dev/null | tail -1)
if [[ "$RESOLVED" != "$A_IP" ]]; then
  echo "ВНИМАНИЕ: $A_DOMAIN резолвится в '$RESOLVED', а не в $A_IP."
  echo "Убедись, что A-запись домена указывает на этот сервер, иначе ACME не пройдёт."
  read -rp "Продолжить всё равно? [y/N] " cont
  [[ "${cont,,}" == "y" ]] || { echo "Прервано."; exit 1; }
fi

step "8/9 — копирование шаблонов и скрипта управления"
mkdir -p /opt/vpn/profiles /opt/vpn/traffic/daily /root/clients /etc/sing-box/clients

cp "$SCRIPT_DIR/templates/template.json" /opt/vpn/template.json
cp "$SCRIPT_DIR/templates/template-legacy.json" /opt/vpn/template-legacy.json
cp "$SCRIPT_DIR/templates/stats.proto" /opt/vpn/stats.proto
cp "$SCRIPT_DIR/vpn-setup.sh" /root/vpn-setup.sh
chmod +x /root/vpn-setup.sh

cat > /root/sb-panel <<EOF
#!/usr/bin/env bash
VPN_CONFIG=$CONFIG_ENV exec /root/vpn-setup.sh "\$@"
EOF
chmod +x /root/sb-panel

step "9/9 — nginx для раздачи профилей + cron"
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

step "ГОТОВО"
cat <<MSG

Установка завершена. ВАЖНО — без шага 2 сервер не заработает:

1) Открой в фаерволе провайдера:
   - TCP 80              (нужен один раз для получения TLS-сертификата)
   - UDP ${WG_PORT}       (WireGuard)
   - UDP/TCP ${HY2_PORT}  (Hysteria2 + VLESS)
   - TCP ${PROFILE_PORT}  (раздача профилей)

2) *** ОБЯЗАТЕЛЬНО СЕЙЧАС ЖЕ *** создай первого клиента — без этого шага
   не будет сертификата, nginx не поднимется на ${PROFILE_PORT}, и раздача
   профилей (а также ссылка на install-b.sh ниже, если она есть) не заработает:
   /root/sb-panel
   -> 1 (создать клиента)

   После этого проверь: systemctl status sing-box ; systemctl status nginx
   Если nginx не поднялся — перезапусти вручную: systemctl restart nginx

Управление: /root/sb-panel
Конфиг сервера: $CONFIG_ENV
MSG

if [[ -n "${B_INSTALL_PATH:-}" ]]; then
  cat <<MSG2

==================================================
Не забудь развернуть сервер B (после шага 2 выше и открытия портов на A):
==================================================

  curl -sL https://${A_DOMAIN}:${PROFILE_PORT}/$(basename "$B_INSTALL_PATH") | sudo bash

Выполни это на самом сервере B (после настройки DNS для $B_DOMAIN
и открытия портов $B_PORT TCP+UDP, 80 TCP на нём).
MSG2
fi
