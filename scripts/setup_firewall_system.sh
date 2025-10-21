source /vagrant/scripts/common.sh

setup_firewall_system() {
    log_message "Настройка системы фаервола (NFTABLES + FIREWALLD)"

    log_message "Проверка поддержки nftables..."
    if ! grep -q nf_tables /proc/modules 2>/dev/null && ! modprobe nf_tables 2>/dev/null; then
        log_warning "NFTables не поддерживается в этой среде. Используем fallback на iptables"
        setup_firewall_fallback
        return 0
    fi

    log_message "1: Базовая настройка nftables"

    if ! command -v nft >/dev/null; then
        log_message "Установка nftables"
        apt-get update -y
        apt-get install -y nftables
    fi

    if ! nft list ruleset 2>/dev/null; then
        log_warning "NFTables не работает. Переключаемся на iptables"
        setup_firewall_fallback
        return 0
    fi

    systemctl enable nftables
    if ! systemctl start nftables 2>/dev/null; then
        log_warning "Не удалось запустить nftables service"
    fi
    log_message "Служба nftables настроена"

    mkdir -p /etc/nftables

    cat > /etc/nftables/ruleset.nft << 'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    
    # Набор для заблокированных IP-адресов
    set blocked_ips {
        type ipv4_addr
        elements = { 192.168.1.100, 10.0.0.5, 203.0.113.15 }
    }
    
    # Цепочка input - для входящих пакетов
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Разрешаем loopback интерфейс
        iif "lo" accept
        
        # Разрешаем установленные и связанные соединения
        ct state established,related accept
        
        # Разрешаем SSH
        tcp dport 22 accept
        
        # Разрешаем HTTP и HTTPS
        tcp dport {80, 443} accept
        
        # Логируем и отбрасываем остальные пакеты
        log prefix "DROPPED: " group 0
        counter drop
    }
    
    # Цепочка output - для исходящих пакетов
    chain output {
        type filter hook output priority 0; policy accept;
    }
    
    # Цепочка forward - для пересылаемых пакетов
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
}
EOF

    log_message "Создан базовый конфигурационный файл nftables"

    if nft -f /etc/nftables/ruleset.nft 2>/dev/null; then
        log_success "Правила nftables применены"
        nft list ruleset > /etc/nftables.conf
        log_message "Правила сохранены для автоматической загрузки"
    else
        log_warning "Не удалось применить правила nftables"
    fi

    log_message "Настройка firewalld"

    if ! command -v firewall-cmd >/dev/null; then
        log_message "Установка firewalld"
        apt-get update -y
        apt-get install -y firewalld
    fi

    systemctl enable firewalld
    if systemctl start firewalld 2>/dev/null; then
        log_message "Служба firewalld запущена"
        
        local current_zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo "не доступно")
        log_message "Текущая зона по умолчанию: $current_zone"

        if firewall-cmd --permanent --add-service=http 2>/dev/null && \
           firewall-cmd --permanent --add-service=https 2>/dev/null && \
           firewall-cmd --permanent --add-service=ssh 2>/dev/null && \
           firewall-cmd --reload 2>/dev/null; then
            log_success "Сервисы HTTP, HTTPS и SSH добавлены в firewalld"
        else
            log_warning "Не удалось настроить firewalld"
        fi
    else
        log_warning "Не удалось запустить firewalld"
    fi

    log_message "Тестирование системы фаервола"

    echo "1. Проверка текущих правил:"
    if command -v nft >/dev/null && nft list ruleset 2>/dev/null | grep -q "chain"; then
        echo "   NFTables активен"
        nft list ruleset 2>/dev/null | grep -E "chain|policy" | head -5
    elif command -v iptables >/dev/null; then
        echo "   IPTables активен"
        iptables -L 2>/dev/null | head -10
    else
        echo "   Фаервол не настроен"
    fi

    echo "2. Проверка открытых портов:"
    ss -tulpn | grep -E ":22|:80|:443" || echo "   Основные порты не слушаются"

    echo "3. Тестирование подключений:"
    if ss -tulpn | grep -q ":22"; then
        log_success "SSH порт 22 открыт"
    else
        log_warning "SSH порт 22 не слушается"
    fi

    echo "4. Тестирование ICMP (ping):"
    if ping -c 2 -W 1 127.0.0.1 >/dev/null 2>&1; then
        log_success "Ping localhost работает"
    else
        log_warning "Ping localhost не работает"
    fi

    log_message "Создание тестовых скриптов"

    cat > /usr/local/bin/firewall-status.sh << 'EOF'
#!/bin/bash
echo "=== СТАТУС ФАЕРВОЛА ==="

if command -v nft >/dev/null && nft list ruleset 2>/dev/null | grep -q "chain"; then
    echo "NFTables:"
    nft list ruleset 2>/dev/null | grep -E "chain|policy" | head -10
elif command -v iptables >/dev/null; then
    echo "IPTables:"
    iptables -L 2>/dev/null | head -15
else
    echo "Фаервол не настроен"
fi

echo ""
echo "=== ОТКРЫТЫЕ ПОРТЫ ==="
ss -tulpn | grep -E ":22|:80|:443" | head -10

echo ""
echo "=== FIREWALLD ==="
if systemctl is-active firewalld 2>/dev/null; then
    firewall-cmd --list-all 2>/dev/null | head -10
else
    echo "Firewalld не активен"
fi
EOF

    chmod +x /usr/local/bin/firewall-status.sh

    log_success "Настройка системы фаервола завершена"
}

setup_firewall_fallback() {
    log_message "Настройка базовой защиты через iptables"
    
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -j DROP
    
    log_success "Базовая защита iptables настроена"
}

setup_firewall_system