#!/bin/bash

# This script should NOT be run as root. It has been updated for Ubuntu 24.

# When this script is run on a VM or Linux host, it will:
#   Install everything necessary for the VM or host (if the host is compatible)
#   Update everything necessary for the VM or host

cd $( dirname "${BASH_SOURCE[0]}" )

if [[ $(whoami) == "root" ]]; then
  echo "This script should NOT be run as root. Exiting..."
  exit 1
fi

if [ -e /vagrant/Vagrantfile ]; then VCODE="/vagrant"; else VCODE=`pwd`; fi
if [ ! -e $HOME/.osis-converters/src ]; then mkdir -p $HOME/.osis-converters/src; fi

sudo apt-get update
sudo apt-get install -y openjdk-8-jdk
sudo apt-get install -y build-essential cmake libtool autoconf make pkg-config libicu-dev swig libxml-libxml-perl zlib1g-dev default-jre libsaxonb-java libxml2-dev libxml2-utils liblzma-dev libtool-bin
sudo apt-get install -y zip unzip curl cpanminus subversion git dos2unix epubcheck imagemagick linkchecker

# XML::LibXML
sudo cpanm HTML::Entities
# DateTime is not included in Mint
sudo cpanm DateTime
sudo cpanm Term::ReadKey
sudo cpanm JSON::XS
sudo cpanm Text::CSV_XS

# VSCODE (extensions: Code intelligence via ctags cfgweb.vscode-perl, Language Server and Debugger richterger.perl)
sudo cpanm Perl::LanguageServer
sudo cpanm Perl::Tidy

# Fonts
sudo apt-get install -y fonts-noto
sudo apt-get install -y fonts-symbola

# Calibre 7 (Ubuntu 24 calibre has a package problem, so install from calibre-ebook.com)
if [[ -z "$(which calibre)" ]]; then
  sudo apt-get install -y qt6-base-dev libegl1 libopengl0 libxcb-cursor0
  sudo -v && wget --no-check-certificate -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin version=7.6.0
fi
calibre-customize -b $VCODE/calibre_plugin/OSIS-Input

# GoBible Creator
if [ ! -e  $HOME/.osis-converters/GoBibleCreator.245 ]; then
  cd $HOME/.osis-converters
  wget https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/gobible/GoBibleCreator.245.zip
  unzip GoBibleCreator.245.zip
  rm GoBibleCreator.245.zip
fi

# Module-tools
if [ ! -e $HOME/.osis-converters/src/Module-tools/.git ]; then
  cd $HOME/.osis-converters/src
  if [ -e ./Module-tools ]; then
    rm -rf ./Module-tools
  fi
  git clone https://github.com/JohnAustinDev/Module-tools.git
else
  cd $HOME/.osis-converters/src/Module-tools
  git stash
  git checkout master
  git pull
fi

# SWORD 1.8 from subversion
swordRev=3900
if [ ! -e $HOME/.osis-converters/src/sword ]; then
  svnrev=0
else
  cd $HOME/.osis-converters/src/sword
  svnrev=`svnversion`
fi

# Build Sword tools and install Perl bindings
if [[ ${svnrev:0:${#swordRev}} != "$swordRev" ]]; then
  cd $HOME/.osis-converters/src
  svn checkout -r $swordRev https://crosswire.org/svn/sword/trunk sword
  mkdir sword/build
  cd sword
  
  # fix xml2gbs.cpp bug (feature??) where '.' in a GenBook key causes all characters before it to be ignored!
  cp "$VCODE/sword-patch/xml2gbs.cpp" "$HOME/.osis-converters/src/sword/utilities/"
  # fix osis2mod bug that drops paragraph type when converting to milestone div
  # fix osis2mod bug that puts New Testament intro at end of Malachi
  # fix osis2mod bug that fails to treat subSection titles as pre-verse titles
  cp "$VCODE/sword-patch/osis2mod.cpp" "$HOME/.osis-converters/src/sword/utilities/"
  
  cd build
  cmake -G "Unix Makefiles" -DSWORD_PERL="TRUE" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 ..
  make 
  sudo make install
fi

# non English hosts may need this:
sudo su -c "echo LC_ALL=en_US.UTF-8 >> /etc/environment"
sudo su -c "echo LANG=en_US.UTF-8 >> /etc/environment"

