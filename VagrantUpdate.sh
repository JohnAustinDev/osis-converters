#!/bin/bash

# This updates the Virtual Machine

# Make sure we're in osis-converters root dir
cd "$( dirname "${BASH_SOURCE[0]}" )"


is="$(grep 'config.vm.box ' ./Vagrantfile_tpl)";
was="$(grep 'config.vm.box ' ./Vagrantfile)";

if [ "$is" != "$was" ]; then 
  echo 
  echo CANNOT UPDATE VIRTUAL MACHINE. Vagrant configuration has changed.
  echo You need to run:
  echo \$ Vagrant destroy
  echo \$ Vagrant up
  exit
fi

# Running VagrantProvision.sh on the VM will update the VM's installed software
vagrant ssh -c "bash /vagrant/VagrantProvision.sh"
