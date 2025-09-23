LOG_FILE="/etc/kernel-security/logs/security-$(date +%Y%m%d).log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

apply_grub_security() {
    log "Настройка параметров безопасности GRUB"
    
    cp /etc/default/grub "/etc/default/grub.backup.$(date +%Y%m%d)"
    
    sed -i 's/ spectre_v2=[^ ]*//g' /etc/default/grub
    sed -i 's/ spec_store_bypass_disable=[^ ]*//g' /etc/default/grub
    sed -i 's/ mitigations=[^ ]*//g' /etc/default/grub
    
    CURRENT_CMDLINE=$(grep "GRUB_CMDLINE_LINUX=" /etc/default/grub | cut -d'"' -f2)
    
    SECURITY_PARAMS="spectre_v2=on spec_store_bypass_disable=seccomp mitigations=auto"
    
    sed -i "s|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$CURRENT_CMDLINE $SECURITY_PARAMS\"|" /etc/default/grub
    
    if command -v update-grub >/dev/null 2>&1; then
        update-grub
        log "Обновлена ​​конфигурация безопасности GRUB"
    else
        log "Команда update-grub недоступна"
    fi
}

log "Применение исправлений безопасности, требующих перезагрузки"

apply_grub_security

log "Применены исправления, требующие перезагрузки. Рекомендуется перезагрузить систему"