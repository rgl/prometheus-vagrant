Vagrant.configure('2') do |config|
  config.vm.provider :virtualbox do |v, override|
    v.linked_clone = true
    v.cpus = 2
    v.memory = 2048
    v.customize ['modifyvm', :id, '--vram', 64]
    v.customize ['modifyvm', :id, '--clipboard', 'bidirectional']
  end

  config.vm.define :prometheus do |config|
    config.vm.box = 'windows-2016-amd64'
    config.vm.hostname = 'prometheus'
    config.vm.network :private_network, ip: '10.10.10.100'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-common.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-prometheus.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-grafana.ps1'
  end
end
