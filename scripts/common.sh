log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
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

create_user() {
    local username=$1 home_dir=$2 shell=$3 group=$4 uid=${5:-}
    local uid_param=""
    
    if [ -n "$uid" ]; then
        uid_param="-u $uid"
    fi
    
    if ! id "$username" &>/dev/null; then
        useradd -m $uid_param -d "$home_dir" -s "$shell" -g "$group" "$username"
        echo "$username:password123" | chpasswd
        chown "$username:$group" "$home_dir"
        echo "Создан пользователь: $username"
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