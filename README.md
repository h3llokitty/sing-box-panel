# sing-box-panel

VPN infrastructure built on sing-box: WireGuard + Hysteria2+salamander + VLESS+Reality,
with automatic client profile generation, delivery via nginx (auto modern/legacy
selection based on the client's User-Agent), and traffic monitoring via v2ray_api.

## Architecture

A client connects to server A using one of three protocols (WireGuard, Hysteria2,
or VLESS+Reality), or through an automatic urltest selector that picks the fastest
one on its own. All traffic from server A is forwarded to server B via Hysteria2
or VLESS+Reality — the ingress and egress points are kept separate.

client --(WireGuard | Hysteria2 | VLESS+Reality)--> server A --(Hysteria2 | VLESS+Reality)--> server B --> internet

VLESS+Reality also supports multiple masking domains sharing a single external
port (via nginx stream SNI routing) — domains can be added or removed after
installation without reinstalling the server.

## Installation on a clean server

```bash
git clone git@github.com:h3llokitty/sing-box-panel.git
cd sing-box-panel
sudo bash install.sh
```

The installer is interactive and available in English (default) or Russian —
you'll be asked to choose a language on first run. It will then ask for:

- this server's IP and domain
- an email address for Let's Encrypt
- server B's domain, port, and password (or generate a new server B setup —
  see below)
- the masking site for VLESS+Reality (see below)

The installation compiles sing-box from source with `with_v2ray_api` support
(required for per-client traffic statistics) — this takes 5-15 minutes.

If server B doesn't exist yet, `install.sh` will generate a ready-to-run
`install-b.sh` script and print a `curl | sudo bash` command to deploy it —
just run that command on server B once its DNS is configured.

## Choosing a Reality masking site

You need a real site with TLS 1.3 support. Large global services (microsoft.com,
apple.com, cloudflare.com) are preferable — blocking them selectively is costly
for a censor, unlike blocking a local/regional service.

Checking a candidate:

```bash
openssl s_client -connect DOMAIN:443 -servername DOMAIN -tls1_3 </dev/null 2>&1 | grep -E "Protocol|subject|issuer"
```

Should return `Protocol: TLSv1.3` and a valid certificate.

Additional masking domains can be added later through the management menu
(see below) without touching the original one.

## Optional WARP routing for Yandex and Kinopoisk

Server A can route Yandex and Kinopoisk through a local Cloudflare WARP SOCKS5
proxy while leaving all other traffic unchanged. Provision WARP separately in
local proxy mode on `127.0.0.1:40000`, then add these values to
`/etc/sing-box/vpn-panel.env`:

```bash
WARP_RU_ENABLED=1
WARP_RU_PORT=40000
WARP_RU_TAG="WARP"
```

Rebuild the server configuration from the management menu. The generated
sing-box outbound uses the configured tag. A tokenized WARP installer link is
printed at the end of the main installation; the script asks for the tag,
installs and verifies WARP, saves these settings, and rebuilds sing-box. WARP
registration credentials are local server secrets and are never stored in this
repository.

## Management after installation

```bash
/root/sb-panel
```

Main menu:
1. create a client
2. edit a client (rename, change transport)
3. revoke a client
4. show a client (profile, QR code, URL)
5. service — logs, traffic stats, config rebuild, A↔B transport, Reality domains:
   - client request logs
   - modern/legacy version stats
   - live log monitoring
   - rebuild and restart the config (also regenerates all client profiles)
   - traffic statistics (today / 7 days / all-time)
   - manage the A→B transport (direct / Hysteria2 / VLESS+Reality)
   - manage Reality masking domains (list / add / remove)

## Server B requirements

A separate sing-box instance with a Hysteria2 inbound (and optionally
VLESS+Reality) listening on a known port with a known password — this
information is entered during server A's installation, or generated
automatically if you choose to deploy a new server B.

## Repository structure

install.sh              — installer for a clean server
i18n.sh                 — translation table (English/Russian) for install.sh
vpn-setup.sh            — CLI client manager (run via /root/sb-panel)
config.env.example      — reference list of parameters (install.sh asks for them itself)
templates/
template.json           — client profile for sing-box 1.12+ (modern)
template-legacy.json     — client profile for sing-box 1.11.x (legacy)
server-template.json     — technical server configuration template
server-routing.json      — server route rule sets and policy rules
stats.proto              — protobuf schema for traffic statistics collection
