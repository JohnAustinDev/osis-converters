#!/usr/bin/perl
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

# This file is only used only by forks.pl to run individual threads

my $forkFunc = @ARGV[2];
my $forkFile = @ARGV[3];
my @forkArgs; my $a = 4; while (@ARGV[$a]) {push(@forkArgs, @ARGV[$a++]);}

our $NOLOG = 1;
use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){3}$//; require "$SCRD/scripts/bootstrap.pl"; &init_linux_script();
our $NOLOG = 0;

# Include files where $forkFunc might be located
require("$SCRD/scripts/addScripRefLinks.pl");
require("$SCRD/scripts/bible/addDictLinks.pl");
require("$SCRD/scripts/dict/addSeeAlsoLinks.pl");

if (!-e $forkFile) {&ErrorBug("forkFile does not exist: $forkFile\n", 1);}
if (!exists &{$forkFunc}) {&ErrorBug("forkFunc does not exist: $forkFunc\n", 1);}

no strict "refs";
&$forkFunc($forkFile, @forkArgs);

1;
