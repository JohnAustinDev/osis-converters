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
     @SWORD_CONFIGS, @SWORD_OC_CONFIGS, %SWORD_CONFIG_VALUES,
     @PROJECT_TYPES);

# Return a list of all config entries which have values defined in the 
# current context.
sub contextConfigEntries {
  
  my @entries;
  foreach my $fe (keys %{$CONF}) {
    if ($fe eq 'MAINMOD') {next;}
    my $e = $fe;
    my $s = ($e =~ s/^([^\+]+)\+// ? $1:'');
    if ($s eq 'system') {next;}
    if (!defined(&conf($e, undef, undef, undef, 1))) {next;}
    push(@entries, $e);
  }
  
  return @entries;
}

# Fill a config conf data pointer with SWORD entries taken from the
# project config.conf and %SWORD_CONFIG_VALUES.
sub getSwordConf {
  my $moduleSource = shift;
  
  my $xml = $XML_PARSER->parse_file($moduleSource);
  
  my %swordConf = ( 'MAINMOD' => $MOD );
  
  # Copy any SWORD entries set in project config.conf
  my $swordRE = &configRE(@SWORD_CONFIGS, @SWORD_OC_CONFIGS);
  foreach my $e (&contextConfigEntries()) {
    if ($e !~ /$swordRE/) {next;}
    $swordConf{"$MOD+$e"} = &conf($e);
  }
  
  # Set values in %SWORD_CONFIG_VALUES
  my $osisversion = @{$XPC->findnodes('//osis:osis/@xsi:schemaLocation', $xml)}[0];
  $osisversion = $osisversion->value;
  $osisversion =~ s/^.*osisCore\.([\d\.]+).*?\.xsd$/$1/i;
  
  my @tm = localtime(time);
  my $today = sprintf("%d-%02d-%02d", (1900+$tm[5]), ($tm[4]+1), $tm[3]);
  
  my $mod = lc($MOD);
  
  my $scope = (&conf('ProjectType') =~ /^(bible|commentary)$/ &&
               $MOD eq $MAINMOD ? &getScopeXML($xml) : '');
               
  my $chblCompanion = ($MOD =~ /^(\w{3,4})CB$/ ? $1 : '');
  
  my $keysort = &conf('KeySort'); $keysort =~ s/(\[[^\]]*\]|\{[^\}]*\})//g;
  
  my $cssfile = &getDefaultFile( ($MOD eq $DICTMOD ? 'DICTMOD' : '') .
    "/sword/css/module.css", -1);
  my $modulecss = ($cssfile ? 'module.css' : '');

  foreach my $t ( 'all', 
      ($MOD eq $MAINMOD ? &conf('ProjectType') : 'dictionary') ) {
    foreach my $e (keys %{$SWORD_CONFIG_VALUES{$t}}) {
      my $val = $SWORD_CONFIG_VALUES{$t}{$e};
      eval('$val = "' . $val . '";');
      if (!$val) {next;}
      $swordConf{"$MOD+$e"} = $val;
    }
  }

  return \%swordConf;
}

sub checkConfGlobals {

  my $ok = grep(&conf('ProjectType') eq $_, @PROJECT_TYPES);
  if (!$ok) {
    &Error(
"Unknown project type: " . &conf('ProjectType'), 
&help('ProjectType', 1)
    ,1);
  }
  
  if ($DICTMOD) {
    foreach my $fe (sort keys %{$CONF}) {
      if ($fe !~ /^(.*?)\+ProjectType$/ || $1 eq $MAINMOD) {next;}
      &Error(
"ProjectType may only appear in the [$MAINMOD] section.", 
"Move/remove it from the [$1] section", 1);
    }
  }

  if (&conf('ProjectType') eq 'childrens_bible' && &conf('FullResourceURL')) {
    &Error(
"For Children's Bibles, FullResourceURL must be removed from config.conf or set to false.", 
"Children's Bibles do not currently support this feature so it must be turned off."
    );
  }
  
  foreach my $entry (sort keys %{$CONF}) {
    my $isConf = &isValidConfig($entry);
    if (!$isConf) {
      &Error(
"Unrecognized config entry: $entry", 
"Either this entry is not needed, or else it is named incorrectly."
      );
    }
    elsif ($isConf eq 'sword-autogen') {
      &Error(
"Config request '$entry' is valid but it should not be set in config.conf because it is auto-generated.", 
"Remove this entry from the config.conf file."
      );
    }
  }

  if ($INPD ne $DICTINPD) {
    # Check for UI that needs localization
    foreach my $s (@SUB_PUBLICATIONS) {
      my $sp = $s; $sp =~ s/\s/_/g;
      if (&conf("SubPublicationTitle[$sp]") && &conf("SubPublicationTitle[$sp]") !~ / DEF$/) {next;}
      &Warn(
"Sub publication title config entry 'SubPublicationTitle[$sp]' is not localized: ".&conf("SubPublicationTitle[$sp]"), 
"You should localize the title in config.conf with: SubPublicationTitle[$sp]=Localized Title"
      );
    }
  }
  
  if ($DICTMOD && !&conf('KeySort', $DICTMOD)) {
    &Error("KeySort is missing from config.conf", '
This required config entry facilitates correct sorting of glossary 
keys. EXAMPLE:
KeySort = AaBbDdEeFfGgHhIijKkLlMmNnOoPpQqRrSsTtUuVvXxYyZz[G`][g`][Sh][sh][Ch][ch][ng]`{\\[\\\\[\\\\]\\\\{\\\\}\\(\\)\\]}
' . &help('KeySort', 1));
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

1;
