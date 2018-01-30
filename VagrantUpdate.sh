#!/bin/bash

# This updates the Virtual Machine by running VagrantProvision.sh on it

if [ "$(grep 'Module-tools' Vagrantshares)" != "" ]; then
  sed -i '/Module-tools/d' Vagrantshares
  if [ "$(vagrant status | grep 'The VM is running')" != "" ]; then vagrant halt; fi
fi

if [ "$(vagrant status | grep 'The VM is running')" == "" ]; then vagrant up; fi

vagrant provision
