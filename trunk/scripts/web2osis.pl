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
$IgnoreKeyTags = "<b><i>";
$IgnoreKeyTagAttributes = "<a name><a href><* id>";

$AllowOverlappingHTMLTags = 1;
$AllowReducedTagClasses = 1;
$AllowSet = "addScripRefLinks|addDictLinks|addCrossRefs";
$InlineTags = "(span|font|sup|a|b|i)";

$Filename = "";
$Linenum  = 0;
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

&Log("\nLISTING OF SPAN CLASSES:\n");
foreach my $class (sort {$SpanClassCounts{$a} <=> $SpanClassCounts{$b}} keys %AllSpanClasses) {
	&Log(sprintf("INFO:%5i %3s=%s\n", $SpanClassCounts{$class}, $class, $AllSpanClasses{$class}));
}

&Log("\nLISTING OF DIV CLASSES:\n");
foreach my $class (sort {$DivClassCounts{$a} <=> $DivClassCounts{$b}} keys %AllDivClasses) {
	&Log(sprintf("INFO:%5i %3s=%s\n", $DivClassCounts{$class}, $class, $AllDivClasses{$class}));
}

&Log("\nLISTING OF ALL HTML TAGS:\n");
foreach my $t (sort keys %AllHTMLTags) {
	&Log($t." ");
}
&Log("\nlisting complete\n");

1;

########################################################################
########################################################################

# Convert auto-generated HTML file to a normalized HTML file
sub bookHTMLtoOSIS1() {
	my $file = shift;
	my $book = shift;
	
	$Filename = $file;
	$Filename =~ s/^.*?[\/\\]([^\/\\]+)$/$1/;
	$Linenum = 0;
  
  &Log("Processing $book\n");
  &normalizeNewLines($file);
  &logProgress($book);
  
  open(INP1, "<:encoding(UTF-8)", $file) or print getcwd." ERROR: Could not open file $file.\n";
  my $processing = 0;
  my $text = "";
  my %tagstack;
  my %textclass;
  while(<INP1>) {
		$Linenum++;
		$_ =~ s/[\n\l\r]+$//;
		
		if ($text) {$text .= " ";} # a previous line feed in text requires a space
		
		# process body only and ignore all else
		if ($_ =~ /<body[^>]*>(.*)$/i) {
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
		$AllHTMLTags{"br"}++;
		return;
	}
	
	# start tag
	if ($tag !~ /^<\/(\w+)/) {
		$tag =~ /^<(\w+)\s*(.*)?\s*>$/;
		my $tagname = $1;
		my $atts = $2;
		
		$AllHTMLTags{$tagname}++;
		
		my $tagkey = "<".lc($tagname);
		my $tagvalue = $tagkey;
		if ($atts) {
			# sort all attributes out
			my %attrib;
			if ($atts =~ /^((\w+)(=("([^"]*)"|[\w\d]+))?\s*)+$/) {
				while ($atts) {
					if ($atts =~ s/^(\w+)=("([^"]*)"|([\w\d]+))\s*//) {
						$attrib{$1} = ($3 ? $3:$4);
					}
					$atts =~ s/^\w+(\s+|$)//; # some HTML has empty attribs so just remove them
				}
			}
			else {&Log("ERROR: $Filename line $Linenum: bad tag attributes \"$atts\"\n");}
			
			
			my @ignoreAttribs = split(/(<[^>]*>)/, $IgnoreKeyTagAttributes);
			
			foreach my $a (sort keys %attrib) {
				$tagvalue .= " ".lc($a)."=\"".$attrib{$a}."\"";
				my $skipme = 0;
				
				# skip listed tag/attribute pairs which are not relavent to key
				foreach my $ignoreAttrib (@ignoreAttribs) {
					if (!$ignoreAttrib) {next;}
					if ($ignoreAttrib !~ /^<([\w\*]+)\s+(\w+)\s*>$/) {
						&Log("ERROR: Bad IgnoreKeyTagAttributes value \"$ignoreAttrib\"\n");
						next;
					}
					my $it = $1;
					my $ia = $2;
					if (lc($ia) eq lc($a) && ($it eq "*" || lc($it) eq lc($tagname))) {
						$skipme = 1;
					}
				}
				if ($skipme) {next;}
				
				# save attribute to key
				$tagkey .= " ".lc($a)."=\"".$attrib{$a}."\"";
			}
		}
		$tagkey .= ">";
		$tagvalue .= ">";
		
		# write out all block tags now
		if ($tagname !~ /^$InlineTags$/i) {
			if (!defined($tsP->{"classes"}{$tagkey})) {
				$DivClassNumber++;
				$tsP->{"classes"}{$tagkey} = "d".$DivClassNumber;
				$AllDivClasses{"d".$DivClassNumber} = $tagkey;
			}
			
			$DivClassCounts{$tsP->{"classes"}{$tagkey}}++;
			&Write("<".lc($tagname)." class=\"".$tsP->{"classes"}{$tagkey}."\">\n");
		}

		# skip certain tags for tagkey
		my @ignoreTags = split(/(<[^>]*>)/, $IgnoreKeyTags);
		foreach my $ignoreTag (@ignoreTags) {
			if (!$ignoreTag) {next;}
			if ($ignoreTag !~ /<(\w+)/) {next;}
			my $it = $1;
			if (lc($it) eq lc($tagname)) {$tagkey = "";}
		}
		if ($tagname !~ /^$InlineTags$/i) {$tagkey = "";}

		$tsP->{"level"}++;
		$tsP->{"tag-name"}{$tsP->{"level"}} = $tagname;
		$tsP->{"tag-key"}{$tsP->{"level"}} = $tagkey;
		$tsP->{"tag-value"}{$tsP->{"level"}} = $tagvalue;
	}
	
	#end tag
	else {
		my $tagname = $1;
		my $taglevel = $tsP->{"level"};
		
		$AllHTMLTags{$tagname}++;
		
		if ($tagname ne $tsP->{"tag-name"}{$tsP->{"level"}}) {
			if ($AllowOverlappingHTMLTags) {
				for (my $i = $tsP->{"level"}; $i > 0; $i--) {
					if ($tagname eq $tsP->{"tag-name"}{$i}) {
						$taglevel = $i;
						last;
					}
				}
			}
			else {
				&Log("ERROR: $Filename line $Linenum: Bad tag stack \"$tag\" != \"".$tsP->{"tag-name"}{$tsP->{"level"}}."\"\n");
			}
		}
		for (my $i = $tsP->{"level"}; $i > 0; $i--) {
			if ($i == $taglevel) {
				delete($tsP->{"tag-name"}{$i});
				delete($tsP->{"tag-key"}{$i});
				delete($tsP->{"tag-value"}{$i});
			}
			if ($i > $taglevel) {
				$tsP->{"tag-name"}{$i-1} = $tsP->{"tag-name"}{$i};
				$tsP->{"tag-key"}{$i-1} = $tsP->{"tag-key"}{$i};
				$tsP->{"tag-value"}{$i-1} = $tsP->{"tag-value"}{$i};
			}
		}
		$tsP->{"level"}--;
		
		if ($tagname !~ /^$InlineTags$/i) {
			&Write("<\/".lc($tagname).">\n");
		}
	}
	
}

sub handleText(\$\%) {
	my $textP = shift;
	my $tsP = shift;

	if (length($$textP) == 0) {return;}
	
	$$textP =~ s/ +/ /g;
	
	if (!$tsP->{"level"} && $$textP !~ /^\s*$/) {
		&Log("WARN: $Filename line $Linenum: Top level text \"$$textP\"\n");
		&Write($$textP);
	}
	else {
		my $key = "";
		my @tkeys;
		my %count;
		for (my $i = $tsP->{"level"}; $i > 0; $i--) {
			my $ktagval = $tsP->{"tag-key"}{$i};
			if ($ktagval eq "") {next;}
			if ($AllowReducedTagClasses) {
				if (exists($count{$ktagval})) {next;}
			}
			$count{$ktagval}++;
			push(@tkeys, $ktagval);
		}
		
		if ($AllowReducedTagClasses) {
			# tkeys are sorted 
			foreach my $tkey (sort @tkeys) {$key .= $tkey;}
		}
		else {foreach my $tkey (@tkeys) {$key .= $tkey;}}

c16 is empty space with empty spans tags... 

		if (!exists($tsP->{"classes"}{$key})) {
			$ClassNumber++;
			$tsP->{"classes"}{$key} = "c".$ClassNumber;
			$AllSpanClasses{"c".$ClassNumber} = $key;
		}
		
		$SpanClassCounts{$tsP->{"classes"}{$key}}++;
		&Write("<span class=\"".$tsP->{"classes"}{$key}."\">".$$textP."</span>\n");
		
	}
	
	$$textP = "";
}
	
sub Write($) {
  my $print = shift;
  print OUTF $print;
}
