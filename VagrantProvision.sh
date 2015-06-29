#!/bin/bash
sudo su

if [ -e /vagrant ]; then
  OSIS_CONV=/vagrant
else
  cd "$( dirname "${BASH_SOURCE[0]}" )"
  OSIS_CONV=`pwd -P`
fi

apt-get update

apt-get install -y libtool
apt-get install -y autoconf
apt-get install -y make
apt-get install -y pkg-config
apt-get install -y build-essential
apt-get install -y libicu-dev
apt-get install -y unzip
apt-get install -y cpanminus
apt-get install -y subversion
apt-get install -y git
apt-get install -y zip

apt-get install -y default-jre
apt-get install -y libsaxonb-java
apt-get install -y libxml2-dev
apt-get install -y libxml2-utils
apt-get install -y liblzma-dev

# XML::LibXML
cpanm XML::LibXML
cpanm HTML::Entities

# Repotemplate
if [ ! -e /home/vagrant/REPOTEMPLATE_BIN ]; then
  if [ ! -e /home/vagrant/src ]; then
    mkdir /home/vagrant/src
  fi
  cd /home/vagrant/src
  git clone -b ja_devel gitosis@crosswire.org:repotemplate
fi

# Calibre
if [ ! `which calibre` ]; then
  apt-get install xdg-utils imagemagick python-imaging python-mechanize python-lxml python-dateutil python-cssutils python-beautifulsoup python-dnspython python-poppler libpodofo-utils libwmf-bin python-chm
  wget -nv -O- https://raw.githubusercontent.com/kovidgoyal/calibre/master/setup/linux-installer.py | sudo python -c "import sys; main=lambda:sys.stderr.write('Download failed\n'); exec(sys.stdin.read()); main()"
  calibre-customize –b /vagrant/eBooks/OSIS-Input
fi

# GoBible Creator
if [ ! -e  $OSIS_CONV/scripts/GoBibleCreator.245 ]; then
  cd /vagrant/scripts
  wget https://gobible.googlecode.com/files/GoBibleCreator.245.zip
  unzip GoBibleCreator.245.zip
  rm GoBibleCreator.245.zip
fi

# SWORD Tools
# CLucene
if [ ! `which osis2mod` ]; then
  if [ ! -e ~/src ]; then
    mkdir ~/src
  fi
  if [ ! -e ~/src/clucene-core-0.9.21b ]; then
    cd ~/src
    wget http://sourceforge.net/projects/clucene/files/clucene-core-stable/0.9.21b/clucene-core-0.9.21b.tar.bz2/download
    tar -xf download 
    rm download
    cd clucene-core-0.9.21b
    ./configure --disable-multithreading
    make install
    ldconfig
  fi

  # SWORD engine
  swordRev=3203
  if [ ! -e ~/src/sword-svn ]; then
    cd ~/src
    svn checkout -r $swordRev http://crosswire.org/svn/sword/trunk sword-svn
    cd sword-svn
    # modify Makefile to compile and install emptyvss
    sed -i -r -e "s|stepdump step2vpl gbfidx modwrite addvs emptyvss|stepdump step2vpl gbfidx modwrite addvs|" ./utilities/Makefile.am
    sed -i -r -e "s|^bin_PROGRAMS = |bin_PROGRAMS = emptyvss |" ./utilities/Makefile.am
    ./autogen.sh
    ./configure
    make install
    ldconfig
  fi
fi
