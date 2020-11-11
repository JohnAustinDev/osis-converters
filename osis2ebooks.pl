#!/usr/bin/perl
# This file is part of "osis-converters".
# 
# Copyright 2012 John Austin (gpl.programs.info@gmail.com)
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

# usage: osis2ebooks.pl [Project_Directory]

# OSIS wiki: http://www.crosswire.org/wiki/OSIS_Bibles
# CONF wiki: http://www.crosswire.org/wiki/DevTools:conf_Files

use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){1}$//; require "$SCRD/scripts/bootstrap.pl"; &init(shift, shift);
require "$SCRD/scripts/osis2pubs.pl";
&Log("\nUsing ".`calibre --version`);
&osis2pubs('eBook');

&timer('stop'); &Log("\nend time: ".localtime()."\n");

#if (-e "$TMPDIR/OUT_osis2eBooks.txt") {
#  &Log("
#
#
#
#
#------------------------------------------------------------------------
#                      EBOOK DETAIL LOG:
#------------------------------------------------------------------------");
#  &shell("cat \"$TMPDIR/OUT_osis2eBooks.txt\"");
#}

1;
