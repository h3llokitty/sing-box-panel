#!/usr/bin/env bash
# Translation table for sing-box-panel. Sourced by install.sh and vpn-setup.sh.

declare -A T

t() {  # $1 = key
  local key="$1"
  local val="${T[${key}.${LANG_CODE:-en}]:-${T[${key}.en]:-$key}}"
  printf '%s' "$val"
}

# ── install.sh ──────────────────────────────────────────────

T[must_run_as_root.en]="Please run as root: sudo bash install.sh"
T[must_run_as_root.ru]="Запустите от имени root: sudo bash install.sh"

T[rollback_header.en]="INSTALLATION DID NOT COMPLETE (error). Rolling back changes..."
T[rollback_header.ru]="Установка не была завершена (ошибка). Выполняется откат изменений..."

T[rollback_done.en]="Rollback complete. Please run install.sh again to retry."
T[rollback_done.ru]="Откат завершён. Запустите install.sh повторно, чтобы повторить попытку."

T[rollback_binary_kept.en]="(The sing-box binary at /usr/bin/sing-box and the Go toolchain have been left in place — reinstallation will be faster.)"
T[rollback_binary_kept.ru]="(Бинарный файл sing-box в /usr/bin/sing-box и Go оставлены без изменений — переустановка пройдёт быстрее.)"

T[done_marker_found.en]="A completed prior installation was detected (dated %s)."
T[done_marker_found.ru]="Обнаружена ранее завершённая установка (от %s)."

T[done_marker_warning.en]="Reinstalling will delete all existing clients and all server secrets."
T[done_marker_warning.ru]="Переустановка приведёт к удалению всех существующих клиентов и всех секретов сервера."

T[confirm_reinstall.en]="Are you sure you want to reinstall from scratch? [y/N] "
T[confirm_reinstall.ru]="Вы уверены, что хотите переустановить систему с нуля? [y/N] "

T[reinstall_cancelled.en]="Cancelled. Use /root/sb-panel to manage clients."
T[reinstall_cancelled.ru]="Отменено. Для управления клиентами используйте /root/sb-panel."

T[reinstall_proceeding.en]="Proceeding — removing the current installation before reinstalling..."
T[reinstall_proceeding.ru]="Продолжение — удаление текущей установки перед переустановкой..."

T[resuming_incomplete_install.en]="An incomplete prior installation was detected — rolling back before retrying."
T[resuming_incomplete_install.ru]="Обнаружена незавершённая установка — выполняется откат перед повторной попыткой."

T[build_failed.en]="The sing-box build failed; aborting installation."
T[build_failed.ru]="Сборка sing-box завершилась ошибкой; установка прервана."

T[v2ray_api_missing.en]="with_v2ray_api was not found in the build!"
T[v2ray_api_missing.ru]="Тег with_v2ray_api не найден в собранной версии!"

T[build_success.en]="sing-box was built successfully."
T[build_success.ru]="Сборка sing-box завершена успешно."

T[existing_config_found.en]="An existing configuration was found at %s."
T[existing_config_found.ru]="Обнаружена существующая конфигурация: %s."

T[use_existing_skip.en]="Use it and skip these questions? [Y/n] "
T[use_existing_skip.ru]="Использовать её и пропустить вопросы? [Y/n] "

T[fill_new_server_params.en]="Please provide the parameters for the new server A:"
T[fill_new_server_params.ru]="Укажите параметры нового сервера A:"

T[ip_autodetect_failed.en]="The IP address could not be detected automatically; please enter it manually."
T[ip_autodetect_failed.ru]="Не удалось определить IP-адрес автоматически, введите его вручную."

T[prompt_ip_detected.en]="  This server's IP (A_IP) [%s]: "
T[prompt_ip_detected.ru]="  IP-адрес этого сервера (A_IP) [%s]: "

T[prompt_ip_manual.en]="  This server's IP (A_IP): "
T[prompt_ip_manual.ru]="  IP-адрес этого сервера (A_IP): "

T[prompt_domain.en]="  This server's domain (A_DOMAIN, e.g. h3.example.com): "
T[prompt_domain.ru]="  Домен этого сервера (A_DOMAIN, например h3.example.com): "

T[prompt_email.en]="  Email address for ACME / Let's Encrypt: "
T[prompt_email.ru]="  Адрес электронной почты для ACME / Let's Encrypt: "

T[prompt_wg_port.en]="  WireGuard port [51820]: "
T[prompt_wg_port.ru]="  Порт WireGuard [51820]: "

T[prompt_hy2_port.en]="  Hysteria2 port [443]: "
T[prompt_hy2_port.ru]="  Порт Hysteria2 [443]: "

T[server_b_intro.en]="Server B (the egress node that A connects to):"
T[server_b_intro.ru]="Сервер B (выходной узел, к которому подключается сервер A):"

T[prompt_has_b.en]="  Is server B already configured? [Y/n] "
T[prompt_has_b.ru]="  Сервер B уже настроен? [Y/n] "

T[gen_b_secrets_notice1.en]="Secrets for server B will be generated automatically. Once the installation of A completes,"
T[gen_b_secrets_notice1.ru]="Секреты для сервера B будут сгенерированы автоматически. После завершения установки A"

T[gen_b_secrets_notice2.en]="you will receive a link to install-b.sh, which must be executed on server B itself."
T[gen_b_secrets_notice2.ru]="вы получите ссылку на install-b.sh, которую необходимо выполнить непосредственно на сервере B."

T[prompt_b_domain_new.en]="  The domain that server B will use (B_DOMAIN): "
T[prompt_b_domain_new.ru]="  Домен, который будет использовать сервер B (B_DOMAIN): "

T[prompt_b_port_new.en]="  Hysteria2/VLESS port on B [443]: "
T[prompt_b_port_new.ru]="  Порт Hysteria2/VLESS на сервере B [443]: "

T[b_reality_site_notice.en]="Masking site for VLESS+Reality on server B (may differ from A_DOMAIN):"
T[b_reality_site_notice.ru]="Сайт маскировки для VLESS+Reality на сервере B (может отличаться от A_DOMAIN):"

T[prompt_b_vless_dest_new.en]="  Reality masking domain for B (B_VLESS_DEST): "
T[prompt_b_vless_dest_new.ru]="  Домен маскировки Reality для сервера B (B_VLESS_DEST): "

T[prompt_b_domain_existing.en]="  Server B's domain (B_DOMAIN): "
T[prompt_b_domain_existing.ru]="  Домен сервера B (B_DOMAIN): "

T[prompt_b_port_existing.en]="  Server B's port [443]: "
T[prompt_b_port_existing.ru]="  Порт сервера B [443]: "

T[prompt_b_pass.en]="  Hysteria2 password on server B (B_PASS): "
T[prompt_b_pass.ru]="  Пароль Hysteria2 на сервере B (B_PASS): "

T[prompt_b_has_vless.en]="  Does B also run VLESS+Reality? [y/N] "
T[prompt_b_has_vless.ru]="  На сервере B также работает VLESS+Reality? [y/N] "

T[prompt_b_vless_uuid.en]="  VLESS UUID on B (B_VLESS_UUID): "
T[prompt_b_vless_uuid.ru]="  UUID VLESS на сервере B (B_VLESS_UUID): "

T[prompt_b_reality_pub.en]="  Reality public key on B (B_REALITY_PUB): "
T[prompt_b_reality_pub.ru]="  Публичный ключ Reality на сервере B (B_REALITY_PUB): "

T[prompt_b_reality_sid.en]="  Reality short ID on B (B_REALITY_SID): "
T[prompt_b_reality_sid.ru]="  Short ID Reality на сервере B (B_REALITY_SID): "

T[prompt_b_vless_dest_existing.en]="  Reality masking domain on B (B_VLESS_DEST): "
T[prompt_b_vless_dest_existing.ru]="  Домен маскировки Reality на сервере B (B_VLESS_DEST): "

T[prompt_profile_port.en]="  Profile-delivery port (nginx) [8443]: "
T[prompt_profile_port.ru]="  Порт раздачи профилей (nginx) [8443]: "

T[reality_a_notice1.en]="VLESS+Reality on server A — masking site (verify beforehand using RealiTLScanner or openssl s_client;"
T[reality_a_notice1.ru]="VLESS+Reality на сервере A — сайт маскировки (проверьте заранее через RealiTLScanner или openssl s_client;"

T[reality_a_notice2.en]="it must be a genuine TLS 1.3 site, preferably a large global service such as microsoft.com or apple.com):"
T[reality_a_notice2.ru]="сайт должен реально поддерживать TLS 1.3, предпочтительны крупные глобальные сервисы, например microsoft.com или apple.com):"

T[prompt_vless_dest_a.en]="  Reality masking domain for A (VLESS_DEST): "
T[prompt_vless_dest_a.ru]="  Домен маскировки Reality для сервера A (VLESS_DEST): "

T[config_written.en]="Configuration written to %s"
T[config_written.ru]="Конфигурация записана в %s"

T[generating_install_b.en]="Generating install-b.sh for server B..."
T[generating_install_b.ru]="Генерация install-b.sh для сервера B..."

T[install_b_ready.en]="install-b.sh is ready. Run it on server B (after configuring DNS for %s):"
T[install_b_ready.ru]="install-b.sh готов. Выполните его на сервере B (после настройки DNS для %s):"

T[link_will_work_after.en]="(This link will become active once the installation of A completes and nginx is running.)"
T[link_will_work_after.ru]="(Эта ссылка станет рабочей после завершения установки A и запуска nginx.)"

T[dns_warning.en]="WARNING: %s currently resolves to '%s', not to %s."
T[dns_warning.ru]="ВНИМАНИЕ: домен %s сейчас указывает на '%s', а не на %s."

T[dns_warning_hint.en]="Please ensure the domain's A record points to this server, or the ACME certificate request will fail."
T[dns_warning_hint.ru]="Убедитесь, что A-запись домена указывает на этот сервер, иначе получение ACME-сертификата не удастся."

T[prompt_continue_anyway.en]="Continue anyway? [y/N] "
T[prompt_continue_anyway.ru]="Продолжить в любом случае? [y/N] "

T[aborted.en]="Aborted."
T[aborted.ru]="Прервано."

# ── generated install-b.sh (baked at generation time, no i18n.sh on server B) ──

T[b_must_run_as_root.en]="Please run as root: sudo bash install-b.sh"
T[b_must_run_as_root.ru]="Запустите от имени root: sudo bash install-b.sh"

T[b_installing.en]="Installing sing-box (egress node B)..."
T[b_installing.ru]="Установка sing-box (выходной узел B)..."

T[b_configured.en]="Server B has been configured."
T[b_configured.ru]="Сервер B настроен."

T[b_domain_label.en]="  Domain: %s"
T[b_domain_label.ru]="  Домен: %s"

T[b_port_label.en]="  Port:   %s (Hysteria2 + VLESS+Reality on a single port, TCP/UDP)"
T[b_port_label.ru]="  Порт:   %s (Hysteria2 + VLESS+Reality на одном порту, TCP/UDP)"

T[b_dns_reminder.en]="Please ensure DNS for %s points to this server, and that port %s (TCP+UDP) and port 80/TCP (for ACME) are open in the firewall."
T[b_dns_reminder.ru]="Убедитесь, что DNS для %s указывает на этот сервер, и что порт %s (TCP+UDP) и порт 80/TCP (для ACME) открыты в фаерволе."


# ── final instructions ──────────────────────────────────────

T[final_notice.en]="Installation complete. IMPORTANT — the server will not work without step 2:"
T[final_notice.ru]="Установка завершена. ВАЖНО — без шага 2 сервер не будет работать:"

T[final_firewall_header.en]="1) Open the following in your provider's firewall:"
T[final_firewall_header.ru]="1) Откройте в фаерволе провайдера:"

T[final_port_80.en]="   - TCP 80              (needed once, to obtain the TLS certificate)"
T[final_port_80.ru]="   - TCP 80              (требуется один раз для получения TLS-сертификата)"

T[final_port_wg.en]="   - UDP %s       (WireGuard)"
T[final_port_wg.ru]="   - UDP %s       (WireGuard)"

T[final_port_hy2.en]="   - UDP/TCP %s  (Hysteria2 + VLESS)"
T[final_port_hy2.ru]="   - UDP/TCP %s  (Hysteria2 + VLESS)"

T[final_port_profile.en]="   - TCP %s  (profile delivery)"
T[final_port_profile.ru]="   - TCP %s  (раздача профилей)"

T[final_step2_header.en]="2) *** REQUIRED RIGHT NOW *** create the first client — without this step"
T[final_step2_header.ru]="2) *** ОБЯЗАТЕЛЬНО ПРЯМО СЕЙЧАС *** создайте первого клиента — без этого шага"

T[final_step2_body1.en]="   there will be no certificate, nginx will not start on port %s, and profile"
T[final_step2_body1.ru]="   не будет сертификата, nginx не запустится на порту %s, а раздача"

T[final_step2_body2.en]="   delivery (as well as the install-b.sh link below, if present) will not work:"
T[final_step2_body2.ru]="   профилей (а также ссылка на install-b.sh ниже, если она есть) не заработает:"

T[final_step2_cmd1.en]="   /root/sb-panel"
T[final_step2_cmd1.ru]="   /root/sb-panel"

T[final_step2_cmd2.en]="   -> 1 (create client)"
T[final_step2_cmd2.ru]="   -> 1 (создать клиента)"

T[final_step2_check1.en]="   After that, check: systemctl status sing-box ; systemctl status nginx"
T[final_step2_check1.ru]="   После этого проверьте: systemctl status sing-box ; systemctl status nginx"

T[final_step2_check2.en]="   If nginx did not start, restart it manually: systemctl restart nginx"
T[final_step2_check2.ru]="   Если nginx не запустился, перезапустите его вручную: systemctl restart nginx"

T[final_management.en]="Management: /root/sb-panel"
T[final_management.ru]="Управление: /root/sb-panel"

T[final_config_label.en]="Server configuration: %s"
T[final_config_label.ru]="Конфигурация сервера: %s"

T[final_b_reminder_header.en]="Don't forget to deploy server B (after step 2 above and opening the ports on A):"
T[final_b_reminder_header.ru]="Не забудьте развернуть сервер B (после шага 2 выше и открытия портов на A):"

T[final_b_reminder_run1.en]="Run this on server B itself (after configuring DNS for %s"
T[final_b_reminder_run1.ru]="Выполните это на самом сервере B (после настройки DNS для %s"

T[final_b_reminder_run2.en]="and opening ports %s TCP+UDP, 80 TCP on it)."
T[final_b_reminder_run2.ru]="и открытия портов %s TCP+UDP, 80 TCP на нём)."

# ── write_nginx_stream ──────────────────────────────────────

T[cert_not_ready_yet.en]="Certificate for %s has not been issued by ACME yet — nginx will restart automatically once it appears (see nginx-cert-reload.path)."
T[cert_not_ready_yet.ru]="Сертификат для %s ещё не выпущен через ACME — nginx перезапустится автоматически, как только он появится (см. nginx-cert-reload.path)."

# ── vpn-setup.sh startup ────────────────────────────────────

T[config_not_found.en]="config.env not found (looked in: %s)"
T[config_not_found.ru]="Не найден config.env (искал: %s)"

T[config_not_found_hint.en]="Copy config.env.example to config.env and fill in your values."
T[config_not_found_hint.ru]="Скопируйте config.env.example в config.env и заполните своими значениями."
