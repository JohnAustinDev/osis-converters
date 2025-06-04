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
sudo apt-get install -y build-essential cmake libtool autoconf make pkg-config libicu-dev unzip curl cpanminus subversion git gitk zip swig libxml-libxml-perl zlib1g-dev default-jre libsaxonb-java libxml2-dev libxml2-utils liblzma-dev dos2unix epubcheck imagemagick
sudo apt-get install -y libtool-bin

if [[ -z "$(which python2)" ]]; then ln -s /usr/bin/2.7 /usr/local/bin/python2; fi

# Linkchecker is not in the Ubuntu 20 repos, but can be installed with pip2
if [[ "$(lsb_release -r)" =~ "2[0-9]\." ]]; then
  curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
  sudo python2 ./get-pip.py
  rm ./get-pip.py
  sudo pip2 install linkchecker
else
  sudo apt-get install -y linkchecker
fi

# XML::LibXML
sudo cpanm HTML::Entities
# DateTime is not included in Mint
sudo cpanm DateTime
sudo cpanm Term::ReadKey
sudo cpanm JSON::XS

# VSCODE (extensions: Code intelligence via ctags cfgweb.vscode-perl, Language Server and Debugger richterger.perl)
sudo cpanm Perl::LanguageServer
sudo cpanm Perl::Tidy

# Fonts
sudo apt-get install -y fonts-noto
sudo apt-get install -y fonts-symbola

# Calibre 7.6
if [ ! `which calibre` ]; then
  sudo apt-get install -y xorg openbox
  # the .config directory must be created now, or else the calibre installer creates it as root making it unusable by vagrant
  mkdir $HOME/.config
  sudo -v && wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sudo sh /dev/stdin version=7.6
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
  svn checkout -r $swordRev http://crosswire.org/svn/sword/trunk sword
  mkdir sword/build
  cd sword
  
  # fix xml2gbs.cpp bug that disallows '.' in GenBook keys
  ##sed -i -r -e "s|else if \(\*strtmp == '\.'\)|else if (*strtmp == 34)|" ./utilities/xml2gbs.cpp
  # fix osis2mod bug that drops paragraph type when converting to milestone div
  # fix osis2mod bug that puts New Testament intro at end of Malachi
  # fix osis2mod bug that fails to treat subSection titles as pre-verse titles
  cp "$VCODE/sword-patch/osis2mod.cpp" "$HOME/.osis-converters/src/sword/utilities/"
  
  cd build
  cmake -G "Unix Makefiles" -DSWORD_PERL="TRUE" ..
  make 
  sudo make install
fi

# non English hosts may need this:
sudo su -c "echo LC_ALL=en_US.UTF-8 >> /etc/environment"
sudo su -c "echo LANG=en_US.UTF-8 >> /etc/environment"

