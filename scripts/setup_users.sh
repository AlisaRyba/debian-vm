source /vagrant/scripts/common.sh

setup_company_users() {
    log_message "Создание пользователей company"
    
    mkdir -p /home/company
    create_group company 10000
    
    create_group sysadmin
    create_group helpdesk
    create_group netadmin
    
    create_user sysadmin /home/company/sysadmin /bin/bash sysadmin 10101
    create_user helpdesk /home/company/helpdesk /bin/sh helpdesk 10201
    create_user netadmin /home/company/netadmin /bin/bash netadmin 10301
    
    usermod -aG company sysadmin
    usermod -aG company helpdesk
    usermod -aG company netadmin
    
    chmod 755 /home/company
    chown :company /home/company

    #Для отладки
    echo "Директория: $(ls -ld /home/company/)"
    echo "Группа company: $(getent group company)"
    echo "Пользователи:"
    for user in sysadmin helpdesk netadmin; do
        id "$user" && echo "Домашняя директория: $(eval echo ~$user)"
    done
}

setup_department_users() {
    log_message "Создание пользователей отделов"
    
    local dept_groups=("marketing" "sales" "it")
    for group in "${dept_groups[@]}"; do
        create_group "$group"
    done
    
    for group in "${dept_groups[@]}"; do
        mkdir -p "/home/$group"
        chmod 775 "/home/$group"
        chown ":$group" "/home/$group" 2>/dev/null || true
    done
    
    create_user marketing_user /home/marketing/user /bin/false marketing
    create_user marketing_manager /home/marketing/manager /bin/bash marketing
    
    create_user sales_user /home/sales/user /bin/false sales
    create_user sales_manager /home/sales/manager /bin/bash sales
    
    create_user it_admin /home/it/admin /bin/bash it
    create_user it_helpdesk /home/it/helpdesk /bin/bash it

    #Для отладки
    echo "Группы отделов:"
    for group in marketing sales it; do
        echo "  $group: $(getent group $group)"
    done
    echo "Пользователи:"
    for user in marketing_user marketing_manager sales_user sales_manager it_admin it_helpdesk; do
        if id "$user" &>/dev/null; then
            echo "  $user: $(id "$user" | cut -d' ' -f1), shell: $(getent passwd "$user" | cut -d: -f7)"
        fi
    done
}

setup_special_users() {
    log_message "Создание специальных пользователей"
    
    useradd -m -s /bin/bash john
    echo "john:TempPass123" | chpasswd 2>/dev/null || echo "john:TempPass123" | chpasswd -c SHA512
    usermod -aG sudo john
    
    cat << EOF > /etc/sudoers.d/john
john ALL=(ALL) NOPASSWD: ALL
Defaults:john logfile=/var/log/sudo_john.log
Defaults:john log_input, log_output
Defaults:john iolog_dir=/var/log/sudo-io/john
EOF
    chmod 440 /etc/sudoers.d/john
    
    log_message "Пользователь john создан с настроенным sudo"
}

setup_sudo_permissions() {
    log_message "Настройка sudo прав"

    if [ -f "/vagrant/configs/sudoers/sysadmin" ]; then
        cp "/vagrant/configs/sudoers/sysadmin" /etc/sudoers.d/
        log_message "Sudoers sysadmin скопирован"
    fi
    
    if [ -f "/vagrant/configs/sudoers/netadmin" ]; then
        cp "/vagrant/configs/sudoers/netadmin" /etc/sudoers.d/
        log_message "Sudoers netadmin скопирован"
    fi
    
    if [ -f "/vagrant/configs/sudoers/helpdesk" ]; then
        cp "/vagrant/configs/sudoers/helpdesk" /etc/sudoers.d/
        log_message "Sudoers helpdesk скопирован"
    fi
    
    chmod 440 /etc/sudoers.d/sysadmin /etc/sudoers.d/netadmin /etc/sudoers.d/helpdesk 2>/dev/null || true

    echo 'Defaults logfile="/var/log/sudo.log"' >> /etc/sudoers
    echo 'Defaults log_input, log_output' >> /etc/sudoers
    echo 'Defaults iolog_dir="/var/log/sudo-io"' >> /etc/sudoers
    
    mkdir -p /var/log/sudo-io
    chmod 700 /var/log/sudo-io

    #Для отладки
    echo "Права sysadmin: $(sudo -l -U sysadmin 2>/dev/null | head -1 || true)"
    echo "Права netadmin: $(sudo -l -U netadmin 2>/dev/null | grep nmtui || true)"
    echo "Права helpdesk: $(sudo -l -U helpdesk 2>/dev/null | grep passwd || true)"
}

verify_sudo_config() {
    log_info "Проверка конфигурации sudo"
    
    if visudo -c; then
        log_success "Sudoers конфигурация валидна"
    else
        log_error "Ошибка в sudoers конфигурации"
        exit 1
    fi
    
    for user in sysadmin netadmin helpdesk; do
        if id "$user" &>/dev/null; then
            log_info "Права sudo для пользователя $user:"
            sudo -l -U "$user" | head -10 || true
        fi
    done
}

check_root

setup_company_users
setup_special_users

setup_department_users
setup_sudo_permissions
verify_sudo_config