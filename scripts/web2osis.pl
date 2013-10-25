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
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with "osis-converters".	If not, see 
# <http://www.gnu.org/licenses/>.
#
########################################################################

&Log("-----------------------------------------------------\nSTARTING web2osis.pl\n\n");
open(OUTF, ">:encoding(UTF-8)", "$OUTPUTFILE") || die "Could not open web2osis output file $OUTPUTFILE\n";

&getCanon($VERSESYS, \%mycanon, \%mybookorder);

# Read the COMMANDFILE, converting each book as it is encountered
&normalizeNewLines($COMMANDFILE);
&removeRevisionFromCF($COMMANDFILE);
open(COMF, "<:encoding(UTF-8)", $COMMANDFILE) || die "Could not open html2osis command file $COMMANDFILE\n";

$ClassInstructions = "CHAPTER_NUMBER|VERSE_NUMBER|BOLD|ITALIC|REMOVE|CROSSREF|CROSSREF_MARKER|FOOTNOTE|FOOTNOTE_MARKER|IGNORE|INTRO_PARAGRAPH|INTRO_TITLE_1|LIST_TITLE|LIST_ENTRY|TITLE_1|TITLE_2|CANONICAL_TITLE_1|CANONICAL_TITLE_2|BLANK_LINE|PARAGRAPH|POETRY_LINE_GROUP|POETRY_LINE";
$TagInstructions = "IGNORE_KEY_TAGS|IGNORE_KEY_TAG_ATTRIBUTES";
$TrueFalseInstructions = "ALLOW_OVERLAPPING_HTML_TAGS|ALLOW_REDUCED_TAG_CLASSES|GATHER_CLASS_INFO";
$SetInstructions = "addScripRefLinks|addDictLinks|addCrossRefs";
$SetTrueFalse = "addScripRefLinks|addDictLinks|addCrossRefs";

$InlineTags = "(span|font|sup|a|b|i)";

$R = "\n";
$Filename = "";
$Linenum	= 0;
$line=0;
while (<COMF>) {
	$line++;
	
	if ($_ =~ /^\s*$/) {next;}
	elsif ($_ =~ /^#/) {next;}
	elsif ($_ =~ /^($ClassInstructions):\s*(\((.*?)\))?\s*$/) {if ($2) {$ClassInstruction{$1} = $3;}}
	elsif ($_ =~ /^($TagInstructions):\s*((<[^>]*>)+)?\s*$/) {if ($2) {$TagInstruction{$1} = $2;}}
	elsif ($_ =~ /^($TrueFalseInstructions):\s*(true|false)?\s*$/) {if ($2) {$TrueFalseInstruction{$1} = ($2 eq "true" ? 1:0);}}
	elsif ($_ =~ /^OSISBOOK:\s*(.*?)\s*=\s*(.*?)\s*$/) {$OsisBook{$1} = $2;}
	elsif ($_ =~ /^SPAN_CLASS:.*?(s\d+)=((<[^>]*>)+)\s*$/) {$SpanClassName{$2} = $1;}
	elsif ($_ =~ /^DIV_CLASS:.*?(d\d+)=((<[^>]*>)+)\s*$/) {$DivClassName{$2} = $1;}
	# VARIOUS SETTINGS...
	elsif ($_ =~ /^SET_($SetInstructions):(\s*(\S+)\s*)?$/) {
		if ($2) {
			my $par = $1;
			my $val = $3;
			$$par = $val;
			if ($par =~ /^($SetTrueFalse)$/) {
				$$par = ($$par && $$par !~ /^(0|false)$/i ? "1":"0");
			}
			&Log("INFO: Setting $par to $$par\n");
		}
	}
	# HTML file name...
	elsif ($_ =~ /^RUN:\s*(.*?)\s*$/) {
		my $htmlfile = $1;
		$htmlfile =~ s/\\/\//g;
		if ($htmlfile =~ /^\./) {
			chdir($INPD);
			$htmlfile = File::Spec->rel2abs($htmlfile);
			chdir($SCRD);
		}
		my $htmlfileName = $htmlfile;
		$htmlfileName =~ s/^.*?[\/\\]([^\/\\]+)$/$1/;
		if (exists($OsisBook{$htmlfileName}) && exists($mycanon{$OsisBook{$htmlfileName}})) {
			$TrueFalseInstruction{"GATHER_CLASS_INFO"} = ($TrueFalseInstruction{"GATHER_CLASS_INFO"} || !%SpanClassName && !%DivClassName);
			if ($TrueFalseInstruction{"GATHER_CLASS_INFO"}) {&Log("INFO: Gathering class information. Output is NOT OSIS!\n");}
			
			$Book = $OsisBook{$htmlfileName};
			
			my $osisText = &tagsHTMLtoOSIS($htmlfile);
			&handleNotes(\$osisText, "crossref");
			&handleNotes(\$osisText, "footnote");
			
			my $tmpBook = "$OUTPUTFILE.1";
			open(OUTTMP, ">:encoding(UTF-8)", $tmpBook) || die "Could not open web2osis output file $tmpBook\n";
			print OUTTMP $osisText;
			close(OUTTMP);
			
			my $swordText = &osis2SWORD($tmpBook);
			
			# save out text for sorting and printing later
			$OsisBookText{$OsisBook{$htmlfileName}} = $swordText;
		}
		else {&Log("ERROR: SKIPPING \"$htmlfile\". Could not determine OSIS book.\n");}
	}
	else {&Log("ERROR: Unhandled entry \"$_\" in $COMMANDFILE\n");}
}
close(COMF);

# print out our OSIS file in correct book order
&Write("<?xml version=\"1.0\" encoding=\"UTF-8\" ?><osis xmlns=\"http://www.bibletechnologies.net/2003/OSIS/namespace\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.bibletechnologies.net/2003/OSIS/namespace $OSISSCHEMA\"><osisText osisIDWork=\"$MOD\" osisRefWork=\"defaultReferenceScheme\" xml:lang=\"$LANG\"><header><work osisWork=\"$MOD\"><title>$MOD Bible</title><identifier type=\"OSIS\">Bible.$MOD</identifier><refSystem>Bible.$VERSESYS</refSystem></work><work osisWork=\"defaultReferenceScheme\"><refSystem>Bible.$VERSESYS</refSystem></work></header>\n");
&Write("<div type=\"bookGroup\">\n");
foreach my $bk (sort {$mybookorder{$a} <=> $mybookorder{$b}} keys %OsisBookText) {
	if ($wasWritingOT && $mybookorder{$bk} > 39) {&Write("</div>\n<div type=\"bookGroup\">\n");}
	&Write($OsisBookText{$bk});
	$wasWritingOT = ($mybookorder{$bk} <= 39);
}
&Write("</div>\n</osisText>\n</osis>\n");
close (OUTF);

# log a bunch of stuff now...
&Log("\nLISTING OF SPAN CLASSES:\n");
foreach my $classTags (sort {$SpanClassCounts{$SpanClassName{$a}} <=> $SpanClassCounts{$SpanClassName{$b}}} keys %SpanClassName) {
	&Log(sprintf("SPAN_CLASS:%5i %3s=%s\n", $SpanClassCounts{$SpanClassName{$classTags}}, $SpanClassName{$classTags}, $classTags));
}

&Log("\nLISTING OF DIV CLASSES:\n");
foreach my $classTags (sort {$DivClassCounts{$DivClassName{$a}} <=> $DivClassCounts{$DivClassName{$b}}} keys %DivClassName) {
	&Log(sprintf("DIV_CLASS:%5i %3s=%s\n", $DivClassCounts{$DivClassName{$classTags}}, $DivClassName{$classTags}, $classTags));
}

&Log("\nLISTING OF ALL HTML TAGS:\n");
foreach my $t (sort keys %AllHTMLTags) {
	&Log($t." ");
}
&Log("\nlisting complete\n");

1;

########################################################################
########################################################################

# All this does is convert HTML tags into correct OSIS tags.
sub tagsHTMLtoOSIS() {
	my $file = shift;
	
	my $outText = "";
	
	$Filename = $file;
	$Filename =~ s/^.*?[\/\\]([^\/\\]+)$/$1/;
	$Linenum = 0;
	
	&Log("Processing $Book\n");
	&normalizeNewLines($file);
	&logProgress($Book);
	
	open(INP1, "<:encoding(UTF-8)", $file) or print getcwd." ERROR: Could not open file $file.\n";
	my $processing = 0;
	my $text = "";
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
				$outText .= &getText(\$text);
				$outText .= &getTag($tag);
			}
		}
	}
	close(INP1);
	
	if ($text && $text !~ /^\s*$/) {&Log("ERROR: $file line $line: unwritten text \"$text\"\n");}
	if ($tagstack{"level"}) {&Log("ERROR: $file line $line: tag level not zero \"".$tagstack{"level"}."\"\n");}
	
	return $outText;
}

sub getTag($\%) {
	my $tag = shift;
	
	my $outText = "";
	
	if ($tag =~ /<br(\s+|>)/i) {
		$outText .= "<lb \/>\n";
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
			
			
			my @ignoreAttribs = split(/(<[^>]*>)/, $TagInstruction{"IGNORE_KEY_TAG_ATTRIBUTES"});
			
			foreach my $a (sort keys %attrib) {
				$tagvalue .= " ".lc($a)."=\"".$attrib{$a}."\"";
				my $skipme = 0;
				
				# skip listed tag/attribute pairs which are not relavent to key
				foreach my $ignoreAttrib (@ignoreAttribs) {
					if (!$ignoreAttrib) {next;}
					if ($ignoreAttrib !~ /^<([\w\*]+)\s+(\w+)\s*>$/) {
						&Log("ERROR: Bad IGNORE_KEY_TAG_ATTRIBUTES value \"$ignoreAttrib\"\n");
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
			if (!$TrueFalseInstruction{"GATHER_CLASS_INFO"} && !exists($DivClassName{$tagkey})) {
				&Log("ERROR: DIV_CLASS was not specified in CF_html2osis.txt: \"$tagkey\".\n");
			}
			if (!exists($DivClassName{$tagkey})) {
				$DivClassNumber++;
				$DivClassName{$tagkey} = "d".$DivClassNumber;
			}
			$DivClassCounts{$DivClassName{$tagkey}}++;
			
			$outText .= &blockTag2Osis($tagname, $DivClassName{$tagkey}, 0);
		}

		# skip certain tags for tagkey
		my @ignoreTags = split(/(<[^>]*>)/, $TagInstruction{"IGNORE_KEY_TAGS"});
		foreach my $ignoreTag (@ignoreTags) {
			if (!$ignoreTag) {next;}
			if ($ignoreTag !~ /<(\w+)/) {next;}
			my $it = $1;
			if (lc($it) eq lc($tagname)) {$tagkey = "";}
		}

		$TagStack{"level"}++;
		$TagStack{"tag-name"}{$TagStack{"level"}} = $tagname;
		$TagStack{"tag-key"}{$TagStack{"level"}} = $tagkey;
		$TagStack{"tag-value"}{$TagStack{"level"}} = $tagvalue;
	}
	
	#end tag
	else {
		my $tagname = $1;
		my $taglevel = $TagStack{"level"};
		
		$AllHTMLTags{$tagname}++;
		
		if ($tagname ne $TagStack{"tag-name"}{$TagStack{"level"}}) {
			if ($TrueFalseInstruction{"ALLOW_OVERLAPPING_HTML_TAGS"}) {
				for (my $i = $TagStack{"level"}; $i > 0; $i--) {
					if ($tagname eq $TagStack{"tag-name"}{$i}) {
						$taglevel = $i;
						last;
					}
				}
			}
			else {
				&Log("ERROR: $Filename line $Linenum: Bad tag stack \"$tag\" != \"".$TagStack{"tag-name"}{$TagStack{"level"}}."\"\n");
			}
		}
		
		if ($tagname !~ /^$InlineTags$/i) {
			$outText .= &blockTag2Osis($tagname, $DivClassName{$TagStack{"tag-key"}{$taglevel}}, 1);
		}
		
		for (my $i = $TagStack{"level"}; $i > 0; $i--) {
			if ($i == $taglevel) {
				delete($TagStack{"tag-name"}{$i});
				delete($TagStack{"tag-key"}{$i});
				delete($TagStack{"tag-value"}{$i});
			}
			if ($i > $taglevel) {
				$TagStack{"tag-name"}{$i-1} = $TagStack{"tag-name"}{$i};
				$TagStack{"tag-key"}{$i-1} = $TagStack{"tag-key"}{$i};
				$TagStack{"tag-value"}{$i-1} = $TagStack{"tag-value"}{$i};
			}
		}
		$TagStack{"level"}--;
	}
	
	return $outText;
}

sub getText(\$\%) {
	my $textP = shift;
	
	my $outText = "";

	if (length($$textP) == 0) {return;}
	
	my $class = "";
	
	if (!$TagStack{"level"} && $$textP !~ /^\s*$/) {
		&Log("WARN: $Filename line $Linenum: Top level text \"$$textP\"\n");
	}
	else {
		# create a key by combining all current tags
		my $key = "";
		my @tkeys;
		my %count;
		for (my $i = $TagStack{"level"}; $i > 0; $i--) {
			my $ktagval = $TagStack{"tag-key"}{$i};
			if ($TrueFalseInstruction{"ALLOW_REDUCED_TAG_CLASSES"}) {
				if ($TagStack{"tag-name"}{$i} !~ /^$InlineTags$/i) {next;}
				if ($ktagval eq "" || exists($count{$ktagval})) {next;}
				$count{$ktagval}++;
			}
			push(@tkeys, $ktagval);
		}
		
		if ($TrueFalseInstruction{"ALLOW_REDUCED_TAG_CLASSES"}) {
			# then tkeys are sorted 
			foreach my $tkey (sort @tkeys) {$key .= $tkey;}
		}
		else {foreach my $tkey (@tkeys) {$key .= $tkey;}}

		if ($key ne "") {
			if (!$TrueFalseInstruction{"GATHER_CLASS_INFO"} && !exists($SpanClassName{$key})) {
				&Log("ERROR: SPAN_CLASS was not specified in CF_html2osis.txt: \"$key\".\n");
			}
			if (!exists($SpanClassName{$key})) {
				$ClassNumber++;
				$SpanClassName{$key} = "s".$ClassNumber;
			}
			$SpanClassCounts{$SpanClassName{$key}}++;
			
			$class = $SpanClassName{$key};
		}
	}
	
	$outText .= &text2Osis($$textP, $class);
	
	$$textP = "";
	return $outText;
}

sub blockTag2Osis($$$) {
	my $tag = shift;
	my $class = shift;
	my $isEndTag = shift;
	
	return &renderOSISTag($tag, $class, $isEndTag).$R;
}

sub text2Osis($$) {
	my $text = shift;
	my $class = shift;
	
	$text =~ s/\s+/ /g;
	
	my $t = "";
	if ($class) {$t .= &renderOSISTag("span", $class, 0);}
	$t .= $text;
	if ($class) {$t .= &renderOSISTag("span", $class, 1);}
	
	return $t.$R;
}

sub renderOSISTag($$$) {
	my $tag = lc(shift);
	my $class = shift;
	my $isEndTag = shift;
	
	if ($class eq "") {return "";}
	
	my $t = "";
	if ($TrueFalseInstruction{"GATHER_CLASS_INFO"}) {
		$t .= "<";
		if ($isEndTag) {$t .= "/";}
		$t .= $tag;
		if (!$isEndTag && $class) {$t .= " class=\"$class\"";}
		$t .= ">";
	}
	else {
		# convert the tag and class to OSIS
		my $myOsisClass = "";
		foreach my $inst (keys %ClassInstruction) {
			my $c = $ClassInstruction{$inst};
			if ($class =~ /^($c)$/) {
				if ($myOsisClass) {&Log("ERROR: Multiple definitions for class \"$class\" (\"$myOsisClass\" and \"$inst\").\n");}
				$myOsisClass = $inst;
			}
		}
		if ($myOsisClass) {$t .= &getOSISTagfromOSISClass($myOsisClass, $isEndTag);}
		else {
			if (!exists($DefErrorReported{$class})) {
				&Log("ERROR: No definition assigned to class \"$class\"\n");
			}
			$DefErrorReported{$class}++;
		}
	}
	
	return $t;
}

sub getOSISTagfromOSISClass($$) {
	my $class = shift;
	my $isEndTag = shift;
	
	my $tag = "";
	my $attribs = "";

	if    ($class eq "VERSE_NUMBER") {$tag = "verse";}
	elsif($class eq "CHAPTER_NUMBER") {$tag = "chapter";}
	elsif($class eq "BOLD") {$tag = "hi"; $attribs = "type=\"bold\"";}
	elsif($class eq "ITALIC") {$tag = "hi"; $attribs = "type=\"italic\"";}
	elsif($class eq "REMOVE") {return "";} # is it really that safe to remove the enclosing text too???
	elsif($class eq "CROSSREF_MARKER") {$tag = "OC_crossrefMarker"; if (!$isEndTag) {$attribs = "id=\"".&getCurrentNoteId(++$CrossRefMarkerID)."\"";}}
	elsif($class eq "CROSSREF") {$tag = "OC_crossref"; if (!$isEndTag) {$attribs = "id=\"".&getCurrentNoteId(++$CrossRefID)."\"";}}
	elsif($class eq "FOOTNOTE_MARKER") {$tag = "OC_footnoteMarker"; if (!$isEndTag) {$attribs = "id=\"".&getCurrentNoteId(++$FootnoteMarkerID)."\"";}}
	elsif($class eq "FOOTNOTE") {$tag = "OC_footnote"; if (!$isEndTag) {$attribs = "id=\"".&getCurrentNoteId(++$FootnoteID)."\"";}}
	elsif($class eq "IGNORE") {return "";}
	elsif($class eq "INTRO_PARAGRAPH") {$tag = "p"; $attribs = "type=\"x-intro\"";}
	elsif($class eq "INTRO_TITLE_1") {$tag = "title"; $attribs = "type=\"x-intro\" level=\"1\"";}
	elsif($class eq "LIST_TITLE") {$tag = "list"; $attribs = "type=\"x-intro\"";}
	elsif($class eq "LIST_ENTRY") {$tag = "item"; $attribs = "type=\"x-listitem\"";}
	elsif($class eq "TITLE_1") {$tag = "title"; $attribs = "level=\"1\"";}
	elsif($class eq "TITLE_2") {$tag = "title"; $attribs = "level=\"2\"";}
	elsif($class eq "CANONICAL_TITLE_1") {$tag = "title"; $attribs = "level=\"1\" canonical=\"true\"";}
	elsif($class eq "CANONICAL_TITLE_2") {$tag = "title"; $attribs = "level=\"2\" canonical=\"true\"";}
	elsif($class eq "BLANK_LINE") {$tag = (!$isEndTag ? "</lb >":"");}
	elsif($class eq "PARAGRAPH") {$tag = "p";}
	elsif($class eq "POETRY_LINE_GROUP") {$tag = "lg";}
	elsif($class eq "POETRY_LINE") {$tag = "l";}
	
	if ($tag eq "") {&Log("ERROR: No entry for OSIS tag \"$class\"\n");}
	
	if (!$isEndTag && ($class eq "FOOTNOTE" || $class eq "CROSSREF")) {$R = "";}
	if ($isEndTag  && ($class eq "FOOTNOTE" || $class eq "CROSSREF")) {$R = "\n";}

	my $ret = "<";
	if ($isEndTag) {$ret .= "/";}
	$ret .= $tag;
	if (!$isEndTag && $attribs) {$ret .= " ".$attribs;}
	$ret .= ">";
	
	return $ret;
}

sub handleNotes(\$$) {
	my $tP = shift;
	my $type = shift;
	
	# find and convert each note body
	while ($$tP =~ s/(<OC_$type id="([^"]*)">(.*?)<\/OC_$type>)//) {
		my $bodyIndex = $-[1];
		my $id = $2;
		my $body = $3;
		
		my $note = "<note".($type eq "crossref" ? " type=\"crossReference\"":"");
		$note .= " osisRef=\"$Book.xCHx.xVSx\"";
		$note .= " osisID=\"$Book.xCHx.xVSx!".($type eq "crossref" ? "crossReference.":"")."n$id\"";
		$note .= " n=\"$id\"";
		$note .=">$body</note>";
		
		# place the note now
		if (exists($ClassInstruction{($type eq "crossref" ? "CROSSREF_MARKER":"FOOTNOTE_MARKER")})) {
			my $typeMarker = $type."Marker";
			if ($$tP !~ s/(<OC_$typeMarker id="$id">.*?<\/OC_$typeMarker>)/$note/) {
				&Log("ERROR: Could not find marker for $type \"$id\".\n");
			}
		}
		else {substr($$tP, $bodyIndex, 0) = $note;}
	}
	
	if ($$tP =~ /<OC_$type/) {&Log("ERROR: Unhandled note type $type \"$id\".\n");}
}

sub getCurrentNoteId($) {
	my $n = shift;
	return $n;
}

sub osis2SWORD($) {
	my $bkfile = shift;
	
	my $s = "<div type=\"book\" osisID=\"$Book\" canonical=\"true\">\n";
	
	open(IBK, "<:encoding(UTF-8)", $bkfile) || die "Could not open $bkfile\n";

	my $chapter = 0;
	my $verse = 0;

	my $verseEnd = "";
	my $sectionEnd = "";
	my $chapterEnd = "";

	while (<IBK>) {
		if ($_ =~ /<chapter>(.*?)<\/chapter>/) {
			my $ch = $1;
			$verse = 0;
			
			$s .= $verseEnd.$sectionEnd.$chapterEnd;
			$verseEnd = "";
			$sectionEnd = "";
			$chapterEnd = "</chapter>\n";
			
			if ($ch =~ /^\s*(\d+)\s*/) {$chapter = $1;}
			else {&Log("ERROR: Could not parse chapter \"$ch\".\n");}
			
			$s .= "<chapter osisID=\"$Book.$chapter\" n=\"$chapter\">\n";
			next;
		}
		elsif ($_ =~ /<verse>(.*?)<\/verse>/) {
			my $vs = $1;
			
			$s .= $verseEnd;
			
			if ($vs =~ /^\s*(\d+)\s*(-\s*(\d+))?/) {$verse = $1.($2 ? "-$3":"");}
			else {&Log("ERROR: Could not parse verse \"$vs\".\n");}
			$verseEnd = "<verse eID=\"$Book.$chapter.$verse\" />\n";
			
			my $osisID = "$Book.$chapter.$verse";
			if ($verse =~ /^(\d+)\-(\d+)$/) {
				my $v1 = $1;
				my $v2 = $2;
				my $sep = " ";
				for (my $i=$v1; $i<=$v2; $i++) {
					$osisID .= $sep."$Book.$chapter.$i";
					$sep = " ";
				}
			}
			$s .= "<verse sID=\"$Book.$chapter.$verse\" osisID=\"$osisID\" n=\"$verse\" />";
			next;
		}
		
		if ($_ =~ /<title [^>]*>.*?<\/title>/) {
			$s .= $verseEnd.$sectionEnd;
			$verseEnd = "";
			$sectionEnd = "";
			
			if ($chapter) {
				$sectionEnd = "</div>\n";
				$s .= "<div type=\"section\">\n";
			}
		}
		
		$_ =~ s/&nbsp;/ /g;
		$_ =~ s/xCHx/$chapter/g;
		$_ =~ s/xVSx/$verse/g;
		
		$s .= $_;
	}
	close(IBK);
	
	$s .= $verseEnd.$sectionEnd.$chapterEnd;
	$s .= "</div>\n";
	
	return $s;
}
	
sub Write($) {
	my $print = shift;
	print OUTF $print;
}
