hosts = '''
10.10.10.100 prometheus.example.com
10.10.10.100 alertmanager.example.com
10.10.10.100 grafana.example.com
10.10.10.100 elasticsearch.example.com
10.10.10.100 kibana.example.com
'''

Vagrant.configure('2') do |config|
  config.vm.provider "libvirt" do |lv, config|
    lv.memory = 4*1024
    lv.cpus = 2
    lv.cpu_mode = "host-passthrough"
    lv.keymap = "pt"
    # replace the default synced_folder with something that works in the base box.
    # NB for some reason, this does not work when placed in the base box Vagrantfile.
    config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
  end

  config.vm.provider :virtualbox do |v, override|
    v.linked_clone = true
    v.cpus = 2
    v.memory = 4*1024
    v.customize ['modifyvm', :id, '--vram', 64]
    v.customize ['modifyvm', :id, '--clipboard', 'bidirectional']
  end

  config.vm.define :prometheus do |config|
    config.vm.box = 'windows-2019-amd64'
    config.vm.hostname = 'prometheus'
    config.vm.network :private_network, ip: '10.10.10.100', libvirt__forward_mode: 'route', libvirt__dhcp_enabled: false
    config.vm.provision :shell, inline: "'#{hosts}' | Out-File -Encoding Ascii -Append c:/Windows/System32/drivers/etc/hosts"
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-common.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-certificates.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-caddy.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-mailhog.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-alertmanager.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-performance-counters-exporter.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-powershell-exporter.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-wmi-exporter.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-blackbox-exporter.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-elasticsearch-oss.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-kibana-oss.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-prometheusbeat.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-prometheus.ps1'
    config.vm.provision :shell, path: 'ps.ps1', args: 'provision-grafana.ps1'
  end
end
