LOG_FILE="/etc/kernel-security/logs/kernel-build-$(date +%Y%m%d).log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_dependencies() {
    log "Проверка зависимостей сборки"
    
    local dependencies=("build-essential" "libssl-dev" "flex" "bison" "libelf-dev")
    local missing=()
    
    for dep in "${dependencies[@]}"; do
        if ! dpkg -l "$dep" 2>/dev/null | grep -q "^ii"; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log "Установка отсутствующих зависимостей: ${missing[*]}"
        apt-get update && apt-get install -y "${missing[@]}"
    fi
}

main() {
    log "Начало подготовки к перекомпиляции ядра"
    
    check_dependencies
    
    log "Настройка перекомпиляции ядра завершена"
    log "Требуется ручная компиляция: apt-get install linux-source && cd /usr/src/linux && make menuconfig"
}

main "$@"