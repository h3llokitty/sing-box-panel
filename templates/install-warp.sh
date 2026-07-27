#!/usr/bin/env bash
set -euo pipefail

source /opt/vpn/i18n.sh
printf '%s\n' "$(t warp_language_title)"
printf '%s\n' "$(t warp_language_en)"
printf '%s\n' "$(t warp_language_ru)"
read -rp "$(t warp_language_prompt)" LANG_CHOICE
case "$LANG_CHOICE" in
  2) LANG_CODE="ru" ;;
  *) LANG_CODE="en" ;;
esac

if [[ $EUID -ne 0 ]]; then
  echo "$(t warp_root_required)" >&2
  exit 1
fi

CONFIG_ENV=/etc/sing-box/vpn-panel.env
if [[ ! -f "$CONFIG_ENV" || ! -x /root/vpn-setup.sh ]]; then
  echo "$(t warp_panel_missing)" >&2
  exit 1
fi

read -rp "$(t warp_tag_prompt)" WARP_TAG
WARP_TAG=${WARP_TAG:-WARP}
if [[ ! "$WARP_TAG" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "$(t warp_tag_invalid)" >&2
  exit 1
fi
case "$WARP_TAG" in
  direct|to-b|hy2-out|vless-out-b)
    printf "$(t warp_tag_reserved)\n" "$WARP_TAG" >&2
    exit 1
    ;;
esac
read -rp "$(t warp_port_prompt)" WARP_PORT
WARP_PORT=${WARP_PORT:-40000}
if [[ ! "$WARP_PORT" =~ ^[0-9]+$ ]] || (( WARP_PORT < 1024 || WARP_PORT > 65535 )); then
  echo "$(t warp_port_invalid)" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends curl ca-certificates gnupg lsb-release
install -d -m 0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg |
  gpg --dearmor --yes -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
printf 'deb [arch=%s signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ %s main\n' \
  "$(dpkg --print-architecture)" "$(lsb_release -cs)" \
  > /etc/apt/sources.list.d/cloudflare-client.list
apt-get update -qq
apt-get install -y -qq cloudflare-warp
systemctl enable --now warp-svc

if ! warp-cli --accept-tos registration show >/dev/null 2>&1; then
  if ! warp-cli --accept-tos registration new; then
    echo
    echo "$(t warp_registration_unavailable)"
    echo "$(t warp_registration_external)"
    printf "$(t warp_registration_docs)\n" \
      "https://developers.cloudflare.com/warp-client/get-started/linux/"
    echo "$(t warp_registration_step1)"
    echo "$(t warp_registration_step2)"
    exit 1
  fi
fi

warp-cli --accept-tos proxy port "$WARP_PORT"
warp-cli --accept-tos mode proxy
warp-cli --accept-tos connect

connected=0
for _ in $(seq 1 15); do
  if warp-cli --accept-tos status 2>/dev/null | grep -q 'Connected'; then
    connected=1
    break
  fi
  sleep 2
done
if [[ $connected -ne 1 ]]; then
  echo "$(t warp_connect_failed)" >&2
  warp-cli --accept-tos status || true
  exit 1
fi

if ! ss -lnt | grep -q "127.0.0.1:${WARP_PORT}"; then
  printf "$(t warp_listener_missing)\n" "$WARP_PORT" >&2
  exit 1
fi
TRACE=$(curl -4 --socks5 "127.0.0.1:${WARP_PORT}" --connect-timeout 10 --max-time 25 \
  https://www.cloudflare.com/cdn-cgi/trace)
grep -qx 'warp=on' <<<"$TRACE" || {
  echo "$(t warp_health_off)" >&2
  exit 1
}
WARP_IP=$(awk -F= '$1 == "ip" { print $2 }' <<<"$TRACE")
[[ "$WARP_IP" == *.* ]] || {
  echo "$(t warp_health_no_ipv4)" >&2
  exit 1
}

BACKUP_DIR="/etc/sing-box/warp-backup-$(date +%Y%m%d%H%M%S)"
install -d -m 0700 "$BACKUP_DIR"
cp -a "$CONFIG_ENV" "$BACKUP_DIR/vpn-panel.env"
cp -a /etc/sing-box/config.json "$BACKUP_DIR/config.json"
DROPIN=/etc/systemd/system/sing-box.service.d/warp.conf
if [[ -f "$DROPIN" ]]; then
  cp -a "$DROPIN" "$BACKUP_DIR/warp.conf"
fi
sed -i \
  -e '/^WARP_ENABLED=/d' \
  -e '/^WARP_PORT=/d' \
  -e '/^WARP_TAG=/d' \
  "$CONFIG_ENV"
printf '\nWARP_ENABLED=1\nWARP_PORT=%s\nWARP_TAG="%s"\n' \
  "$WARP_PORT" "$WARP_TAG" >> "$CONFIG_ENV"

install -d -m 0755 /etc/systemd/system/sing-box.service.d
cat > /etc/systemd/system/sing-box.service.d/warp.conf <<'UNIT'
[Unit]
Wants=warp-svc.service
After=warp-svc.service
UNIT
systemctl daemon-reload

if ! VPN_CONFIG="$CONFIG_ENV" /root/vpn-setup.sh --rebuild-config; then
  cp -a "$BACKUP_DIR/vpn-panel.env" "$CONFIG_ENV"
  cp -a "$BACKUP_DIR/config.json" /etc/sing-box/config.json
  if [[ -f "$BACKUP_DIR/warp.conf" ]]; then
    cp -a "$BACKUP_DIR/warp.conf" "$DROPIN"
  else
    rm -f "$DROPIN"
  fi
  systemctl daemon-reload
  systemctl restart --no-block sing-box || true
  printf "$(t warp_rebuild_failed)\n" "$BACKUP_DIR" >&2
  exit 1
fi

echo
echo "$(t warp_ready)"
printf "$(t warp_result_tag)\n" "$WARP_TAG"
printf "$(t warp_result_socks)\n" "$WARP_PORT"
printf "$(t warp_result_ipv4)\n" "$WARP_IP"
printf "$(t warp_result_backup)\n" "$BACKUP_DIR"
