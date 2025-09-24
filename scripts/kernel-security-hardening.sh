SECURITY_CONF="/etc/sysctl.d/99-kernel-security.conf"
GRUB_CONF="/etc/default/grub"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

if [ -f "/vagrant/configs/sysctl/99-kernel-security.conf" ]; then
    cp "/vagrant/configs/sysctl/99-kernel-security.conf" "$SECURITY_CONF"
    log_message "Конфигурация безопасности ядра применена из configs/sysctl/"
else
    log_message "Предупреждение: файл конфигурации не найден"
fi

sysctl -p "$SECURITY_CONF"
log_message "Настройки безопасности ядра применены"

if [ -f "$GRUB_CONF" ]; then
    cp "$GRUB_CONF" "${GRUB_CONF}.backup.$(date +%Y%m%d)"
    
    if grep -q "GRUB_CMDLINE_LINUX=" "$GRUB_CONF"; then
        sed -i 's/spectre_v2=[^ ]*//g' "$GRUB_CONF"
        sed -i 's/spec_store_bypass_disable=[^ ]*//g' "$GRUB_CONF"
        sed -i 's/mitigations=[^ ]*//g' "$GRUB_CONF"
        sed -i 's/slub_debug=[^ ]*//g' "$GRUB_CONF"
        sed -i 's/init_on_alloc=[^ ]*//g' "$GRUB_CONF"
        sed -i 's/init_on_free=[^ ]*//g' "$GRUB_CONF"
        sed -i 's/page_alloc.shuffle=[^ ]*//g' "$GRUB_CONF"
        
        CURRENT_CMDLINE=$(grep "GRUB_CMDLINE_LINUX=" "$GRUB_CONF" | cut -d'"' -f2)
        SECURITY_PARAMS="spectre_v2=on spec_store_bypass_disable=seccomp mitigations=auto,nosmt slub_debug=FZP init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1"
        
        sed -i "s|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"$CURRENT_CMDLINE $SECURITY_PARAMS\"|" "$GRUB_CONF"
    fi
    
    if command -v update-grub >/dev/null 2>&1; then
        update-grub
        log_message "Конфигурация GRUB обновлена"
    else
        log_message "Предупреждение: команда update-grub не найдена"
    fi
fi

log_message "Настройки безопасности ядра завершены"