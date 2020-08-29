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

use Encode;

# This file is used only by forks.pl to run any function as a separate 
# osis-converters thread.

#print("\nDEBUG: fork.pl ARGV=\n".join("\n", @ARGV)."\n");

# INPD              = @ARGV[0]; # - Full path of the project directory.
# LOGFILE           = @ARGV[1]; # - Full path of log file for this fork, 
                                #   which must be in a subdirectory that 
                                #   is unique to this fork instance.
our $forkScriptName = @ARGV[2]; # - Used by osis-converters to signal it 
                                #   is running as a fork of a parent script.
my $forkRequire     = @ARGV[3]; # - Full path of script containing $forkFunc
my $forkFunc        = @ARGV[4]; # - Name of function to run
my @forkArgs;       my $a = 5;  # - Arguments to use with $forkFunc

while (defined(@ARGV[$a])) {push(@forkArgs, decode('utf8', @ARGV[$a++]));}

# Initialize osis-converters normally, but without logging anything yet.
our $NOLOG = 1;
use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){3}$//; require "$SCRD/scripts/bootstrap.pl"; &init_linux_script();
our $NOLOG = 0;

require("$SCRD/scripts/forks/fork_funcs.pl");
require($forkRequire);

if (!exists &{$forkFunc}) {
  &ErrorBug("forkFunc '$forkFunc' does not exist in '$forkRequire'.\n", 1);
}

# Run the function
no strict "refs";
&$forkFunc(@forkArgs);

1;
