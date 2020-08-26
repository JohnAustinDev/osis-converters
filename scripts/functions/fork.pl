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

# This file is only used only by forks.pl to run a function in individual threads
use Encode;

my $forkRequire = @ARGV[2];
my $forkFunc = @ARGV[3];
my @forkArgs; my $a = 4; while (defined(@ARGV[$a])) {push(@forkArgs, decode('utf8', @ARGV[$a++]));}

our $NOLOG = 1;
use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){3}$//; require "$SCRD/scripts/bootstrap.pl"; &init_linux_script();
our $NOLOG = 0;

require("$SCRD/scripts/functions/fork_funcs.pl");

if ($forkRequire) {require("$SCRD/$forkRequire");}

if (!exists &{$forkFunc}) {&ErrorBug("forkFunc does not exist: $forkFunc\n", 1);}

no strict "refs";
&$forkFunc(@forkArgs);

1;
