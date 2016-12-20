#!/bin/bash

# This script updates to JohnAustinDev/osis-converters master, and then updates the Virtual Machine

# Make sure we're in osis-converters root dir
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Stash any local changes
if [ -n "$(git status --porcelain)" ]; then 
  git stash
  echo .
  echo LOCAL CHANGES TO OSIS-CONVERTERS HAVE BEEN STASHED!
  echo THE STASH NAME IS LISTED ABOVE.
  echo TO RE-APPLY THESE CHANGES YOU MADE, USE: git stash apply
  echo .
fi

# Switch to local master branch
git checkout master
branch_name="$(git symbolic-ref HEAD 2>/dev/null)" || branch_name="(unnamed branch)"
branch_name=${branch_name##refs/heads/}
if [ $branch_name != "master" ]; then 
  echo Could not switch to master branch. Please switch to the master branch and try again.
  echo Exiting...
  exit 
fi
if [ -n "$(git status --porcelain)" ]; then 
  echo You have uncommited changes in your master branch. Commit or stash them and try again.
  echo Exiting...
  exit
fi

# If this is not JohnAustinDev/osis-converters then first pull from origin master
if [[ "$(git config --get remote.origin.url)" != *JohnAustinDev/osis-converters ]]; then
  echo UPDATING FORK
  git pull origin master
else
  echo NOT A FORK: SKIPPING FORK UPDATE
fi

# Pull updates from https://github.com/JohnAustinDev/osis-converters master
git pull https://github.com/JohnAustinDev/osis-converters master

if [ -n "$(git status --porcelain)" ]; then 
  echo .
  echo UNABLE TO CLEANLY PULL FROM JohnAustinDev/osis-converters!
  echo RUN GIT STATUS AND RESOLVE ANY LOCAL CHANGES, THEN TRY AGAIN
  echo Exiting...
  exit
fi

# The VM must not have a Module-tools synced-folder, so that we can update the VM's own Module-tools
vagrant halt
cp Vagrantfile_tpl Vagrantfile
vagrant up

# Running VagrantProvision.sh on the VM will update the VM's installed software
vagrant ssh -c "bash /vagrant/VagrantProvision.sh"

modtools=$(grep -P '^\$MODULETOOLS_BIN' paths.pl);
if [ ! -z "$modtools" ]; then
  echo .
  echo WARNING!!! WARNING!!! WARNING!!!
  echo ModuleTools ON THE VM HAS BEEN UPDATED.
  echo BUT YOU ARE USING A HOST COPY OF ModuleTools AS SPECIFIED IN 
  echo paths.pl: $modtools
  echo SO YOU MAY STILL NOT BE USING THE LATEST ModuleTools!
  echo .
fi
  
