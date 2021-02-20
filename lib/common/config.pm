# This file is part of "osis-converters".
# 
# Copyright 2021 John Austin (gpl.programs.info@gmail.com)
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

our ($CONF, $DICTINPD, $DICTMOD, $INPD, $MAINMOD, $MOD, 
     $UPPERCASE_DICTIONARY_KEYS, $WRITELAYER, $XML_PARSER, $XPC, 
     @CONFIG_SECTIONS, @MULTIVALUE_CONFIGS, @SUB_PUBLICATIONS, 
     @SWORD_CONFIGS, @SWORD_OC_CONFIGS);

# Sets a config.conf entry to a particular value (when $flag = 1) or  
# adds another entry having the value if there isn't already one ($flag 
# = 2) or just checks that an entry is present with the value (!$flag). 
# Returns 1 if the config contains the value upon function exit, or 0 if 
# it does not.
sub setConfValue {
  my $confP = shift;
  my $fullEntry = shift;
  my $value = shift;
  my $flag = shift;
  
  my $multRE = &configRE(@MULTIVALUE_CONFIGS);
  
  my $e = $fullEntry;
  my $s = ($e =~ s/^([^\+]+)\+// ? $1:'');
  if (!$s) {
    &ErrorBug("setConfValue requires a qualified config entry name.", 1);
  }
 
  my $sep = ($e =~ /$multRE/ ? '<nx/>':'');
  
  if ($value eq $confP->{$fullEntry}) {return 1;}
  if ($flag != 1 && $sep && 
      $confP->{$fullEntry} =~ /(^|\s*\Q$sep\E\s*)\Q$value\E(\s*\Q$sep\E\s*|$)/) {
    return 1;
  }
  if ($flag == 2 && !$sep) {
    &ErrorBug("Config entry '$e' cannot have multiple values, but setConfValue flag='$flag'", 1);
  }
  
  if (!$flag) {return 0;}
  elsif ($flag == 1) {
    $confP->{$fullEntry} = $value;
  }
  elsif ($flag == 2) {
    if ($confP->{$fullEntry}) {$confP->{$fullEntry} .= $sep.$value;}
    else {$confP->{$fullEntry} = $value;}
  }
  else {&ErrorBug("Unexpected setConfValue flag='$flag'", 1);}
  return 1;
}

# Sets a config entry for a CrossWire SWORD module. If the entry is not
# a valid SWORD config entry, an error is thrown.
sub setSwordConfValue {
  my $confP = shift;
  my $entry = shift;
  my $value = shift;
  
  if ($entry =~ /\+/) {
    &ErrorBug("setSwordConfValue requires an unqualified config entry name.");
  }
  
  my $swordAutoRE = &configRE(@SWORD_CONFIGS, @SWORD_OC_CONFIGS);
  if ($entry !~ /$swordAutoRE/) {
    &ErrorBug("'$entry' is not a valid SWORD entry.", 1);
  }
  
  my $multRE = &configRE(@MULTIVALUE_CONFIGS);
  if ($entry =~ /$multRE/) {
    &setConfValue($confP, "$MOD+$entry", $value, 2);
  }
  else {
    &setConfValue($confP, "$MOD+$entry", $value, 1);
  }
}

# Return a list of all config entries which have values in the current 
# context.
sub contextConfigEntries {
  
  my @entries;
  foreach my $fe (keys %{$CONF}) {
    if ($fe =~ /^(MainmodName|DictmodName)$/) {next;}
    my $e = $fe;
    my $s = ($e =~ s/^([^\+]+)\+// ? $1:'');
    if ($s eq 'system') {next;}
    if (!defined(&conf($e, undef, undef, undef, 1))) {next;}
    push(@entries, $e);
  }
  
  return @entries;
}

# Fill a config conf data pointer with SWORD entries taken from:
# 1) Project config.conf
# 2) Current OSIS source file
# 3) auto-generated 
sub getSwordConf {
  my $moduleSource = shift;
  
  my %swordConf = ( 'MainmodName' => $MOD );
  
  # Copy appropriate values from project config.conf
  my $swordConfigRE = &configRE(@SWORD_CONFIGS, @SWORD_OC_CONFIGS);
  foreach my $e (&contextConfigEntries()) {
    if ($e !~ /$swordConfigRE/) {next;}
    &setSwordConfValue(\%swordConf, $e, &conf($e));
  }
  
  my $moddrv = $swordConf{"$MOD+ModDrv"};
  if (!$moddrv) {
		&Error("No ModDrv specified in $moduleSource.", 
    "Update the OSIS file by re-running sfm2osis.", '', 1);
	}
  
	my $dp;
  my $mod = $swordConf{"MainmodName"};
	if    ($moddrv eq "RawText")    {$dp = "./modules/texts/rawtext/".lc($mod)."/";}
  elsif ($moddrv eq "RawText4")   {$dp = "./modules/texts/rawtext4/".lc($mod)."/";}
	elsif ($moddrv eq "zText")      {$dp = "./modules/texts/ztext/".lc($mod)."/";}
	elsif ($moddrv eq "zText4")     {$dp = "./modules/texts/ztext4/".lc($mod)."/";}
	elsif ($moddrv eq "RawCom")     {$dp = "./modules/comments/rawcom/".lc($mod)."/";}
	elsif ($moddrv eq "RawCom4")    {$dp = "./modules/comments/rawcom4/".lc($mod)."/";}
	elsif ($moddrv eq "zCom")       {$dp = "./modules/comments/zcom/".lc($mod)."/";}
	elsif ($moddrv eq "HREFCom")    {$dp = "./modules/comments/hrefcom/".lc($mod)."/";}
	elsif ($moddrv eq "RawFiles")   {$dp = "./modules/comments/rawfiles/".lc($mod)."/";}
	elsif ($moddrv eq "RawLD")      {$dp = "./modules/lexdict/rawld/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "RawLD4")     {$dp = "./modules/lexdict/rawld4/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "zLD")        {$dp = "./modules/lexdict/zld/".lc($mod)."/".lc($mod);}
	elsif ($moddrv eq "RawGenBook") {$dp = "./modules/genbook/rawgenbook/".lc($mod)."/".lc($mod);}
	else {
		&Error("ModDrv \"$moddrv\" is unrecognized.", "Change it to a recognized SWORD module type.");
	}
  # At this time (Jan 2017) JSword does not yet support zText4
  if ($moddrv =~ /^(raw)(text|com)$/i || $moddrv =~ /^rawld$/i) {
    &Error("ModDrv \"".$moddrv."\" should be changed to \"".$moddrv."4\" in config.conf.");
  }
  &setSwordConfValue(\%swordConf, 'DataPath', $dp);

  my $type = 'genbook';
  if ($moddrv =~ /LD/) {$type = 'dictionary';}
  elsif ($moddrv =~ /Text/) {$type = 'bible';}
  elsif ($moddrv =~ /Com/) {$type = 'commentary';}
  
  &setSwordConfValue(\%swordConf, 'Encoding', 'UTF-8');

  if ($moddrv =~ /Text/) {
    &setSwordConfValue(\%swordConf, 'Category', 'Biblical Texts');
    if ($moddrv =~ /zText/) {
      &setSwordConfValue(\%swordConf, 'CompressType', 'ZIP');
      &setSwordConfValue(\%swordConf, 'BlockType', 'BOOK');
    }
  }
  
  my $moduleSourceXML = $XML_PARSER->parse_file($moduleSource);
  my $sourceType = 'OSIS'; # NOTE: osis2tei.xsl still produces a TEI file having OSIS markup!
  
  if (($type eq 'bible' || $type eq 'commentary')) {
    &setSwordConfValue(\%swordConf, 'Scope', &getScope($moduleSourceXML));
  }
  
  if ($moddrv =~ /LD/ && !$swordConf{"$MOD+KeySort"}) {
    &setSwordConfValue(\%swordConf, 'KeySort', &getApproximateLangSortOrder($moduleSourceXML));
  }
  if ($moddrv =~ /LD/ && !$swordConf{"$MOD+LangSortOrder"}) {
    &setSwordConfValue(\%swordConf, 'LangSortOrder', &getApproximateLangSortOrder($moduleSourceXML));
  }
  
  &setSwordConfValue(\%swordConf, 'SourceType', $sourceType);
  if ($swordConf{"$MOD+SourceType"} !~ /^(OSIS|TEI)$/) {
    &Error("Unsupported SourceType: ".$swordConf{"$MOD+SourceType"}, 
    "Only OSIS and TEI are supported by osis-converters", 1);
  }
  if ($swordConf{"$MOD+SourceType"} eq 'TEI') {
    &Warn("Some front-ends may not fully support TEI yet");
  }
  
  if ($swordConf{"$MOD+SourceType"} eq 'OSIS') {
    my $vers = @{$XPC->findnodes('//osis:osis/@xsi:schemaLocation', $moduleSourceXML)}[0];
    if ($vers) {
      $vers = $vers->value; $vers =~ s/^.*osisCore\.([\d\.]+).*?\.xsd$/$1/i;
      &setSwordConfValue(\%swordConf, 'OSISVersion', $vers);
    }
    if ($XPC->findnodes("//osis:reference[\@type='x-glossary']", $moduleSourceXML)) {
      &setSwordConfValue(\%swordConf, 'GlobalOptionFilter', 
      'OSISReferenceLinks|Reference Material Links|Hide or show links to study helps in the Biblical text.|x-glossary||On');
    }

    &setSwordConfValue(\%swordConf, 'GlobalOptionFilter', 'OSISFootnotes');
    &setSwordConfValue(\%swordConf, 'GlobalOptionFilter', 'OSISHeadings');
    &setSwordConfValue(\%swordConf, 'GlobalOptionFilter', 'OSISScripref');
  }
  
  if ($moddrv =~ /LD/) {
    &setSwordConfValue(\%swordConf, 'SearchOption', 'IncludeKeyInSearch');
    # The following is needed to prevent ICU from becoming a SWORD engine dependency (as internal UTF8 keys would otherwise be UpperCased with ICU)
    if ($UPPERCASE_DICTIONARY_KEYS) {
      &setSwordConfValue(\%swordConf, 'CaseSensitiveKeys', 'true');
    }
  }

  my @tm = localtime(time);
  &setSwordConfValue(\%swordConf, 'SwordVersionDate', sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]));
  
  return \%swordConf;
}

sub checkConfGlobals {

  if ($MAINMOD =~ /^...CB$/ && &conf('FullResourceURL')) {
    &Error("For Children's Bibles, FullResourceURL must be removed from config.conf or set to false.", "Children's Bibles do not currently support this feature so it must be turned off.");
  }
  foreach my $entry (sort keys %{$CONF}) {
    my $isConf = &isValidConfig($entry);
    if (!$isConf) {
      &Error("Unrecognized config entry: $entry", "Either this entry is not needed, or else it is named incorrectly.");
    }
    elsif ($isConf eq 'sword-autogen') {
      &Error("Config request '$entry' is valid but it should not be set in config.conf because it is auto-generated by osis-converters.", "Remove this entry from the config.conf file.");
    }
  }
  
  # Check companion value(s)
  if ($DICTMOD && &conf('Companion', $MAINMOD) ne &conf('Companion', $DICTMOD).'DICT') {
    &Error("config.conf companion entries are inconsistent: ".&conf('Companion', $MAINMOD).", ".&conf('Companion', $DICTMOD), 
    "Correct values should be:\n[$MOD]\nCompanion=$DICTMOD\n[$DICTMOD]\nCompanion=$MOD\n");
  }

  if ($INPD ne $DICTINPD) {
    # Check for UI that needs localization
    foreach my $s (@SUB_PUBLICATIONS) {
      my $sp = $s; $sp =~ s/\s/_/g;
      if (&conf("TitleSubPublication[$sp]") && &conf("TitleSubPublication[$sp]") !~ / DEF$/) {next;}
      &Warn("Sub publication title config entry 'TitleSubPublication[$sp]' is not localized: ".&conf("TitleSubPublication[$sp]"), 
      "You should localize the title in config.conf with: TitleSubPublication[$sp]=Localized Title");
    }
  }
  
  if ($DICTMOD && !&conf('KeySort', $DICTMOD)) {
    &Error("KeySort is missing from config.conf", '
This required config entry facilitates correct sorting of glossary 
keys. EXAMPLE:
KeySort = AaBbDdEeFfGgHhIijKkLlMmNnOoPpQqRrSsTtUuVvXxYyZz[G`][g`][Sh][sh][Ch][ch][ng]`{\\[\\\\[\\\\]\\\\{\\\\}\\(\\)\\]}
This entry allows sorting in any desired order by character collation. 
Square brackets are used to separate any arbitrary JDK 1.4 case  
sensitive regular expressions which are to be treated as single 
characters during the sort comparison. Also, a single set of curly 
brackets can be used around a regular expression which matches all 
characters/patterns to be ignored during the sort comparison. IMPORTANT: 
EVERY square or curly bracket within any regular expression must have an 
ADDITIONAL \ added before it. This is required so the KeySort value can 
be parsed correctly. This means the string to ignore all brackets and 
parenthesis would be: {\\[\\\\[\\\\]\\\\{\\\\}\\(\\)\\]}');
  }
  if ($DICTMOD && !&conf('LangSortOrder', $DICTMOD)) {
    &Error("LangSortOrder is missing from config.conf", "
Although this config entry has been replaced by KeySort and is 
deprecated and no longer used by osis-converters, for now it is still 
required to prevent the breaking of older programs. Its value is just 
that of KeySort, but bracketed groups of regular expressions are not 
allowed and must be removed.");
  }
  
}

sub checkRequiredConfEntries {

  if (&conf('Abbreviation') eq $MOD) {
    &Warn("Currently the config.conf 'Abbreviation' setting is '$MOD'.",
"This is a short user-readable name for the module.");
  }
  
  if (&conf('About') eq 'ABOUT') {
    &Error("You must provide the config.conf 'About' setting with information about module $MOD.",
"This can be a lengthier description and may include copyright, 
source, etc. information, possibly duplicating information in other 
elements.");
  }
  
  if (&conf('Description') eq 'DESCRIPTION') {
    &Error("You must provide the config.conf 'Description' setting with a short description about module $MOD.",
"This is a short (1 line) title for the module.");
  }
  
  if (&conf('Lang') eq 'LANG') {
    &Error("You must provide the config.conf 'Lang' setting as the ISO-639 code for this language.",
"Use the shortest available ISO-639 code. If there may be multiple 
scripts then follow the languge code with '-' and an ISO-15924 4 letter 
script code, such as: 'Cyrl', 'Latn' or 'Arab'.");
  }
}

sub getApproximateLangSortOrder {
  my $tei = shift;
  
  my $res = '';
  my @entries = $XPC->findnodes('//tei:entryFree/@n', $tei);
  my $last = '';
  foreach my $e (@entries) {
    my $l = substr($e->value, 0, 1);
    if (&uc2($l) eq $last) {next;}
    $res .= &uc2($l).&lc2($l);
    $last = &uc2($l);
  }

  return $res;
}


1;
