source /vagrant/scripts/common.sh

setup_security() {
    log_message "Дополнительные настройки безопасности"
    
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ssh
        ufw allow http
        ufw allow https
        ufw --force enable
    fi
    
    systemctl restart sshd 2>/dev/null
}

setup_security