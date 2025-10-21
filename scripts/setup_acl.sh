source /vagrant/scripts/common.sh

setup_acl_demo() {
    local test_home="/root/acl_demo"
    mkdir -p "$test_home"
    cd "$test_home"
    
    log_message "Создана тестовая директория: $test_home"
    
    echo "Это тестовый файл для демонстрации ACL" > testfile.txt
    log_message "Создан файл testfile.txt"
    
    chmod 644 testfile.txt
    log_message "Установлены базовые права: 644"
    
    if id "john" &>/dev/null; then
        setfacl -m u:john:r testfile.txt
        log_message "Установлен ACL: пользователь john имеет право на чтение"
    else
        log_warning "Пользователь john не существует, используем user1 для демонстрации"
        setfacl -m u:user1:r testfile.txt
        log_message "Установлен ACL: пользователь user1 имеет право на чтение"
    fi
    
    echo "2. Проверка ACL командой getfacl"
    getfacl testfile.txt
    
    echo "3. Создание директории с наследуемым ACL"
    mkdir testdir
    log_message "Создана директория testdir"
    
    if ! getent group developers >/dev/null; then
        groupadd developers
        log_message "Создана группа developers"
    fi
    
    if id "user1" &>/dev/null; then
        usermod -aG developers user1 2>/dev/null || true
    fi
    if id "user2" &>/dev/null; then
        usermod -aG developers user2 2>/dev/null || true
    fi
    
    setfacl -m g:developers:rwx testdir
    setfacl -d -m g:developers:rwx testdir 
    log_message "Установлены наследуемые ACL: группа developers имеет права rwx"
    
    echo "ACL для директории testdir:"
    getfacl testdir
    
    echo "4. Проверка наследования ACL"
    echo "Файл в testdir" > testdir/inherited_file.txt
    log_message "Создан файл testdir/inherited_file.txt"
    
    mkdir testdir/subdir
    log_message "Создана поддиректория testdir/subdir"
    
    echo "Файл в поддиректории" > testdir/subdir/deep_file.txt
    log_message "Создан файл testdir/subdir/deep_file.txt"
    
    echo "ACL для файла inherited_file.txt:"
    getfacl testdir/inherited_file.txt
    
    echo "ACL для поддиректории subdir:"
    getfacl testdir/subdir
    
    echo "ACL для файла deep_file.txt:"
    getfacl testdir/subdir/deep_file.txt
    
    echo "5. Изменение и удаление ACL"
    if id "john" &>/dev/null; then
        setfacl -m u:john:rw testfile.txt
        log_message "Изменен ACL: пользователь john теперь имеет права rw"
    else
        setfacl -m u:user1:rw testfile.txt
        log_message "Изменен ACL: пользователь user1 теперь имеет права rw"
    fi
    
    echo "ACL после изменения:"
    getfacl testfile.txt
    
    setfacl -b testfile.txt
    log_message "Удалены все ACL с файла testfile.txt"
    
    echo "ACL после удаления:"
    getfacl testfile.txt
    
    echo "6. Работа с масками ACL"
    echo "Файл для демонстрации масок" > mask_demo.txt
    chmod 644 mask_demo.txt
    
    setfacl -m u:user1:rwx mask_demo.txt
    setfacl -m u:user2:r-x mask_demo.txt
    setfacl -m g:developers:rw- mask_demo.txt
    
    echo "ACL до установки маски:"
    getfacl mask_demo.txt
    
    setfacl -m m::r-- mask_demo.txt
    log_message "Установлена маска: r-- (ограничивает максимальные права)"
    
    echo "ACL после установки маски:"
    getfacl mask_demo.txt
    log_message "Маска ограничила эффективные права, несмотря на установленные ACL"
    
    echo "7. Демонстрация эффективных прав"
    echo "Тест эффективных прав" > effective_rights.txt
    setfacl -m u:user1:rwx effective_rights.txt
    setfacl -m u:user2:r-- effective_rights.txt
    setfacl -m m::rw- effective_rights.txt 
    
    echo "Файл effective_rights.txt с маской:"
    getfacl effective_rights.txt
    
    log_message "Эффективные права ограничены маской, даже если ACL разрешают больше"
    
    echo "8. Тестирование доступа"
    if id "user1" &>/dev/null; then
        echo "Тестирование доступа user1 к effective_rights.txt:"
        if sudo -u user1 cat effective_rights.txt >/dev/null 2>&1; then
            echo "  ✓ user1 может читать файл"
        else
            echo "  ✗ user1 не может читать файл"
        fi
        
        if sudo -u user1 sh -c "echo 'test' >> effective_rights.txt" 2>/dev/null; then
            echo "  ✓ user1 может писать в файл"
        else
            echo "  ✗ user1 не может писать в файл"
        fi
    fi
    
    echo "9. Маски в директориях"
    mkdir masked_dir
    setfacl -m u:user1:rwx masked_dir
    setfacl -m u:user2:r-x masked_dir
    setfacl -m m::r-x masked_dir 
    
    echo "ACL для директории masked_dir:"
    getfacl masked_dir
    
    echo "Файл в masked_dir" > masked_dir/file_in_masked_dir.txt
    
    echo "ACL для файла в masked_dir (наследует маску):"
    getfacl masked_dir/file_in_masked_dir.txt
    
    cd - >/dev/null
    
    log_message "Демонстрация ACL завершена"
}

setup_acl_demo