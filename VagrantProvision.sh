#!/bin/bash

# This script should not be run as root (except by Vagrant during initial provisioning)

# When this script is run, it should:
#   Install everything necessary for the VM
#   Update everything necessary for the VM

cd $( dirname "${BASH_SOURCE[0]}" )

if [ -e /vagrant ]; then VUSER="vagrant"; else VUSER=$USER; fi
if [ -e /vagrant ]; then VCODE="/vagrant"; else VCODE=`pwd`; fi
if [ -e /vagrant ]; then VHOME="/home/vagrant"; else VHOME=$HOME; fi
if [ ! -e $VHOME/.osis-converters ]; then mkdir $VHOME/.osis-converters; fi
if [ ! -e $VHOME/.osis-converters/src ]; then mkdir $VHOME/.osis-converters/src; fi

sudo apt-get update
sudo apt-get install -y libtool autoconf make pkg-config build-essential libicu-dev unzip cpanminus subversion git zip swig zlib1g-dev default-jre libsaxonb-java libxml2-dev libxml2-utils liblzma-dev

# XML::LibXML
sudo cpanm XML::LibXML
sudo cpanm HTML::Entities

# Calibre
if [ ! `which calibre` ]; then
  sudo apt-get install -y xorg openbox
  sudo apt-get install -y xdg-utils imagemagick python-imaging python-mechanize python-lxml python-dateutil python-cssutils python-beautifulsoup python-dnspython python-poppler libpodofo-utils libwmf-bin python-chm
  wget -nv -O- https://raw.githubusercontent.com/kovidgoyal/calibre/master/setup/linux-installer.py | sudo python -c "import sys; main=lambda:sys.stderr.write('Download failed\n'); exec(sys.stdin.read()); main()"
fi
sudo su - $VUSER -c "calibre-customize -b $VCODE/eBooks/OSIS-Input"

# GoBible Creator
if [ ! -e  $VHOME/.osis-converters/GoBibleCreator.245 ]; then
  cd $VHOME/.osis-converters
  wget https://gobible.googlecode.com/files/GoBibleCreator.245.zip
  unzip GoBibleCreator.245.zip
  rm GoBibleCreator.245.zip
fi

# u2o is for u2o.py testing
if [ ! -e $VHOME/.osis-converters/src/u2o ]; then
  cd $VHOME/.osis-converters/src
  git clone https://github.com/adyeths/u2o.git
else
  cd $VHOME/.osis-converters/src/u2o
  git pull
fi
chmod a+x "$VHOME/.osis-converters/src/u2o/u2o.py"

# python3 is only for u2o.py testing
if [ ! `which python3` ]; then
  #sudo apt-get install -y python3
  #sudo pip3 install lxml
  # u2o.py does not work with Python 3.0 - 3.2.x and the stock VM [Ubuntu Precise] uses 3.2.3. So build 3.4.3 from source...
  cd $VHOME/.osis-converters/src
  wget https://www.python.org/ftp/python/3.4.3/Python-3.4.3.tgz
  tar -xzf Python-3.4.3.tgz
  rm Python-3.4.3.tgz
  cd Python-3.4.3
  sudo apt-get install -y libbz2-dev libxml2-dev libxslt-dev python-dev
  ./configure --prefix=/usr
  make
  sudo make install
  sudo pip3 install lxml
fi

# Module-tools
if [ ! -e $VHOME/.osis-converters/src/Module-tools ]; then
  cd $VHOME/.osis-converters/src
  git clone https://github.com/JohnAustinDev/Module-tools.git
else
  cd $VHOME/.osis-converters/src/Module-tools
  git stash
  git checkout master
  git pull
fi

# SWORD Tools
swordRev=3375
if [ ! -e $VHOME/.osis-converters/src/sword-svn ]; then
svnrev=0
else
  cd $VHOME/.osis-converters/src/sword-svn
svnrev=`svnversion`
fi
if [ ${svnrev:0:${#swordRev}} != "$swordRev" ]; then
  # CLucene
  if [ ! -e $VHOME/.osis-converters/src/clucene-core-0.9.21b ]; then
    cd $VHOME/.osis-converters/src
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
  cd $VHOME/.osis-converters/src
  svn checkout -r $swordRev http://crosswire.org/svn/sword/trunk sword-svn
  cd sword-svn
  make clean
  # modify Makefile to compile and install emptyvss
  sed -i -r -e "s|stepdump step2vpl gbfidx modwrite addvs emptyvss|stepdump step2vpl gbfidx modwrite addvs|" ./utilities/Makefile.am
  sed -i -r -e "s|^bin_PROGRAMS = mod2imp |bin_PROGRAMS = emptyvss mod2imp |" ./utilities/Makefile.am
  # fix xml2gbs.cpp bug that disallows '.' in GenBook keys
  sed -i -r -e "s|else if \(\*strtmp == '\.'\)|else if (*strtmp == 34)|" ./utilities/xml2gbs.cpp
  ./autogen.sh
  ./configure --without-bzip2
  make
  sudo make install
  
  # Perl bindings
  cd $VHOME/.osis-converters/src/sword-svn/bindings/swig/package
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

if [ -e /vagrant ]; then chown -R vagrant:vagrant /home/vagrant/.osis-converters; fi
