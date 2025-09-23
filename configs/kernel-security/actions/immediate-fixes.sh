LOG_FILE="/etc/kernel-security/logs/security-$(date +%Y%m%d).log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

apply_network_hardening() {
    log "Применение усиления сетевой безопасности"
    
    cat > /etc/sysctl.d/99-kernel-network.conf << 'EOF'
# Network Security Hardening
net.core.bpf_jit_harden=2
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv4.conf.default.accept_source_route=0
net.ipv6.conf.all.accept_ra=0
net.ipv6.conf.default.accept_ra=0
EOF
    
    sysctl -p /etc/sysctl.d/99-kernel-network.conf
    log "Применено усиление сетевой безопасности"
}

apply_kernel_protection() {
    log "Применение защиты памяти ядра"
    
    cat > /etc/sysctl.d/99-kernel-memory.conf << 'EOF'
# Kernel Memory Protection
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.unprivileged_bpf_disabled=1
user.max_user_namespaces=0
dev.tty.ldisc_autoload=0
EOF
    
    sysctl -p /etc/sysctl.d/99-kernel-memory.conf
    log "Применена защита памяти ядра"
}

apply_userspace_protection() {
    log "Применение защиты безопасности пользовательского пространства"
    
    cat > /etc/sysctl.d/99-userspace.conf << 'EOF'
# Userspace Security
fs.protected_fifos=2
fs.protected_regular=2
kernel.yama.ptrace_scope=2
kernel.oops_limit=100
kernel.warn_limit=100
EOF
    
    sysctl -p /etc/sysctl.d/99-userspace.conf
    log "Применена защита безопасности пользовательского пространства"
}

# Основное исполнение
log "Начало немедленного исправления проблем безопасности"

apply_network_hardening
apply_kernel_protection
apply_userspace_protection

log "Все немедленные исправления безопасности успешно выполнены"