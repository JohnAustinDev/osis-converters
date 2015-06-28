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
  wget https://dl.boxcloud.com/bc/4/5dccf0425976aa68902504fd2e1576ed/RBYqZVLb2ycMIy2M9HZ05lA9g1fKt-MxNTZ_K_xlIDn1Jp8NMtueT_r_FbzmmEaIIZCCksiRw3ccfg1eBDnke7jL4zH9OimpUK_-ACyAN8k6eZSV5yhHLG4lLvCYogoViq6HAcEPIeWjwata8GVL0olDa_d440XitJ7Sy_Vigwn2zOK4qG5IR9ILlA6EEKuqR2MvixgKSIXZnJ7XrkAm2E55_Q9vxXEWyj8iFbJRVu6fLKd7cowW-KL3a-5KyFSRXfhkFlnHA1EExSAhgqgJ6yyo9VMxz6UGQu6eD_p8Po7mzVYYkp98IWpCQzyVgjPgy6DpfQhlueXh4tr2ht6lAcKmhoudxYRNXqiB2moS_IVuM2BKkyy_bvjtsSf0n9xScxax_L6PGHogGsUdLAtZ1JEXVI_OWN7Sf4Y9xiaAoF4KsaVyCTHfKFK0lcDya7As4kc9Ysw0YewSaVlIpH_bTRpXkQXFe6EpJ4NhCk1trRgZHXBjRr-8Ep3-BXZs3sowmnn6_u5tUa1LntCOZchiv9yfuh2IBEty1uHt0TykhxWvkpUQnIvFxrugUReJIX-lZL7iM1Ao8r_7I5tOCV9l6N-jTFmr1noEmgPiz0qs9hU8B4XhH1erv5AznGOvtg1zx7H9e7sTYozfpI2Htbnw1QdhvCwTktNhRUiJrw6FUIWjw1HnQqYmIZpKou0oy0gJ3_Qe2qQhH-3bFOSz_osMoVFqs3KLFxh1NbGKlCAQDKTYlfrftLXjFwbkPIti3ObHdlPuMovHHF9DLAOcQ6Qji7Np5ty3N6pQvOWf32ElQ9ofAVx6EtwiY1whlkz3NHx3838bxg5niH784bMBM_MLfctfyT7SVbRngSyn5LnGl2NBKq8PDBiVQErfV8aSZvWVKFMVGa5bC43q0Ps9aQ0hFYyTw0mrfCmMLcclwaNFUGjKQ7Tf4FE1XtJrVeF06gvBB8oJReaUNGq8PoB8mlsW4jcCA-ovYMogNSYeS0qdf344-mpYGqQfuJbMwyJ-FSIQJQoboOGMFOT-UzmJPQdsc77x2Gn8WsSQ1A4BzsOkxkjeNp3gufr5eyayyJ0jlbGVoS1bB0Hui4u0ShnuZIXrOo6VbHMX3ha5qn9wYvzCekwPIlDLbxsAbHDUVSQCW_2avk8Owv9BZFG9JrAxzdYahgj_2MkE7-NpCmKIMP-sRDeAQqDqYN2YZOHl_jQmCs0DF8AVZfLtvTzeEYT4pScql2vDWpx2TublwIMc-g../
  unzip index.html
  rm index.html
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
