source /vagrant/scripts/common.sh

setup_polkit() {
    log_message "Настройка Polkit"
    
    mkdir -p /etc/polkit-1/localauthority/50-local.d
    
    if [ -f "/vagrant/configs/polkit/10-network-manager.pkla" ]; then
        cp "/vagrant/configs/polkit/10-network-manager.pkla" /etc/polkit-1/localauthority/50-local.d/
        log_message "Конфиг Network Manager скопирован"
    fi
    
    if [ -f "/vagrant/configs/polkit/20-package-management.pkla" ]; then
        cp "/vagrant/configs/polkit/20-package-management.pkla" /etc/polkit-1/localauthority/50-local.d/
        log_message "Конфиг Package Management скопирован"
    fi
    
    chmod 644 /etc/polkit-1/localauthority/50-local.d/*.pkla
}

setup_access_control() {
    log_message "Настройка контроля доступа"
    
    create_group pkgusers
    usermod -aG pkgusers vagrant
    
    if [ -f "/vagrant/configs/sudoers/pkg-management" ]; then
        cp "/vagrant/configs/sudoers/pkg-management" /etc/sudoers.d/
        chmod 440 /etc/sudoers.d/pkg-management
        log_message "Sudoers pkg-management скопирован"
    fi
    
    # Настройка ACL
    for user_dir in /home/*; do
        [ -d "$user_dir" ] && setfacl -R -m g:user:--- "$user_dir" 2>/dev/null
    done
    
    setfacl -m g:user:--- /etc/passwd /etc/shadow /etc/group 2>/dev/null
}

setup_iptables() {
    log_message "Настройка iptables"

    update-alternatives --set iptables /usr/sbin/iptables-legacy
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
    update-alternatives --set arptables /usr/sbin/arptables-legacy
    update-alternatives --set ebtables /usr/sbin/ebtables-legacy
    
    iptables -F && iptables -t nat -F
    iptables -X && iptables -t nat -X
    
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    iptables -A INPUT -p tcp --dport 80 -j DROP
    iptables -A INPUT -p tcp --dport 443 -j DROP
    iptables -A INPUT -s 10.210.19.0/24 -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -s 10.210.19.0/24 -p tcp --dport 8080 -j ACCEPT
    
    iptables -t nat -A POSTROUTING -s 10.210.19.0/24 -o eth0 -j MASQUERADE
    iptables -A FORWARD -s 10.210.19.0/24 -o eth0 -j ACCEPT
    iptables -A FORWARD -d 10.210.19.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    if command -v netfilter-persistent >/dev/null 2>&1; then
        netfilter-persistent save
    else
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi
}

setup_chroot() {
    log_message "Настройка chroot окружения"
    
    local CHROOT_DIR="/srv/chroot/debian-web"
    
    if [ ! -d "$CHROOT_DIR/etc" ]; then
        mkdir -p $CHROOT_DIR
        debootstrap --arch=amd64 bookworm $CHROOT_DIR http://deb.debian.org/debian/
    fi
    
    mount -o bind /proc $CHROOT_DIR/proc 2>/dev/null || true
    mount -o bind /dev $CHROOT_DIR/dev 2>/dev/null || true
    mount -o bind /sys $CHROOT_DIR/sys 2>/dev/null || true
    
    if ! chroot $CHROOT_DIR dpkg -l nginx 2>/dev/null | grep -q "^ii"; then
        chroot $CHROOT_DIR /bin/bash -c "
        apt-get update
        apt-get install -y nginx
        echo 'Тестовое приложение в chroot' > /var/www/html/index.html
        "
        
        if [ -f "/vagrant/configs/nginx/chroot-default.conf" ]; then
            cp "/vagrant/configs/nginx/chroot-default.conf" $CHROOT_DIR/etc/nginx/sites-available/default
            chroot $CHROOT_DIR ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
        fi
    fi
    
    cat > /etc/schroot/chroot.d/debian-web << 'EOL'
[debian-web]
description=Debian Web Chroot
directory=/srv/chroot/debian-web
users=root
root-groups=root
profile=default
type=directory
EOL

    if ! pgrep -f "chroot.*nginx" >/dev/null; then
        chroot $CHROOT_DIR /usr/sbin/nginx
    fi
}

setup_polkit
setup_access_control
setup_iptables
setup_chroot