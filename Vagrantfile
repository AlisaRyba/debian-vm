Vagrant.configure("2") do |config|
  config.vm.box = "generic/debian12"
  config.vm.hostname = "OS-security"
  config.ssh.insert_key = false

  # Используем rsync для синхронизации
  config.vm.synced_folder "scripts", "/vagrant/scripts", type: "rsync"
  config.vm.synced_folder "configs", "/vagrant/configs", type: "rsync"

  config.vm.provision "shell", path: "scripts/main.sh"

  config.vm.provider 'vmware_desktop' do |v|
    v.vmx["memsize"] = "2048" 
    v.vmx["numvcpus"] = "2"
    v.vmx["cpuid.coresPerSocket"] = "1" 
    v.vmx["ethernet0.virtualDev"] = "vmxnet3" 
    v.vmx["ethernet0.dnsserver1"] = "8.8.8.8"
    v.vmx["ethernet0.dnsserver2"] = "8.8.4.4"
    v.vmx["ethernet0.natdnshostresolver1"] = "on"
  end

  config.vm.network "forwarded_port", guest: 8080, host: 8080
end