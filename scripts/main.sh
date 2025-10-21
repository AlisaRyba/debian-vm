cd /vagrant/scripts

chmod +x *.sh

source common.sh

log_message "Начало выполнения main.sh"

log_message "Запуск setup_base.sh"
bash setup_base.sh

log_message "Запуск setup_users.sh" 
bash setup_users.sh

log_message "Запуск setup_acl.sh" 
bash setup_acl.sh

log_message "Запуск setup_services.sh"
bash setup_services.sh

log_message "Запуск setup_security.sh"
bash setup_security.sh

log_message "Запуск setup_kernel_hardening.sh"
bash setup_kernel_hardening.sh

log_message "Запуск setup_kernel_security_automation.sh"
bash setup_kernel_security_automation.sh

log_message "Запуск systemd-targets-setup.sh"
bash systemd-targets-setup.sh

log_message "Запуск setup_bash.sh" 
bash setup_bash.sh
