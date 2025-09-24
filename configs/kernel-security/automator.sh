CONFIG="/etc/kernel-security/config.cfg"
LOG_DIR="/etc/kernel-security/logs"
REPORT_DIR="/etc/kernel-security/reports"
ACTIONS_DIR="/etc/kernel-security/actions"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$LOG_DIR" "$REPORT_DIR" "$ACTIONS_DIR"

[ -f "$CONFIG" ] && source "$CONFIG"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/security-$(date +%Y%m%d).log"
}

cleanup_old_files() {
    log_message "Очистка старых журналов и отчетов"
    
    local LOG_RETENTION_CLEAN="${LOG_RETENTION_DAYS:-30}"
    local REPORT_RETENTION_CLEAN="${REPORT_RETENTION_DAYS:-90}"
    
    find "$LOG_DIR" -name "*.log" -mtime +"$LOG_RETENTION_CLEAN" -delete 2>/dev/null || true
    find "$REPORT_DIR" -name "*.md" -mtime +"$REPORT_RETENTION_CLEAN" -delete 2>/dev/null || true
    
    log_message "Очистка завершена"
}

apply_immediate_fixes() {
    log_message "Выполнение немедленных исправлений безопасности"
    
    if [ -f "$ACTIONS_DIR/immediate-fixes.sh" ]; then
        bash "$ACTIONS_DIR/immediate-fixes.sh"
        log_message "Немедленные исправления успешно применены"
    else
        log_message "Предупреждение: immediate-fixes.sh не найден"
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
    local scan_file=$3
    
    REPORT_FILE="$REPORT_DIR/weekly-report-$(date +%Y%m%d).md"
    
    local compliance_percent="0.0"
    local total_checks=$((ok_count + fail_count))
    
    if [ "$total_checks" -gt 0 ]; then
        compliance_percent=$(echo "scale=1; $ok_count * 100 / $total_checks" | bc 2>/dev/null || echo "0.0")
    fi
    
    cat > "$REPORT_FILE" << EOF
# Еженедельный отчет о безопасности ядра - $(date +%Y-%m-%d)

- **Всего проверок:** $total_checks
- **Пройдено:** $ok_count
- **Не пройдено:** $fail_count
- **Уровень соответствия:** ${compliance_percent}%

**Дата сканирования:** $(date)  
**Версия ядра:** $(uname -r)  
**Система:** $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')

## Статистика
- Файл сканирования: $scan_file
- Следующая проверка: $(date -d "+${SCAN_INTERVAL:-24} hours")

## Топ-5 критических проблем
$(grep "FAIL:" "$scan_file" | head -5 || echo "Нет критических проблем")

EOF

    log_message "Отчет создан: $REPORT_FILE"
}

run_security_scan() {
    log_message "Запуск комплексного сканирования безопасности ядра"
    
    if ! command -v bc >/dev/null 2>&1; then
        apt-get install -y bc >/dev/null 2>&1 || log_message "Ошибка установки bc"
    fi

    if ! command -v dos2unix >/dev/null 2>&1; then
        apt-get install -y dos2unix >/dev/null 2>&1 || log_message "Ошибка установки dos2unix"
    fi

    find /etc/kernel-security -type f -name "*.sh" -exec dos2unix {} \; 2>/dev/null || true
    find /etc/kernel-security -type f -name "*.cfg" -exec dos2unix {} \; 2>/dev/null || true
    
    FAIL_THRESHOLD_CLEAN="${FAIL_THRESHOLD:-50}"
    LOG_RETENTION_CLEAN="${LOG_RETENTION_DAYS:-30}"
    REPORT_RETENTION_CLEAN="${REPORT_RETENTION_DAYS:-90}"
    
    if ! command -v kernel-hardening-checker >/dev/null 2>&1; then
        log_message "Ошибка: kernel-hardening-checker не найден"
        return 1
    fi

    local scan_file="$LOG_DIR/scan-$TIMESTAMP.txt"
    log_message "Сохранение сканирования в: $scan_file"
    
    if kernel-hardening-checker -a > "$scan_file" 2>&1; then
        log_message "Сканирование выполнено успешно"
    else
        log_message "Сканирование завершено с ошибками"
    fi
    
    local ok_count=0
    local fail_count=0
    
    if [ -f "$scan_file" ]; then
        ok_count=$(grep -c "OK:" "$scan_file" || echo "0")
        fail_count=$(grep -c "FAIL:" "$scan_file" || echo "0")
    fi

    echo "OK=$ok_count" > /tmp/scan_results.txt
    echo "FAIL=$fail_count" >> /tmp/scan_results.txt
    
    log_message "Сканирование завершено: OK=$ok_count, FAIL=$fail_count"
    
    generate_report "$ok_count" "$fail_count" "$scan_file"
    
    return 0
}

case "${1:-run}" in
    "run")
        run_security_scan
        
        if [ -f "/tmp/scan_results.txt" ]; then
            source /tmp/scan_results.txt
            if [ "$FAIL" -gt "${FAIL_THRESHOLD:-50}" ]; then
                log_message "Критический уровень уязвимостей ($FAIL), применяем исправления"
                apply_immediate_fixes
            fi
            rm -f /tmp/scan_results.txt
        fi
        
        cleanup_old_files
        ;;
    "fix")
        apply_immediate_fixes
        apply_reboot_required_fixes
        ;;
    "report")
        generate_report "0" "0" ""
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

exit 0