#!/bin/bash

cd $( dirname "${BASH_SOURCE[0]}" )

# If host is Linux, then run provision.sh
if [ "$(uname -o)" == "GNU/Linux" ]; then ./provision.sh; fi

# Updates any Virtual Machine by running provision.sh on it
if [ ! -z "$(vagrant status | grep 'not created')" ]; then exit; fi
if [ "$(grep 'Module-tools' Vagrantshares)" != "" ]; then
  sed -i '/Module-tools/d' Vagrantshares
  if [ "$(vagrant status | grep 'The VM is running')" != "" ]; then vagrant halt; fi
fi

if [ "$(vagrant status | grep 'The VM is running')" == "" ]; then vagrant up; fi

vagrant provision
