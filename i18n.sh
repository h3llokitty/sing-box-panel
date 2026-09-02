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

T[rollback_done.en]="Cleanup complete. The installer will continue with a clean installation."
T[rollback_done.ru]="Очистка завершена. Установщик продолжит чистую установку."

T[rollback_binary_kept.en]="(The managed sing-box binary at /usr/local/lib/sing-box-panel/sing-box and the Go toolchain have been left in place — reinstallation will be faster.)"
T[rollback_binary_kept.ru]="(Управляемый бинарный файл sing-box в /usr/local/lib/sing-box-panel/sing-box и Go оставлены без изменений — переустановка пройдёт быстрее.)"

T[done_marker_found.en]="A completed prior installation was detected (dated %s)."
T[done_marker_found.ru]="Обнаружена ранее завершённая установка (от %s)."

T[existing_install_action.en]="What do you want to do?"
T[existing_install_action.ru]="Что вы хотите сделать?"
T[existing_install_update.en]="  1) update files from Git (default)"
T[existing_install_update.ru]="  1) обновить файлы из Git (по умолчанию)"
T[existing_install_reinstall.en]="  2) full reinstall (deletes clients and server secrets)"
T[existing_install_reinstall.ru]="  2) полная переустановка (удалит клиентов и секреты сервера)"
T[existing_install_cancel.en]="  0) cancel"
T[existing_install_cancel.ru]="  0) отмена"
T[prompt_choice_012_default1.en]="Choice [0-2, Enter=1]: "
T[prompt_choice_012_default1.ru]="Выбор [0-2, Enter=1]: "
T[update_started.en]="Updating the existing installation without cleanup..."
T[update_started.ru]="Обновление существующей установки без очистки..."
T[routing_file_found.en]="Existing routing rules file found: %s"
T[routing_file_found.ru]="Найден существующий файл правил маршрутизации: %s"
T[routing_keep_option.en]="  1) keep the current file (default)"
T[routing_keep_option.ru]="  1) оставить текущий файл (по умолчанию)"
T[routing_replace_option.en]="  2) replace it with the standard file from Git"
T[routing_replace_option.ru]="  2) заменить стандартным файлом из Git"
T[prompt_choice_12_default1.en]="Choice [1-2, Enter=1]: "
T[prompt_choice_12_default1.ru]="Выбор [1-2, Enter=1]: "
T[routing_kept.en]="The current server-routing.json was kept."
T[routing_kept.ru]="Текущий server-routing.json сохранён."
T[routing_replaced.en]="server-routing.json was replaced with the standard file from Git."
T[routing_replaced.ru]="server-routing.json заменён стандартным файлом из Git."
T[client_routing_file_found.en]="Existing default client routing file found: %s"
T[client_routing_file_found.ru]="Найден существующий стандартный routing клиентов: %s"
T[client_routing_keep_option.en]="  1) keep the current default client routing (default)"
T[client_routing_keep_option.ru]="  1) оставить текущий стандартный routing клиентов (по умолчанию)"
T[client_routing_replace_option.en]="  2) replace it with the standard file from Git"
T[client_routing_replace_option.ru]="  2) заменить стандартным файлом из Git"
T[client_routing_kept.en]="The current default client routing was kept."
T[client_routing_kept.ru]="Текущий стандартный routing клиентов сохранён."
T[client_routing_replaced.en]="Default client routing was replaced with the standard file from Git."
T[client_routing_replaced.ru]="Стандартный routing клиентов заменён файлом из Git."
T[update_failed_restored.en]="Update failed; previous files were restored from %s"
T[update_failed_restored.ru]="Обновление завершилось ошибкой; предыдущие файлы восстановлены из %s"
T[update_completed.en]="Update completed. Backup: %s"
T[update_completed.ru]="Обновление завершено. Резервная копия: %s"

T[done_marker_warning.en]="Reinstalling will delete all existing clients and all server secrets."
T[done_marker_warning.ru]="Переустановка приведёт к удалению всех существующих клиентов и всех секретов сервера."

T[confirm_reinstall.en]="Are you sure you want to reinstall from scratch? [y/N] "
T[confirm_reinstall.ru]="Вы уверены, что хотите переустановить систему с нуля? [y/N] "

T[reinstall_cancelled.en]="Cancelled. Use /opt/vpn/sb-panel to manage clients."
T[reinstall_cancelled.ru]="Отменено. Для управления клиентами используйте /opt/vpn/sb-panel."

T[reinstall_proceeding.en]="Proceeding — removing the current installation before reinstalling..."
T[reinstall_proceeding.ru]="Продолжение — удаление текущей установки перед переустановкой..."

T[resuming_incomplete_install.en]="An incomplete prior installation was detected — completed steps will be reused."
T[resuming_incomplete_install.ru]="Обнаружена незавершённая установка — завершённые шаги будут использованы повторно."

T[tmux_offer.en]="Run the installation in a persistent tmux session? [Y/n] "
T[tmux_offer.ru]="Запустить установку в устойчивой tmux-сессии? [Y/n] "
T[tmux_installing.en]="Installing tmux (SSH services will not be restarted)..."
T[tmux_installing.ru]="Установка tmux (SSH-службы не будут перезапускаться)..."
T[tmux_attach_hint.en]="If SSH disconnects, reconnect and resume with:"
T[tmux_attach_hint.ru]="Если SSH отключится, подключитесь снова и продолжите командой:"
T[install_paused.en]="Installation stopped after completed step %s. Existing results were kept."
T[install_paused.ru]="Установка остановилась после завершённого шага %s. Полученные результаты сохранены."
T[install_resume_command.en]="Run the same install.sh again; it will resume from the next incomplete step."
T[install_resume_command.ru]="Снова запустите тот же install.sh: работа продолжится с ближайшего незавершённого шага."
T[step_skipped.en]="Step %s is already complete — reusing it."
T[step_skipped.ru]="Шаг %s уже завершён — использую его результат."

T[build_failed.en]="The sing-box build failed; aborting installation."
T[build_failed.ru]="Сборка sing-box завершилась ошибкой; установка прервана."

T[v2ray_api_missing.en]="with_v2ray_api was not found in the build!"
T[v2ray_api_missing.ru]="Тег with_v2ray_api не найден в собранной версии!"

T[build_success.en]="sing-box was built successfully."
T[build_success.ru]="Сборка sing-box завершена успешно."
T[build_reused.en]="Using the existing verified sing-box build for revision %s."
T[build_reused.ru]="Используется существующая проверенная сборка sing-box ревизии %s."
T[build_checkpoint_invalid.en]="The saved sing-box build does not match its revision/SHA-256 checkpoint; rebuilding it."
T[build_checkpoint_invalid.ru]="Сохранённая сборка sing-box не совпадает с контрольной точкой ревизии/SHA-256; выполняется повторная сборка."
T[generated_b_reused.en]="Using the existing generated server B installer: %s"
T[generated_b_reused.ru]="Используется уже созданный установщик сервера B: %s"
T[generated_warp_reused.en]="Using the existing generated WARP installer: %s"
T[generated_warp_reused.ru]="Используется уже созданный установщик WARP: %s"
T[singbox_runtime_label.en]="  sing-box: %s (revision %s)"
T[singbox_runtime_label.ru]="  sing-box: %s (ревизия %s)"
T[singbox_b_same_binary.en]="Server B will install the exact same verified sing-box binary."
T[singbox_b_same_binary.ru]="Сервер B установит тот же самый проверенный бинарный файл sing-box."

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

T[ru_rules_question.en]="Use the standard rules for Russian resources (.ru/.su/.рф/.xn--p1ai and geoip-ru)?"
T[ru_rules_question.ru]="Использовать стандартные правила для российских ресурсов (.ru/.su/.рф/.xn--p1ai и geoip-ru)?"

T[ru_rules_disabled_option.en]="  1) no (default)"
T[ru_rules_disabled_option.ru]="  1) нет (по умолчанию)"

T[ru_rules_enabled_option.en]="  2) yes"
T[ru_rules_enabled_option.ru]="  2) да"

T[ruleset_intro.en]="Rule-set source (the base URL must contain geoip/ and geosite/ directories):"
T[ruleset_intro.ru]="Источник rule-set (базовый URL должен содержать каталоги geoip/ и geosite/):"

T[prompt_ruleset_base.en]="  Rule-set base URL [%s]: "
T[prompt_ruleset_base.ru]="  Базовый URL rule-set [%s]: "

T[ruleset_base_invalid.en]="Invalid URL. Enter a domain or an HTTPS URL without a query or fragment."
T[ruleset_base_invalid.ru]="Некорректный URL. Укажите домен или HTTPS URL без query-параметров и фрагмента."

T[ruleset_checking_existing.en]="Checking the required rule-set files..."
T[ruleset_checking_existing.ru]="Проверка обязательных файлов rule-set..."

T[ruleset_existing_ready.en]="The rule-set source is available."
T[ruleset_existing_ready.ru]="Источник rule-set доступен."

T[ruleset_existing_retry.en]="The rule-set source is unavailable or incomplete. Enter another URL."
T[ruleset_existing_retry.ru]="Источник rule-set недоступен или неполон. Укажите другой URL."

T[ruleset_file_unavailable.en]="Required rule-set file is unavailable: %s"
T[ruleset_file_unavailable.ru]="Недоступен обязательный файл rule-set: %s"

T[ruleset_file_invalid.en]="The downloaded rule-set file is not a valid sing-box binary rule set: %s"
T[ruleset_file_invalid.ru]="Загруженный файл не является корректным бинарным rule-set sing-box: %s"

T[config_written.en]="Configuration written to %s"
T[config_written.ru]="Конфигурация записана в %s"

T[initial_b_route_direct.en]="The initial A -> B route is set to direct until the transports to server B are verified."
T[initial_b_route_direct.ru]="Начальный маршрут A -> B установлен в direct до проверки транспортов к серверу B."

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

T[b_dns_mismatch.en]="DNS check failed for server B. Domain: %s; resolved IP: %s; this server's IPv4: %s. Fix the A record and run this installer again."
T[b_dns_mismatch.ru]="Проверка DNS сервера B не пройдена. Домен: %s; IP в DNS: %s; IPv4 этого сервера: %s. Исправьте A-запись и снова запустите установщик."

T[b_service_failed.en]="sing-box failed to start on server B. Recent service logs follow."
T[b_service_failed.ru]="sing-box не запустился на сервере B. Ниже последние записи журнала службы."

T[b_configured.en]="Server B has been configured."
T[b_configured.ru]="Сервер B настроен."

T[b_domain_label.en]="  Domain: %s"
T[b_domain_label.ru]="  Домен: %s"

T[b_port_label.en]="  Port:   %s (Hysteria2 + VLESS+Reality on a single port, TCP/UDP)"
T[b_port_label.ru]="  Порт:   %s (Hysteria2 + VLESS+Reality на одном порту, TCP/UDP)"

T[b_dns_reminder.en]="Please ensure DNS for %s points to this server, and that port %s (TCP+UDP) and port 80/TCP (for ACME) are open in the firewall."
T[b_dns_reminder.ru]="Убедитесь, что DNS для %s указывает на этот сервер, и что порт %s (TCP+UDP) и порт 80/TCP (для ACME) открыты в фаерволе."

T[b_verify_from_a_reminder1.en]="Return to server A and test both A -> B transports before creating clients:"
T[b_verify_from_a_reminder1.ru]="Вернитесь на сервер A и проверьте оба транспорта A -> B до создания клиентов:"

T[b_verify_from_a_reminder2.en]="  /opt/vpn/sb-panel -> 5 -> 6 -> 3"
T[b_verify_from_a_reminder2.ru]="  /opt/vpn/sb-panel -> 5 -> 6 -> 3"


# ── final instructions ──────────────────────────────────────

T[final_notice.en]="Installation complete. The services and installer links have been verified."
T[final_notice.ru]="Установка завершена. Службы и ссылки установщиков проверены."

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

T[final_step2_header.en]="2) Create the first client to start using the VPN:"
T[final_step2_header.ru]="2) Создайте первого клиента, чтобы начать пользоваться VPN:"

T[final_step4_header.en]="4) Create the first client after a working A -> B transport has been selected:"
T[final_step4_header.ru]="4) Создайте первого клиента после выбора рабочего транспорта A -> B:"

T[final_step2_body1.en]="   Profile delivery is already available on port %s."
T[final_step2_body1.ru]="   Раздача профилей уже доступна на порту %s."

T[final_step2_body2.en]="   Open the manager and choose client creation:"
T[final_step2_body2.ru]="   Откройте менеджер и выберите создание клиента:"

T[final_step2_cmd1.en]="   /opt/vpn/sb-panel"
T[final_step2_cmd1.ru]="   /opt/vpn/sb-panel"

T[final_step2_cmd2.en]="   -> 1 (create client)"
T[final_step2_cmd2.ru]="   -> 1 (создать клиента)"

T[final_step2_check1.en]="   Optional service check: systemctl status sing-box ; systemctl status nginx"
T[final_step2_check1.ru]="   При необходимости проверьте службы: systemctl status sing-box ; systemctl status nginx"

T[final_step2_check2.en]="   The installation stops with diagnostics if either service is unavailable."
T[final_step2_check2.ru]="   Если одна из служб недоступна, установка остановится и покажет диагностику."

T[final_management.en]="Management: /opt/vpn/sb-panel"
T[final_management.ru]="Управление: /opt/vpn/sb-panel"

T[final_config_label.en]="Server configuration: %s"
T[final_config_label.ru]="Конфигурация сервера: %s"

T[final_b_reminder_header.en]="Don't forget to deploy server B after configuring its DNS and opening its ports:"
T[final_b_reminder_header.ru]="Не забудьте развернуть сервер B после настройки его DNS и открытия его портов:"

T[final_b_step_header.en]="2) Deploy server B after configuring its DNS and opening its ports:"
T[final_b_step_header.ru]="2) Разверните сервер B после настройки его DNS и открытия его портов:"

T[final_b_verify_header.en]="3) Return to server A, test both transports and select a working route:"
T[final_b_verify_header.ru]="3) Вернитесь на сервер A, проверьте оба транспорта и выберите рабочий маршрут:"

T[final_b_verify_cmd1.en]="   /opt/vpn/sb-panel"
T[final_b_verify_cmd1.ru]="   /opt/vpn/sb-panel"

T[final_b_verify_cmd2.en]="   -> 5 -> 6 -> 3"
T[final_b_verify_cmd2.ru]="   -> 5 -> 6 -> 3"

T[final_b_reminder_run1.en]="Run this on server B itself (after configuring DNS for %s"
T[final_b_reminder_run1.ru]="Выполните это на самом сервере B (после настройки DNS для %s"

T[final_b_reminder_run2.en]="and opening ports %s TCP+UDP, 80 TCP on it)."
T[final_b_reminder_run2.ru]="и открытия портов %s TCP+UDP, 80 TCP на нём)."

T[final_warp_header.en]="Optional: install Cloudflare WARP on server A:"
T[final_warp_header.ru]="Опционально: установите Cloudflare WARP на сервер A:"

T[final_warp_note.en]="The script adds a verified WARP IPv4 outbound. Select its route later in menu 5 -> 6."
T[final_warp_note.ru]="Скрипт добавит проверенный WARP IPv4 outbound. Маршрут выберите позже в меню 5 -> 6."

T[existing_b_transport_warning.en]="No working transport to the existing server B was found. A -> B remains direct; fix connectivity and repeat the test in menu 5 -> 6 -> 3."
T[existing_b_transport_warning.ru]="Рабочий транспорт к существующему серверу B не найден. A -> B остаётся direct; исправьте связность и повторите проверку в меню 5 -> 6 -> 3."

T[generated_b_transport_pending.en]="Server B has not been deployed yet. A -> B remains direct; after deploying B, run the transport test in menu 5 -> 6 -> 3."
T[generated_b_transport_pending.ru]="Сервер B ещё не развёрнут. A -> B остаётся direct; после установки B запустите проверку транспортов в меню 5 -> 6 -> 3."

# ── install-warp.sh ─────────────────────────────────────────

T[warp_language_title.en]="Select language / Выберите язык:"
T[warp_language_title.ru]="Select language / Выберите язык:"
T[warp_language_en.en]="  1) English (default)"
T[warp_language_en.ru]="  1) English (по умолчанию)"
T[warp_language_ru.en]="  2) Русский"
T[warp_language_ru.ru]="  2) Русский"
T[warp_language_prompt.en]="[1-2, Enter=1]: "
T[warp_language_prompt.ru]="[1-2, Enter=1]: "
T[warp_root_required.en]="Run this script as root."
T[warp_root_required.ru]="Запустите этот скрипт от имени root."
T[warp_panel_missing.en]="sing-box-panel is not installed on this server."
T[warp_panel_missing.ru]="На этом сервере не установлен sing-box-panel."
T[warp_tag_prompt.en]="sing-box outbound tag [WARP]: "
T[warp_tag_prompt.ru]="Тег аутбаунда sing-box [WARP]: "
T[warp_tag_invalid.en]="Invalid tag. Use only letters, digits, _ and -."
T[warp_tag_invalid.ru]="Недопустимый тег. Используйте только латинские буквы, цифры, _ и -."
T[warp_tag_reserved.en]="Tag %s is reserved by sing-box-panel. Choose another tag."
T[warp_tag_reserved.ru]="Тег %s зарезервирован sing-box-panel. Выберите другой тег."
T[warp_port_prompt.en]="Local WARP SOCKS5 port [40000]: "
T[warp_port_prompt.ru]="Локальный порт WARP SOCKS5 [40000]: "
T[warp_port_invalid.en]="Invalid port."
T[warp_port_invalid.ru]="Недопустимый порт."
T[warp_registration_unavailable.en]="Cloudflare registration API is unavailable from this server."
T[warp_registration_unavailable.ru]="API регистрации Cloudflare недоступен с этого сервера."
T[warp_external_offer.en]="Use another computer as a temporary connection for registration? [Y/n] "
T[warp_external_offer.ru]="Использовать другой компьютер как временное подключение для регистрации? [Y/n] "
T[warp_external_port_prompt.en]="Temporary reverse SOCKS port [41080]: "
T[warp_external_port_prompt.ru]="Порт временного reverse SOCKS [41080]: "
T[warp_external_server_ip_missing.en]="Could not read the server IP from vpn-panel.env."
T[warp_external_server_ip_missing.ru]="Не удалось прочитать IP сервера из vpn-panel.env."
T[warp_external_command_intro.en]="On another computer, open a separate terminal and run:"
T[warp_external_command_intro.ru]="На другом компьютере откройте отдельный терминал и выполните:"
T[warp_external_command_note.en]="This command works in macOS Terminal, Linux shell, and Windows PowerShell with OpenSSH. Keep it running."
T[warp_external_command_note.ru]="Команда работает в macOS Terminal, Linux shell и Windows PowerShell с OpenSSH. Оставьте её запущенной."
T[warp_external_ready_prompt.en]="Press Enter here when the tunnel is ready: "
T[warp_external_ready_prompt.ru]="Когда туннель будет готов, нажмите здесь Enter: "
T[warp_external_listener_missing.en]="Reverse SOCKS listener did not appear on 127.0.0.1:%s."
T[warp_external_listener_missing.ru]="Reverse SOCKS не появился на 127.0.0.1:%s."
T[warp_external_proxy_failed.en]="The temporary connection through the other computer is not working."
T[warp_external_proxy_failed.ru]="Временное подключение через другой компьютер не работает."
T[warp_external_same_ip.en]="The temporary connection uses the same IP as the server; registration would fail again."
T[warp_external_same_ip.ru]="Временное подключение использует тот же IP, что и сервер; регистрация снова завершится ошибкой."
T[warp_external_ips.en]="Direct server IP: %s; temporary exit IP: %s"
T[warp_external_ips.ru]="Прямой IP сервера: %s; временный выходной IP: %s"
T[warp_external_proxychains_missing.en]="The proxychains library was not found after installation."
T[warp_external_proxychains_missing.ru]="После установки не найдена библиотека proxychains."
T[warp_external_dropin_exists.en]="Temporary WARP registration drop-in already exists: %s"
T[warp_external_dropin_exists.ru]="Временный drop-in регистрации WARP уже существует: %s"
T[warp_external_registration_failed.en]="WARP registration through the other computer failed."
T[warp_external_registration_failed.ru]="Регистрация WARP через другой компьютер завершилась ошибкой."
T[warp_external_registration_done.en]="WARP registration succeeded. You can now stop the SSH tunnel on the other computer with Ctrl+C."
T[warp_external_registration_done.ru]="Регистрация WARP выполнена. Теперь можно остановить SSH-туннель на другом компьютере сочетанием Ctrl+C."

T[warp_registration_external.en]="Register through an external connection, then run this script again."
T[warp_registration_external.ru]="Выполните регистрацию через внешнее подключение, затем запустите этот скрипт снова."
T[warp_registration_docs.en]="Official instructions: %s"
T[warp_registration_docs.ru]="Официальная инструкция: %s"
T[warp_registration_step1.en]="1. Give this server temporary Internet access through another connection and run: warp-cli --accept-tos registration new"
T[warp_registration_step1.ru]="1. Дайте серверу временный доступ в интернет через другое подключение и выполните: warp-cli --accept-tos registration new"
T[warp_registration_step2.en]="2. After registration succeeds, run this WARP installer again."
T[warp_registration_step2.ru]="2. После успешной регистрации снова запустите этот установщик WARP."
T[warp_connect_failed.en]="WARP did not connect."
T[warp_connect_failed.ru]="WARP не подключился."
T[warp_listener_missing.en]="WARP SOCKS5 listener did not appear on 127.0.0.1:%s."
T[warp_listener_missing.ru]="Слушатель WARP SOCKS5 не появился на 127.0.0.1:%s."
T[warp_health_off.en]="WARP health check failed: warp=on was not returned."
T[warp_health_off.ru]="Проверка WARP не пройдена: ответ не содержит warp=on."
T[warp_health_no_ipv4.en]="WARP health check did not return an IPv4 address."
T[warp_health_no_ipv4.ru]="Проверка WARP не вернула IPv4-адрес."
T[warp_rebuild_failed.en]="sing-box rebuild failed; the previous configuration was restored from %s"
T[warp_rebuild_failed.ru]="Не удалось пересобрать sing-box; предыдущая конфигурация восстановлена из %s"
T[warp_ready.en]="WARP is ready."
T[warp_ready.ru]="WARP готов."
T[warp_result_tag.en]="  outbound tag: %s"
T[warp_result_tag.ru]="  тег аутбаунда: %s"
T[warp_result_socks.en]="  SOCKS5:       127.0.0.1:%s"
T[warp_result_socks.ru]="  SOCKS5:       127.0.0.1:%s"
T[warp_result_ipv4.en]="  WARP IPv4:    %s"
T[warp_result_ipv4.ru]="  WARP IPv4:    %s"
T[warp_result_backup.en]="  backup:       %s"
T[warp_result_backup.ru]="  резервная копия: %s"

# ── write_nginx_stream ──────────────────────────────────────

T[cert_not_ready_yet.en]="Certificate for %s has not been issued by ACME yet — nginx will restart automatically once it appears (see nginx-cert-reload.path)."
T[cert_not_ready_yet.ru]="Сертификат для %s ещё не выпущен через ACME — nginx перезапустится автоматически, как только он появится (см. nginx-cert-reload.path)."

# ── vpn-setup.sh startup ────────────────────────────────────

T[config_not_found.en]="config.env not found (looked in: %s)"
T[config_not_found.ru]="Не найден config.env (искал: %s)"

T[config_not_found_hint.en]="Copy config.env.example to config.env and fill in your values."
T[config_not_found_hint.ru]="Скопируйте config.env.example в config.env и заполните своими значениями."

T[invalid_warp_tag.en]="Invalid WARP tag: use only letters, digits, _ and -."
T[invalid_warp_tag.ru]="Недопустимый тег WARP: используйте только латинские буквы, цифры, _ и -."
T[server_config_check_failed.en]="Server configuration check failed; the active configuration was not changed."
T[server_config_check_failed.ru]="Проверка конфигурации сервера не пройдена; активная конфигурация не изменена."
T[config_ok.en]="Configuration is valid."
T[config_ok.ru]="Конфигурация корректна."


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

T[wg_profile_mode_header.en]="WireGuard in sing-box JSON profiles:"
T[wg_profile_mode_header.ru]="WireGuard в JSON-профилях sing-box:"

T[wg_profile_mode_disabled.en]="  1) do not include (the standalone WireGuard .conf remains available)"
T[wg_profile_mode_disabled.ru]="  1) не включать (отдельный WireGuard .conf останется доступен)"

T[wg_profile_mode_selector.en]="  2) include in Select, but exclude from Auto (urltest)"
T[wg_profile_mode_selector.ru]="  2) включить в Select, но исключить из Auto (urltest)"

T[wg_profile_mode_urltest.en]="  3) include in Select and Auto (urltest)"
T[wg_profile_mode_urltest.ru]="  3) включить в Select и Auto (urltest)"

T[prompt_choice_13_default.en]="Choice [1-3, Enter=%s]: "
T[prompt_choice_13_default.ru]="Выбор [1-3, Enter=%s]: "

T[wg_profile_mode_label.en]="WireGuard in sing-box JSON: %s"
T[wg_profile_mode_label.ru]="WireGuard в JSON sing-box: %s"

T[wg_profile_mode_disabled_short.en]="not included"
T[wg_profile_mode_disabled_short.ru]="не включён"
T[wg_profile_mode_selector_short.en]="Select only (excluded from Auto)"
T[wg_profile_mode_selector_short.ru]="только Select (исключён из Auto)"
T[wg_profile_mode_urltest_short.en]="Select and Auto"
T[wg_profile_mode_urltest_short.ru]="Select и Auto"

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

T[svc_opt_transport.en]="  6) manage routing"
T[svc_opt_transport.ru]="  6) управление маршрутизацией"

T[svc_opt_reality.en]="  7) manage Reality domains"
T[svc_opt_reality.ru]="  7) управление Reality-доменами"

T[svc_opt_rebuild_profiles.en]="  8) rebuild remote client profiles (no service restart)"
T[svc_opt_rebuild_profiles.ru]="  8) пересобрать remote-профили клиентов (без перезапуска сервисов)"

T[prompt_choice_18.en]="Choice [1-8]: "
T[prompt_choice_18.ru]="Выбор [1-8]: "

T[prompt_device_number.en]="Device number: "
T[prompt_device_number.ru]="Номер устройства: "

T[no_requests_found.en]="No requests found."
T[no_requests_found.ru]="Обращений не найдено."

T[version_stats_header.en]="Version statistics (known client profiles):"
T[version_stats_header.ru]="Статистика по версиям (известные профили клиентов):"

T[version_stats_row.en]="  %s: %d profile(s), %d request(s)"
T[version_stats_row.ru]="  %s: профилей — %d, запросов — %d"

T[version_stats_no_data.en]="  No requests from known client profiles."
T[version_stats_no_data.ru]="  Запросов от известных профилей клиентов нет."

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

# ── routing_menu ─────────────────────────────────────────────

T[routing_header.en]="Routing:"
T[routing_header.ru]="Маршрутизация:"
T[routing_opt_ab.en]="  1) A -> B route"
T[routing_opt_ab.ru]="  1) маршрут A -> B"
T[routing_opt_direct_rules.en]="  2) route for direct rules (.ru/.su/.рф and geoip-ru)"
T[routing_opt_direct_rules.ru]="  2) маршрут direct-правил (.ru/.su/.рф и geoip-ru)"
T[routing_opt_test_ab.en]="  3) test A -> B transports"
T[routing_opt_test_ab.ru]="  3) проверить транспорты A -> B"
T[direct_rules_header.en]="Route for direct rules (current: %s):"
T[direct_rules_header.ru]="Маршрут direct-правил (сейчас: %s):"
T[direct_rules_label_direct.en]="direct (server A)"
T[direct_rules_label_direct.ru]="direct (сервер A)"
T[direct_rules_label_warp.en]="%s (Cloudflare WARP)"
T[direct_rules_label_warp.ru]="%s (Cloudflare WARP)"
T[direct_rules_switched.en]="Route for direct rules switched to: %s"
T[direct_rules_switched.ru]="Маршрут direct-правил переключён на: %s"

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

# ── A -> B transport diagnostics ────────────────────────────

T[transport_test_header.en]="A -> B transport test (the active sing-box service will not be restarted):"
T[transport_test_header.ru]="Проверка транспортов A -> B (активный sing-box не будет перезапущен):"
T[transport_test_dns_ok.en]="  DNS: OK — %s -> %s"
T[transport_test_dns_ok.ru]="  DNS: OK — %s -> %s"
T[transport_test_dns_failed.en]="  DNS: FAIL — %s was not resolved"
T[transport_test_dns_failed.ru]="  DNS: ОШИБКА — %s не разрешается"
T[transport_test_tcp_ok.en]="  TCP %s:%s: OK"
T[transport_test_tcp_ok.ru]="  TCP %s:%s: OK"
T[transport_test_tcp_failed.en]="  TCP %s:%s: FAIL — connection timeout or rejection"
T[transport_test_tcp_failed.ru]="  TCP %s:%s: ОШИБКА — таймаут или отказ соединения"
T[transport_test_label_hy2.en]="Hysteria2"
T[transport_test_label_hy2.ru]="Hysteria2"
T[transport_test_label_vless.en]="VLESS/Reality"
T[transport_test_label_vless.ru]="VLESS/Reality"
T[transport_test_result_ok.en]="  %s: OK — HTTP 204 in %s s"
T[transport_test_result_ok.ru]="  %s: OK — HTTP 204 за %s с"
T[transport_test_result_failed.en]="  %s: FAIL — %s"
T[transport_test_result_failed.ru]="  %s: ОШИБКА — %s"
T[transport_test_result_invalid.en]="  %s: FAIL — the isolated test configuration is invalid"
T[transport_test_result_invalid.ru]="  %s: ОШИБКА — изолированный тестовый конфиг невалиден"
T[transport_test_result_start_failed.en]="  %s: FAIL — the isolated test process did not start: %s"
T[transport_test_result_start_failed.ru]="  %s: ОШИБКА — изолированный тестовый процесс не запустился: %s"
T[transport_test_no_details.en]="no diagnostic details"
T[transport_test_no_details.ru]="нет диагностических подробностей"
T[transport_test_hy2_missing.en]="  Hysteria2: SKIP — hy2-out is not configured"
T[transport_test_hy2_missing.ru]="  Hysteria2: ПРОПУСК — hy2-out не настроен"
T[transport_test_vless_missing.en]="  VLESS/Reality: SKIP — vless-out-b is not configured"
T[transport_test_vless_missing.ru]="  VLESS/Reality: ПРОПУСК — vless-out-b не настроен"
T[transport_test_tcp_explanation1.en]="  VLESS/Reality was not reached: TCP traffic is blocked before server B."
T[transport_test_tcp_explanation1.ru]="  До VLESS/Reality соединение не дошло: TCP блокируется до сервера B."
T[transport_test_tcp_explanation2.en]="  Changing Reality keys will not fix this network-path failure."
T[transport_test_tcp_explanation2.ru]="  Смена Reality-ключей не исправит эту сетевую проблему."
T[transport_test_none_working.en]="No working A -> B transport was found. The route was not changed."
T[transport_test_none_working.ru]="Рабочих транспортов A -> B не найдено. Маршрут не изменён."
T[transport_test_current_ok.en]="Current A -> B transport is working: %s"
T[transport_test_current_ok.ru]="Текущий транспорт A -> B работает: %s"
T[transport_test_recommended.en]="Recommended A -> B transport: %s"
T[transport_test_recommended.ru]="Рекомендуемый транспорт A -> B: %s"
T[transport_test_switch_prompt.en]="Switch A -> B to %s? [Y/n] "
T[transport_test_switch_prompt.ru]="Переключить A -> B на %s? [Y/n] "
T[b_bootstrap_revoke_prompt.en]="Both B transports work. Remove the published B installer and binary now? [Y/n] "
T[b_bootstrap_revoke_prompt.ru]="Оба транспорта B работают. Удалить опубликованные установщик B и бинарный файл? [Y/n] "
T[b_bootstrap_revoked.en]="The server B bootstrap files have been removed from profile delivery."
T[b_bootstrap_revoked.ru]="Файлы первичной установки сервера B удалены из раздачи профилей."

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

T[client_routing_label.en]="Client routing: %s"
T[client_routing_label.ru]="Routing клиента: %s"
T[client_outbounds_label.en]="Client outbounds: %s"
T[client_outbounds_label.ru]="Outbounds клиента: %s"
T[rendered_client_outbounds.en]="Resolved endpoints and outbounds:"
T[rendered_client_outbounds.ru]="Итоговые endpoints и outbounds:"

T[client_routing_invalid_shape.en]="client routing: rule_set and rules must be arrays"
T[client_routing_invalid_shape.ru]="routing клиента: rule_set и rules должны быть массивами"

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
T[legacy_validator_missing.en]="  legacy validation unavailable: pinned sing-box 1.11.15 is not installed"
T[legacy_validator_missing.ru]="  проверка legacy недоступна: закреплённый sing-box 1.11.15 не установлен"
T[legacy_check_failed.en]="  legacy failed sing-box 1.11.15 check:"
T[legacy_check_failed.ru]="  legacy не прошёл проверку sing-box 1.11.15:"
T[legacy_validator_installing.en]="Installing the pinned sing-box 1.11.15 legacy profile validator..."
T[legacy_validator_installing.ru]="Установка закреплённого валидатора legacy-профилей sing-box 1.11.15..."
T[legacy_validator_ready.en]="Legacy profile validator is ready: sing-box %s"
T[legacy_validator_ready.ru]="Валидатор legacy-профилей готов: sing-box %s"
T[legacy_validator_arch_unsupported.en]="The legacy validator does not support architecture: %s"
T[legacy_validator_arch_unsupported.ru]="Архитектура не поддерживается валидатором legacy: %s"
T[legacy_validator_checksum_failed.en]="Legacy validator archive checksum verification failed."
T[legacy_validator_checksum_failed.ru]="Не совпала контрольная сумма архива валидатора legacy."

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
T[client_layout_migrated.en]="Client directories migrated (%s): %s"
T[client_layout_migrated.ru]="Каталоги клиентов перенесены (%s): %s"
T[client_layout_conflict.en]="Client directory migration stopped: '%s' conflicts with '%s'."
T[client_layout_conflict.ru]="Перенос каталогов клиентов остановлен: '%s' конфликтует с '%s'."
T[client_layout_invalid_owner.en]="Client directory migration stopped: invalid or missing NAME in %s."
T[client_layout_invalid_owner.ru]="Перенос каталогов клиентов остановлен: некорректный или отсутствующий NAME в %s."

T[profiles_rebuild_header.en]="Rebuilding remote client profiles:"
T[profiles_rebuild_header.ru]="Пересборка remote-профилей клиентов:"
T[profile_rebuild_ok.en]="  %s: OK"
T[profile_rebuild_ok.ru]="  %s: OK"
T[profile_rebuild_failed.en]="  %s: FAILED; previously published profiles were kept"
T[profile_rebuild_failed.ru]="  %s: ОШИБКА; ранее опубликованные профили сохранены"
T[profiles_rebuild_summary.en]="Done: %s of %s clients."
T[profiles_rebuild_summary.ru]="Готово: %s из %s клиентов."
T[profiles_rebuild_no_restart.en]="sing-box and nginx were not restarted."
T[profiles_rebuild_no_restart.ru]="sing-box и nginx не перезапускались."

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

T[cert_not_ready_yet_install.en]="(TLS certificate not issued yet — nginx will start automatically after the first client is created; see step 2 below)"
T[cert_not_ready_yet_install.ru]="(TLS-сертификат ещё не выпущен — nginx запустится автоматически после создания первого клиента; см. шаг 2 ниже)"

T[done_step.en]="DONE"
T[done_step.ru]="ГОТОВО"

# ── step headers (restored) ─────────────────────────────────

T[step1.en]="1/9 — base packages"
T[step1.ru]="1/9 — базовые пакеты"

T[step2.en]="2/9 — installing Go (required to build sing-box)"
T[step2.ru]="2/9 — установка Go (требуется для сборки sing-box)"

T[step3.en]="3/9 — building sing-box from source (with_v2ray_api) — this will take a few minutes"
T[step3.ru]="3/9 — сборка sing-box из исходного кода (with_v2ray_api) — это займёт несколько минут"

T[build_revision_mismatch.en]="The checked-out sing-box source revision does not match the required revision."
T[build_revision_mismatch.ru]="Версия исходного кода sing-box не совпадает с требуемой ревизией."

T[step4.en]="4/9 — installing grpcurl"
T[step4.ru]="4/9 — установка grpcurl"

T[step5.en]="5/9 — systemd unit for sing-box"
T[step5.ru]="5/9 — systemd-юнит для sing-box"

T[step6.en]="6/9 — server parameters"
T[step6.ru]="6/9 — параметры сервера"

T[step7.en]="7/9 — DNS check"
T[step7.ru]="7/9 — проверка DNS"

T[step8.en]="8/9 — copying templates and management script"
T[step8.ru]="8/9 — копирование шаблонов и скрипта управления"

T[step9.en]="9/9 — nginx for profile delivery + cron"
T[step9.ru]="9/9 — nginx для раздачи профилей и cron"

T[building_initial_config.en]="Building and validating the initial sing-box configuration..."
T[building_initial_config.ru]="Сборка и проверка начальной конфигурации sing-box..."

T[singbox_start_failed.en]="sing-box failed to start. Recent service logs follow."
T[singbox_start_failed.ru]="sing-box не запустился. Ниже последние записи журнала службы."

T[waiting_for_certificate.en]="Waiting for the TLS certificate..."
T[waiting_for_certificate.ru]="Ожидание TLS-сертификата..."

T[certificate_wait_failed.en]="The TLS certificate was not issued in time. Check DNS, ports 80/443, and the logs below."
T[certificate_wait_failed.ru]="TLS-сертификат не был выпущен вовремя. Проверьте DNS, порты 80/443 и журнал ниже."

T[nginx_start_failed.en]="nginx failed to start. Recent service logs follow."
T[nginx_start_failed.ru]="nginx не запустился. Ниже последние записи журнала службы."

T[installer_publish_check_failed.en]="The generated server B installer could not be retrieved through the published HTTPS URL."
T[installer_publish_check_failed.ru]="Сгенерированный установщик сервера B не удалось получить по опубликованной HTTPS-ссылке."

T[installer_publish_ready.en]="The published server B installer link has been verified."
T[installer_publish_ready.ru]="Опубликованная ссылка установщика сервера B проверена."
T[binary_publish_check_failed.en]="The verified sing-box binary for server B could not be retrieved through the published HTTPS URL."
T[binary_publish_check_failed.ru]="Проверенный бинарный файл sing-box для сервера B не удалось получить по опубликованной HTTPS-ссылке."
T[binary_publish_ready.en]="The published sing-box binary for server B has been verified by SHA-256."
T[binary_publish_ready.ru]="Опубликованный бинарный файл sing-box для сервера B проверен по SHA-256."
