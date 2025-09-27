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
- **├── systemd-targets-setup.sh** # Установка Multi-user.target по умолчанию
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

### Защита от Fork Bomb

#### Ограничения процессов через limits.conf:

- Все пользователи: soft=500, hard=1000 процессов
- Административные пользователи: повышенные лимиты (sysadmin: soft=1000, hard=2000)
- Пользователь john: soft=400, hard=800 процессов
- Защита от DoS-атак через исчерпание ресурсов

### Усиленная парольная политика PAM

#### Настройки pam_cracklib:

- Минимальная длина: 12 символов

##### Сложность символов:

- Минимум 1 цифра (dcredit=-1)
- Минимум 1 заглавная буква (ucredit=-1)
- Минимум 1 строчная буква (lcredit=-1)
- Минимум 1 специальный символ (ocredit=-1)

##### Защита от простых паролей:

- Запрет словарных слов - проверка против системного словаря
- Запрет палиндромов - блокировка симметричных последовательностей
- Запрет повторяющихся символов - не более 3 одинаковых символов подряд
- Проверка отличия от старого пароля - минимум 5 различных символов
- Запрет паролей, содержащих имя пользователя - защита от социальной инженерии

##### Дополнительная защита:

- История паролей: запоминание последних 5 паролей (remember=5)
- Лимит попыток: 3 попытки ввода пароля (retry=3)
- Защита от подбора: obscuring и хэширование yescrypt

### PAM Script для мониторинга доступа

#### Логирование всех входов/выходов в /var/log/pam_scripts.log

#### Отслеживание:

- Время и дата входа/выхода
- Имя пользователя и источник подключения
- Сервис аутентификации (SSH, login)

#### Автоматическая активация через pam_exec для sshd и login

# Установка

## Запуск виртуальной машины

- `cd debian-vm`
- `vagrant up`

## Подключение по SSH

- `vagrant ssh`

## Перезапуск с повторной настройкой

- `vagrant reload --provision`

# Проверка работы

## Проверка пользователей

- `vagrant ssh -c "getent passwd | grep -E '(sysadmin|helpdesk|netadmin)'"`

## Проверка безопасности ядра

- `vagrant ssh -c "sysctl net.core.bpf_jit_harden kernel.kptr_restrict"`

## Проверка сервисов

- `vagrant ssh -c "systemctl status nginx"`
- `vagrant ssh -c "iptables -L -n"`

## Проверка chroot

- `vagrant ssh -c "ls -la /srv/chroot/"`

# Работа с setup_kernel_security_automation

## Проверка отчета

- `vagrant ssh -c "cat /etc/kernel-security/reports/weekly-report-20250921.md"`

## Проверка работы службы

- `vagrant ssh -c "systemctl status kernel-security.timer"`
- `vagrant ssh -c "systemctl status kernel-security.service"`

## Запуск повторного сканирования

- `vagrant ssh -c "/etc/kernel-security/automator.sh run"`

## Проверка настроек безопасности

- `vagrant ssh -c "sysctl net.core.bpf_jit_harden kernel.kptr_restrict kernel.dmesg_restrict"`

## Запуск исправлений

- `vagrant ssh -c "/etc/kernel-security/automator.sh fix"`

## Просмотр логов автоматора

- `vagrant ssh -c "journalctl -u kernel-security.service -f"`

## Ручной запуск перекомпиляции ядра

- `vagrant ssh -c "sudo /etc/kernel-security/actions/kernel-recompile.sh"`

# Проверка корректности настройки PAM

## Проверка лимитов пользователей

- `vagrant ssh -c "sudo -u john bash -c 'ulimit -u'"`
- `vagrant ssh -c "sudo -u john bash -c 'ulimit -Hu'"`
- `vagrant ssh -c "sudo -u sysadmin bash -c 'ulimit -u'"`
- `vagrant ssh -c "sudo -u netadmin bash -c 'ulimit -u'"`

## Проверка PAM cracklib парольной политики

- `vagrant ssh -c "sudo cat /etc/pam.d/common-password | head -10"`
- `vagrant ssh -c "echo 'john:123' | sudo chpasswd"`

## Проверка PAM script логирования

- `vagrant ssh -c "ls -la /usr/local/bin/login_notify.sh"`
- `vagrant ssh -c "sudo grep login_notify /etc/pam.d/sshd /etc/pam.d/login"`
- `vagrant ssh -c "sudo tail -10 /var/log/pam_scripts.log"`

## Проверка sudo для john без пароля + логирование

- `vagrant ssh -c "sudo -l -U john"`
- `vagrant ssh -c "sudo -u john sudo whoami"`
- `vagrant ssh -c "sudo -u john sudo echo 'Тест команды для логирования'"`
- `vagrant ssh -c "sudo tail -5 /var/log/sudo.log"`

## Проверка автоматизации

- `vagrant ssh -c "sudo ls -la /vagrant/scripts/"`
- `vagrant ssh -c "sudo tail -20 /var/log/security_setup.log"`
