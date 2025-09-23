SECURITY_CONF="/etc/sysctl.d/99-kernel-security.conf"
GRUB_CONF="/etc/default/grub"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

if [ -f "/vagrant/configs/sysctl/99-kernel-security.conf" ]; then
    cp "/vagrant/configs/sysctl/99-kernel-security.conf" "$SECURITY_CONF"
    log_message "Конфигурация безопасности ядра применена из configs/sysctl/"
else
    log_message "Предупреждение: файл конфигурации не найден, создаем стандартный"
    cat > "$SECURITY_CONF" << 'EOF'
# Базовые настройки безопасности ядра
net.core.bpf_jit_harden = 2
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.kexec_load_disabled = 1
kernel.unprivileged_bpf_disabled = 1
user.max_user_namespaces = 0
dev.tty.ldisc_autoload = 0
kernel.modules_disabled = 1
kernel.sysrq = 0
fs.protected_fifos = 2
kernel.yama.ptrace_scope = 3
kernel.oops_limit = 100
kernel.warn_limit = 100
EOF
fi

sysctl -p "$SECURITY_CONF"
log_message "Настройки безопасности ядра применены"

# Настройка GRUB
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