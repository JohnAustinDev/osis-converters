#!/bin/bash

# This script should not be run as root

# When this script is run, it should:
#   Install everything necessary for the VM
#   Update everything necessary for the VM

cd $( dirname "${BASH_SOURCE[0]}" )

if [ -e /vagrant ]; then VCODE="/vagrant"; else VCODE=`pwd`; fi
if [ ! -e $HOME/.osis-converters/src ]; then mkdir -p $HOME/.osis-converters/src; fi

sudo apt-get update
sudo apt-get install -y libtool autoconf make pkg-config build-essential libicu-dev unzip cpanminus subversion git zip swig libxml-libxml-perl zlib1g-dev default-jre libsaxonb-java libxml2-dev libxml2-utils liblzma-dev dos2unix epubcheck

# XML::LibXML
sudo cpanm XML::LibXML::PrettyPrint
sudo cpanm HTML::Entities

# Calibre
if [ ! `which calibre` ]; then
  sudo apt-get install -y xorg openbox
  sudo apt-get install -y xdg-utils imagemagick python-imaging python-mechanize python-lxml python-dateutil python-cssutils python-beautifulsoup python-dnspython python-poppler libpodofo-utils libwmf-bin python-chm
  wget -nv -O- https://download.calibre-ebook.com/linux-installer.py | sudo python -c "import sys; main=lambda:sys.stderr.write('Download failed\n'); exec(sys.stdin.read()); main()"
fi
calibre-customize -b $VCODE/eBooks/OSIS-Input

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

# SWORD Tools
swordRev=3375
if [ ! -e $HOME/.osis-converters/src/sword-svn ]; then
  svnrev=0
else
  cd $HOME/.osis-converters/src/sword-svn
  svnrev=`svnversion`
fi
if [ ${svnrev:0:${#swordRev}} != "$swordRev" ]; then
  # CLucene
  if [ ! -e $HOME/.osis-converters/src/clucene-core-0.9.21b ]; then
    cd $HOME/.osis-converters/src
    wget http://sourceforge.net/projects/clucene/files/clucene-core-stable/0.9.21b/clucene-core-0.9.21b.tar.bz2/download
    tar -xf download 
    rm download
    cd clucene-core-0.9.21b
    ./configure --disable-multithreading
    make
    sudo make install
    sudo ldconfig
  fi

  # SWORD engine
  cd $HOME/.osis-converters/src
  svn checkout -r $swordRev http://crosswire.org/svn/sword/trunk sword-svn
  cd sword-svn
  make clean
  # modify Makefile to compile and install emptyvss
  sed -i -r -e "s|stepdump step2vpl gbfidx modwrite addvs emptyvss|stepdump step2vpl gbfidx modwrite addvs|" ./utilities/Makefile.am
  sed -i -r -e "s|^bin_PROGRAMS = mod2imp |bin_PROGRAMS = emptyvss mod2imp |" ./utilities/Makefile.am
  # fix xml2gbs.cpp bug that disallows '.' in GenBook keys
  sed -i -r -e "s|else if \(\*strtmp == '\.'\)|else if (*strtmp == 34)|" ./utilities/xml2gbs.cpp
  # fix osis2mod bug that drops paragraph type when converting to milestone div
  # fix osis2mod bug that puts New Testament intro at end of Malachi
  # fix osis2mod bug that fails to treat subSection titles as pre-verse titles
  cp "$VCODE/sword-patch/osis2mod.cpp" "$HOME/.osis-converters/src/sword-svn/utilities/"
  ./autogen.sh
  ./configure --without-bzip2
  make
  sudo make install
  
  # Perl bindings
  cd $HOME/.osis-converters/src/sword-svn/bindings/swig/package
  make clean
  libtoolize --force
  ./autogen.sh
  ./configure
  make perlswig
  make perl_make
  cd perl
  sudo make install
  sudo ldconfig
fi

# non English hosts may need this:
sudo su -c "echo LC_ALL=en_US.UTF-8 >> /etc/environment"
sudo su -c "echo LANG=en_US.UTF-8 >> /etc/environment"
