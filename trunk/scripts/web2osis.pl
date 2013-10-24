# This file is part of "osis-converters".
# 
# Copyright 2013 John Austin (gpl.programs.info@gmail.com)
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
#
########################################################################

open(OUTF, ">:encoding(UTF-8)", "$OUTPUTFILE.1") || die "Could not open web2osis output file $OUTPUTFILE.1\n";
&Write("<?xml version=\"1.0\" encoding=\"UTF-8\" ?><osis xmlns=\"http://www.bibletechnologies.net/2003/OSIS/namespace\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.bibletechnologies.net/2003/OSIS/namespace $OSISSCHEMA\"><osisText osisIDWork=\"$MOD\" osisRefWork=\"defaultReferenceScheme\" xml:lang=\"$LANG\"><header><work osisWork=\"$MOD\"><title>$MOD Bible</title><identifier type=\"OSIS\">Bible.$MOD</identifier><refSystem>Bible.$VERSESYS</refSystem></work><work osisWork=\"defaultReferenceScheme\"><refSystem>Bible.$VERSESYS</refSystem></work></header>\n");

&Log("-----------------------------------------------------\nSTARTING web2osis.pl\n\n");

# Read the COMMANDFILE, converting each book as it is encountered to an intermediate, single file form
&normalizeNewLines($COMMANDFILE);
&removeRevisionFromCF($COMMANDFILE);
open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open html2osis command file $COMMANDFILE\n";

#Defaults:

$filename = "";
$linenum  = "";
$AllowSet = "addScripRefLinks|addDictLinks|addCrossRefs";
$line=0;
while (<COMF>) {
  $line++;
  
  if ($_ =~ /^\s*$/) {next;}
  elsif ($_ =~ /^#/) {next;}
  # VARIOUS SETTINGS...
  elsif ($_ =~ /^SET_($AllowSet):(\s*(\S+)\s*)?$/) {
    if ($2) {
      my $par = $1;
      my $val = $3;
      $$par = $val;
      if ($par =~ /^(addScripRefLinks|addDictLinks|addCrossRefs)$/) {
        $$par = ($$par && $$par !~ /^(0|false)$/i ? "1":"0");
      }
      &Log("INFO: Setting $par to $$par\n");
    }
  }
  # OT command...
  elsif ($_ =~ /^OT\s*$/) {
		$Testament="OT";
    &Write("<div type=\"bookGroup\">\n");
    $endTestament="</div>";
  }
  # NT command...
  elsif ($_ =~ /^NT\s*$/) {
    $Testament="NT";
    &Write("$endTestament\n<div type=\"bookGroup\">\n");
    $endTestament="</div>";
  }
  # SFM file name...
  elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {
    my $htmlfile = $1;
    $htmlfile =~ s/\\/\//g;
    if ($htmlfile =~ /^\./) {
      chdir($INPD);
      $htmlfile = File::Spec->rel2abs($htmlfile);
      chdir($SCRD);
    }
    my $bkname = "LUKE";
    &Write(&bookHTMLtoOSIS1($htmlfile, $bkname));
  }
  else {&Log("ERROR: Unhandled entry \"$_\" in $COMMANDFILE\n");}
}
close(COMF);

&Write("$endTestament\n</osisText>\n</osis>\n");
close (OUTF);

########################################################################
########################################################################

# Convert auto-generated HTML file to a normalized HTML file
sub bookHTMLtoOSIS1() {
	my $file = shift;
	my $book = shift;
	
	$filename = $file;
	$filename =~ s/^.*?[\/\\]([^\/\\]+)$/$1/;
	$linenum = 0;
  
  &Log("Processing $book\n");
  &normalizeNewLines($file);
  &logProgress($book);
  
  open(INP1, "<:encoding(UTF-8)", $file) or print getcwd." ERROR: Could not open file $file.\n";
  my $processing = 0;
  my $text = "";
  my %tagstack;
  my %textclass;
  while(<INP1>) {
		$linenum++;
		$_ =~ s/[\n\l\r]+$//;
		
		if ($text) {$text .= " ";}
		
		# process body only and ignore all else
		if ($_ =~ /<body[> ](.*)$/i) {
			$_ = $1;
			$processing = 1;
		}
		if (!$processing) {next;}
		if ($_ =~ /^(.*)<\/body[> ]/i) {
			$_ = $1;
			$processing = 0;
		}
		
		while($_) {
			if ($_ =~ s/^([^<]+)(<|$)/$2/) {$text .= $1;}
			if ($_ =~ s/^(<[^>]*>)//) {
				my $tag = $1;
				&handleText(\$text, \%tagstack);
				&handleTag($tag, \%tagstack);
			}
		}
	}
	close(INP1);
	
	if ($text && $text !~ /^\s*$/) {&Log("ERROR: $file line $line: unwritten text \"$text\"\n");}
	if ($tagstack{"level"}) {&Log("ERROR: $file line $line: tag level not zero \"".$tagstack{"level"}."\"\n");}
}

sub handleTag($\%) {
	my $tag = shift;
	my $tsP = shift;
	
	if ($tag =~ /<br(\s+|>)/i) {
		&Write("<lb \/>\n");
		return;
	}
	
	my $inline = "(span|font|sup|a|b|i)";
	
	# end tag
	if ($tag =~ /^<\/(\w+)/) {
		my $tagname = $1;
		my $taglevel = $tsP->{"level"};
		
		if ($tagname ne $tsP->{"tag-name"}{$tsP->{"level"}}) {
			if (1) {
				for (my $i = $tsP->{"level"}; $i > 0; $i--) {
					if ($tagname eq $tsP->{"tag-name"}{$i}) {
						$taglevel = $i;
						last;
					}
				}
			}
			else {
				&Log("ERROR: $filename line $linenum: Bad tag stack \"$tag\" != \"".$tsP->{"tag-name"}{$tsP->{"level"}}."\"\n");
			}
		}
		for (my $i = $tsP->{"level"}; $i > 0; $i--) {
			if ($i == $taglevel) {
				delete($tsP->{"tag-name"}{$i});
				delete($tsP->{"tag-key"}{$i});
			}
			if ($i > $taglevel) {
				$tsP->{"tag-name"}{$i-1} = $tsP->{"tag-name"}{$i};
				$tsP->{"tag-key"}{$i-1} = $tsP->{"tag-key"}{$i};
			}
		}
		$tsP->{"level"}--;
		
		if ($tagname !~ /^$inline$/i) {
			&Write("<\/".lc($tagname).">\n");
		}
	}
	
	#start tag
	else {
		$tag =~ /^<(\w+)\s*(.*)?\s*>$/;
		my $tagname = $1;
		my $atts = $2;
		
		my $tagkey = "";
		
		if ($atts) {
			# sort attributes to get key
			if ($atts =~ /^((\w+)(=("([^"]*)"|[\w\d]+))?\s*)+$/) {
				my %attrib;
				while ($atts) {
					if ($atts =~ s/^(\w+)=("([^"]*)"|([\w\d]+))\s*//) {
						$attrib{$1} = ($3 ? $3:$4);
					}
					$atts =~ s/^\w+(\s+|$)//; # some HTML has empty attribs so just remove
				}
			}
			else {&Log("ERROR: $filename line $linenum: bad tag attributes \"$atts\"\n");}
			$tagkey = $tag;
			foreach my $a (sort keys %attrib) {$tagkey .= " ".$a."=\"".$attrib{$a}."\"";}
		}
	
		$tsP->{"level"}++;
		$tsP->{"tag-name"}{$tsP->{"level"}} = $tagname;
		$tsP->{"tag-key"}{$tsP->{"level"}} = $tagkey;
		
		if ($tagname !~ /^$inline$/i) {
			if (!defined($tsP->{"classes"}{$tagkey})) {
				$ClassNumber++;
				$tsP->{"classes"}{$tagkey} = "c".$ClassNumber;
			}
			&Write("<".lc($tagname)." class=\"".$tsP->{"classes"}{$tagkey}."\">\n");
		}
	
	}
}

sub handleText(\$\%) {
	my $textP = shift;
	my $tsP = shift;

	if (length($$textP) == 0) {return;}
	
	$$textP =~ s/ +/ /g;
	
	if (!$tsP->{"level"} && $$textP !~ /^\s*$/) {
		&Log("WARN: $filename line $linenum: Top level text \"$$textP\"\n");
		&Write($$textP);
	}
	else {
		my $key = "";
		for (my $i = $tsP->{"level"}; $i > 0; $i--) {
			$key .= $tsP->{"tag-key"}{$i}.";";
		}
		if (!exists($tsP->{"classes"}{$key})) {
			$ClassNumber++;
			$tsP->{"classes"}{$key} = "c".$ClassNumber;
		}
		&Write("<span class=\"".$tsP->{"classes"}{$key}."\">".$$textP."</span>\n");
	}
	
	$$textP = "";
}
	
sub Write($) {
  my $print = shift;
  print OUTF $print;
}
