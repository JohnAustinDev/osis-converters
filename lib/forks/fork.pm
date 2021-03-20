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

use strict;
use Encode;
use File::Path; 

# This file is used only by forks.pm to run any function as a separate 
# osis-converters thread.

#print("\nDEBUG: fork.pm ARGV=\n".join("\n", @ARGV)."\n");

# our INPD       = @ARGV[0]; # - Absolute path of the project directory.
# our LOGFILE    = @ARGV[1]; # - Absolute path of the log file for this
                             #   fork which must be in a unique 
                             #   subdirectory for this fork instance.
our $SCRIPT_NAME = @ARGV[2]; # - SCRIPT_NAME for forks.pm conf() context
my  $forkRequire = @ARGV[3]; # - Full path of script containing $forkFunc
my  $forkFunc    = @ARGV[4]; # - Name of function to run
my  @forkArgs;   my $a = 5;  # - Arguments to use with $forkFunc

while (defined(@ARGV[$a])) {push(@forkArgs, decode('utf8', @ARGV[$a++]));}

# Set TMPDIR so it will not be deleted by init(), and create it.
our $TMPDIR = @ARGV[1]; $TMPDIR =~ s/\/[^\/]+$//;
File::Path::make_path($TMPDIR);

# Save log path and use tmp log
my $forklog = @ARGV[1]; 
@ARGV[1] = "$TMPDIR/LOG_startup.txt";

# Initialize osis-converters
use strict; use File::Spec; our $SCRIPT = File::Spec->rel2abs(__FILE__); our $SCRD = $SCRIPT; $SCRD =~ s/([\\\/][^\\\/]+){3}$//; require "$SCRD/lib/common/bootstrap.pm"; &init(shift, shift);
our $LOGFILE = $forklog;

require("$SCRD/lib/forks/fork_funcs.pm");
require($forkRequire);

if (!exists &{$forkFunc}) {
  &ErrorBug("forkFunc '$forkFunc' does not exist in '$forkRequire'.\n", 1);
}

# Run the function
no strict "refs";

&Debug("Starting fork: $forkFunc(".join(', ', map("'$_'", @forkArgs)).")");

&$forkFunc(@forkArgs);

1;
