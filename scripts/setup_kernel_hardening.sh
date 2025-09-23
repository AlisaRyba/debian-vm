source /vagrant/scripts/common.sh

setup_kernel_hardening_checker() {
    log_message "Установка kernel-hardening-checker"
        
    if ! command -v git &> /dev/null; then
        run_command "apt-get install -y git" "Установка git"
    else
        log_message "Git уже установлен"
    fi
        
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    VENV_PACKAGE="python${PYTHON_VERSION}-venv"
        
    if ! dpkg -l "$VENV_PACKAGE" 2>/dev/null | grep -q "^ii"; then
        run_command "apt-get install -y $VENV_PACKAGE" "Установка $VENV_PACKAGE"
    else
        log_message "$VENV_PACKAGE уже установлен"
    fi
        
    local CHECKER_DIR="/home/vagrant/kernel-hardening-checker"
    if [ ! -d "$CHECKER_DIR" ]; then
        run_command "git clone https://github.com/a13xp0p0v/kernel-hardening-checker.git $CHECKER_DIR" "Клонирование репозитория kernel-hardening-checker"
    else
        log_message "Репозиторий kernel-hardening-checker уже склонирован"
    fi
        
    if [ -d "$CHECKER_DIR" ]; then
        cd "$CHECKER_DIR"
            
        VENV_DIR="/home/vagrant/khc-venv"
        if [ ! -d "$VENV_DIR" ]; then
            run_command "python3 -m venv $VENV_DIR" "Создание виртуального окружения"
        fi
            
        if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
            run_command "source $VENV_DIR/bin/activate && pip install ." "Установка kernel-hardening-checker в виртуальное окружение"
                
            cat > /usr/local/bin/kernel-hardening-checker << 'EOL'

source /home/vagrant/khc-venv/bin/activate
exec /home/vagrant/khc-venv/bin/kernel-hardening-checker "$@"
EOL
                
            run_command "chmod +x /usr/local/bin/kernel-hardening-checker" "Установка прав на скрипт-обертку"
        else
            log_message "Ошибка: виртуальное окружение не было создано правильно"
            run_command "pip install . --break-system-packages" "Установка с флагом --break-system-packages"
        fi
            
        cd -
    fi
}

setup_kernel_hardening_script() {
    log_message "Установка скрипта усиления ядра"
    
    if [ -f "/vagrant/scripts/kernel-security-hardening.sh" ]; then
        cp "/vagrant/scripts/kernel-security-hardening.sh" /usr/local/bin/
        chmod +x /usr/local/bin/kernel-security-hardening.sh
        log_message "Скрипт усиления безопасности скопирован"
        
        /usr/local/bin/kernel-security-hardening.sh
    else
        log_message "Ошибка: файл kernel-security-hardening.sh не найден"
    fi
}

setup_kernel_hardening_checker
setup_kernel_hardening_script