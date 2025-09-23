CONFIG="/etc/kernel-security/config.cfg"
LOG_DIR="/etc/kernel-security/logs"
REPORT_DIR="/etc/kernel-security/reports"
ACTIONS_DIR="/etc/kernel-security/actions"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

[ -f "$CONFIG" ] && source "$CONFIG"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/security-$(date +%Y%m%d).log"
}

run_security_scan() {
    log_message "Запуск комплексного сканирования безопасности ядра"
    
    if ! command -v bc >/dev/null 2>&1; then
        apt-get install -y bc
    fi

    if ! command -v dos2unix >/dev/null 2>&1; then
        apt-get install -y dos2unix
    fi

    dos2unix /etc/kernel-security/* 2>/dev/null || true
    dos2unix /etc/kernel-security/actions/* 2>/dev/null || true
    dos2unix /etc/systemd/system/kernel-security.* 2>/dev/null || true
    
    FAIL_THRESHOLD_CLEAN=$(echo "${FAIL_THRESHOLD:-50}" | tr -d '\r')
    LOG_RETENTION_CLEAN=$(echo "${LOG_RETENTION_DAYS:-30}" | tr -d '\r')
    REPORT_RETENTION_CLEAN=$(echo "${REPORT_RETENTION_DAYS:-90}" | tr -d '\r')
    
    if ! command -v kernel-hardening-checker >/dev/null 2>&1; then
        log_message "ОШИБКА: kernel-hardening-checker не найден"
        return 1
    fi
    
    SCAN_RESULT=$(kernel-hardening-checker -a 2>&1)
    echo "$SCAN_RESULT" > "$LOG_DIR/scan-$TIMESTAMP.log"
    
    OK_COUNT=$(echo "$SCAN_RESULT" | grep -oP "'OK' - \K[0-9]+" | head -1)
    FAIL_COUNT=$(echo "$SCAN_RESULT" | grep -oP "'FAIL' - \K[0-9]+" | head -1)
    
    log_message "Сканирование завершено: OK=$OK_COUNT, FAIL=$FAIL_COUNT"
    
    if [ "$FAIL_COUNT" -gt "$FAIL_THRESHOLD_CLEAN" ]; then
        log_message "КРИТИЧЕСКАЯ УЯЗВИМОСТЬ: Большое количество уязвимостей ($FAIL_COUNT), применение немедленных исправлений"
        apply_immediate_fixes
    fi
    
    generate_report "$OK_COUNT" "$FAIL_COUNT"
}

apply_immediate_fixes() {
    log_message "Выполнение немедленных исправлений безопасности"
    
    if [ -f "$ACTIONS_DIR/immediate-fixes.sh" ]; then
        bash "$ACTIONS_DIR/immediate-fixes.sh"
        log_message "Немедленные исправления успешно применены"
    else
        log_message "ПРЕДУПРЕЖДЕНИЕ: immediate-fixes.sh не найден"
    fi
}

apply_reboot_required_fixes() {
    log_message "Применение исправлений безопасности, требующих перезагрузки"
    
    if [ -f "$ACTIONS_DIR/reboot-required.sh" ]; then
        bash "$ACTIONS_DIR/reboot-required.sh"
        log_message "Применены исправления, требующие перезагрузки"
    fi
}

generate_report() {
    local ok_count=$1
    local fail_count=$2
    
    REPORT_FILE="$REPORT_DIR/weekly-report-$(date +%Y%m%d).md"
    
    cat > "$REPORT_FILE" << EOF
# Еженедельный отчет о безопасности ядра - $(date +%Y-%m-%d)

- **Всего проверок:** $((ok_count + fail_count))
- **Пройдено:** $ok_count
- **Не пройдено:** $fail_count
- **Уровень соответствия:** $(printf "%.1f%%" $(echo "scale=1; $ok_count/($ok_count+$fail_count)*100" | bc))

**Дата сканирования:** $(date)  
**Версия ядра:** $(uname -r)  
**Система:** $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')

\`\`\`
$(kernel-hardening-checker -a | grep "FAIL:" | head -10)
\`\`\`

\`\`\`
$(tail -10 "$LOG_DIR/security-$(date +%Y%m%d).log" | grep "Applying\|Applied")
\`\`\`

1. **Немедленные действия:** $(if [ $fail_count -gt 50 ]; then echo "Применить критические исправления немедленно"; else echo "Просмотреть неудачные элементы"; fi)
2. **Плановые работы:** Применить исправления, требующие перезагрузки

- Следующее автоматическое сканирование: $(date -d "+${SCAN_INTERVAL:-24} hours")
- Отчет создан: Kernel Security Automator v1.0
EOF

    log_message "Подробный отчет создан: $REPORT_FILE"
}

cleanup_old_files() {
    log_message "Очистка старых журналов и отчетов"
    
    find "$LOG_DIR" -name "*.log" -mtime +"$LOG_RETENTION_CLEAN" -delete
    find "$REPORT_DIR" -name "*.md" -mtime +"$REPORT_RETENTION_CLEAN" -delete
    
    log_message "Очистка завершена"
}

case "${1:-run}" in
    "run")
        run_security_scan
        cleanup_old_files
        ;;
    "fix")
        apply_immediate_fixes
        apply_reboot_required_fixes
        ;;
    "report")
        generate_report "0" "0"
        ;;
    "test")
        echo "Testing automation system - OK"
        echo "Config: $CONFIG"
        echo "Logs: $LOG_DIR"
        echo "Actions: $ACTIONS_DIR"
        ;;
    *)
        echo "Usage: $0 {run|fix|report|test}"
        exit 1
        ;;
esac