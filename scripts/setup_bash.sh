source /vagrant/scripts/common.sh

setup_bash_scripting_task() {
    local test_file="/root/log_analysis.txt"
    
    cat > "$test_file" << 'EOF'
2014-10-12 14:22:44 OK
2014-10-12 16:11:41 OK
2015-02-11 14:12:31 OK
2015-05-05 03:17:11
2020-08-06 12:11:31
2020-07-07 11:17:51 OK
2020-05-08 14:15:21
EOF

    log_message "Создан тестовый файл: $test_file"
    
    echo "Содержимое файла:"
    cat "$test_file"
    
    local script_file="/root/count_ok_per_day.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash

FILE="${1:-/root/log_analysis.txt}"

if [ ! -f "$FILE" ]; then
    echo "Ошибка: Файл $FILE не найден!" >&2
    exit 1
fi

echo "Анализ файла: $FILE"

awk '
{
    date = $1
    
    if ($0 ~ /OK$/) {
        ok_count[date]++
    } else {
        if (!(date in ok_count)) {
            ok_count[date] = 0
        }
    }
    
    if (!(date in dates_seen)) {
        dates[++count] = date
        dates_seen[date] = 1
    }
}
END {
    for (i = 1; i <= count; i++) {
        date = dates[i]
        if (!(date in ok_count)) {
            ok_count[date] = 0
        }
        printf "%s %d\n", date, ok_count[date]
    }
}
' "$FILE"
EOF

    chmod +x "$script_file"
    log_message "Создан скрипт для анализа: $script_file"
    
    echo "Результат выполнения скрипта:"
    "$script_file"
}

setup_system_info_script() {
    local script_file="/root/system_info_collector.sh"
    
    cat > "$script_file" << 'EOF'
#!/bin/bash

# Скрипт для сбора системной информации
# Записывает в output.txt или output_new.txt если файл существует

set -euo pipefail

OUTPUT_FILE="output.txt"
if [[ -f "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="output_new.txt"
    echo "Файл output.txt уже существует, используем $OUTPUT_FILE"
fi

add_separator() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Команда '$1' не найдена. Пропускаем этот раздел."
        return 1
    fi
    return 0
}

echo "Сбор системной информации..."
echo "Файл вывода: $OUTPUT_FILE"
echo "Время сбора: $(date)"

{
    add_separator "ТЕКУЩИЕ ПРОЦЕССЫ (top 20)"
    if check_command "ps"; then
        echo "PID   USER     COMMAND"
        ps aux --sort=-%cpu | head -20
    fi

    add_separator "ОТКРЫТЫЕ ПОРТЫ"
    if check_command "netstat"; then
        netstat -tulpn 2>/dev/null | head -20
    elif check_command "ss"; then
        ss -tulpn | head -20
    else
        echo "Не найдены команды netstat или ss"
    fi

    add_separator "СПИСОК ПОЛЬЗОВАТЕЛЕЙ СИСТЕМЫ"
    if check_command "getent"; then
        echo "Пользователи с оболочкой login:"
        getent passwd | grep -v "/false\|/nologin" | cut -d: -f1,6,7 | head -20
        echo ""
        echo "Все пользователи (первые 20):"
        cut -d: -f1 /etc/passwd | head -20
    else
        cut -d: -f1 /etc/passwd | head -20
    fi

    add_separator "СЕТЕВЫЕ ИНТЕРФЕЙСЫ И IP АДРЕСА"
    if check_command "ip"; then
        ip addr show | grep -E "inet |^[0-9]+:" | grep -v "127.0.0.1"
    elif check_command "ifconfig"; then
        ifconfig | grep -E "inet |flags"
    else
        echo "Не найдены команды ip или ifconfig"
    fi

    add_separator "ИСПОЛЬЗОВАНИЕ ДИСКОВОГО ПРОСТРАНСТВА"
    if check_command "df"; then
        df -h | grep -E "^Filesystem|/$|/home"
    fi

    add_separator "ДОПОЛНИТЕЛЬНАЯ СИСТЕМНАЯ ИНФОРМАЦИЯ"
    
    echo "Информация о системе:"
    if [[ -f /etc/os-release ]]; then
        echo "ОС: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
    fi
    echo "Ядро: $(uname -r)"
    echo "Архитектура: $(uname -m)"
    
    echo "Оперативная память:"
    if check_command "free"; then
        free -h
    fi
    
    echo "Загрузка системы:"
    echo "Время работы: $(uptime -p 2>/dev/null || uptime)"
    echo "Средняя загрузка: $(cat /proc/loadavg)"

    add_separator "АКТИВНЫЕ ПОЛЬЗОВАТЕЛИ"
    if check_command "who"; then
        who
    else
        echo "Команда who не найдена"
    fi

} > "$OUTPUT_FILE"

echo "Информация успешно сохранена в файл: $OUTPUT_FILE"
echo "Размер файла: $(du -h "$OUTPUT_FILE" | cut -f1)"
echo "Количество строк: $(wc -l < "$OUTPUT_FILE")"

echo "Превью содержимого (первые 10 строк):"
head -10 "$OUTPUT_FILE"
EOF

    chmod +x "$script_file"
    log_message "Создан скрипт для сбора системной информации: $script_file"
    
    echo "Первый запуск скрипта:"
    cd /root && "$script_file"
    
    echo "Второй запуск скрипта (проверка создания output_new.txt):"
    cd /root && "$script_file"
    
    log_message "Созданные файлы:"
    for file in output.txt output_new.txt; do
        if [[ -f "/root/$file" ]]; then
            echo "$file: $(du -h "/root/$file" | cut -f1), $(wc -l < "/root/$file") строк"
        fi
    done
}

setup_bash_scripting_task
setup_system_info_script