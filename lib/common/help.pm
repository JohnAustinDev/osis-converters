#!/usr/bin/perl
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

# This script might be run on Linux, MS-Windows, or MacOS operating systems.

our ($SCRIPT_NAME, @CONV_OSIS, @CONV_PUBS);

# Argument globals
our ($HELP, $INPD, $LOGFILE, $NO_ADDITIONAL, $CONVERSION, $MODRE, $MAXTHREADS, $SKIPRE);

# Each script takes 3 types of arguments: 'switch', 'option' and 'argument'.
# Each argument is specified by: [ <global-name>, <default-value>, <short-description>, <documentation> ]
our %ARG = (

  'all' => { # Arguments available to all scripts:
  
    'switch' => {
    
      'h' => [ 'HELP', 0, 'boolean', 'Show usage message and exit.' ],
    },
    
    'argument' => {
    
      'first' => [ 'INPD', '.', 'dir', 'Path to an osis-converters project directory. Default is the working directory.' ],
    
      'second' => [ 'LOGFILE', undef, 'log', 'Log file path. Default is LOG_'.$SCRIPT_NAME.'.txt in the project\'s output directory.' ],
    },
  },

  'convert' => { # Arguments available to the 'convert' script:
  
    'switch' => {
    
      'n' => [ 'NO_ADDITIONAL', 0, 'boolean', 'No additional modules will be run to meet any dependencies.' ], 
    },
    
    'argument' => {
    
      # this overrides the second argument of 'all' above
      'second' => [ 'LOGFILE', './LOG_convert.txt', 'log', 'Log file path. Default is ./OUT_convert.txt in the working directory.' ],
    },
    
    'option' => {
      
      'c' => [ 'CONVERSION', 'sfm2all', 'conv', 'Conversion(s) to run. Default is "sfm2all". Others are: ' . join(', ', sort keys %{&listConversions(\@CONV_OSIS, \@CONV_PUBS)}) . '.' ],
      
      'm' => [ 'MODRE', '.+', 'rx', 'Regex matching modules to run. Default is all.' ],

      't' => [ 'MAXTHREADS', &numCPUs(), 'N', 'Number of threads to use. Default is '.&numCPUs() . '.' ],

      'x' => [ 'SKIPRE', undef, 'rx', 'Regex matching modules to skip. Default is none.' ],
    },
  },
);

# osis-converters help documentation is stored in the following data structure:
# <script> => [ [ <heading>, [ [ sub-heading|para|list, value ], ... ] ], ... ]
# where: list = [ 'list', [key-heading, description-heading], [ [ <name>, <description> ], ... ] ]

# Scope help??
our %HELP = (

'sfm2osis' => [

  ['CONVERT PARATEXT FILES INTO OSIS XML', [
    ['para', 'OSIS is an xml standard for encoding Bibles and related texts (see: http://crosswire.org/osis/). The OSIS files generated by sfm2osis will include meta-data, explicit references, and textual information not present in the original Paratext Universal Standard Format Marker (USFM) sources. The resulting OSIS file is a more complete source text than the original Paratext files and is an excellent intermediate format, easily and reliably converted into any other format.' ],
    ['para',  'The conversion process is directed by control files. A description of each control file and its options follows. Default control files are created by the \'defaults\' command.' ],
  ]],
  
  ['config.conf', [
    ['para', ' Each project has a config.conf file located in its top directory. The configuration file contains conversion settings and meta-data for the project. A project consist of a single main module, and possibly a single dictionary module containing reference material. A config.conf file usually has multiple sections. The main section contains configuration settings applying to the entire project, while settings in other sections are effective in their particular context, overriding any matching settings of the main section. The \'system\' section is special because it contains global constants that are the same in any context. The following sections are recognized: '.join(', ', map("'$_'", @CONFIG_SECTIONS)). ' (MAINMOD is the project code and DICTMOD is the same project code suffixed with \'DICT\'). What follows are all settings available in the config.conf file. The letters in parenthesis indicate the following special features:'],
    ['list', ['' ,''], 
    [
      ['(C)', 'These entry values are continuable from one line to the next using a backslash character.'],
      ['(L)', 'These entry values are localizable by appending an underscore and language ISO code to the entry name.'],
      ['(S)', 'These entries may only appear in the system section.'],
      ['(W)', 'These entries are also SWORD standard entries (see https://wiki.crosswire.org/DevTools:conf_Files).'],
    ]],
    ['list', ['ENTRY', 'DESCRIPTION'], 
      &addEntryType(&getList([&{sub {$re=&configRE(@SWORD_AUTOGEN_CONFIGS); return grep {$_ !~ /$re/} @_;}}(@SWORD_CONFIGS, @SWORD_OC_CONFIGS, @OC_CONFIGS)], 
    [
      [ 'Abbreviation', 'A short localized name for the module.' ],
      [ 'About', 'Localized information about the module.' ],
      [ 'Description', 'A short localized description of the module.' ],
      [ 'KeySort', 'This entry allows sorting a language in any desired way using character collation. Square brackets are used to separate any arbitrary JDK 1.4 case sensitive regular expressions which are to be treated as single characters during the sort comparison. Also, a single set of curly brackets can be used around a regular expression which matches any characters/patterns that need to be ignored during the sort comparison. IMPORTANT: Any square or curly bracket within these regular expressions must have an ADDITIONAL \ before it.' ],
      [ 'LangSortOrder', 'DEPRECATED. Use the more flexible KeySort instead.' ],
      [ 'AudioCode', 'A publication code for associated audio. Multiple modules having different scripts may reference the same audio.' ],
      [ 'AddScripRefLinks', 'Select whether to parse scripture references in the text and convert them to hyperlinks: (true | false | AUTO).' ],
      [ 'AddDictLinks' => 'Select whether to parse glossary references in the text and convert them to hyperlinks: (true | false | check | AUTO).' ],
      [ 'AddFootnoteLinks' => 'Select whether to parse footnote references in the text and convert them to hyperlinks: (true | false | AUTO).' ],
      [ 'AddCrossRefLinks' => 'Select whether to insert externally generated cross-reference notes into the text: (true | false |AUTO).' ],
      [ 'Versification' => 'The versification system of the project. All deviations from this verse system must be recorded in CF_sfm2osis.txt by VSYS instructions. Supported options are: '.join(', ', split(/\|/, $SWORD_VERSE_SYSTEMS)).'.' ],
      [ 'Encoding' => 'osis-converters only supports UTF-8 encoding.' ],
      [ 'TOC' => 'A number from 1 to 3 indicating the SFM tag to use for generating the Table Of Contents: \toc1, \toc2 or \toc3.' ],
      [ 'TitleCase' => 'A number from 0 to 2 selecting letter casing for the Table Of Contents: 0 is as-is, 1 is Like This, 2 is LIKE THIS.' ],
      [ 'TitleTOC' => 'A number from 1 to 3 indicating this SFM tag to use for generating the publication titles: \toc1, \toc2 or \toc3.' ],
      [ 'CreatePubTran' => 'Select whether to create a single ePublication containing everything in the OSIS file: (true | false | AUTO).'],
      [ 'CreatePubSubpub' => 'Select whether to create separate outputs for individual sub-publications within the OSIS file: (true | false | AUTO | <scope> | first | last).' ],
      [ 'CreatePubBook' => 'Select whether to create separate ePublications for individual Bible books within the OSIS file: (true | false | AUTO | <OSIS-book> | first | last).' ],
      [ 'CreateTypes' => 'Select which type, or types, of eBooks to create: (AUTO | epub | azw3 | fb2).' ],
      [ 'CombineGlossaries' => 'Set this to \'true\' to combine all glossaries into one, or false to keep them each as a separate glossary. \'AUTO\' let\'s osis-converters decide.' ],
      [ 'FullResourceURL' => 'Single Bible book eBooks often have links to other books. This URL is where the full publication may be found.' ],
      [ 'CustomBookOrder' => 'Set to true to allow Bible book order to remain as it appears in CF_sfm2osis.txt, rather than project versification order: (true | false).' ],
      [ 'ReorderGlossaryEntries' => 'Set to true and all glossaries will have their entries re-ordered according to KeySort, or else set to a regex to re-order only glossaries whose titles match: (true | <regex>).' ],
      [ 'CombinedGlossaryTitle' => 'A localized title for the combined glossary in the Table of Contents.' ],
      [ 'BookGroupTitle\w+' => 'A localized title to use for these book groups: '.&{sub {my $x=join(', ', @OSIS_GROUPS); $x=~s/_/ /g; return $x;}}().'.' ],
      [ 'BookGroupTitleOT' => 'A localized title for the New Testament in the Table of Contents.' ],
      [ 'BookGroupTitleNT' => 'A localized title for the Old Testament in the Table of Contents.' ],
      [ 'TranslationTitle' => 'A localized title for the entire translation.' ],
      [ 'IntroductionTitle' => 'A localized title for Bible book introductions.' ],
      [ 'TitleSubPublication\[\S+\]', 'A localized title for each sub-publication. A sub-publication is created when SFM files are placed within an sfm sub-directory. The name of the sub-directory must be the scope of the sub-publication, having spaces replaced by underscores.' ], 
      [ 'NormalizeUnicode' => 'Apply a Unicode normalization to all characters: (true | false | NFD | NFC | NFKD | NFKC | FCD).' ],
      [ 'Lang' => 'ISO language code and script code. Examples: tkm-Cyrl or tkm-Latn' ],
      [ 'ARG_\w+' => 'Config settings for undocumented fine control.' ],
      [ 'GlossaryNavmenuLink\[[1-9]\]' => 'Specify custom DICTMOD module navigation links.' ], 
      [ 'History_[\d\.]+' => 'Each version of released publications should have one of these entries describing what is new that version.' ],              
      [ 'Version', 'The version of the publication being produced.' ],
    ]))],
  ]],
  
  ['CF_sfm2osis.txt', [
    ['para', 'This control file is required for all sfm2osis conversions. It should be located in each module\'s directory (both MAINMOD and DICTMOD if there is one). It controls what material appears in each module\'s OSIS file and in what order, and is used to apply Perl regular expressions for making changes to SFM files before conversion. ' ],
    ['para', 'Its other purpose is to describe deviations from the standard versification system that Bible translators made during translation. Translators nearly always deviate from the standard versification system in some way. It is imperative these deviations be recorded so references from external documents may be properly resolved, and parallel rendering together with other texts can be accomplished. Each verse must be identified according to the project\'s strictly defined standard versification scheme. The commands to accomplish this all begin with VSYS. Their proper use results in OSIS files which contain both a rendering of the translator\'s custom versification scheme and a rendering of the standard versification scheme. OSIS files can then be rendered in either scheme using an XSLT stylesheet. ' ],
    ['para', 'NOTES: Each VSYS instruction is evaluated in verse system order regardless of order in the control file. A verse may be effected by multiple VSYS instructions. VSYS operations on entire chapters are not supported except VSYS_EXTRA for chapters at the end of a book (such as Psalm 151 of Synodal).'],
    ['list', ['COMMAND', 'DESCRIPTION'], &getList([@CF_SFM2OSIS, @VSYS_INSTRUCTIONS], [
      ['EVAL_REGEX', 'Any perl regular expression to be applied to source SFM files before conversion. An EVAL_REGEX instruction is only effective for the RUN statements which come after it. The EVAL_REGEX command may be suffixed with a label or path in parenthesis and must be followed by a colon. A label might make organizing various kinds of changes easier, while a file path makes the EVAL_REGEX effective on only a single file. If an EVAL_REGEX has no regular expression, all previous EVAL_REGEX commands sharing the same label are canceled. 
      \bExamples: 
      \bEVAL_REGEX: s/^search/replace/gm 
      \bEVAL_REGEX(myfix): s/^search/replace/gm 
      \bEVAL_REGEX(./sfm/file/path.sfm): s/^search/replace/gm' ],
      ['RUN', 'Causes an SFM file to be converted and appended to the module\'s OSIS file. Each RUN must be followed by a colon and the file path of an SFM file to convert. RUN can be used more than once on the same file. IMPORTANT: Bible books are normally re-ordered according to the project\'s versification system. To maintain RUN Bible book order, \'CustomBookOrder\' must be set to true in config.conf.' ],
      ['SPECIAL_CAPITALS', 'DEPRECATED. Was used to enforce non-standard capitalizations. It should only be used if absolutely necessary, since Perl Unicode is now good at doing the right thing on its own. It is better to use EVAL_REGEX to replace offending characters with the proper Unicode character. For example: \'SPECIAL_CAPITALS:i->İ ı->I\'.' ],
      ['PUNC_AS_LETTER', 'DEPRECATED. Was used to treat a punctuation character as a letter for pattern matches. For example: \'PUNC_AS_LETTER:`\'. It is far better to use EVAL_REGEX to replace a punctuation character with the proper Unicode character, which will automatically be treated properly.' ],
      ['VSYS_MISSING', 'Specifies that this translation does not include a range of verses of the standard versification scheme. This instruction takes the form:
      \b\bVSYS_MISSING: Josh.24.34.36
      \bMeaning that Joshua 24:34-36 of the standard versification scheme has not been included in the custom scheme. When the OSIS file is rendered as the standard versification scheme, the preceeding verse\'s osisID will be modified to include the missing range. But any externally supplied cross-references that refer to the missing verses will be removed. If there are verses already sharing the verse numbers of the missing verses, then the standard versification rendering will renumber them and all following verses upward by the number of missing verses, and alternate verse numbers will be appended displaying the original verse numbers. References to affected verses will be tagged so as to render correctly in either the standard or custom versification scheme. An entire missing chapter is not supported unless it is the last chapter in the book.' ],
      ['VSYS_EXTRA', 'Used when translators inserted a range of verses that are not part of the project\'s versification scheme. This instruction takes the form:
      \b\b VSYS_EXTRA: Prov.18.8 <- Synodal:Prov.18.8
      \b The left side is a verse range specifying the extra verses in the custom verse scheme, and the right side range is an optional universal address for those extra verses. The universal address is used to record where the extra verses originated from. When the OSIS file is rendered in the standard versification scheme, the additional verses will become alternate verses appended to the preceding verse, and if there are verses following the extra verses, they will be renumbered downward by the number of extra verses, and alternate verse numbers will be appended displaying the custom verse numbers. References to affected verses will be tagged so as to render correctly in either the standard or custom versification scheme. The extra verse range may be an entire chapter if it occurs at the end of a book (such as Psalm 151). When rendered in the standard versification scheme, an alternate chapter number will then be inserted and the entire extra chapter will be appended to the last verse of the previous chapter.' ],
      ['VSYS_FROM_TO', 'This is usually not the right instruction to use; it is used internally as part of other instructions. It does not effect any verse or alternate verse markup. It could be used if a verse is marked in the text but is left empty, while there is a footnote about it in the previous verse (but see VSYS_MISSING_FN which is the more common case). '], 
      ['VSYS_EMPTY', 'Like VSYS_MISSING, but is only to be used if regular empty verse markers are included in the text. This instruction will only remove external scripture cross-references to the removed verses.' ],
      ['VSYS_MOVED', 'Used when translators moved a range of verses from the expected location within the project\'s versification scheme to another location. This instruction can have several forms:
      \b\b VSYS_MOVED: Rom.14.24.26 -> Rom.16.25.27 
      \b Indicates the range of verses given on the left was moved from its expected location to a custom location given on the right. Rom.16.25.27 is Romans 16:25-27. Both ranges must cover the same number of verses. Either or both ranges may end with the keyword \'PART\' in place of the range\'s last verse, indicating only part of the verse was moved. All references to affected verses will be tagged so as to be correct in either the standard or the custom versification scheme. When verses are moved within the same book, the verses will be \'fit\' into the standard verse scheme. When verses are moved from one book to another, the effected verses will be recorded in both places within the OSIS file. Depending upon whether the OSIS file is rendered as standard, or custom versification scheme, the verses will appear in one location or the other.
      \b\b VSYS_MOVED: Tob -> Apocrypha[Tob]
      \b Indicates the entire book on the left was moved from its expected location to a custom book-group[book] given on the right. See %OSIS_GROUP for supported book-groups and books. An index number may be used on the right side in place of the book name. The book will be recorded in both places within the OSIS file. Depending upon whether the OSIS file is rendered as the standard, or custom versification scheme, the book will appear in one location or the other.
      \b\b VSYS_MOVED: Apocrypha -> bookGroup[2]
      \bIndicates the entire book-group on the left was moved from its expected location to a custom book-group index on the right. See %OSIS_GROUP for supported book-groups. The book-group will be recorded in both places within the OSIS file. Depending upon whether the OSIS file is rendered as the standard, or custom versification scheme, the book-group will appear in one location or the other.' ],
      ['VSYS_MOVED_ALT', 'Like VSYS_MOVED but this should be used when alternate verse markup like \'\va 2\va*\' has been used by the translators for the verse numbers of the moved verses (rather than regular verse markers which is the more common case). If both regular verse markers (showing the source system verse number) and alternate verse numbers (showing the fixed system verse numbers) have been used, then VSYS_MOVED should be used. This instruction will not change the OSIS markup of alternate verses. '],
      ['VSYS_MISSING_FN', 'Like VSYS_MISSING but is only to be used if a footnote was included in the verse before the missing verses which gives the reason for the verses being missing. This instruction will simply link the verse having the footnote together with the missing verse.' ],
      ['VSYS_CHAPTER_SPLIT_AT', 'Used when the translators split a chapter of the project\'s versification scheme into two chapters. This instruction takes the form:
      \b\b VSYS_CHAPTER_SPLIT_AT: Joel.2.28
      \b When the OSIS file is rendered as the standard versification scheme, verses from the split onward will be appended to the end of the previous verse and given alternate chapter:verse designations. Verses of any following chapters will also be given alternate chapter:verse designations. All references to affected verses will be tagged so as to be correct in either the standard or the custom versification scheme.' ],
    ])],
  ]],
  
  ['CF_addScripRefLinks.txt', [
    ['para', 'Paratext publications typically contain localized scripture references found in cross-reference notes, footnotes, introductions and other reference material. These references are an invaluable study aid. However, they often are unable to function as hyperlinks until converted from localized textual references to strictly standardized references. This control file tells the parser how to search the text for textual scripture references, and how to translate them into standardized hyperlinks.' ],
    ['para', 'Some descriptions below refer to extended references. An extended reference is composed of a series of individual scripture references which together form a single contextual sentence. An example of an extended reference is: See also Gen 4:4-6, verses 10-14 and chapter 6. The parser searches the text for extended references, and then parses each reference individually, in order, remembering the book and chapter context of the previous reference. This extended reference memory is required to correcly convert textual references in most translations.' ],
    ['list', ['SETTING', 'DESCRIPTION'], &getList([@CF_ADDSCRIPREFLINKS], [
      ['CONTEXT_BOOK', 'Textual references do not always include the book being referred to. Then the target book must be discovered from the context of the reference. Where the automated context search fails to discover the correct book, the CONTEXT_BOOK setting should be used. It takes the following form:
      \b\bCONTEXT_BOOK: Gen if-xpath ancestor::div[1]
      \bWhere Gen is any osis book abbreviation, \'if-xpath\' is a required keyword, and what follows is any xpath expression. The xpath will be evaluated for each textual reference and if it evaluates as true then the given book will be used as the context book for that reference.' ],
      ['WORK_PREFIX', 'Sometimes textual references are to another work. For instance a Children\'s Bible may contain references to an actual Bible translation. To change the work to which references apply, the WORK_PREFIX setting should be used. It takes the following form:
      \b\bWORK_PREFIX: LEZ if-xpath //@osisIDWork=\'LEZCB\'
      \bWhere LEZ is any project code to be referenced, \'if-xpath\' is a required keyword, and what follows is any xpath expression. The xpath will be evaluated for each textual reference and if it evaluates as true then LEZ will be used as the work prefix for that reference.' ],
      ['SKIP_XPATH', 'When a section or category of text should be skipped by the parser SKIP_XPATH can be used. It takes the following form:
      \b\bSKIP_XPATH: ancestor::div[@type=\'introduction\']
      \bThe given xpath expression will be evaluated for every suspected textual scripture reference, and if it evaluates as true, it will be left alone.' ],
      ['ONLY_XPATH', 'Similar to SKIP_XPATH but when used used, all suspected textual references will be skipped unless the given xpath expression evaluates as true.' ],
      ['CHAPTER_TERMS', 'A Perl regular expression matching localized words/phrases which will be understood as meaning "chapter". Example:
      \bCHAPTER_TERMS:(psalm|chap)' ],
      ['CURRENT_CHAPTER_TERMS', 'A Perl regular expression matching localized words/phrases which will be understood as meaning "the current chapter". Example:
      \bCURRENT_CHAPTER_TERMS:(this chapter)' ],
      ['CURRENT_BOOK_TERMS', 'A Perl regular expression matching localized words/phrases which will be understood as meaning "the current book". Example:
      \bCURRENT_BOOK_TERMS:(this book)' ],
      ['VERSE_TERMS', 'A Perl regular expression matching localized words/phrases which will be understood as meaning "verse". Example:
      \bVERSE_TERMS:(verse)' ],
      ['COMMON_REF_TERMS', 'A Perl regular expression matching phrases or characters which should be ignored within an extended textual reference. When an error is generated because an extended textual reference was incompletely parsed, parsing may have been terminated by a word or character which should instead be ignored. Adding it to COMMON_REF_TERMS may allow the textual reference to parse completely. Example:
      \bCOMMON_REF_TERMS:(but not|a|b)' ],
      ['PREFIXES', 'A Perl regular expression matching characters or language prefixes that may appear before other terms, including book names, chapter and verse terms etc. These terms are treated as part of the word they prefix but are otherwise ignored. Example:
      \bPREFIXES:(\(|")' ],
      ['REF_END_TERMS', 'A Perl regular expression matching characters that are required to end an extended textual reference. Example:
      \bREF_END_TERMS:(\.|")' ],
      ['SUFFIXES', 'A Perl regular expression matching characters or language suffixes that may appear after other terms, including book names, chapter and verse terms etc. These terms are treated as part of the word that precedes them but are otherwise ignored. Some languages have many grammatical suffixes and including them in SUFFIXES can improve the parsability of such langauges. Example:
      \bSUFFIXES:(\)|s)' ],
      ['SEPARATOR_TERMS', 'A Perl regular expression matching words or characters that are to be understood as separating individual references within an extended reference. Example:
      \bSEPARATOR_TERMS:(also|and|or|,)' ],
      ['CHAPTER_TO_VERSE_TERMS', 'A Perl regular expression matching characters that are used to separate the chapter from the verse in textual references. Example:
      \bCHAPTER_TO_VERSE_TERMS:(:)' ],
      ['CONTINUATION_TERMS', 'A Perl regular expression matching characters that are used to indicate a chapter or verse range. Example:
      \bCONTINUATION_TERMS:(to|-)' ],
      ['FIX', 'If the parser fails to properly convert any particular textual reference, FIX can be used to correct it or skip it. It has the following form:
      \b\bFIX: Gen.1.5 Linking: "7:1-8" = "<r Gen.7.1>7:1</r><r Gen.8>-8</r>"
      \bAfter FIX follows the line from the log file where the extended reference of concern was logged. Replace everything after the equal sign with a shorthand for the fix with the entire fix enclosed by double quotes. Or, remove everything after the equal sign to skip the extended reference entirely. The fix shorthand includes each reference enclosed in r tags with the correct osisID.' ],
      ['<osis-abbreviation>', 'To assign a localized book name or abbreviation to the corresponding osis book abbreviation, use the following form:
      \b\bGen = The book of Genesis
      \bThe osis abbreviation on the left of the equal sign may appear on multiple lines. Each line assigns a localized name or abbreviation on the right to its osis abbreviation on the left. Names on the right are not Perl regular expressions, but they are case insensitive. Listed book names do not need to include any prefixes of PREFIXES or suffixes of SUFFIXES to be parsed correctly.' ],
    ])],
  ]],
  
  ['CF_addFootnoteLinks.txt', [
    ['para', 'When translators include study notes which reference other study notes, this command file can be used to parse references to footnotes and convert them into working hyperlinks. This conversion requires that CF_addScripRefLinks.txt is also performed.' ],
    ['list', ['SETTING', 'DESCRIPTION'], &getList([@CF_ADDFOOTNOTELINKS], [
      ['ORDINAL_TERMS', 'A list of ordinal:term pairs where ordinal is ( \d | prev | next | last ) and term is a localization of that ordinal to be searched for in the text. Example:
      \bORDINAL_TERMS:(1:first|2:second|prev:preceding)' ],
      ['FIX', 'Used to fix a problematic reference. Each instance has the form:
      \b\bLOCATION=\'book.ch.vs\' AT=\'ref-text\' and REPLACEMENT=\'exact-replacement\'
      \bWhere LOCATION is the context of the fix, AT is the text to be fixed, and REPLACEMENT is the fix. If REPLACEMENT is \'SKIP\', there will be no footnote reference link.' ],
      ['SKIP_XPATH', 'See CF_addScripRefLinks.txt'],
      ['ONLY_XPATH', 'See CF_addScripRefLinks.txt'],
      ['FOOTNOTE_TERMS', 'A Perl regular expression matching terms that are to be converted into footnote links.'],
      ['COMMON_TERMS', 'See CF_addScripRefLinks.txt'], 
      ['CURRENT_VERSE_TERMS', 'See CF_addScripRefLinks.txt'],
      ['SUFFIXES', 'See CF_addScripRefLinks.txt'],
      ['STOP_REFERENCE', 'A Perl regular expression matching where scripture references stop and footnote references begin. This is only needed if an error is generated because the parser cannot find the transition. For instance: \'See verses 16:1-5 and 16:14 footnotes\' might require the regular expression: verses[\s\d:-]+and to delineate between the scripture and footnote references.'],
    ])],
  ]],
  
  ['CF_addDictLinks.xml', [
    ['para', '' ],
    ['list', ['ELEMENT', 'DESCRIPTION'], [
    
    ]],
    ['list', ['ATTRIBUTE', 'DESCRIPTION'], [
    
    ]],
  ]],
],

'osis2osis' => [

  ['Overview', [
    ['para', 'This is the Overview text.'],
  ]],
  
  ['CF_osis2osis.txt', [
    ['para', 'This is the CF_osis2osis.txt text.'],
  ]],
],

'osis2ebooks' => [

  ['Overview', [
    ['para', 'This is the Overview text.'],
  ]],
  
],

'osis2html' => [

  ['Overview', [
    ['para', 'This is the Overview text.'],
  ]],
  
],

'osis2sword' => [

  ['Overview', [
    ['para', 'This is the Overview text.'],
  ]],
  
],

'osis2gobible' => [

  ['Overview', [
    ['para', 'This is the Overview text.'],
  ]],
  
],

);

# Search for a particular key in a %HELP list and return its value. Key
# can be a script name, a heading, or the entry part of any 'list'.
sub help {
  my $lookup = shift;
  
  if (ref($HELP{$lookup})) {return &helpTop($HELP{$lookup});}
  
  my $r;
  foreach my $script (sort keys %HELP) {
    foreach my $headP (@{$HELP{$script}}) {
      if ($headP->[0] =~ /\Q$lookup\E/i) {
        return &helpHeading($headP->[1]);
      }
      foreach my $subP (@{$headP->[1]}) {
        if ($subP->[0] ne 'list') {next;}
        foreach my $listP (@{$subP->[1]}) {
          if ($listP->[0] =~ /\Q$lookup\E/i) {
            return $listP->[1];
          }
        }
      }
    }
  }
  
  return "No help available for $script.";
}

sub helpTop {
  my $topAP = shift;
  
  my $r; foreach (@{$topAP}) {$r .= &helpHeading($_);}
  
  return $r;
}

sub helpHeading {
  my $headingAP = shift;
  
  my $r = &format($headingAP->[0], 'heading');
    
  foreach my $s (@{$headingAP->[1]}) {
    if ($s->[0] eq 'list') {
      $r .= &helpList($s->[1], $s->[2]);
    }
    else {
      $r .= &format($s->[1], $s->[0]);
    }
  }
  
  return $r;
}

sub format {
  my $text = shift;
  my $type = shift;
  my $listAP = shift;
  
  my @args; if ($type =~ s/:(.+)$//) {@args = split(/,/, $1);}
  
  if ($type eq 'heading') {
    return $text . "\n" . '-' x length($text) . "\n";
  }
  elsif ($type eq 'sub-heading') {
    return uc($text) . "\n";
  }
  elsif ($type eq 'para') {
    return &para($text, @args);
  }
  
  return $text;
}

sub helpList {
  my $listheadAP = shift;
  my $listAP = shift;
  
  my $sep = ' -';
 
  # find column 1 width
  my $left = 0;
  foreach my $row (@{$listAP}) {
    if ($left < length($row->[0])) {$left = length($row->[0]);}
  }
  
  my $r = &listRow( $listheadAP->[0], 
                    $listheadAP->[1], 
                    $left, 
                    ' ' x length($sep));
                    
  foreach my $row (@{$listAP}) {
    $r .= &listRow($row->[0], $row->[1], $left, $sep) . "\n";
  }
  
  return $r;
}

sub listRow {
  my $key = shift;
  my $description = shift;
  my $left = shift;
  my $sep = shift;
  
  if (!$key && !$description) {return '';}
  
  if ($left > 28) {$left = 28;}

  return sprintf("%-${left}s%s%s", 
    $key,
    ($description ? $sep : ''),
    &para( $description, -1, $left + length($sep), undef, 1 ));
}

# Return a formatted paragraph of string t. Whitespace is first norm-
# alized in the string. $indent is the first line indent, $left is the
# left margin, and $width is the width in characters of the paragraph.
# $indent of -1 means output starts with the first character of $t (or
# -$left in other words). The special tag \b will be rendered as a 
# blank line with the paragraph.
sub para {
  my $t = shift;
  my $indent = shift; if (!defined($indent)) {$indent = 0;}
  my $left   = shift; if (!defined($left))   {$left   = 0;}
  my $width  = shift; if (!defined($width))  {$width  = 72;}
  my $noBlankLine = shift;
  
  $t =~ s/\s*\n\s*/ /g;
  $t =~ s/(^\s*|\s*$)//g;
  
  if ($indent == -1) {
    $indent = 0;
  }
  else {
    $indent = $left + $indent;
  }
  if ($indent) {$t = ' ' x $indent . $t;}
  
  my $tab = ' ' x $left;
 
  my $w = $width - $left - 12;
  
  my $out;
  my $i = $w + $indent;
  foreach my $sec (split(/(\s*\\b\s*)/, $t)) {
    if ($sec =~ /\\b/) {$out .= ' ' x $left; next;}
    while ($sec =~ s/^(.{$i}\S*\s+)//) {
      $out .= "$1\n$tab";
      $i = $w
    }
    $out .= $sec . "\n";
  }
  if (!$noBlankLine) {$out .= "\n";}
  
  return $out;
}

# Return a pointer to an array of help-list rows. Each key in $keyAP 
# becomes the key of a new row in the help-list, while the description 
# is a combination of any matching key description found in $descAP and 
# any matching default value in %CONFIG_DEFAULTS. Any unused 
# descriptions in $descAP will generate an error.
sub getList {
  my $keyAP = shift;
  my $descAP = shift;
  
  my $refRE = &configRE(keys %CONFIG_DEFAULTS);
  
  my @out;
  # Go through all required keys (some may be MATCHES keys)
  foreach my $k (sort @{$keyAP}) {
    my $key = $k;
    
    # Look for one or more matching description keys
    my @desc;
    if ($key =~ s/^MATCHES://) {
      foreach my $kdP (@{$descAP}) {
        if ($kdP->[0] =~ /^($key)$/ || $kdP->[0] eq $key) {
          push(@desc, $kdP->[0]);
        }
      }
    }
    else {push(@desc, $key);}
    
    # Output one row for each matching description
    foreach my $k2 (sort @desc) {
    
      my $descP; foreach my $kdP (@{$descAP}) {
        if ($kdP->[0] eq $k2) {$descP = $kdP; $kdP = undef;}
      }
      
      my $def;
      if ($key =~ /($refRE)/) {$def = $CONFIG_DEFAULTS{$key};}
      if ($def =~ /DEF$/) {$def = '';}
      
      push(@out, [
        ($descP->[0] ? $descP->[0] : $key), 
        ($descP->[1] ? $descP->[1].' ':'').($def ? "Default is '$def'.":'')
      ]);
    }
  }
  
  foreach (@{$descAP}) {
    if (ref($_) && ($_->[0] || $_->[1])) {
      &ErrorBug("Unused description: '".$_->[0]."', '".$_->[1]."'\n", 1);
    }
  }

  return \@out;
}

# Adds an entry type code to each key of a 'list'.
sub addEntryType {
  my $aP = shift;

  my %re = (
    'system' => ['S', &configRE(@OC_SYSTEM_CONFIGS)],
    'local'  => ['L', &configRE(@SWORD_LOCALIZABLE_CONFIGS, @OC_LOCALIZABLE_CONFIGS)],
    'cont'   => ['C', &configRE(@CONTINUABLE_CONFIGS)],
    'sword'  => ['W', &configRE(@SWORD_CONFIGS)],
  );
  
  foreach my $rP (@{$aP}) {
    my @types;
    foreach my $t (sort keys %re) {
      my $a = $re{$t}[1];
      if ($rP->[0] =~ /$a/) {push(@types, $re{$t}[0]);}
    }
    if (@types) {
      $rP->[0] .= ' ('.join('', @types).')';
    }
  }
  
  return $aP;
}

sub usage {
  my $r = "\nUSAGE: $SCRIPT_NAME ";
    
  my %p; my $c;
  foreach my $t ('argument', 'option', 'switch') {
    foreach my $s ('all', $SCRIPT_NAME) {
      foreach my $a (sort keys %{$ARG{$s}{$t}}) {
        if ( $s eq 'all' && exists($ARG{$SCRIPT_NAME}{$t}{$a}) ) {
          next;
        }
        my @a = @{$ARG{$s}{$t}{$a}};
        
        my $sub = ( $t eq 'switch' ? "-$a" : 
                  ( $t eq 'option' ? "-$a ".@a[2] : @a[2] ));
               
        # Set the sort order using numbered hash keys
        my $k1 = ($t eq 'switch'   ? 100 : ($t eq 'option' ? 1000: 10000));
        my $k2 = ($t eq 'argument' ? 100 : ($t eq 'switch' ? 1000: 10000));
        
        $p{'tem'}{ ($k1 + $c) } = "[$sub]";
        $p{'exp'}{ ($k2 + $c) }{$sub} = @a[3];
        $c++;
      }
    }
  }
  
  my $l = 0; foreach (keys %{$p{'tem'}}) {
    if ($l < length($p{'tem'}{$_})-2) {$l = length($p{'tem'}{$_})-2;}
  }
  
  my $tem = 
    join(' ', map($p{'tem'}{$_}, sort {$a <=> $b} keys %{$p{'tem'}}));
    
  my $exp;
  foreach my $i (sort {$a <=> $b} keys %{$p{'exp'}}) {
    foreach my $s (sort keys %{$p{'exp'}{$i}}) {
      $exp .= sprintf('%-'.$l."s : %s\n", 
              $s, &usagePrint(($l+3), 72, $p{'exp'}{$i}{$s}));
    }
  }
  
  $r .= "$tem\n\n$exp\n";
  
  return $r;
}

sub usagePrint {
  my $tablen = shift;
  my $width = shift;
  my $string = shift;
  
  my $chars = ($width - 12 - $tablen);
  my $tab = (' ' x $tablen);
  $string =~ s/(.{$chars}\S*)\s/$1\n$tab/g;
  
  return $string;
}

# Read all arguments in @_ and set all argument globals. Return a hash 
# containing the supplied arguments if successful. If unexpected 
# arguments are found an abort message is output and undef is returned.
sub arguments {
  no strict 'refs';
  
  # First set globals to default values
  foreach my $s ('all', $SCRIPT_NAME) {
    foreach my $t (keys %{$ARG{$s}}) {
      foreach my $a (keys %{$ARG{$s}{$t}}) {
        my $n = @{$ARG{$s}{$t}{$a}}[0];
        my $v = @{$ARG{$s}{$t}{$a}}[1];
        $$n = $v
      }
    }
  }
  
  my $switchRE = join('|', map(keys %{$ARG{$_}{'switch'}}, 'all', $SCRIPT_NAME));
  my $optionRE = join('|', map(keys %{$ARG{$_}{'option'}}, 'all', $SCRIPT_NAME));
  
  my %args;
  
  # Now update globals based on the provided arguments.
  my $argv = shift;
  my @a = ('first', 'second'); $a = 0;
  my ($arg, $val, $type);
  while ($argv) {
    if ($argv =~ /^\-(\S*)/) {
      my $f = $1;
      if ($f =~ /^($switchRE)$/) {
        $arg = $1;
        $val = undef;
        $type = 'switch';
      }
      elsif ($f =~ /^($optionRE)$/) {
        $arg = $1;
        $val = shift; 
        $type = 'option';
        if (!$val || $val =~ /^\-/) {
          print "\nABORT: option -$f needs a value\n";
          return;
        }
      }
      else {
        print "\nABORT: unhandled option: $argv\n";
        return;
      }
    }
    else {
      $arg = @a[$a];
      $val = $argv;
      $type = 'argument';
      if (@a[$a]) {$a++;}
      else {
        print "\nABORT: too many arguments.\n";
        return;
      }
    }
    
    my $var;
    if (ref($ARG{$SCRIPT_NAME}{$type}{$arg})) {
      $var = $ARG{$SCRIPT_NAME}{$type}{$arg}[0];
    }
    else {$var = $ARG{'all'}{$type}{$arg}[0];}
    
    if ($type eq 'switch') {$val = !$$var;}
    
    $$var = $val;
    $args{$arg} = $val;
    
    $argv = shift;
  }
  
  &DebugListVars("$SCRIPT_NAME arguments", 'HELP', 'INPD', 'LOGFILE', 
    'NO_ADDITIONAL', 'CONVERSION', 'MODRE', 'MAXTHREADS', 'SKIPRE');
  
  return %args;
}
