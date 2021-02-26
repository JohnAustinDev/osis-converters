#!/usr/bin/perl

# This file contains functions to interface with a particular server 
# setup. This file will be superceded by any corresponding default file
# in a project's defaults directory.

# Return the filename to use (without extension) for a particular 'tran' 
# publication.
sub tranPubFileName {
  my $title = shift;
  my $scope = shift;
  
  my $t = $title; $t =~ s/\s+/-/g;
  my $s = $scope; $s =~ s/\s+/_/g;
  
  return "$t($s)";
}

# Return the filename to use (without file extension) for a particular
# sub-publication.
sub subPubFileName {
  my $title = shift;
  my $scope = shift;

  my $t = $title; $t =~ s/\s+/-/g;
  my $s = $scope; $s =~ s/\s+/_/g;
  
  return "Subpub $t($s)";
}

# Return the filename to use (without file extension) for a particular
# single-book publication.
sub bookPubFileName {
  my $title = shift;
  my $scope = shift;
  my $type = shift;

  my $t = $title; $t =~ s/\s+/-/g;
  my $s = $scope; $s =~ s/\s+/_/g;
  
  return "$type $t($s)";
}

# Return the filename to use (without extension) for a particular
# Children's Bible publication.
sub childrensBibleFileName {
  my $title = shift;
  
  my $t = $title; $t =~ s/\s+/-/g;
  
  return "$t(Childrens_Bible)";
}

# Return a hash whose key value pairs are scope => sub-directory by
# scanning $url for files of $type and recording the scope of such 
# files located there and the sub-directory in which they are found. 
# The scope: 'childrens_bible' is used when Children's Bibles (having no 
# scope) are found.
sub readServerScopes {
  my $url        = shift; # URL to go to
  my $mainmod    = shift; # mainmod to look for
  my $type       = shift; # type of file to look for
  
  my %result;
  
  return \%result;
}

1;
