# This file is part of "osis-converters".
# 
# Copyright 2019 John Austin (gpl.programs.info@gmail.com)
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

@CB_SECTION_CHAPS = (0, 133, 113, 23); # Number of chapters in: Book intro, OT, NT, maps+pics
%CB_IMAGES = ('ot.1' => '015','ot.2' => '017','ot.3' => '019','ot.4' => '021','ot.5' => '023','ot.6' => '025','ot.7' => '027','ot.8' => '029','ot.9' => '031','ot.10' => '033','ot.11' => '035','ot.12' => '037','ot.13' => '039','ot.14' => '041','ot.15' => '043','ot.16' => '045','ot.17' => '047','ot.18' => '049','ot.19' => '051','ot.20' => '053','ot.21' => '055','ot.22' => '057','ot.23' => '059','ot.24' => '061','ot.25' => '063','ot.26' => '065','ot.27' => '067','ot.28' => '069','ot.29' => '071','ot.30' => '073','ot.31' => '075','ot.32' => '077','ot.33' => '079','ot.34' => '081','ot.35' => '083','ot.36' => '085','ot.37' => '087','ot.38' => '089','ot.39' => '091','ot.40' => '093','ot.41' => '095','ot.42' => '097','ot.43' => '099','ot.44' => '101','ot.45' => '103','ot.46' => '105','ot.47' => '107','ot.48' => '109','ot.49' => '111','ot.50' => '113','ot.51' => '115','ot.52' => '117','ot.53' => '119','ot.54' => '121','ot.55' => '123','ot.56' => '125','ot.57' => '127','ot.58' => '129','ot.59' => '131','ot.60' => '133','ot.61' => '135','ot.62' => '137','ot.63' => '139','ot.64' => '141','ot.65' => '143','ot.66' => '145','ot.67' => '147','ot.68' => '149','ot.69' => '151','ot.70' => '153','ot.71' => '155','ot.72' => '157','ot.73' => '159','ot.74' => '161','ot.75' => '163','ot.76' => '165','ot.77' => '167','ot.78' => '169','ot.79' => '171','ot.80' => '173','ot.81' => '175','ot.82' => '177','ot.83' => '179','ot.84' => '181','ot.85' => '183','ot.86' => '185','ot.87' => '187','ot.88' => '189','ot.89' => '191','ot.90' => '193','ot.91' => '195','ot.92' => '197','ot.93' => '199','ot.94' => '201','ot.95' => '203','ot.96' => '205','ot.97' => '207','ot.98' => '209','ot.99' => '211','ot.100' => '213','ot.101' => '215','ot.102' => '217','ot.103' => '219','ot.104' => '221','ot.105' => '223','ot.106' => '225','ot.107' => '227','ot.108' => '229','ot.109' => '231','ot.110' => '233','ot.111' => '235','ot.112' => '237','ot.113' => '239','ot.114' => '241','ot.115' => '243','ot.116' => '245','ot.117' => '247','ot.118' => '249','ot.119' => '251','ot.120' => '253','ot.121' => '255','ot.122' => 'text','ot.123' => '259','ot.124' => '261','ot.125' => '263','ot.126' => '265','ot.127' => '267','ot.128' => '269','ot.129' => '271','ot.130' => '273','ot.131' => '275','ot.132' => '277','ot.133' => '279','nt.1' => '287','nt.2' => '289','nt.3' => '291','nt.4' => '293','nt.5' => '295','nt.6' => '297','nt.7' => '299','nt.8' => '301','nt.9' => '303','nt.10' => '305','nt.11' => '307','nt.12' => '309','nt.13' => '311','nt.14' => '313','nt.15' => '315','nt.16' => '317','nt.17' => '319','nt.18' => '321','nt.19' => '323','nt.20' => '325','nt.21' => '327','nt.22' => '329','nt.23' => '331','nt.24' => '333','nt.25' => 'text','nt.26' => '337','nt.27' => 'text','nt.28' => '341','nt.29' => '343','nt.30' => '345','nt.31' => '347','nt.32' => '349','nt.33' => '351','nt.34' => '353','nt.35' => '355','nt.36' => '357','nt.37' => '359','nt.38' => '361','nt.39' => '363','nt.40' => '365','nt.41' => '367','nt.42' => '369','nt.43' => '371','nt.44' => '375','nt.45' => '379','nt.46' => '381','nt.47' => '383','nt.48' => '377','nt.49' => '385','nt.50' => '387','nt.51' => '389','nt.52' => '391','nt.53' => '393','nt.54' => '397','nt.55' => '399','nt.56' => '401','nt.57' => '403','nt.58' => '405','nt.59' => '407','nt.60' => '409','nt.61' => '411','nt.62' => '413','nt.63' => '415','nt.64' => '417','nt.65' => '419','nt.66' => '421','nt.67' => '423','nt.68' => '425','nt.69' => '427','nt.70' => '429','nt.71' => '431','nt.72' => '433','nt.73' => '435','nt.74' => '437','nt.75' => '439','nt.76' => '441','nt.77' => '443','nt.78' => '445','nt.79' => '447','nt.80' => '449','nt.81' => '451','nt.82' => '453','nt.83' => '455','nt.84' => '457','nt.85' => '459','nt.86' => '461','nt.87' => '463','nt.88' => '465','nt.89' => '467','nt.90' => '469','nt.91' => '471','nt.92' => '473','nt.93' => '475','nt.94' => '477','nt.95' => '479','nt.96' => '481','nt.97' => '483','nt.98' => '485','nt.99' => '487','nt.100' => '489','nt.101' => '491','nt.102' => '493','nt.103' => '495','nt.104' => '497','nt.105' => '499','nt.106' => 'text','nt.107' => '503','nt.108' => '505','nt.109' => '507','nt.110' => '509','nt.111' => '511','nt.112' => '513','nt.113' => '515');

# Children's Bibles all have the same structure so they can be viewed in parallel. So
# check that structure now and return 1 if all is well:
# <div type="book" osisID="English Children's Bible">
#   <figure cover/><figure letter/>
#   <div type="majorSection" osisID="Book Introduction">This is the book introduction</div>
#   <div type="majorSection" osisID="Old Testament">
#     This is the testament intro (maybe just a title)
#     <div type="chapter" osisID="Chapter"></div> (x of these)
#   </div>
#   <div type="majorSection" osisID="New Testament">
#     This is the testament intro (maybe just a title)
#     <div type="chapter" osisID="Chapter"></div> (x of these)
#   </div>
#   <div type="majorSection" osisID="Maps and pictures">
#     This is the Maps and pictures introduction (maybe just a title)
#     <div type="chapter" osisID="Chapter"></div> (x of these)
#   </div>
# </div> 
sub checkChildrensBibleStructure($) {
  my $osis = shift;
  
  &Log("\nCHECKING CHILDREN'S BIBLE STRUCTURE IN $osis...\n");
  
  my $xml = $XML_PARSER->parse_file($osis);
  my @divs = &getCBDivs($xml);
  my $success = (@divs ? 1:0);
  for (my $x=1; $x<=@CB_SECTION_CHAPS; $x++) {
    &Note("Checking section #$x:");
    if (!&checkCBsection(@divs[$x], $x)) {$success = 0;}
  }
  
  $success &= &checkAdjustCBImages(\$osis, 1);
  
  if ($success) {&Note("There are no problems with the Children's Bible structure.");}
  
  return $success;
}

sub getCBDivs($) {
  my $xml = shift;
  
  my $success = 1;
  my @divs = ();
  my @books = $XPC->findnodes('/osis:osis/osis:osisText/osis:div', $xml);
  if (@books != 1) {&Error("Number of books divs is ".@books, "There should be a single div type='book'"); $success = 0;}
  if (@books[0]->getAttribute('type') ne 'book') {&Error("Book div type is '".@books[0]->getAttribute('type')."'", "The type should be 'book'"), $success = 0;}
  push (@divs, @books[0]);
  
  my @sections = $XPC->findnodes('child::osis:div', @books[0]);
  if (@sections != @CB_SECTION_CHAPS) {&Error("Number of sections is ".@sections, "There should be ".@CB_SECTION_CHAPS." sections: book introduction, Old Testament, New Testament and images."), $success = 0;}
  push (@divs, @sections);
  
  return ($success ? @divs:());
}

sub checkCBsection($$) {
  my $s = shift;
  my $secnum = shift;
  
  my $numchaps = @CB_SECTION_CHAPS[($secnum-1)];
  
  my $success = 1;
  if ($s->getAttribute('type') ne 'majorSection') {&Error("Section type is '".$s->getAttribute('type')."'", "Section type should be 'majorSection'."), $success = 0;}
  
  my @intro = $XPC->findnodes('descendant::text()[normalize-space()][1][not(ancestor::osis:div[@type="chapter"])]', $s);
  if (!@intro[0]) {&Error("<-Section introduction has no text.", "The introduction should at least be a title."), $success = 0;}
  
  my @chaps = $XPC->findnodes('child::osis:div[@type="chapter"]', $s);
  if (@chaps != $numchaps) {&Error("<-Section has ".@chaps." chapters.", "There should be $numchaps chapters."), $success = 0;}
  
  return $success;
}

# Even though CBs have identical structure, images may be named differently.
# This replaces them with the standard image names. Also, the letter.jpg
# is marked as a special image.
sub checkAdjustCBImages($$) {
  my $osisP = shift;
  my $checkOnly = shift;
  
  my $output = $$osisP; $output =~ s/^(.*?\/)([^\/]+)(\.[^\.\/]+)$/$1checkAdjustCBImages$3/;
  my $xml = $XML_PARSER->parse_file($$osisP);
  
  my $success = 1;
  my @divs = &getCBDivs($xml);
  my %hs = ('2' => 'ot', '3' => 'nt');
  foreach my $s (sort keys %hs) {
    my @chs = $XPC->findnodes('child::osis:div[@type="chapter"]', @divs[$s]);
    for (my $ch=0; $ch<@chs; $ch++) {
      my @figs = $XPC->findnodes('descendant::osis:figure', @chs[$ch]);
      if (@figs[0] && @figs > 1) {
        &Error("Children's Bible ".$hs{$s}." chapter ".($ch+1)." (osisID=".@chs[$ch]->getAttribute('osisID').") has multiple figure elements.", "Each chapter should have at most one figure element.");
        $success = 0;
      }
      my $cbk = $hs{$s}.'.'.($ch+1);
      if (!@figs[0]) {
        if($CB_IMAGES{$cbk} ne 'text') {
          &Error("Children's Bible ".$hs{$s}." chapter ".($ch+1)." (osisID=".@chs[$ch]->getAttribute('osisID').") is missing its figure element.", "This chapter is supposed to have a figure element, but it does not.");
          $success = 0;
        }
      }
      else {
        my $fnum = @figs[0]->getAttribute('src');
        my $ip = ($fnum =~ s/^(.*?)\/([^\/\.]+)\.jpg$/$2/ ? "$1":'');
        my $correctnum = $CB_IMAGES{$cbk};
        if ("$fnum" ne "$correctnum") {
          if (-e "$MAININPD/".@figs[0]->getAttribute('src')) {}
          elsif ($correctnum eq 'text') {
            &Warn("Children's Bible ".$hs{$s}." chapter ".($ch+1)." (osisID=".@chs[$ch]->getAttribute('osisID').") has figure element ".@figs[0]." where text should be.", "This chapter should not have an image unless the image is of text.");
          }
          elsif ($checkOnly) {
            &Error("Children's Bible image is $fnum but it should be $correctnum.", "This image is not correct according to the structure.");
            $success = 0;
          }
          else {
            &Warn("Updating Children's Bible image from $fnum to $correctnum.", "If this Children's Bible has the correct structure, this change should correct the image name.");
            @figs[0]->setAttribute('src', "$ip/$correctnum.jpg");
          }
        }
      }
    }
  }
  
  my $letter = @{$XPC->findnodes('//osis:figure[@src="./images/letter.jpg"][1]', $xml)}[0];
  if ($letter) {
    $letter->setAttribute('subType', 'x-letter-image');
    &Note("Added subType='x-letter-image' to letter.jpg");
  }
  
  if (!$checkOnly) {&writeXMLFile($xml, $output, $osisP);}
  
  return $success;
}

# return childrens Bible context reference for $node, which is simply the
# chapter name.
sub chBibleContext($) {
  my $node = shift;
  
  my $context = '';
  
  # get book
  my $chapter = @{$XPC->findnodes('ancestor::osis:div[@osisID][1]', $node)}[0];
  if (!$chapter) {
    &Error("Children's Bible text node is not within a GenBook chapter: $node", "All GenBook material must be located within a div whose osisID is the GenBook key.");
    return '';
  }
  if (!$chapter->getAttribute('osisID')) {
    &Error("Children's Bible text node chapter has no osisID: $node", "All GenBook material must be located within a div whose osisID is the GenBook key.");
    return '';
  }
  return $chapter->getAttribute('osisID');
}

# Children's Bible figure src have special local paths, so handle them here.
# Return '' on failure or the local path to the image on success.
sub getFigureLocalPath($$) {
  my $f = shift;
  my $projdir = shift;
  $projdir = ($projdir ? $projdir:$INPD);
  
  my $src = $f->getAttribute('src');
  if (!$src) {
    &Error("Figure \"$f\" has no src target", "The source location must be specified by the SFM \\fig tag.");
    return '';
  }
  
  # If an image exists in the project's image directory, don't use a CB_Common image
  if (-e "$projdir/$src") {return "$projdir/$src";}
  
  if (&isChildrensBible($f) && $f->getAttribute('subType') eq 'x-text-image') {
    my $ret  = ($src =~ /^\.\/images\/(\d+)\.jpg$/ ? "$MAININPD/../CB_Common/images/copyright/".sprintf("%03d", $1).".jpg":'');
    return $ret;
  }
  elsif (&isChildrensBible($f) && $f->getAttribute('subType') eq 'x-letter-image') {
    my $ret  = ($src eq './images/letter.jpg' ? "$MAININPD/../CB_Common/images/ibt/letter.jpg":'');
    return $ret;
  }
  
  return "$projdir/$src";
}
