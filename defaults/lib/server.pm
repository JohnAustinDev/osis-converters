#!/usr/bin/perl

# This file contains functions to interface with a particular server
# setup. This file will be superceded by any corresponding default file
# in a project's defaults directory.

# Return the filename to use (without extension) for the 'comp'
# publication.
sub compilationPubFileName {
  my $title = shift;
  my $scope = shift;

  my $t = $title; $t =~ s/\s+/-/g;
  my $s = $scope; $s =~ s/\s+/_/g;

  return "$t($s)";
}

# Return the filename to use (without file extension) for a particular
# 'full' sub-publication.
sub fullPubFileName {
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

# Return the filename to use (without extension) for a particular
# Generic Book publication.
sub genericBookFileName {
  my $title = shift;

  my $t = $title; $t =~ s/\s+/-/g;

  return "$t(Book)";
}

1;
