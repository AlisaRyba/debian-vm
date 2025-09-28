LOG_FILE="/var/log/security_setup.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_info() {
    echo "[INFO] $(date): $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo "[SUCCESS] $(date): $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $(date): $1" | tee -a "$LOG_FILE" >&2
}

log_warning() {
    echo "[WARNING] $(date): $1" | tee -a "$LOG_FILE"
}

run_command() {
    local cmd="$1"
    local description="$2"
    
    log_message "Начинаем: $description"
    eval "$cmd"
    
    if [ $? -eq 0 ]; then
        log_message "Успешно: $description"
    else
        log_message "Ошибка: $description"
        return 1
    fi
}

generate_secure_password() {
    local length=${1:-12}
    tr -dc 'A-Za-z0-9!@#$%^&*()' < /dev/urandom | head -c $length
    echo
}

create_user() {
    local username=$1 home_dir=$2 shell=$3 group=$4 uid=${5:-}
    local uid_param=""
    local password_file="/root/user_passwords.txt"
    
    if [ -n "$uid" ]; then
        uid_param="-u $uid"
    fi
    
    if ! id "$username" &>/dev/null; then
        useradd -m $uid_param -d "$home_dir" -s "$shell" -g "$group" "$username"
        
        local password=$(generate_secure_password 16)
        
        if set_user_password "$username" "$password"; then
            echo "$username:$password" >> "$password_file"
            chmod 600 "$password_file"
            
            chage -d 0 "$username"
            
            echo "Создан пользователь: $username (пароль записан в $password_file)"
        else
            echo "Ошибка: Не удалось установить пароль для $username"
            return 1
        fi
        
        chown "$username:$group" "$home_dir"
    else
        echo "Пользователь $username уже существует"
    fi
}

create_group() {
    local groupname=$1 gid=${2:-}
    local gid_param=""
    
    if [ -n "$gid" ]; then
        gid_param="-g $gid"
    fi
    
    if ! getent group "$groupname" &>/dev/null; then
        groupadd $gid_param "$groupname"
        echo "Создана группа: $groupname"
    else
        echo "Группа $groupname уже существует"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Этот скрипт должен запускаться с правами root"
        exit 1
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Создан бэкап: ${file}.backup"
    fi
}

apply_config() {
    local src="$1"
    local dst="$2"
    
    if [[ -f "$src" ]]; then
        backup_file "$dst"
        cp "$src" "$dst"
        log_success "Применена конфигурация: $dst"
    else
        log_error "Файл конфигурации не найден: $src"
        return 1
    fi
}