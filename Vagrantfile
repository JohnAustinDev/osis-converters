# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "alvistack/ubuntu-24.04"
  
  config.ssh.forward_x11 = true

  config.vm.box_check_update = false

  # SSH forwarding doesn't work on Windows, so here is a work-around.
  if Vagrant::Util::Platform.windows?
    # Copy ~/.ssh/id_rsa to the VM
    if File.exists?(File.join(Dir.home, ".ssh", "id_rsa"))
      user_ssh_key = File.read(File.join(Dir.home, ".ssh", "id_rsa"))
      config.vm.provision :shell, :inline => "echo 'Windows-specific: Copying host SSH Key to VM...' && mkdir -p /home/vagrant/.ssh && echo '#{user_ssh_key}' > /home/vagrant/.ssh/id_rsa && chown -R vagrant:vagrant /home/vagrant/.ssh && chmod 600 /home/vagrant/.ssh/id_rsa"
    end
  else
    config.ssh.forward_agent = true
  end

  config.vm.provision :shell do |shell|
    shell.inline = "if [ -e /var/lib/dpkg/lock ]; then echo UNLOCKING DPKG && sudo rm /var/lib/dpkg/lock; fi"
  end

  config.vm.provision :shell, :path => "provision.sh", privileged: false
  
  # Include a customized vagrant file for customizing things like RAM
  Vagrantcustom = File.join(File.expand_path(File.dirname(__FILE__)), 'Vagrantcustom')
  if File.exists?(Vagrantcustom) then
    eval(IO.read(Vagrantcustom), binding)
  end
  
  # Include an auto-generated file containing VM shares
  Vagrantshares = File.join(File.expand_path(File.dirname(__FILE__)), 'Vagrantshares')
  if File.exists?(Vagrantshares) then
    eval(IO.read(Vagrantshares), binding)
  end
  
  # Default NAT's DNS for Linux VM within MS-Windows VM does not always 
  # work, so the fix:
  config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end
  
end
