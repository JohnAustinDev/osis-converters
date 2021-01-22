# This file is part of "osis-converters".
# 
# Copyright 2020 John Austin (gpl.programs.info@gmail.com)
#     
# "osis-converters" is free software: you can redistribute it and/or 
# modify it under the terms of the GNU General Public License as 
# published by the Free Software Foundation, either version 2 of 
# the License, or (at your option) any later version.
# 
# "osis-converters" is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with "osis-converters".  If not, see 
# <http://www.gnu.org/licenses/>.

use strict;
use Encode;

# Limit any section of Perl code to use by one thread at a time:
#
# my $block = BlockFile->new($filePath);
#
# This object will only be returned if and when there is no other 
# BlockFile object (in this or any other thread) having the same  
# $filepath. Thereafter it will block all other matching BlockFile 
# objects from returning until $block has passed out of scope.
# The $filePath must be a valid path to any file which may be 
# temporarily created and then deleted.

our ($WRITELAYER, $DEBUG);

# Destroy all block files on interrupt
$SIG{'INT'} = sub { exit; };

package BlockFile;

sub new {
  my $class = shift;
  my $self = { 'path' => shift };
  
  if (!$self->{'path'}) {
    &main::ErrorBug("Cannot create a blockFile without a file path.", 1);
    return;
  }
  
  while (1) {
    if (! -e $self->{'path'} && open(MTMP, ">$self->{'path'}")) {
      last;
    }
    print Encode::encode('utf8', "Waiting for BlockFile: $self->{'path'}\n");
    sleep 2;
  }
  close(MTMP);
  
  if ($DEBUG) {
    print Encode::encode('utf8', "Creating BlockFile: $self->{'path'}\n");
  }
  
  bless($self, $class);
  
  return $self
}

sub DESTROY {
  local($., $@, $!, $^E, $?);
  my $self = shift;
  
  if (! -e $self->{'path'}) {return;}
  
  if ($DEBUG) {
    print Encode::encode('utf8', "Removing BlockFile: $self->{'path'}\n");
  }
  
  unlink($self->{'path'});
}

package main;

;1
