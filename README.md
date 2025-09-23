## 📁 Структура проекта:

**debian-vm/**

- **├── Vagrantfile** # Конфигурация виртуальной машины
- **├── configs/** # Конфигурационные файлы
- **│ ├── nginx/**
- **│ │ └── chroot-default.conf** # Конфиг Nginx для chroot
- **│ ├── polkit/**
- **│ │ ├── 10-network-manager.pkla** # Правила Network Manager
- **│ │ └── 20-package-management.pkla** # Правила управления пакетами
- **│ ├── sudoers/**
- **│ │ ├── helpdesk** # Права helpdesk пользователя
- **│ │ ├── netadmin** # Права netadmin пользователя
- **│ │ ├── pkg-management** # Права управления пакетами
- **│ │ └── sysadmin** # Права sysadmin пользователя
- **│ ├── sysctl/**
- **│ │ └── 99-kernel-security.conf** # Настройки безопасности ядра
- **│ └── kernel-security/** #Конфиги системы безопасности ядра
- **│ │ ├── actions/** # Скрипты действий для системы безопасности
- **│ │ │ ├── immediate-fixes.sh** # Немедленные исправления безопасности
- **│ │ │ ├── kernel-recompile.sh** # Скрипт перекомпиляции ядра
- **│ │ │ └── reboot-required.sh** # Действия, требующие перезагрузки
- **│ │ ├── systemd/** # Systemd службы автоматизации
- **│ │ │ ├── kernel-security.service** # Служба проверки безопасности
- **│ │ │ └── kernel-security.timer** # Таймер запланированной проверки
- **│ │ ├── automator.sh** # Основной скрипт автоматора
- **│ │ └── config.cfg** # Конфигурация автоматора
- **└── scripts/** # Скрипты автоматизации
- **├── common.sh** # Общие функции и утилиты
- **├── main.sh** # Главный скрипт запуска
- **├── setup_base.sh** # Базовая настройка системы
- **├── setup_users.sh** # Настройка пользователей и групп
- **├── setup_services.sh** # Настройка сервисов (polkit, iptables, chroot)
- **├── setup_security.sh** # Настройка безопасности
- **├── setup_kernel_security_automation.sh** # Автоматизация безопасности ядра
- **└── setup_kernel_hardening.sh** # Усиление безопасности ядра

## Возможности

- Создание и управление пользователями и группами
- Настройка прав доступа через sudoers и polkit
- Усиление безопасности ядра Linux
- Настройка iptables и сетевой безопасности
- Chroot окружение для изоляции сервисов
- ACL (Access Control Lists) для контроля доступа
- Полная система мониторинга и логирования

## Система автоматизации безопасности ядра

- Еженедельный мониторинг - автоматическая проверка уязвимостей ядра
- Генерация отчетов - детальные отчеты в формате Markdown
- Автоматические исправления - применение security patches
- Перекомпиляция ядра - при необходимости обновления
- Уведомления о перезагрузке - для активации критических исправлений
- Systemd таймеры - регулярное выполнение проверок

## 👥 Пользователи и группы

### Company группа (GID: 10000):

- **sysadmin** (UID: 10101) - Полные права на систему
- **helpdesk** (UID: 10201) - Смена паролей пользователей
- **netadmin** (UID: 10301) - Управление сетью через nmtui

### Группы отделов

- **marketing** - marketing_user, marketing_manager
- **sales** - sales_user, sales_manager
- **it** - it_admin, it_helpdesk

## 🔐 Настройки безопасности

### Безопасность ядра

- JIT-компилятор BPF защищен от Spectre атак
- Запрещены ICMP перенаправления
- Ограничен доступ к /proc/kallsyms
- Заблокирован kexec и загрузка модулей
- Ограничены user namespaces
- Отключен Magic SysRq

### Сетевая безопасность

- iptables с strict политикой
- Разрешен только SSH доступ
- Ограничен доступ к портам 80/443
- NAT и форвардинг для внутренней сети

### Контроль доступа

- Polkit правила для Network Manager
- Sudoers с ограниченными правами
- ACL для домашних директорий
- Изоляция сервисов в chroot

# Установка

## Запуск виртуальной машины

`cd debian-vm`
`vagrant up`

## Подключение по SSH

`vagrant ssh`

## Перезапуск с повторной настройкой

`vagrant reload --provision`

# Проверка работы

## Проверка пользователей

`vagrant ssh -c "getent passwd | grep -E '(sysadmin|helpdesk|netadmin)'"`

## Проверка безопасности ядра

`vagrant ssh -c "sysctl net.core.bpf_jit_harden kernel.kptr_restrict"`

## Проверка сервисов

`vagrant ssh -c "systemctl status nginx"`
`vagrant ssh -c "iptables -L -n"`

## Проверка chroot

`vagrant ssh -c "ls -la /srv/chroot/"`

# Работа с setup_kernel_security_automation

## Проверка отчета

`vagrant ssh -c "cat /etc/kernel-security/reports/weekly-report-20250921.md"`

## Проверка работы службы

`vagrant ssh -c "systemctl status kernel-security.timer"`
`vagrant ssh -c "systemctl status kernel-security.service"`

## Запуск повторного сканирования

`vagrant ssh -c "/etc/kernel-security/automator.sh run"`

## Проверка настроек безопасности

`vagrant ssh -c "sysctl net.core.bpf_jit_harden kernel.kptr_restrict kernel.dmesg_restrict"`

## Запуск исправлений

`vagrant ssh -c "/etc/kernel-security/automator.sh fix"`

## Просмотр логов автоматора

`vagrant ssh -c "journalctl -u kernel-security.service -f"`

## Ручной запуск перекомпиляции ядра

`vagrant ssh -c "sudo /etc/kernel-security/actions/kernel-recompile.sh"`
