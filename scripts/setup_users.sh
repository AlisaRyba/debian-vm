source /vagrant/scripts/common.sh

setup_company_groups() {
    local groups=("company" "sysadmin" "helpdesk" "netadmin" "it" "sales" "marketing")
    for group in "${groups[@]}"; do
        create_group "$group"
    done
}

setup_company_directories() {
    local directories=(
        "/home/company"
        "/company/it" 
        "/company/sales"
        "/company/shared"
        "/home/marketing"
        "/home/sales" 
        "/home/it"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
    done
}

setup_company_core_users() {
    log_message "Создание основных пользователей company"
    
    local company_users=(
        "sysadmin:/home/company/sysadmin:/bin/bash:sysadmin:10101"
        "helpdesk:/home/company/helpdesk:/bin/sh:helpdesk:10201" 
        "netadmin:/home/company/netadmin:/bin/bash:netadmin:10301"
    )
    
    for user_spec in "${company_users[@]}"; do
        IFS=':' read -r username home_dir shell group uid <<< "$user_spec"
        create_user "$username" "$home_dir" "$shell" "$group" "$uid"
        usermod -aG company "$username"
    done
    
    chmod 755 /home/company
    chown :company /home/company
}

setup_company_structure_users() {
    log_message "Создание пользователей структуры компании"
    
    local it_users=(
        "ituser1:/company/it/ituser1:/bin/bash:company"
        "ituser2:/company/it/ituser2:/bin/bash:company"
        "itadmin:/company/it/itadmin:/bin/bash:company"
    )
    
    for user_spec in "${it_users[@]}"; do
        IFS=':' read -r username home_dir shell group <<< "$user_spec"
        create_user "$username" "$home_dir" "$shell" "$group"
        usermod -aG it "$username"
    done
      
    local sales_users=(
        "suser1:/company/sales/suser1:/bin/sh:company"
        "suser2:/company/sales/suser2:/bin/sh:company"
        "sadmin:/company/sales/sadmin:/bin/sh:company"
    )
    
    for user_spec in "${sales_users[@]}"; do
        IFS=':' read -r username home_dir shell group <<< "$user_spec"
        create_user "$username" "$home_dir" "$shell" "$group"
        usermod -aG sales "$username"
    done
}

setup_department_users() {
    log_message "Создание пользователей отделов"
    
    local dept_users=(
        "marketing_user:/home/marketing/user:/bin/false:marketing"
        "marketing_manager:/home/marketing/manager:/bin/bash:marketing"
        "sales_user:/home/sales/user:/bin/false:sales"
        "sales_manager:/home/sales/manager:/bin/bash:sales" 
        "it_admin:/home/it/admin:/bin/bash:it"
        "it_helpdesk:/home/it/helpdesk:/bin/bash:it"
    )
    
    for user_spec in "${dept_users[@]}"; do
        IFS=':' read -r username home_dir shell group <<< "$user_spec"
        create_user "$username" "$home_dir" "$shell" "$group"
    done
    
    for group in marketing sales it; do
        chmod 775 "/home/$group"
        chown ":$group" "/home/$group" 2>/dev/null || true
    done
}

setup_special_users() {
    log_message "Создание специальных пользователей"
    
    if ! id "john" &>/dev/null; then
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
    else
        log_message "Пользователь john уже существует"
    fi
}

setup_additional_users() {
    log_message "Создание дополнительных пользователей user1, user2, user3"
    
    if ! getent group appusers >/dev/null; then
        groupadd appusers
        log_message "Создана группа appusers"
    fi
    
    for i in 1 2 3; do
        local username="user$i"
        local home_dir="/home/$username"
        
        if ! id "$username" &>/dev/null; then
            create_user "$username" "$home_dir" "/bin/bash" "appusers"
            log_message "Создан пользователь $username"
        else
            usermod -aG appusers "$username" 2>/dev/null || true
            log_message "Пользователь $username уже существует, добавлен в группу appusers"
        fi
    done
    
    demonstrate_shell_difference
}

demonstrate_shell_difference() {
    log_message "Демонстрация различий между login и non-login shell"
    
    echo "export DEMO_VAR=login_shell_value" | sudo tee -a /home/user1/.profile > /dev/null
    
    log_message "Login Shell (загружает .profile):"
    sudo -u user1 bash -l -c 'echo "DEMO_VAR: $DEMO_VAR"'
    
    log_message "Non-Login Shell (не загружает .profile):"
    sudo -u user1 bash -c 'echo "DEMO_VAR: $DEMO_VAR"'
}

setup_directory_permissions() {
    log_message "Настройка прав доступа к директориям"
    
    local dir_permissions=(
        "/company/it:root:it:770"
        "/company/sales:root:sales:770" 
        "/company/shared:root:company:775"
    )
    
    for perm_spec in "${dir_permissions[@]}"; do
        IFS=':' read -r directory owner group mode <<< "$perm_spec"
        chown "$owner:$group" "$directory"
        chmod "$mode" "$directory"
        log_message "Директория $directory: владелец $owner:$group, права $mode"
    done
}

create_shared_files() {
    log_message "Создание файлов пользователей в /company/shared"
    
    local shared_users=("ituser1" "ituser2" "itadmin" "suser1" "suser2" "sadmin")
    
    for user in "${shared_users[@]}"; do
        local file_path="/company/shared/${user}_file.txt"
        sudo -u "$user" touch "$file_path" 2>/dev/null || \
        (touch "$file_path" && chown "$user" "$file_path")
        
        echo "Файл пользователя $user, создан: $(date)" | sudo tee "$file_path" > /dev/null
        log_message "Создан файл $file_path"
    done
}

setup_sudoers_files() {
    log_message "Настройка файлов sudoers"
    
    local sudoers_files=("sysadmin" "netadmin" "helpdesk")
    for file in "${sudoers_files[@]}"; do
        if [ -f "/vagrant/configs/sudoers/$file" ]; then
            cp "/vagrant/configs/sudoers/$file" /etc/sudoers.d/
            log_message "Sudoers $file скопирован"
        fi
    done
    
    setup_additional_sudoers
    
    echo 'Defaults logfile="/var/log/sudo.log"' >> /etc/sudoers
    echo 'Defaults log_input, log_output' >> /etc/sudoers  
    echo 'Defaults iolog_dir="/var/log/sudo-io"' >> /etc/sudoers
    
    mkdir -p /var/log/sudo-io
    chmod 700 /var/log/sudo-io
    
    chmod 440 /etc/sudoers.d/* 2>/dev/null || true
}

setup_additional_sudoers() {
    log_message "Настройка sudo прав для дополнительных пользователей"
    
    cat << EOF > /etc/sudoers.d/10-user2-admin
# User2 - System Administrator
user2 ALL=(ALL) ALL
EOF

    cat << EOF > /etc/sudoers.d/20-user1-ls
# User1 - can run ls as user2
user1 ALL=(user2) /bin/ls
EOF

    cat << EOF > /etc/sudoers.d/30-appusers-group
%appusers ALL=(root) NOPASSWD: /usr/bin/apt-get update, /usr/bin/apt-get upgrade, /sbin/shutdown
EOF

    chmod 440 /etc/sudoers.d/10-user2-admin /etc/sudoers.d/20-user1-ls /etc/sudoers.d/30-appusers-group
}

verify_company_structure() {
    log_message "Проверка структуры компании"
    
    echo "Проверка групп"
    for group in company sysadmin helpdesk netadmin it sales marketing; do
        if getent group "$group" >/dev/null; then
            echo "Группа $group: $(getent group $group)"
        fi
    done
    
    echo "Проверка директорий"
    for dir in /company /company/it /company/sales /company/shared /home/company /home/marketing /home/sales /home/it; do
        if [ -d "$dir" ]; then
            echo "Директория $dir: $(ls -ld "$dir")"
        fi
    done
    
    echo "Содержимое /company/shared"
    ls -la /company/shared/
}

verify_sudo_configuration() {
    log_info "Проверка конфигурации sudo"
    
    if visudo -c; then
        log_success "Sudoers конфигурация валидна"
    else
        log_error "Ошибка в sudoers конфигурации"
        exit 1
    fi
}

verify_additional_setup() {
    log_message "Проверка дополнительных пользователей"
    
    echo "Проверка user2 (администратор)"
    sudo -l -U user2 | head -5 || true
    
    echo "Проверка user1 (ls как user2)" 
    sudo -l -U user1 | grep -A2 -B2 user2 || true
    
    echo "Проверка групповых прав appusers"
    for i in 1 2 3; do
        echo "user$i:"
        sudo -l -U "user$i" | grep -E "(apt-get|shutdown)" || true
    done
}

check_root

setup_company_groups
setup_company_directories
 
setup_company_core_users
setup_company_structure_users
setup_department_users
setup_special_users
setup_additional_users

setup_directory_permissions
create_shared_files
setup_sudoers_files

verify_company_structure
verify_sudo_configuration
verify_additional_setup

log_success "Настройка пользователей завершена"