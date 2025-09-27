source /vagrant/scripts/common.sh

setup_pam_security() {
    log_info "Настройка PAM и парольной политики"

    DEBIAN_FRONTEND=noninteractive apt-get install -y libpam-script > /dev/null 2>&1

    sed -i '/login_notify.sh/d' /etc/pam.d/sshd
    sed -i '/login_notify.sh/d' /etc/pam.d/login
    
    log_info "Настройка ограничений процессов для всех пользователей"
    
    cat << EOF > /etc/security/limits.conf
*       hard    nproc   1000
*       soft    nproc   500

# Особые лимиты для административных пользователей
sysadmin    hard    nproc   2000
sysadmin    soft    nproc   1000
netadmin    hard    nproc   1500
netadmin    soft    nproc   800
helpdesk    hard    nproc   800
helpdesk    soft    nproc   400

# Лимиты для пользователей отделов
marketing_user hard nproc 300
marketing_user soft nproc 150
sales_user     hard nproc 300
sales_user     soft nproc 150
it_admin       hard nproc 1000
it_admin       soft nproc 500
it_helpdesk    hard nproc 600
it_helpdesk    soft nproc 300

john    hard    nproc   800
john    soft    nproc   400
EOF

    log_info "Настройка парольной политики для всех пользователей"
    backup_file "/etc/pam.d/common-password"
    
    cat << EOF > /etc/pam.d/common-password
password requisite pam_cracklib.so \\
    retry=3 minlen=12 difok=5 \\
    dcredit=-1 ucredit=-1 lcredit=-1 ocredit=-1 \\
    reject_username dictpath=/usr/share/dict/words \\
    maxrepeat=3 palindrom

password requisite pam_pwhistory.so remember=5 use_authtok
password [success=1 default=ignore] pam_unix.so obscure use_authtok try_first_pass yescrypt
password requisite pam_deny.so
password required pam_permit.so
EOF

    log_info "Настройка PAM скриптов для логирования входов"
    
    mkdir -p /var/log/
    
    cat << 'EOF' > /usr/local/bin/login_notify.sh

LOG_FILE="/var/log/pam_scripts.log"

touch "$LOG_FILE" 2>/dev/null || exit 0
chmod 600 "$LOG_FILE" 2>/dev/null

if [ -z "$PAM_TYPE" ] || [ -z "$PAM_USER" ]; then
    exit 0 
fi

case "$PAM_TYPE" in
    "open_session")
        echo "$(date '+%Y-%m-%d %H:%M:%S') - LOGIN: User $PAM_USER from $PAM_RHOST (Service: $PAM_SERVICE)" >> "$LOG_FILE"
        ;;
    "close_session")
        echo "$(date '+%Y-%m-%d %H:%M:%S') - LOGOUT: User $PAM_USER" >> "$LOG_FILE"
        ;;
    *)
        exit 0
        ;;
esac

exit 0
EOF

    chmod +x /usr/local/bin/login_notify.sh

    if ! grep -q "login_notify.sh" /etc/pam.d/sshd; then
        echo "session optional pam_exec.so /usr/local/bin/login_notify.sh" >> /etc/pam.d/sshd
    fi

    if ! grep -q "login_notify.sh" /etc/pam.d/login; then
        echo "session optional pam_exec.so /usr/local/bin/login_notify.sh" >> /etc/pam.d/login
    fi

    log_success "Настройка PAM завершена"
}

setup_security() {
    log_message "Дополнительные настройки безопасности"
    
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ssh
        ufw allow http
        ufw allow https
        ufw --force enable
    fi
    
    systemctl daemon-reload
    systemctl restart ssh 2>/dev/null || systemctl restart sshd
    systemctl restart systemd-logind
    
    sleep 2
    
    log_success "Дополнительные настройки безопасности применены"
}

verify_security() {
    log_info "Проверка настроек безопасности"

    log_info "1. Проверка лимитов процессов:"
    for user in john sysadmin netadmin helpdesk marketing_user sales_user; do
        if id "$user" &>/dev/null; then
            soft_limit=$(sudo -u "$user" bash -c 'ulimit -Su 2>/dev/null || ulimit -u' 2>/dev/null || echo "N/A")
            hard_limit=$(sudo -u "$user" bash -c 'ulimit -Hu 2>/dev/null' 2>/dev/null || echo "N/A")
            echo "$user: soft=$soft_limit, hard=$hard_limit"
        fi
    done
    
    log_info "2. Проверка PAM конфигурации:"
    grep -A2 "pam_cracklib" /etc/pam.d/common-password

    log_info "3. Проверка PAM скрипта:"
    ls -la /usr/local/bin/login_notify.sh
    echo "PAM конфигурация SSH:"
    grep "login_notify" /etc/pam.d/sshd || echo "Не настроено в SSH"
    echo "PAM конфигурация login:"
    grep "login_notify" /etc/pam.d/login || echo "Не настроено в login"
    
    if [ -f "/var/log/pam_scripts.log" ]; then
        echo "Тестовый лог:" >> /var/log/pam_scripts.log
        echo "$(date '+%Y-%m-%d %H:%M:%S') - TEST: PAM script работает" >> /var/log/pam_scripts.log
        echo "Последние записи лога:"
        tail -5 /var/log/pam_scripts.log
    else
        echo "Лог-файл не существует"
    fi
    
    log_success "Проверка завершена"
}

check_root
setup_pam_security
setup_security
verify_security