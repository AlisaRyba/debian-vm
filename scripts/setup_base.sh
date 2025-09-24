source /vagrant/scripts/common.sh

setup_network() {
    log_message "Настройка сети и DNS"
    
    echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    sleep 5
}

setup_base() {
    log_message "Базовая настройка системы"
    
    export DEBIAN_FRONTEND=noninteractive
    
    run_command "apt-get update" "Обновление списка пакетов"
    
    if apt list --upgradable 2>/dev/null | grep -q upgradable; then
        run_command "apt-get -y upgrade" "Обновление системы"
    fi
    
    # Установка основных пакетов
    local packages=("nginx" "iptables" "iptables-persistent" "acl" "debootstrap" "schroot" "policykit-1" "network-manager")
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            run_command "apt-get install -y $pkg" "Установка $pkg"
        fi
    done

    # Запуск nginx
    if systemctl is-active --quiet nginx; then
        log_message "Nginx уже запущен"
    else
        run_command "systemctl enable --now nginx" "Запуск Nginx"
    fi
}

setup_ssh() {
    log_message "Настройка SSH"
    
    ssh_dir="/home/vagrant/.ssh"
    private_key="$ssh_dir/id_rsa"
    public_key="$ssh_dir/id_rsa.pub"
    
    mkdir -p $ssh_dir
    if [ ! -f "$private_key" ]; then
        ssh-keygen -t rsa -b 4096 -f "$private_key" -N "" -C "vagrant@$(hostname)" >/dev/null 2>&1
    fi
}

setup_network
setup_base
setup_ssh