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

    #Для отладки
    echo "Права sysadmin: $(sudo -l -U sysadmin 2>/dev/null | head -1 || true)"
    echo "Права netadmin: $(sudo -l -U netadmin 2>/dev/null | grep nmtui || true)"
    echo "Права helpdesk: $(sudo -l -U helpdesk 2>/dev/null | grep passwd || true)"
}

setup_company_users
setup_department_users
setup_sudo_permissions