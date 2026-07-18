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

# ── create_client ────────────────────────────────────────────

T[prompt_owner_name.en]="Owner name (e.g. kitty): "
T[prompt_owner_name.ru]="Имя владельца (напр. kitty): "

T[err_name_format.en]="name: letters/digits/_ only"
T[err_name_format.ru]="имя: латиница/цифры/_"

T[prompt_device_name.en]="Profile/device (e.g. phone): "
T[prompt_device_name.ru]="Профиль/устройство (напр. phone): "

T[err_device_format.en]="device: letters/digits/_ only"
T[err_device_format.ru]="профиль: латиница/цифры/_"

T[key_already_exists.en]="%s already exists"
T[key_already_exists.ru]="%s уже есть"

T[transport_header.en]="Transport:"
T[transport_header.ru]="Транспорт:"

T[transport_opt_both.en]="  1) both (WG + Proxy)"
T[transport_opt_both.ru]="  1) оба (WG + Proxy)"

T[transport_opt_wg_only.en]="  2) WG only"
T[transport_opt_wg_only.ru]="  2) только WG"

T[transport_opt_proxy_only.en]="  3) Proxy only (%s)"
T[transport_opt_proxy_only.ru]="  3) только Proxy (%s)"

T[prompt_choice_13.en]="Choice [1-3, Enter=1]: "
T[prompt_choice_13.ru]="Выбор [1-3, Enter=1]: "

T[wg_routing_header.en]="WireGuard routing:"
T[wg_routing_header.ru]="Маршрутизация WG:"

T[wg_routing_full.en]="  1) all traffic"
T[wg_routing_full.ru]="  1) весь трафик"

T[wg_routing_split.en]="  2) except private networks"
T[wg_routing_split.ru]="  2) кроме приватных сетей"

T[prompt_choice_12.en]="Choice [1-2, Enter=1]: "
T[prompt_choice_12.ru]="Выбор [1-2, Enter=1]: "

T[no_ip_available.en]="no IP available"
T[no_ip_available.ru]="нет IP"

T[device_created.en]="  + device %s created (%s)."
T[device_created.ru]="  + устройство %s создано (%s)."

T[prompt_add_another_device.en]="Add another device for this owner? [y/N] "
T[prompt_add_another_device.ru]="Добавить ещё устройство этому владельцу? [y/N] "

T[no_new_devices.en]="No new devices created."
T[no_new_devices.ru]="Новых устройств не создано."

T[created_devices_header.en]="Done. Devices created in this run:"
T[created_devices_header.ru]="Готово. Созданные в этом запуске устройства:"

# ── shared prompts (used across show_client / revoke_client / edit_client / service_menu) ──

T[no_clients.en]="No clients."
T[no_clients.ru]="Клиентов нет."

T[owners_header.en]="Owners:"
T[owners_header.ru]="Владельцы:"

T[owner_line.en]="  %d) %s  (%d device(s))"
T[owner_line.ru]="  %d) %s  (%d устр.)"

T[prompt_owner_number.en]="Owner number: "
T[prompt_owner_number.ru]="Номер владельца: "

T[invalid.en]="invalid"
T[invalid.ru]="неверно"

T[devices_header.en]="Devices for '%s':"
T[devices_header.ru]="Устройства '%s':"

T[device_line.en]="  %d) %s"
T[device_line.ru]="  %d) %s"

T[prompt_device_number_all.en]="Device number (0 — all): "
T[prompt_device_number_all.ru]="Номер устройства (0 — все): "

# ── revoke_client ────────────────────────────────────────────

T[whole_owner_option.en]="  0) ENTIRE owner '%s'"
T[whole_owner_option.ru]="  0) ВЕСЬ владелец '%s' целиком"

T[prompt_what_to_revoke.en]="What to revoke: "
T[prompt_what_to_revoke.ru]="Что отозвать: "

T[prompt_delete_all_devices.en]="Delete ALL devices for '%s'? [y/N] "
T[prompt_delete_all_devices.ru]="Удалить ВСЕ устройства '%s'? [y/N] "

T[cancelled.en]="cancelled"
T[cancelled.ru]="отмена"

T[owner_deleted.en]="Owner '%s' deleted entirely."
T[owner_deleted.ru]="Владелец '%s' удалён целиком."

T[prompt_delete_device.en]="Delete device '%s'? [y/N] "
T[prompt_delete_device.ru]="Удалить устройство '%s'? [y/N] "

T[device_deleted.en]="Device '%s' deleted."
T[device_deleted.ru]="Устройство '%s' удалено."

# ── traffic_menu ─────────────────────────────────────────────

T[period_header.en]="Period:"
T[period_header.ru]="Период:"

T[period_today.en]="  1) today"
T[period_today.ru]="  1) сегодня"

T[period_7days.en]="  2) 7 days"
T[period_7days.ru]="  2) 7 дней"

T[period_alltime.en]="  3) all time"
T[period_alltime.ru]="  3) всего"

T[prompt_choice_13_short.en]="Choice [1-3]: "
T[prompt_choice_13_short.ru]="Выбор [1-3]: "

T[period_result_today.en]="=== Today ==="
T[period_result_today.ru]="=== За сегодня ==="

T[period_result_7days.en]="=== Last 7 days ==="
T[period_result_7days.ru]="=== За 7 дней ==="

T[period_result_alltime.en]="=== All time ==="
T[period_result_alltime.ru]="=== За всё время ==="

# ── traffic_aggregate ────────────────────────────────────────

T[server_total_label.en]="SERVER TOTAL (WG+Proxy)"
T[server_total_label.ru]="СЕРВЕР ВСЕГО (WG+Proxy)"

T[total_word.en]="total"
T[total_word.ru]="всего"

T[no_client_traffic.en]="  (no client traffic for this period)"
T[no_client_traffic.ru]="  (нет клиентского трафика за этот период)"

T[by_client_header.en]="  By client (v2ray):"
T[by_client_header.ru]="  По клиентам v2ray:"

# ── service_menu ─────────────────────────────────────────────

T[service_header.en]="Service:"
T[service_header.ru]="Сервис:"

T[svc_opt_client_logs.en]="  1) requests for a specific client"
T[svc_opt_client_logs.ru]="  1) обращения конкретного клиента"

T[svc_opt_version_stats.en]="  2) modern/legacy stats"
T[svc_opt_version_stats.ru]="  2) статистика modern/legacy"

T[svc_opt_live_log.en]="  3) live log monitoring (tail -f, Ctrl+C to exit)"
T[svc_opt_live_log.ru]="  3) живой мониторинг (tail -f, Ctrl+C для выхода)"

T[svc_opt_rebuild.en]="  4) rebuild and restart config"
T[svc_opt_rebuild.ru]="  4) пересобрать и перезапустить конфиг"

T[svc_opt_traffic.en]="  5) traffic statistics"
T[svc_opt_traffic.ru]="  5) статистика трафика"

T[svc_opt_transport.en]="  6) manage A -> B transport"
T[svc_opt_transport.ru]="  6) управление транспортом A -> B"

T[svc_opt_reality.en]="  7) manage Reality domains"
T[svc_opt_reality.ru]="  7) управление Reality-доменами"

T[prompt_choice_17.en]="Choice [1-7]: "
T[prompt_choice_17.ru]="Выбор [1-7]: "

T[prompt_device_number.en]="Device number: "
T[prompt_device_number.ru]="Номер устройства: "

T[no_requests_found.en]="No requests found."
T[no_requests_found.ru]="Обращений не найдено."

T[version_stats_header.en]="Version statistics (all clients):"
T[version_stats_header.ru]="Статистика по версиям (все клиенты):"

T[live_log_header.en]="Live log monitoring (Ctrl+C to exit):"
T[live_log_header.ru]="Живой мониторинг (Ctrl+C для выхода):"

# ── reality_domains_menu ─────────────────────────────────────

T[reality_domains_header.en]="Reality domains:"
T[reality_domains_header.ru]="Reality-домены:"

T[rd_opt_list.en]="  1) show list"
T[rd_opt_list.ru]="  1) показать список"

T[rd_opt_add.en]="  2) add domain"
T[rd_opt_add.ru]="  2) добавить домен"

T[rd_opt_remove.en]="  3) remove domain"
T[rd_opt_remove.ru]="  3) удалить домен"

T[active_reality_domains.en]="Active Reality domains:"
T[active_reality_domains.ru]="Активные Reality-домены:"

T[rd_primary_label.en]="  %d) %s  (primary, from config.env)"
T[rd_primary_label.ru]="  %d) %s  (основной, из config.env)"

T[rd_internal_port_label.en]="  %d) %s  (internal port %s)"
T[rd_internal_port_label.ru]="  %d) %s  (внутренний порт %s)"

T[prompt_new_reality_domain.en]="New Reality domain (verify TLS 1.3 beforehand): "
T[prompt_new_reality_domain.ru]="Новый домен для Reality (проверь TLS 1.3 заранее): "

T[empty_input.en]="empty"
T[empty_input.ru]="пусто"

T[domain_already_in_list.en]="'%s' is already in the list"
T[domain_already_in_list.ru]="'%s' уже есть в списке"

T[no_free_internal_ports.en]="no free internal ports"
T[no_free_internal_ports.ru]="нет свободных внутренних портов"

T[domain_added.en]="Domain '%s' added (internal port %s)."
T[domain_added.ru]="Домен '%s' добавлен (внутренний порт %s)."

T[rebuilding_config_and_profiles.en]="Rebuilding config and all client profiles..."
T[rebuilding_config_and_profiles.ru]="Пересобираю конфиг и профили всех клиентов..."

T[domains_primary_not_removable.en]="Domains (the primary one cannot be removed here):"
T[domains_primary_not_removable.ru]="Домены (основной нельзя удалить отсюда):"

T[nothing_to_remove.en]="Nothing to remove (besides the primary domain)."
T[nothing_to_remove.ru]="Нечего удалять (кроме основного)."

T[prompt_number_to_remove.en]="Number to remove: "
T[prompt_number_to_remove.ru]="Номер для удаления: "

T[prompt_delete_domain.en]="Delete domain '%s'? Client profiles will be rebuilt. [y/N] "
T[prompt_delete_domain.ru]="Удалить домен '%s'? Профили клиентов будут пересобраны. [y/N] "

T[domain_removed.en]="Domain '%s' removed."
T[domain_removed.ru]="Домен '%s' удалён."

# ── transport_menu ───────────────────────────────────────────

T[transport_label_direct.en]="direct (straight to the internet, bypassing B)"
T[transport_label_direct.ru]="direct (напрямую, минуя B)"

T[transport_label_hy2.en]="hy2-out (Hysteria2 to B)"
T[transport_label_hy2.ru]="hy2-out (Hysteria2 к B)"

T[transport_label_vless.en]="vless-out-b (VLESS+Reality to B)"
T[transport_label_vless.ru]="vless-out-b (VLESS+Reality к B)"

T[transport_ab_header.en]="A -> B transport (current: %s):"
T[transport_ab_header.ru]="Транспорт A -> B (сейчас: %s):"

T[prompt_choice_1n.en]="Choice [1-%s]: "
T[prompt_choice_1n.ru]="Выбор [1-%s]: "

T[transport_switched.en]="A -> B transport switched to: %s"
T[transport_switched.ru]="Транспорт A -> B переключён на: %s"

# ── edit_client ──────────────────────────────────────────────

T[action_for_owner.en]="Action for '%s':"
T[action_for_owner.ru]="Действие для '%s':"

T[edit_opt_rename_owner.en]="  1) rename owner (all devices)"
T[edit_opt_rename_owner.ru]="  1) переименовать владельца (все устройства)"

T[edit_opt_rename_device.en]="  2) rename device"
T[edit_opt_rename_device.ru]="  2) переименовать устройство"

T[edit_opt_change_transport.en]="  3) change device transport"
T[edit_opt_change_transport.ru]="  3) изменить транспорт устройства"

T[edit_opt_cancel.en]="  0) cancel"
T[edit_opt_cancel.ru]="  0) отмена"

T[prompt_choice_03.en]="Choice [0-3]: "
T[prompt_choice_03.ru]="Выбор [0-3]: "

T[prompt_new_owner_name.en]="New owner name: "
T[prompt_new_owner_name.ru]="Новое имя владельца: "

T[skip_already_exists.en]="  skipping %s: '%s' already exists"
T[skip_already_exists.ru]="  пропуск %s: '%s' уже существует"

T[devices_renamed.en]="Devices renamed: %s"
T[devices_renamed.ru]="Переименовано устройств: %s"

T[prompt_new_device_name.en]="New device name: "
T[prompt_new_device_name.ru]="Новое имя устройства: "

T[current_transport.en]="Current transport: %s"
T[current_transport.ru]="Текущий транспорт: %s"

T[none_word.en]="(none)"
T[none_word.ru]="(нет)"

T[key_already_exists_cancel.en]="'%s' already exists, cancelling"
T[key_already_exists_cancel.ru]="'%s' уже существует, отмена"

T[updated_current_state.en]="Updated. Current state:"
T[updated_current_state.ru]="Обновлено. Текущее состояние:"

# ── emit_client ──────────────────────────────────────────────

T[client_header.en]="=== Client: %s  (profile: %s) ==="
T[client_header.ru]="=== Клиент: %s  (profile: %s) ==="

T[wg_conf_label.en]=".conf (WireGuard app): %s"
T[wg_conf_label.ru]=".conf (WireGuard app): %s"

T[block_wg_endpoint.en]="--- WG endpoint block (sing-box) ---"
T[block_wg_endpoint.ru]="--- блок WG endpoint (sing-box) ---"

T[block_vless_outbound_domain.en]="--- vless outbound block (sing-box) [%s] ---"
T[block_vless_outbound_domain.ru]="--- блок vless outbound (sing-box) [%s] ---"

T[block_outbound_generic.en]="--- %s outbound block (sing-box) ---"
T[block_outbound_generic.ru]="--- блок %s outbound (sing-box) ---"

T[block_urltest.en]="--- urltest (auto) ---"
T[block_urltest.ru]="--- urltest (auto) ---"

T[block_selector.en]="--- selector ---"
T[block_selector.ru]="--- selector ---"

T[profile_url_label.en]="sing-box profile URL:"
T[profile_url_label.ru]="URL-профиль sing-box:"

# ── gen_profile ──────────────────────────────────────────────

T[json_error_modern.en]="  JSON ERROR (modern)"
T[json_error_modern.ru]="  ОШИБКА JSON (modern)"

T[modern_check_failed.en]="  modern failed sing-box check:"
T[modern_check_failed.ru]="  modern не прошёл sing-box check:"

T[json_error_legacy.en]="  JSON ERROR (legacy)"
T[json_error_legacy.ru]="  ОШИБКА JSON (legacy)"

T[both_variants_failed.en]="  Both variants failed to generate, no URL issued."
T[both_variants_failed.ru]="  Оба варианта не сгенерились, URL не выдан."

T[ok_word.en]="OK"
T[ok_word.ru]="OK"

T[failed_see_above.en]="failed (see above)"
T[failed_see_above.ru]="нет (см. выше)"

T[no_word.en]="failed"
T[no_word.ru]="нет"

T[modern_result.en]="  modern: %s"
T[modern_result.ru]="  modern: %s"

T[legacy_result.en]="  legacy: %s"
T[legacy_result.ru]="  legacy: %s"

T[url_ua_label.en]="  URL (auto-selected by User-Agent):"
T[url_ua_label.ru]="  URL (авто по User-Agent):"

T[link_label.en]="  link:"
T[link_label.ru]="  link:"

T[qr_label.en]="  QR:"
T[qr_label.ru]="  QR:"

# ── main menu ────────────────────────────────────────────────

T[main_menu_header.en]="=== VPN manager (A: %s / %s) ==="
T[main_menu_header.ru]="=== VPN manager (A: %s / %s) ==="

T[main_opt_create.en]="1) create client"
T[main_opt_create.ru]="1) создать клиента"

T[main_opt_edit.en]="2) edit client"
T[main_opt_edit.ru]="2) редактировать клиента"

T[main_opt_revoke.en]="3) revoke client"
T[main_opt_revoke.ru]="3) отозвать клиента"

T[main_opt_show.en]="4) show client"
T[main_opt_show.ru]="4) показать клиента"

T[main_opt_service.en]="5) service"
T[main_opt_service.ru]="5) сервис"

T[main_opt_exit.en]="0) exit"
T[main_opt_exit.ru]="0) выход"

T[prompt_choice_05.en]="Choice [0-5]: "
T[prompt_choice_05.ru]="Выбор [0-5]: "

T[bye.en]="Bye!"
T[bye.ru]="Пока!"

T[unknown_option.en]="unknown option"
T[unknown_option.ru]="неизвестный пункт"

# ── missed strings ───────────────────────────────────────────

T[singbox_restarted.en]="sing-box restarted."
T[singbox_restarted.ru]="sing-box перезапущен."

T[client_profiles_rebuilt.en]="Client profiles rebuilt (%s total)."
T[client_profiles_rebuilt.ru]="Клиентские профили пересобраны (%s шт.)."

T[stats_proto_missing.en]="%s not found — statistics unavailable"
T[stats_proto_missing.ru]="нет %s — статистика недоступна"

T[grpcurl_not_installed.en]="grpcurl is not installed"
T[grpcurl_not_installed.ru]="grpcurl не установлен"

T[stats_fetch_failed.en]="failed to fetch statistics (v2ray_api unavailable)"
T[stats_fetch_failed.ru]="не удалось получить статистику (v2ray_api недоступен)"

T[unknown_proxy_type.en]="unknown proxy type: %s"
T[unknown_proxy_type.ru]="неизвестный proxy type: %s"

T[summary_saved.en]="(This summary has also been saved to %s)"
T[summary_saved.ru]="(Эта сводка также сохранена в %s)"

# ── existing B transport choice ─────────────────────────────

T[prompt_b_has_hy2.en]="  Does B support Hysteria2? [Y/n] "
T[prompt_b_has_hy2.ru]="  Поддерживает ли B Hysteria2? [Y/n] "

T[err_no_transport_selected.en]="At least one transport (Hysteria2 or VLESS+Reality) must be selected for B."
T[err_no_transport_selected.ru]="Нужно выбрать хотя бы один транспорт (Hysteria2 или VLESS+Reality) для B."
