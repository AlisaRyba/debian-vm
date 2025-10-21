source /vagrant/scripts/common.sh

setup_journaling_system() {
    log_message "Настройка системы журналирования (RSYSLOG + AUDITD)"
    
    log_message "Установка rsyslog и auditd"
    apt-get update -y
    apt-get install -y rsyslog auditd
    
    mkdir -p /var/log/audit
    log_message "Созданы необходимые директории для логов"
    
    log_message "1: Настройка rsyslog для централизованного сбора логов"
    
    cat > /etc/rsyslog.d/50-journal-categories.conf << 'EOF'
auth.*,authpriv.*                 /var/log/auth.log
& stop

local0.*                          /var/log/myapp.log
& stop

*.crit                            /var/log/critical.log
& stop

kern.*                            /var/log/kernel.log
& stop

mail.*                            /var/log/mail.log
& stop
EOF

    log_message "Созданы правила категоризации логов rsyslog"
    
    cat > /etc/rsyslog.d/60-central-logging.conf << 'EOF'
module(load="imtcp")
input(type="imtcp" port="514" ruleset="remote")

ruleset(name="remote") {
    if ($fromhost-ip startswith "192.168.1.") then {
        action(type="omfile" file="/var/log/remote/secure.log")
        stop
    }
    
    action(type="omfile" file="/var/log/remote/general.log")
    stop
}

template(name="RemoteLogs" type="string" string="/var/log/remote/%FROMHOST%/%PROGRAMNAME%.log")
EOF

    mkdir -p /var/log/remote
    log_message "Настроен централизованный прием логов по TCP порту 514"
    
    systemctl enable rsyslog
    systemctl restart rsyslog
    log_success "Rsyslog настроен и запущен"
    
    log_message "2: Создание правил auditd для мониторинга безопасности"
    
    cat > /etc/audit/rules.d/50-security-monitoring.rules << 'EOF'
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes  
-w /etc/group -p wa -k group_changes
-w /etc/gshadow -p wa -k gshadow_changes

-w /etc/sudoers -p wa -k sudo_config
-w /etc/sudoers.d/ -p wa -k sudo_config_dir
-w /etc/ssh/sshd_config -p wa -k ssh_config

-a always,exit -F arch=b64 -S execve -F euid=0 -k root_commands
-a always,exit -F arch=b32 -S execve -F euid=0 -k root_commands

-a always,exit -F arch=b64 -S chmod -S fchmod -S chown -S fchown -k file_permissions
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k file_deletion

-a always,exit -F arch=b64 -S bind -S connect -k network_activity

-w /sbin/insmod -p x -k module_load
-w /sbin/rmmod -p x -k module_unload
-w /sbin/modprobe -p x -k module_management

-D
EOF
    chmod 600 /etc/audit/rules.d/50-security-monitoring.rules
    log_message "Созданы правила мониторинга безопасности auditd"
    
    augenrules --load
    systemctl enable auditd
    systemctl restart auditd
    log_success "Auditd настроен и запущен"
    
    log_message "3: Настройка анализа и отчетности"
    
    local report_script="/usr/local/bin/security_reports.sh"
    
    cat > "$report_script" << 'EOF'
#!/bin/bash

set -euo pipefail

REPORT_DIR="/var/log/security-reports"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$REPORT_DIR/report_$TIMESTAMP.log"

mkdir -p "$REPORT_DIR"

add_section() {
    echo "" >> "$LOG_FILE"
    echo "=== $1 ===" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Команда '$1' не найдена" >> "$LOG_FILE"
        return 1
    fi
    return 0
}

{
    echo "ОТЧЕТ ПО БЕЗОПАСНОСТИ"
    echo "Время генерации: $(date)"
    echo "Система: $(hostname)"
    echo ""

    add_section "ИЗМЕНЕНИЯ СИСТЕМНЫХ ФАЙЛОВ (последние 24 часа)"
    if check_command "ausearch"; then
        ausearch -k passwd_changes -ts recent 2>/dev/null | head -20 >> "$LOG_FILE" || echo "События не найдены" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        ausearch -k shadow_changes -ts recent 2>/dev/null | head -20 >> "$LOG_FILE" || echo "События не найдены" >> "$LOG_FILE"
    fi

    add_section "СТАТИСТИКА АУТЕНТИФИКАЦИИ"
    if [[ -f "/var/log/auth.log" ]]; then
        echo "Успешные входы:" >> "$LOG_FILE"
        grep "session opened" /var/log/auth.log | wc -l >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        echo "Неудачные попытки:" >> "$LOG_FILE"
        grep "authentication failure" /var/log/auth.log | wc -l >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        echo "Последние неудачные попытки:" >> "$LOG_FILE"
        grep "authentication failure" /var/log/auth.log | tail -5 >> "$LOG_FILE"
    fi

    add_section "ПРИВИЛЕГИРОВАННЫЕ КОМАНДЫ"
    if check_command "ausearch"; then
        ausearch -k root_commands -ts recent 2>/dev/null | head -10 >> "$LOG_FILE" || echo "События не найдены" >> "$LOG_FILE"
    fi

    add_section "ИСПОЛЬЗОВАНИЕ SUDO"
    if [[ -f "/var/log/auth.log" ]]; then
        echo "Команды sudo (последние 10):" >> "$LOG_FILE"
        grep "sudo:" /var/log/auth.log | tail -10 >> "$LOG_FILE"
    fi

    add_section "СТАТИСТИКА AUDITD"
    if check_command "aureport"; then
        aureport --summary >> "$LOG_FILE"
    fi

    echo "" >> "$LOG_FILE"
    echo "Отчет сохранен в: $LOG_FILE"

} >> "$LOG_FILE"

ln -sf "$LOG_FILE" "$REPORT_DIR/latest.log"

echo "Отчет создан: $LOG_FILE"
EOF

    chmod 700 "$report_script"
    log_message "Создан скрипт для генерации отчетов безопасности"
    
    cat > /etc/cron.d/security-reports << 'EOF'
0 2 * * * root /usr/local/bin/security_reports.sh >/dev/null 2>&1

0 3 * * 0 root /usr/local/bin/security_reports.sh >/dev/null 2>&1
EOF

    log_message "Настроено автоматическое создание отчетов по расписанию"

    log_message "4: Интеграция auditd и rsyslog"
    
    cat > /etc/rsyslog.d/70-audit-integration.conf << 'EOF'
if $programname == 'audit' then {
    if $msg contains "passwd_changes" then {
        action(type="omfile" file="/var/log/audit/passwd_changes.log")
        stop
    }
    
    if $msg contains "shadow_changes" then {
        action(type="omfile" file="/var/log/audit/shadow_changes.log")  
        stop
    }
    
    if $msg contains "root_commands" then {
        action(type="omfile" file="/var/log/audit/root_commands.log")
        stop
    }
    
    if $msg contains "ssh_config" then {
        action(type="omfile" file="/var/log/audit/ssh_changes.log")
        stop
    }
    
    action(type="omfile" file="/var/log/audit/general_audit.log")
    stop
}
EOF

    systemctl restart auditd
    systemctl restart rsyslog
    log_success "Настроена интеграция между auditd и rsyslog"
    
    log_message "5: Создание системы оповещений"
    
    local alert_script="/usr/local/bin/security_alerts.sh"
    
    cat > "$alert_script" << 'EOF'
#!/bin/bash

set -euo pipefail

ALERT_LOG="/var/log/security_alerts.log"
CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')

log_alert() {
    echo "[$CURRENT_TIME] $1" >> "$ALERT_LOG"
    logger -t "SECURITY_ALERT" "$1"
}

check_suspicious_activity() {
    local failed_logins=$(grep "authentication failure" /var/log/auth.log 2>/dev/null | wc -l)
    if [[ $failed_logins -gt 10 ]]; then
        log_alert "МНОЖЕСТВЕННЫЕ НЕУДАЧНЫЕ ПОПЫТКИ ВХОДА: $failed_logins попыток"
    fi
    
    local current_hour=$(date +%H)
    if [[ $current_hour -gt 22 || $current_hour -lt 6 ]]; then
        local recent_changes=$(ausearch -k passwd_changes -ts recent 2>/dev/null | wc -l)
        if [[ $recent_changes -gt 0 ]]; then
            log_alert "ИЗМЕНЕНИЯ СИСТЕМНЫХ ФАЙЛОВ В НЕРАБОЧЕЕ ВРЕМЯ"
        fi
    fi
    
    local suspicious_procs=$(ps aux 2>/dev/null | grep -E "(nc |telnet |nmap |nessus)" | grep -v grep | wc -l)
    if [[ $suspicious_procs -gt 0 ]]; then
        log_alert "ОБНАРУЖЕНЫ ПОДОЗРИТЕЛЬНЫЕ ПРОЦЕССЫ СЕТЕВОГО СКАНИРОВАНИЯ"
    fi
    
    local ssh_changes=$(ausearch -k ssh_config -ts recent 2>/dev/null | wc -l)
    if [[ $ssh_changes -gt 0 ]]; then
        log_alert "ОБНАРУЖЕНЫ ИЗМЕНЕНИЯ В КОНФИГУРАЦИИ SSH"
    fi
}

{
    echo "ПРОВЕРКА БЕЗОПАСНОСТИ $CURRENT_TIME"
    check_suspicious_activity
    echo "ПРОВЕРКА ЗАВЕРШЕНА"
} >> "$ALERT_LOG"

tail -1000 "$ALERT_LOG" > "${ALERT_LOG}.tmp" && mv "${ALERT_LOG}.tmp" "$ALERT_LOG"

echo "Проверка безопасности завершена"
EOF

    chmod 700 "$alert_script"
    log_message "Создан скрипт для мониторинга безопасности и оповещений"
    
    cat > /etc/cron.d/security-monitoring << 'EOF'
*/5 * * * * root /usr/local/bin/security_alerts.sh >/dev/null 2>&1

0 * * * * root /usr/local/bin/security_reports.sh >/dev/null 2>&1
EOF

    log_success "Настроена система оповещений о безопасности"
    
    log_message "ТЕСТИРОВАНИЕ СИСТЕМЫ ЖУРНАЛИРОВАНИЯ"
    
    echo "Тестирование rsyslog..."
    logger -p auth.info "TEST: Сообщение аутентификации"
    logger -p local0.notice "TEST: Сообщение кастомного приложения" 
    logger -p crit "TEST: Критическое сообщение"
    
    sleep 2
    
    local log_files=(
        "/var/log/auth.log"
        "/var/log/myapp.log" 
        "/var/log/critical.log"
        "/var/log/audit/audit.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            log_success "Лог-файл создан: $log_file"
        else
            log_warning "Лог-файл не создан: $log_file"
        fi
    done
    
    echo "Проверка правил auditd..."
    if auditctl -l | grep -q "/etc/passwd"; then
        log_success "Правила auditd загружены"
    else
        log_error "Правила auditd не загружены"
    fi
    
    touch /etc/test_audit_file
    rm -f /etc/test_audit_file
    
    echo "Тестирование системы отчетности..."
    "$report_script"
    
    echo "Тестирование системы оповещений..."
    "$alert_script"
    
    echo "Финальная проверка служб:"
    echo "  rsyslog: $(systemctl is-active rsyslog)"
    echo "  auditd: $(systemctl is-active auditd)"
    
    log_success "Система журналирования полностью настроена и протестирована"
}

setup_journaling_system