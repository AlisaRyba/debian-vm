log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

task1_rescue_fstab() {
    log_message "Запуск работы с Rescue.target и Fstab"
    
    log_message "1.1. Содержимое /etc/fstab:"
    cat /etc/fstab
    
    log_message "1.2. Доступные systemd targets:"
    systemctl list-units --type=target | grep -E "(rescue|multi-user|graphical)"
}

task2_set_multi_user_default() {
    log_message "Установка Multi-user.target по умолчанию"
    
    local old_target=$(systemctl get-default)
    log_message "2.1. Старый target: $old_target"
    
    systemctl set-default multi-user.target
    local new_target=$(systemctl get-default)
    log_message "2.2. Новый target: $new_target"

    if [ "$new_target" = "multi-user.target" ]; then
        log_message "2.3. Успех: multi-user.target установлен по умолчанию"
    else
        log_message "2.3. Ошибка: не удалось установить multi-user.target"
    fi
}


main() { 
    task1_rescue_fstab
    task2_set_multi_user_default
}

main "$@"