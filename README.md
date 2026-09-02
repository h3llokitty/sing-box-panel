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
git clone --branch agent/add-su-direct-route --single-branch https://github.com/h3llokitty/sing-box-panel.git /root/vpn-repo
cd /root/vpn-repo
sudo bash install.sh
```

The installer is interactive and available in English (default) or Russian —
you'll be asked to choose a language on first run. It will then ask for:

- this server's IP and domain
- an email address for Let's Encrypt
- server B's domain, port, and password (or generate a new server B setup —
  see below)
- the masking site for VLESS+Reality (see below)
- whether to enable the standard Russian-resource policy (`.ru`, `.su`, `.рф`,
  `.xn--p1ai`, and `geoip-ru`)
- when that policy is enabled, the external rule-set base URL (defaults to
  `https://unicorns.kz/sources`)

The installation compiles sing-box from source with `with_v2ray_api` support
(required for per-client traffic statistics) — this takes 5-15 minutes.
For an interactive SSH installation it offers to run inside a persistent `tmux`
session. If SSH disconnects, reconnect and run
`tmux attach -t sing-box-install`. Completed installer steps are checkpointed;
running `install.sh` again resumes from the first incomplete step and reuses a
verified build of the pinned sing-box revision.

The Russian-resource policy is disabled by default. When enabled, its suffix
rules and `geoip-ru` are added together to both server and client routing. The
installer asks for an external rule-set base URL, then downloads and validates
`geoip/geoip-ru.srs` as a sing-box binary rule set. It does not create or host a
rule-set storage service on server A.

If server B doesn't exist yet, `install.sh` will generate a ready-to-run
`install-b.sh` script and print a `curl | sudo bash` command to deploy it —
just run that command on server B once its DNS is configured. The installer also
publishes a tokenized copy of A's verified sing-box binary, checks its SHA-256 on
B, and pins both systemd services to the managed binary at
`/usr/local/lib/sing-box-panel/sing-box` so package upgrades cannot silently
replace it. The B package is additionally placed on hold. After both A→B
transports pass the manager test, the manager offers to remove the temporary B
installer and binary from profile delivery (default: yes).

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

## Updating an existing installation

When install.sh detects /etc/sing-box/.install-done, it does not run cleanup.
It offers an in-place Git update, a separately confirmed full reinstall, or cancel.
During an in-place update, an existing /opt/vpn/server-routing.json can be
kept (the default) or replaced explicitly with the standard file from Git.
The same independent choice is offered for the default
`/opt/vpn/client-routing.json`. The repository-owned
`/opt/vpn/client-outbounds.json` is the default for new devices. Per-device
routing and outbound files are never overwritten by an update.
Every update creates a rollback backup under `/opt/vpn/backups/update-*`.

Server A certificates are issued and renewed by certbot through the nginx
HTTP-01 webroot. sing-box and the profile server read the same files from
`/etc/letsencrypt/live/<A_DOMAIN>/`; the certbot deploy hook restarts sing-box
and reloads nginx only after a successful renewal. Existing CertMagic files are
accepted as a migration fallback, but inline ACME is not retained after the
first valid certificate is available.

## Optional Cloudflare WARP outbound

Server A can install a local Cloudflare WARP SOCKS5 proxy on
`127.0.0.1:40000`. The WARP installer only adds the outbound and does not
change routing rules automatically.

When the optional Russian-resource policy is enabled, its `.ru`, `.su`, `.рф`,
`.xn--p1ai`, and `geoip-ru` rules use `direct` by default. After WARP is
installed successfully, choose their route in the manager: `5) service` ->
`6) manage routing` -> `2) route for direct rules`, then select `direct` or the
configured WARP tag.

If direct Cloudflare registration is unavailable, the installer can guide the user through a temporary reverse SOCKS connection from another computer. The generated SSH command works with OpenSSH on macOS, Linux, and Windows PowerShell; temporary proxy settings are removed immediately after registration.

A tokenized WARP installer link is printed at the end of the main installation.
The script asks for the tag, installs and verifies WARP, saves these settings,
and rebuilds sing-box without switching the direct-rule route. WARP registration
credentials are local server secrets and are never stored in this repository.

## Management after installation

```bash
/opt/vpn/sb-panel
```

All panel executables, templates, generated artifacts, build files, summaries,
and rollback backups live under `/opt/vpn`. The installer does not create a
launcher or copy program files under `/root`. System service configuration and
secrets remain in `/etc/sing-box`, with a navigation symlink at
`/opt/vpn/sing-box`.

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
   - rebuild remote client profiles without restarting sing-box or nginx

Each owner has a private directory under `/opt/vpn/clients`. WireGuard
configuration and editable per-device routing are stored together, for example:

```text
/opt/vpn/clients/kitty/kitty_mac_wg.conf
/opt/vpn/clients/kitty/kitty_mac_routing.json
/opt/vpn/clients/kitty/kitty_mac_outbounds.json
```

Existing owner directories directly under `/opt/vpn` are migrated
transactionally on the first manager run. Conflicting files are never
overwritten.

Run `/opt/vpn/sb-panel --rebuild-profiles` after editing routing manually, or use
the corresponding service-menu command. Published modern/legacy profile URLs
do not change.

The per-device `_outbounds.json` is also created once and then preserved. It
contains editable WireGuard, Hysteria2, VLESS, urltest, and selector templates.
Client keys, UUIDs, domains, ports, and generated tags are substituted only
while rendering a profile. VLESS is expanded once per active Reality domain,
and selector/urltest membership is derived from the device transports and its
WireGuard profile mode. `extra_outbounds`, `modern_extra_outbounds`, and
`legacy_extra_outbounds` can hold additional complete outbound objects.

Both variants are rendered to temporary files and published atomically only
after validation. Modern profiles are checked by the managed runtime;
legacy profiles are checked by the separately installed official, checksum-
verified sing-box 1.11.15 binary. That validator never runs as a service.

When a device uses both WireGuard and proxy transports, the manager stores a
per-device WireGuard profile mode. WireGuard can be omitted from sing-box JSON,
included only in the `Select` selector, or included in both `Select` and the
`auto` urltest. The standalone WireGuard `.conf` and the server-side peer remain
available in every mode. Existing devices without this setting retain the
previous `Select` + `auto` behavior.

Client routing files separate portable policy rules by compatibility level:

- `common_rules` are added to both profile variants before user rules;
- `modern_rules` are added only to the sing-box 1.12+ profile;
- `legacy_rules` are added only to the sing-box 1.11.x profile;
- `rules` contains the ordinary per-client policy applied after those rules.

DNS interception, resolution, and sniffing remain in the profile templates as
mandatory transport plumbing rather than editable policy.

## Server B requirements

A separate sing-box instance with a Hysteria2 inbound (and optionally
VLESS+Reality) listening on a known port with a known password — this
information is entered during server A's installation, or generated
automatically if you choose to deploy a new server B.

## Repository structure

install.sh              — installer for a clean server
i18n.sh                 — translation table (English/Russian) for install.sh
vpn-setup.sh            — CLI client manager (installed as /opt/vpn/vpn-setup.sh)
config.env.example      — reference list of parameters (install.sh asks for them itself)
templates/
template.json           — client profile for sing-box 1.12+ (modern)
template-legacy.json     — client profile for sing-box 1.11.x (legacy)
client-routing.json      — default route rule sets and policy rules for new clients
client-outbounds.json    — default endpoint/outbound templates for new clients
server-template.json     — technical server configuration template
server-routing.json      — server route rule sets and policy rules
install-warp.sh        — optional localized Cloudflare WARP installer
stats.proto              — protobuf schema for traffic statistics collection
render-client-profile.py — strict modern/legacy client profile renderer
