source /vagrant/scripts/common.sh

setup_firewall_system() {
    log_message "Настройка системы фаервола (NFTABLES + FIREWALLD)"

    log_message "1: Базовая настройка nftables"

    if ! command -v nft >/dev/null; then
        log_message "Установка nftables"
        apt-get update -y
        apt-get install -y nftables
    fi

    systemctl enable nftables
    systemctl start nftables
    log_message "Служба nftables запущена"

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
        
        # Защита от SYN Flood
        tcp flags syn limit rate 10/second burst 20 packets accept
        tcp flags syn drop
        
        # Защита от Ping Flood
        ip protocol icmp icmp type echo-request limit rate 5/second burst 10 packets accept
        ip protocol icmp icmp type echo-request drop
        
        # Блокировка IP из черного списка
        ip saddr @blocked_ips drop
        
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
        
        # Разрешаем всё исходящее
        ct state established,related accept
    }
    
    # Цепочка forward - для пересылаемых пакетов
    chain forward {
        type filter hook forward priority 0; policy drop;
        
        # Запрещаем пересылку пакетов
        log prefix "FORWARD_DROPPED: " group 0
        counter drop
    }
}
EOF

    log_message "Создан базовый конфигурационный файл nftables"

    nft -f /etc/nftables/ruleset.nft
    log_success "Правила nftables применены"

    nft list ruleset > /etc/nftables.conf
    log_message "Правила сохранены для автоматической загрузки"

    log_message "2: Настройка защиты от сетевых атак"

    nft add rule inet filter input tcp flags syn limit rate 15/second burst 25 packets accept
    nft add rule inet filter input tcp flags syn drop
    
    nft add rule inet filter input ip protocol icmp icmp type echo-request limit rate 3/second burst 5 packets accept
    nft add rule inet filter input ip protocol icmp icmp type echo-request drop
    
    log_success "Добавлена защита от SYN Flood и Ping Flood"

    log_message "3: Работа с наборами IP-адресов"

    nft add set inet filter temp_blocked { type ipv4_addr \; }
    nft add element inet filter temp_blocked { 192.168.1.200, 10.0.0.10 }
    nft add rule inet filter input ip saddr @temp_blocked drop
    
    log_success "Создан временный набор заблокированных IP"

    log_message "4: Сравнение с iptables"

    if command -v iptables >/dev/null; then
        log_message "Текущие правила iptables:"
        iptables -L 2>/dev/null | head -20 || log_warning "iptables не настроен"
        
        log_message "Текущие правила nftables:"
        nft list ruleset | head -30
    else
        log_message "Показываем только правила nftables:"
        nft list ruleset | head -30
    fi

    log_message "5: Настройка firewalld"

    if ! command -v firewall-cmd >/dev/null; then
        log_message "Установка firewalld"
        apt-get update -y
        apt-get install -y firewalld
    fi

    systemctl enable firewalld
    systemctl start firewalld
    log_message "Служба firewalld запущена"

    local current_zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo "не доступно")
    log_message "Текущая зона по умолчанию: $current_zone"

    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    firewall-cmd --permanent --add-service=ssh
    firewall-cmd --reload
    
    log_success "Сервисы HTTP, HTTPS и SSH добавлены в firewalld"

    log_message "Проверка открытых сервисов в firewalld:"
    firewall-cmd --list-services

    log_message "Тестирование системы фаервола"

    echo "1. Проверка текущих правил nftables:"
    nft list ruleset | grep -E "chain|policy|accept|drop" | head -10

    echo "2. Проверка счетчиков пакетов:"
    nft list ruleset | grep "counter packets" | head -5

    echo "3. Проверка работы firewalld:"
    firewall-cmd --state && echo "Firewalld активен" || echo "Firewalld не активен"

    echo "4. Проверка открытых портов:"
    ss -tulpn | grep -E ":22|:80|:443" || echo "Порты не слушаются"

    echo "5. Тестирование подключений:"
    
    if ss -tulpn | grep -q ":22"; then
        log_success "SSH порт 22 открыт"
    else
        log_warning "SSH порт 22 не слушается"
    fi

    echo "6. Тестирование ICMP (ping):"
    if ping -c 2 -W 1 127.0.0.1 >/dev/null 2>&1; then
        log_success "Ping localhost работает"
    else
        log_warning "Ping localhost не работает"
    fi

    echo "7. Статистика фаервола:"
    echo "   nftables:"
    nft list ruleset | grep -c "counter packets" | xargs echo "   Правил со счетчиками:"
    
    echo "   firewalld:"
    firewall-cmd --list-all | grep -E "services|ports" | head -5

    log_message "Создание тестовых скриптов"

    cat > /usr/local/bin/firewall-status.sh << 'EOF'
#!/bin/bash
echo "=== СТАТУС NFTABLES ==="
nft list ruleset 2>/dev/null | grep -E "chain|policy|counter packets" | head -20

echo ""
echo "=== СТАТУС FIREWALLD ==="
firewall-cmd --state 2>/dev/null && firewall-cmd --list-all || echo "Firewalld не активен"

echo ""
echo "=== ОТКРЫТЫЕ ПОРТЫ ==="
ss -tulpn | grep -E ":22|:80|:443|:53" | head -10
EOF

    chmod +x /usr/local/bin/firewall-status.sh

    cat > /usr/local/bin/firewall-reset.sh << 'EOF'
#!/bin/bash
echo "Сброс правил nftables..."
nft flush ruleset
nft add table inet filter
echo "Правила сброшены"
EOF

    chmod +x /usr/local/bin/firewall-reset.sh

    log_success "Тестовые скрипты созданы"

    log_success "Настройка системы фаервола завершена"
}

setup_firewall_system