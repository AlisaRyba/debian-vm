source /vagrant/scripts/common.sh

setup_kernel_security_automation() {
    log_message "Установка автоматизированной системы безопасности ядра"
    
    if [ ! -f "/vagrant/configs/kernel-security/automator.sh" ]; then
        log_message "Ошибка: Конфиги не найдены в /vagrant/configs/kernel-security/"
        return 1
    fi

    mkdir -p /etc/kernel-security/{actions,logs,reports}
    
    log_message "Копирование конфигурационных файлов..."
    
    cp "/vagrant/configs/kernel-security/automator.sh" /etc/kernel-security/
    cp "/vagrant/configs/kernel-security/config.cfg" /etc/kernel-security/
    
    if [ -d "/vagrant/configs/kernel-security/actions" ]; then
        cp "/vagrant/configs/kernel-security/actions/"* /etc/kernel-security/actions/
    else
        log_message "Предупреждение: папка actions не найдена"
    fi
    
    if [ -d "/vagrant/configs/kernel-security/systemd" ]; then
        cp "/vagrant/configs/kernel-security/systemd/"* /etc/systemd/system/
    else
        log_message "Предупреждение: папка systemd не найдена"
    fi
    
    chmod +x /etc/kernel-security/automator.sh
    chmod +x /etc/kernel-security/actions/*.sh 2>/dev/null || true
    chown -R root:root /etc/kernel-security/
    
    systemctl daemon-reload
    systemctl enable kernel-security.timer 2>/dev/null || log_message "Предупреждение: не удалось включить timer"
    systemctl start kernel-security.timer 2>/dev/null || log_message "Предупреждение: не удалось запустить timer"

    log_message "Тестовый запуск системы безопасности..."
    /etc/kernel-security/automator.sh run
    
    log_message "Автоматизированная система безопасности ядра установлена"
    log_message "Директория: /etc/kernel-security/"
    log_message "Ежедневные проверки: systemctl status kernel-security.timer"
    log_message "Ручной запуск: /etc/kernel-security/automator.sh run"
}

setup_kernel_security_automation