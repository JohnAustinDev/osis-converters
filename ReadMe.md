# osis-converters
Ubuntu dependencies may be installed by running `sudo ./provision.sh`.

# convert 

## SYNOPSIS 
With Paratext USFM files in the directory: `/<PROJECT_CODE>/sfm/`<br /><br />`./bin/defaults ./<PROJECT_CODE>`<br /><br />`./bin/convert ./<PROJECT_CODE>`<br /><br />Creates:<br />* An [OSIS](http://www.crosswire.org/osis/) XML file<br />* A reference OSIS XML file (if there are USFM reference materials)<br />* Linked HTML<br />* epub and azw3 eBook Bibles<br />* A [SWORD](http://www.crosswire.org/wiki/Main_Page) Bible module<br />* A SWORD Dictionary module (if there are USFM reference materials)<br />* [GoBible](http://www.crosswire.org/wiki/Projects:Go_Bible) Java-ME apps


### USFM / SFM 
Paratext Unified Standard Format Markers (USFM) is the successor of Standard Format Markers (SFM). SFM may require preprocessing before conversion to OSIS (see `./bin/convert -h EVAL_REGEX`).


### DEFAULT CONTROL FILES 
The conversion process is guided by control files. When the `defaults` program is run on a project, project control files are created from templates located in one of the `defaults` directories. Conversion is controlled by these files located in the project directory. A project is not ready to publish until there are no errors reported in LOG files, warnings have been checked, and all materials and meta-data have been added to the project. For details see `./bin/convert -h defaults`


### LOG FILES 
Log files report everything about the conversion process. They are written to the module's output directory and begin with `LOG_`. Each conversion step generates its own log file containing these labels:

LABEL | DESCRIPTION
----- | -----------
**ERROR** | Problems that must be fixed. A solution to the problem is also listed. Fix the first error, because this will often fix following errors.
**WARNING** | Possible problems. Read the message and decide if anything needs to be done.
**NOTE** | Informative notes.
**REPORT** | Conversion reports. Helpful for comparing runs.


### CONVERT 
The `convert` program will schedule and run conversions for one or more projects. It schedules any pre-requisite conversions, insuring each publication is up-to-date. Normally it is the last command run on a project before publication. During development, running individual scripts may be more convenient. The following scripts are called by `convert`, depending on its arguments:

SCRIPT | DESCRIPTION
------ | -----------
**sfm2osis** | Convert Paratext SFM/USFM to OSIS XML.
**osis2osis** | Convert an OSIS file from one script to another, or convert control files from one script to another.
**osis2ebooks** | Convert OSIS to eBook publications, including an entire translation eBook publication, sub-publication eBooks and single Bible book eBooks.
**osis2html** | Convert OSIS to HTML, including a table-of-contents and comprehensive navigational links.
**osis2sword** | Convert OSIS to CrossWire SWORD modules. A main module will be produced, as well as a linked dictionary module when applicable.
**osis2gobible** | Convert OSIS to Java-ME feature phone apps.


### SCOPE 
A 'scope' is a specific way of listing the contents of Bible publications. It is generally a space separated list of OSIS book abbreviations in verse system order (see `./bin/convert -h OSIS_ABBR`). When used in directory names, file names or config.conf entry names, spaces should be replaced by underscores. Example: `Ruth_Esth_Jonah`. Continuous ranges of more than two books are shortened using '-'. Example: `Matt-Rev`.


### SUB-PUBLICATIONS 
A Bible translation may have been published in multiple parts, such as a Penteteuch publication and a Gospels publication. These are referred to as sub-publications. Conversions may output electronic publications for each sub-publication, in addition to the whole. They may also output single Bible book electronic publications. Each electronic publication will include reference materials that fall within its scope.

A sub-publication is added to a project by putting those SFM files which are part of the sub-publication in subdirectory `<main-module> / sfm / <scope>` where `<scope>` is the scope of the sub-publication (see `./bin/convert -h scope`). The scope may be prepended with a 2 digit number followed by '_' to order the sub-publications within the whole translation.


### HELP 
Run `./bin/convert -h '<setting> | <file> | <script>'` to find help on any particular setting, control file or script.


# defaults 

## SYNOPSIS 
Create default control files for a project (for both `MAINMOD` and `DICTMOD` if there is one) from source files located in `defaults` directories. Existing project control files are never changed or overwritten. If a template is located, it will be copied and then modified for the project, otherwise any default file located will be copied. The order of search is:<br />1. `<file>_<type>_template.<ext>`<br />2. `<file>_template.<ext>`<br />3. `<file>_<type>.<ext>`<br />4. Any file with the same name and extension.<br />Where `<file>.<ext>` is `(config.conf | CF_sfm2osis.txt | CF_addScripRefLinks.txt | CF_addFootnoteLinks.txt)` and `<type>` is `(bible | childrens_bible | commentary | dictionary)` according to the type of project or module.


### DEFAULTS DIRECTORIES 
All `defaults` files are searched for in the following directories, in order. The first template found is modified and used, otherwise the first file found is used. The directories searched are:<br />1. `<project-directory>`<br />2. `<project-directory>/../defaults`<br />3. `osis-converters/defaults`<br />NOTE: during #2 each <project-directory> ancestor directory will be searched for a `defaults` directory, not just the parent, so similar projects may be grouped together in subdirectories, sharing default files.


# sfm2osis 

## SYNOPSIS 

### CONVERT PARATEXT FILES INTO OSIS XML 
OSIS is an xml standard for encoding Bibles and related texts (see: [http://crosswire.org/osis/](http://crosswire.org/osis/)). The OSIS files generated by sfm2osis include meta-data, explicit references, cross-references and textual information not present in the original Paratext USFM/SFM source files. The resulting OSIS file is a more complete source file than the original Paratext files and is an excellent intermediate format, easily and reliably converted into any other format.

A project conversion creates a main OSIS file, which may contain a Bible, Children's Bible or commentary. Related Paratext glossaries, maps and other reference materials, if they exist, are all included in another OSIS file. These two OSIS files are converted as separate modules, referred to as MAINMOD and DICTMOD. If a project has a DICTMOD, it will appear as a subdirectory of the main module, ending with `DICT`.

The SFM to OSIS conversion process is directed by the following control files:

FILE | DESCRIPTION
---- | -----------
**config.conf** | Configuration file with settings and meta-data for a project.
**CF_sfm2osis.txt** | Place and order converted SFM files within the OSIS file and record deviations from the standard markup and verse system.
**CF_`<vsys>`.xml** | Insert Bible cross-references into the text.
**CF_addScripRefLinks.txt** | Control parsing of scripture references from the text and their conversion to working OSIS hyperlinks.
**CF_addDictLinks.xml** | Control parsing of reference material references from the text and their conversion to working OSIS hyperlinks.
**CF_addFootnoteLinks.txt** | Control parsing of footnote references from the text and their conversion to working OSIS hyperlinks.

Default control files are created by the 'defaults' command. For help on an individual file or command run: `./bin/convert -h '<file> | <command>'`


### TABLE OF CONTENTS 
A table of contents or menu system (referred to as the TOC) is a critical part of most electronic publications. Bible books, chapters, introductions, glossaries, tables, maps and other reference materials appear in the TOC. The sfm2osis script tries to auto-detect TOC entries, and marks them. But the TOC is also customizable. By default, USFM `\toc2` tags create new TOC entries. Alternative `\tocN` tags may be used if desired (see `./bin/convert -h TOC`). Chapters and glossary keywords automatically appear in the TOC and do not need a `\tocN` tag. Note: `EVAL_REGEX` may be used to insert a TOC tag into an SFM file.

Two renderings of the TOC are generated. One is a detached, hierarchical TOC having up to three levels of hierarchy. This fits the requirements of an eBook TOC. The second is an inline TOC appearing along with the text in segments, having no hierarchical limitations. This fits the requirments of SWORD. Some ePublications use both renderings, such as epub.

One or more of the following instructions may be prepended to any TOC title to fine tune how the TOC is rendered:

INSTRUCTION | DESCRIPTION
----------- | -----------
**[levelN]** | Explicitly specifies the TOC hierarchy level. Where `N` is 1 for top level, 2 for second, or 3 for inner-most level. By Default, TOC hierarchy level is determined from OSIS element hierarchy.
**[no_toc]** | Removes a chapter or keyword from the TOC.
**[parent]** | Force a TOC to become a parent by making the following TOC's to have the next highest TOC level.
**[not_parent]** | Force the children of a TOC entry to follow the parent by inheriting its TOC level.
**[no_inline_toc]** | Remove a TOC entry from the inline TOC. This could result in broken link errors for non-eBook publications.
**[only_inline_toc]** | Remove a TOC entry from the detached TOC.
**[no_main_inline_toc]** | Remove a TOC entry from the main inline TOC. The main inline TOC appears on the beginning of an ePublication and serves as the overall TOC for the entire publication. The TOC entry may still appear in subsequent inline TOC segments.
**[inline_toc_first]** | Place the inline TOC segment right after the TOC entry. This only applies to DICTMOD, where by default inline TOC segments are placed just before the following TOC entry.
**[inline_toc_last]** | Place the inline TOC segment before the following TOC entry. This only applies to MAINMOD, where by default inline TOC segments are placed right after the TOC entry. NOTE: the inline TOC will be placed before the following child TOC entry even when it is marked as `[no_toc]`. So a `[no_toc]` child entry can be used as a placeholder for the previous inline TOC segment.
**[bookSubGroup]** | The TOC entry corresponds to a Bible book sub-group introduction; useful for distinguishing it from the book-group introduction.


### SFM ID DIRECTIVES 
All USFM files begin with an \id tag. Special directives may be appended to the \id tag to mark its content for special purposes or to place content appropriately within the OSIS file. Although SFM files are converted and appended to the OSIS file in the order they are `RUN` in `CF_sfm2osis.txt`, an SFM file's content may need to appear in different locations. For instance an SFM file may contain a `\periph` tag for the copyright information, another for the introduction and another for end-notes. Each should take a different location within the OSIS file even though they reside together in the same SFM file. ID directives will handle this situation and more.

Each ID directive has the form `<directive> == <value>` and will act on one or more OSIS div elements. A set of ID directives may be appended to an `\id` tag, with each directive separated by a comma, and all must appear on a single line. ID directives are not part of the original SFM source file. The default `CF_sfm2osis.txt` file uses `EVAL_REGEX` to append default directives to the `\id` tag. There are two types of ID directive:

(P): Placement directives select the OSIS div element referred to on the left of the `==` and mark, move or remove it according to the right side's xpath expression or keyword. An xpath expression selects one or more OSIS XML nodes, before which the div element will be placed. The `remove` keyword removes the div element entirely from the OSIS file. The `mark` keyword leaves the div where it is. If not removed, the div element will be marked by all previous marking ID directives in the set. If the xpath expression selects more than one node, the marked div element will be copied and placed before each selected node. Example placement directives:<br />`"Table of Contents" == remove`,<br />`introduction == //div[@osisID="Gen"]`

(M): Mark directives will mark OSIS div elements in some way. The kind of mark left of `==` having the value to the right, will be applied to each OSIS div element selected by subsequent placement directives in the set. Example marking directives:<br />`cover == yes`,<br />`scope == Matt-Rev`<br />When the `\id` line has been fully processed, the top OSIS div element will be marked if it was not explicitly marked by the `location == mark` directive. Any particular mark will cease for that set after a `<mark-type> == stop` directive.


DIRECTIVE | DESCRIPTION
--------- | -----------
**location (P)** | Selects the OSIS div of the converted SFM file for marking or placement. When an SFM file contains `\periph` sections which are also being placed, those `\periph` sections are removed from their position within the parent OSIS div. Therefore when the entire contents of an SFM file is placed somewhere else, `location == remove` may be used to remove the resulting empty parent div element from the OSIS file.
**`<identifier>` (P)** | Selects an OSIS child div of the converted SFM file for marking or placement. The identifier must be an OSIS div type, OSIS div subType, USFM periph type, or USFM periph name. A USFM periph name must be enclosed in double quotes. The next div child matching the identifier will be selected. Note: An SFM file's top (parent) div should be selected using `location`.
**x-unknown (P)** | Selects the next OSIS child div of the converted SFM file, regardless of what it is.
**scope (M)** | Marks OSIS div elements with a given scope. This may be used to mark the Pentateuch introduction with `scope == Gen-Deut` for instance, associating it with each of book of the Pentateuch.
**feature (M)** | Mark OSIS div elements for use with a particular feature. See SPECIAL FEATURES below.
**cover (M)** | Takes a `( yes \| no )` value. A value of yes marks OSIS div elements to receive a cover image when scope matches an available cover image. Use in conjunction with the scope ID directive.
**conversion (M)** | Takes a space separated list of conversions for which the marked OSIS div is to be included. For conversions not listed, the OSIS div will be removed. Conversion options are `( none \| ebooks \| html \| sword \| gobible \| book \| subpub \| tbook \| tran)`.
**not_conversion (M)** | Takes a space separated list of conversions during which the marked OSIS div is to be removed. Conversion options are `( ebooks \| html \| sword \| gobible \| CF_addDictLinks \| CF_addDictLinks.bible \| CF_addDictLinks.dict \| book \| subpub \| tbook \| tran)`.


### SPECIAL FEATURES 
The directive `feature == <feature>` may be used to mark OSIS div elements for special purposes (see `./bin/convert -h 'SFM ID DIRECTIVES'`). Supported features are:

FEATURE | DESCRIPTION
------- | -----------
**NO_TOC** | A glossary marked with this feature will not appear in any table of contents or navigational menus. This is useful on material that was duplicated as a glossary containing targets for textual links.
**INT** | When a translation has introductory material that applies to the whole, it is useful to have this material added to navigation menus. It will then be accessible from every introduction, chapter and keyword, rather than from one location alone. To enable this feature, include a `RUN` statement for the introduction SFM file in both `MAINMOD/CF_sfm2osis.txt` and  `DICTMOD/CF_sfm2osis.txt` adding the `feature == INT` ID directive each time. The other requirement is the use of EVAL_REGEX to convert headings into keywords in DICTMOD. Here is an example:<br /><br />`/MAINMOD/CF_sfm2osis.txt` might contain:<br />`EVAL_REGEX:s/(\\id [^\n]+)/$1, feature == INT/`<br />`RUN:../sfm/FRT.SFM`<br /><br />`/DICTMOD/CF_sfm2osis.txt` might contain:<br />`EVAL_REGEX:s/(\\id [^\n]+)/\\id GLO feature == INT/`<br />`EVAL_REGEX:s/^\\(?:imt\|is) (.*?)$/\\m \\k $1\\k*/gm`<br />`RUN:../sfm/FRT.SFM`
**NAVMENU** | Navigation menus are created automatically from the TOC. But when custom navigation menus are desired, the NAVMENU feature may be used. Design the custom menu in USFM and append the ID directive to its `\id` tag:<br />`feature == NAVMENU.<osisID>.<replace\|top>`<br />Using the osisID of an existing navigation menu to modify, and using either `replace` to replace that menu, or `top` to insert the custom menu at the top of that menu.


### HOOKS 
For situations when custom processing is required, hooks are provided for custom Perl scripts and XSLT transforms. Use hooks only when EVAL_REGEX is insufficient as they complicate project maintenance. Perl scripts have two arguments: input OSIS file and output OSIS file, while XSLT transforms use standard XML output.

Scripts with these names in a module directory will be called at different points during the conversion to OSIS:

HOOK | WHEN CALLED
---- | -----------
**bootstrap.pl** | The sfm2osis or osis2osis script will execute it before conversion begins. It must appear in a project's top directory, and it takes no arguments. It may be used to copy or process any project file etc., but should be used only when osis2osis is insufficient (see `./bin/convert -h osis2osis`).
**preprocess.pl** | It will be executed after usfm2osis.py does the initial conversion to OSIS, before subsequent processing. Use EVAL_REGEX when preprocessing of SFM files would be sufficient.
**preprocess.xsl** | Same as preprocess.pl (after it).
**postprocess.pl** | It will be executed after an OSIS file has been fully processed, but before OSIS validation and final checks.
**postprocess.xsl** | Same as postprocess.pl (after it).


## config.conf 
Each project has a `config.conf` file. The configuration file contains conversion settings and meta-data for the project. A project consist of a single main module, and possibly a single dictionary module containing reference material. The `config.conf` file may have multiple sections. The main section contains configuration settings applying to the entire project, while settings in other sections are effective in their particular context, overriding any matching settings of the main section. The 'system' section is different as it contains global constants that are the same in any context. The following sections are recognized: `MAINMOD`, `DICTMOD`, `system`, `osis2ebooks`, `osis2html`, `osis2sword`, `osis2gobible` (where `MAINMOD` is the project code and `DICTMOD` is the project code suffixed with `DICT`).

The following table lists the available entries of `config.conf`. See the end of the table for the meaning of letters in parenthesis which follow some entry names.

ENTRY | DESCRIPTION
----- | -----------
**ARG_\w+** | Config settings for undocumented fine control.
**Abbreviation (LW)** | A short localized name for the module.
**About (CLW)** | Localized information about the module. Similar to `Description` but longer.
**AddCrossRefLinks** | Select whether to insert externally generated cross-reference notes into the text: `(true \| false \|AUTO)`. `AUTO` adds them only if a `CF_<vsys>.xml` file is found for the project (see `./bin/convert -h 'Adding External Cross-References'`). Default is `AUTO`.
**AddDictLinks** | Select whether to parse glossary references in the text and convert them to hyperlinks: `(true \| false \| check \| AUTO)`. `AUTO` runs the parser only if `CF_addDictLinks.txt` is present for the module. Default is `AUTO`.
**AddFootnoteLinks** | Select whether to parse footnote references in the text and convert them to hyperlinks: `(true \| false \| AUTO)`. `AUTO` runs the parser only if `CF_addFootnoteLinks.txt` is present for the module. Default is `AUTO`.
**AddScripRefLinks** | Select whether to parse scripture references in the text and convert them to hyperlinks: `(true \| false \| AUTO)`. `AUTO` runs the parser only if `CF_addScripRefLinks.txt` is present for the module. Default is `AUTO`.
**AudioCode** | A publication code for associated audio. Multiple modules having different scripts may reference the same audio.
**BookGroupTitle\[\w+\]** | A localized title to use for one the book groups. `BookGroupTitle[NT]` is the New Testament's title and `BookGroupTitle[OT]` is the Old Testament's title. One of the following book group codes must appear between the square brackets: `OT, NT, Apocrypha, Apostolic_Fathers, Armenian_Orthodox_Canon_Additions, Ethiopian_Orthodox_Canon, Peshitta_Syriac_Orthodox_Canon, Rahlfs_LXX, Rahlfs_variant_books, Vulgate_and_other_later_Latin_mss, Other`. Example: `BookGroup[NT]=The New Testament` or `BookGroup[Apocrypha]=The Apocrypha`
**COVERS (PSU)** | Location where cover images may be found. Cover images should be named: `<project-code>_<scope>.jpg` and will then automatically be included in the appropriate OSIS files.
**CombineGlossaries** | Set to `true` to combine all glossaries into one, or false to keep them separate. `AUTO` lets osis-converters decide. Default is `AUTO`.
**CombinedGlossaryTitle (L)** | A localized title for the combined glossary in the Table of Contents.
**Companion (W)** | 
**Copyright (CLW)** | Contains the copyright notice for the work, including the year of copyright and the owner of the copyright.
**CopyrightContactAddress (CLW)** | Address of the copyright holder.
**CopyrightContactEmail (LW)** | Email address of the copyright holder.
**CopyrightContactName (CLW)** | Name for copyright contact.
**CopyrightContactNotes (CLW)** | Notes concerning copyright holder contact.
**CopyrightDate (LW)** | Four digit copyright year.
**CopyrightHolder (LW)** | Name of the copyright holder.
**CopyrightNotes (CLW)** | Notes from the copyright holder.
**CustomBookOrder** | Set to `true` to allow Bible book order to remain as it appears in CF_sfm2osis.txt, rather than project versification order: `(true \| false)`. Default is `false`.
**DEBUG (S)** | Set to `true` enable debugging log output.
**Description (LW)** | A short localized description of the module.
**Direction (W)** | LtoR (Left to Right), RtoL (Right to Left) or BiDi (Bidirectional) Default is `LtoR`.
**DistributionLicense (W)** | see: [https://wiki.crosswire.org/DevTools:conf_Files](https://wiki.crosswire.org/DevTools:conf_Files)
**DistributionNotes (CLW)** | Additional distribution notes.
**EBOOKS (SU)** | Location where eBooks are published.
**FONTS (PSU)** | Permanent location where specified fonts can be found.
**Font (W)** | The font to use for electronic publications.
**FullResourceURL (U)** | Single Bible book eBooks often have links to other books. This URL is where the full publication may be found. Default is `false`.
**GlossaryNavmenuLink\[[1-9]\]** | Specify a custom main navigation menu link. For example to change the title of the second link on the main menu: `GlossaryNavmenuLink[2]=New Title` or to bypass a sub-menu having only one link on it: `GlossaryNavmenuLink[1]=&osisRef=<osisID>&text=My Link Title`
**History_[\d\.]+** | Each version of released publications should have one of these entries describing what was new in that version.
**IntroductionTitle (L)** | A localized title for Bible book introductions.
**KeySort** | This entry enables localized list sorting by character collation. Square brackets are used to separate any arbitrary case sensitive regular expressions which are to be treated as single characters during the sort comparison. Also, a single set of curly brackets can be used around a regular expression which matches any characters/patterns that need to be ignored during the sort comparison. IMPORTANT: Any square or curly bracket within regular expressions must have an additional backslash before it. NOTE: The regular expression processor currently in use does not support look-around assertions.
**Lang (W)** | ISO language code and script code. Examples: tkm-Cyrl or tkm-Latn
**MakeSet[book]** | Select whether to create separate ePublications for individual Bible books within the OSIS file: `(true \| false \| AUTO \| <OSIS-book> \| first \| last)`.
**MakeSet[subpub]** | Select whether to create separate outputs for individual sub-publications within the OSIS file: `(true \| false \| AUTO \| <scope> \| first \| last)`.
**MakeSet[tran]** | Select whether to create a single ePublication containing everything in the OSIS file: `(true \| false \| AUTO)`.
**MakeTypes** | Select which type, or types, of publications to make: `(AUTO \| azw3 \| epub)`. Default is `AUTO`.
**NO_FORKS (S)** | Set to `true` to disable the multi-thread fork feature. Doing so may increase conversion time.
**NormalizeUnicode** | Apply a Unicode normalization to all characters: `(true \| false \| NFD \| NFC \| NFKD \| NFKC \| FCD)`. Default is `false`.
**OUTDIR (PS)** | Location where output files should be written. OSIS, LOG and publication files will appear in a module subdirectory here. Default is an `output` subdirectory within the module.
**Obsoletes (W)** | see: [https://wiki.crosswire.org/DevTools:conf_Files](https://wiki.crosswire.org/DevTools:conf_Files)
**PreferredCSSXHTML (W)** | SWORD module css may be included by placing it in a `module.css` file located in a default directory (See `./bin/convert -h defaults`).
**ProjectType** | Type of project. Options are: `bible \| childrens_bible \| commentary`. Default is `bible`.
**RAM_GB_EBOOKS (S)** | The required amount of RAM, in GB, that needs to be free before the scheduler will start another eBook or HTML build. Default is 1. Increase this value if scheduled eBook builds are using too much RAM.
**RAM_MB_EBOOKS_PERBOOK (S)** | The required amount of RAM, in MB per Bible book, that needs to be free in addition to RAM_GB_EBOOKS, before the scheduler will start another eBook or HTML build. Default is 32. This value can be used to further optimize RAM usage.
**REPOSITORY (PSU)** | Location where SWORD modules are published.
**ReorderGlossaryEntries** | Set to `true` and all glossaries will have their entries re-ordered according to KeySort, or else set to a regex to re-order only glossaries whose titles match: `(true \| <regex>)`. Default is `false`.
**ShortCopyright (LW)** | Short copyright string.
**ShortPromo (LW)** | A link to the home page for the module, perhaps with an encouragement to visit the site.
**SubPublicationTitle\[\S+\]** | The localized title of a particular sub-publication. The scope of the sub-publication must appear between the square brackets (see `./bin/convert -h SUB-PUBLICATIONS` and see `./bin/convert -h scope`).
**TOC** | A number from 1 to 3 indicating which SFM tag to use for generating the table of contents: `\toc1`, `\toc2` or `\toc3`. Default is `2`.
**TextSource (CW)** | Indicates a name or URL for the source of the text.
**TitleCase** | A number from 0 to 2 selecting letter casing for table of contents titles: 0 is as-is, 1 is Like This, 2 is LIKE THIS.
**TitleTOC** | A number from 1 to 3 indicating which Bible book title to use for the TOC and single book publications: 1 uses the BookNames.xml `long` name or the book `\toc1` tag, 2 uses the BookNames.xml `short` name or the book `\toc2` tag, and 3 uses the BookNames.xml `abbr` name or book `\toc3` tag. Default is `2`.
**TranslationTitle (L)** | A localized title for the entire translation.
**VAGRANT (S)** | Set to `true` to force osis-converters to run in a Vagrant VirtualBox virtual machine.
**Versification (W)** | The versification system of the project. All deviations from this verse system must be recorded in CF_sfm2osis.txt by VSYS instructions. Supported options are: `KJV`, `German`, `KJVA`, `Synodal`, `Leningrad`, `NRSVA`, `Luther`, `Vulg`, `SynodalProt`, `Orthodox`, `LXX`, `NRSV`, `MT`, `Catholic`, `Catholic2`. Default is `KJV`.
**Version (W)** | The version of the publication being produced. There should be a corresponding `History_<version>` entry stating what is new in this version.

(C): Continuable from one line to another using a backslash character.

(L): Localizable by appending underscore and language ISO code to the entry name.

(P): Path of a local file or directory.

(S): May appear in the system section only.

(U): An http or https URL.

(W): SWORD standard (see: [https://wiki.crosswire.org/DevTools:conf_Files](https://wiki.crosswire.org/DevTools:conf_Files)).



## CF_sfm2osis.txt 
This control file is required for sfm2osis conversions. It should be located in each module's directory (both MAINMOD and DICTMOD if there is one). It controls what material appears in each module's OSIS file and in what order, and is used to apply Perl regular expressions for making changes to SFM files before conversion.

COMMAND | DESCRIPTION
------- | -----------
**EVAL_REGEX** | Any perl regular expression to be applied to source SFM files before conversion. An EVAL_REGEX instruction is only effective for the RUN statements which come after it. The EVAL_REGEX command may be suffixed with a label or path in parenthesis and must be followed by a colon. A label might make organizing various kinds of changes easier, while a file path makes the EVAL_REGEX effective on only a single file. If an EVAL_REGEX has no regular expression, all previous EVAL_REGEX commands sharing the same label are canceled.<br />Examples:<br />`EVAL_REGEX: s/^search/replace/gm`<br />`EVAL_REGEX(myfix): s/^search/replace/gm`<br />`EVAL_REGEX(./sfm/file/path.sfm): s/^search/replace/gm`
**RUN** | Causes an SFM file to be converted and appended to the module's OSIS file. Each RUN must be followed by a colon and the file path of an SFM file to convert. RUN can be used more than once on the same file. IMPORTANT: Bible books are normally re-ordered according to the project's versification system. To maintain RUN Bible book order, `CustomBookOrder` must be set to true in `config.conf`.


### VSYS INSTRUCTIONS 
The other purpose of the `CF_sfm2osis.txt` file for Bibles and commentaries is to describe deviations from the versification standard. These deviations should be recorded so references from external documents may be properly resolved, and parallel rendering with other texts can be done. Each verse is identified according to the project's strictly defined versification. The commands to accomplish this begin with VSYS. Their proper use results in OSIS files containing both a rendering of the translator's custom versification and a rendering of the standard versification. OSIS files can then be rendered in either scheme using the corresponding XSLT stylesheet.

VSYS instructions are evaluated in verse system order regardless of their order in the control file. A verse may be affected by multiple VSYS instructions. VSYS operations on entire chapters are not supported except for VSYS_EXTRA chapters at the end of a book (such as Psalm 151 of Synodal).

COMMAND | DESCRIPTION
------- | -----------
**VSYS_MOVED** | Used when translators moved a range of verses from the expected location within the project's versification scheme to another location. This instruction can have several forms:<br />`VSYS_MOVED: Rom.14.24.26 -> Rom.16.25.27`<br />Indicates the range of verses given on the left was moved from its expected location to a custom location given on the right. Rom.16.25.27 is Romans 16:25-27. Both ranges must cover the same number of verses. Either or both ranges may end with the keyword `PART` in place of the range's last verse, indicating only part of the verse was moved. References to affected verses will be tagged so as to render correctly in both standard and custom versification schemes. When verses are moved within the same book, the verses will be fit into the standard verse scheme. When verses are moved from one book to another, the effected verses will be recorded in both places within the OSIS file, and depending on how the OSIS file is rendered, the verses will appear in one location or the other.<br />`VSYS_MOVED: Tob -> Apocrypha[Tob]`<br />Indicates the entire book on the left was moved from its expected location to a custom book-group[book] given on the right. See `./bin/convert -h OSIS_GROUPS` for supported book-groups and `./bin/convert -h OSIS_ABBR_ALL` for supported books. An index number may be used on the right side in place of the book name. The book will be recorded in both places within the OSIS file, and depending on how the OSIS file is rendered, the book will appear in one location or the other.<br />`VSYS_MOVED: Apocrypha -> bookGroup[2]`<br />Indicates the entire book-group on the left was moved from its expected location to a custom book-group index on the right. See `./bin/convert -h OSIS_GROUPS` for supported book-groups. The book-group will be recorded in both places within the OSIS file, and depending on how the OSIS file is rendered, the book-group will appear in one location or the other.
**VSYS_MISSING** | Specifies that this translation does not include a range of verses of the standard versification scheme. This instruction takes the form:<br />`VSYS_MISSING: Josh.24.34.36`<br />Meaning that Joshua 24:34-36 of the standard versification scheme has not been included in the custom scheme. When the OSIS file is rendered as the standard versification scheme, the preceeding verse's osisID will be modified to include the missing range. But any externally supplied cross-references that refer to the missing verses will be removed. If there are verses in the chapter having the verse numbers of the missing verses, then the standard versification rendering will renumber them and any following verses upward by the number of missing verses, and alternate verse numbers will be appended to display the original verse numbers. References to affected verses will be tagged so as to render them correctly in either standard or custom versification schemes. An entire missing chapter is not supported unless it is the last chapter in the book.
**VSYS_EXTRA** | Used when translators inserted a range of verses that are not part of the project's versification scheme. This instruction takes the form:<br />`VSYS_EXTRA: Prov.18.8 <- Synodal:Prov.18.8`<br />The left side is a verse range specifying the extra verses in the custom verse scheme, and the right side range is a universal address for those extra verses. The universal address is used to record where the extra verses originated from. When the OSIS file is rendered in the standard versification scheme, the additional verses will become alternate verses appended to the preceding verse, and if there are verses following the extra verses, they will be renumbered downward by the number of extra verses, and alternate verse numbers will be appended displaying the custom verse numbers. References to affected verses will be tagged so as to render correctly in either the standard or custom versification scheme. The extra verse range may be an entire chapter if it occurs at the end of a book (such as Psalm 151). When rendered in the standard versification scheme, an alternate chapter number will then be inserted and the entire extra chapter will be appended to the last verse of the previous chapter.
**VSYS_EMPTY** | Like `VSYS_MISSING`, but is only to be used if regular empty verse markers are included in the text. This instruction will only remove external scripture cross-references to the removed verses.
**VSYS_MOVED_ALT** | Like `VSYS_MOVED` but this should be used when alternate verse markup like `\va 2\va*` has been used by the translators for the verse numbers of the moved verses (rather than regular verse markers which is the more common case). If both regular verse markers (showing the source system verse number) and alternate verse numbers (showing the fixed system verse numbers) have been used, then `VSYS_MOVED` should be used. This instruction will not change the OSIS markup of alternate verses.
**VSYS_MISSING_FN** | Like `VSYS_MISSING` but is only to be used if a footnote was included in the verse before the missing verses which gives the reason for the verses being missing. This instruction will simply link the verse having the footnote together with the missing verse.
**VSYS_CHAPTER_SPLIT_AT** | Used when the translators split a chapter of the project's versification scheme into two chapters. This instruction takes the form:<br />`VSYS_CHAPTER_SPLIT_AT: Joel.2.28`<br />When the OSIS file is rendered as the standard versification scheme, verses from the split onward will be appended to the end of the previous verse and given alternate chapter:verse designations. Verses of any following chapters will also be given alternate chapter:verse designations. References to affected verses will be tagged so as to be correct in both the standard and the custom versification scheme.
**VSYS_FROM_TO** | This is usually not the right instruction to use; it is used internally as part of other instructions. It does not affect any verse or alternate verse markup. It could be used if a verse is marked in the text but is left empty, while there is a footnote about it in the previous verse (but see `VSYS_MISSING_FN` which is the more common case).


## CF_vsys.xml 

### ADDING EXTERNAL CROSS-REFERENCES 
A strictly defined address is assigned to each verse, making it is possible to incorporate a list of cross-references into the translation. These cross-references, although not part of the original translation, can be an excellent Bible study tool. The cross-reference list must belong to the same versification system as the project. The list must be placed in `AddCrossRefs / CF_<vsys>.xml` within a `defaults` directory (see `./bin/convert -h defaults`). `<vsys>` is the project's versification system (options are: `KJV`, `German`, `KJVA`, `Synodal`, `Leningrad`, `NRSVA`, `Luther`, `Vulg`, `SynodalProt`, `Orthodox`, `LXX`, `NRSV`, `MT`, `Catholic`, `Catholic2`). These verse systems are defined in `canon_<vsys>.h` of [SWORD](https://crosswire.org/svn/sword/trunk/include/). Verse maps between these verse systems are defined in `<vsys>.properties` of [JSWORD](https://github.com/crosswire/jsword/tree/master/src/main/resources/org/crosswire/jsword/versification)

Cross-references in the list are localized and inserted into the appropriate verses as OSIS notes. Two note types are supported: parallel-passage, and cross-reference. Parallel-passage references are inserted at the beginning of a verse, and cross-references at the end.

The `CF_<vsys>.xml` file is an OSIS file with books, chapters and verses following the versification system; the only content required however are OSIS notes. Example OSIS notes:<br />`<note type="crossReference" osisRef="Gen.1.1" osisID="Gen.1.1!crossReference.r1">`<br />`<reference osisRef="Josh.14.15"/>`<br />`<reference osisRef="Judg.1.10"/>`<br />`<reference osisRef="Gen.13.18"/>`<br />`<reference osisRef="Gen.23.2"/>`<br />`</note>`<br />`<note type="crossReference" subType="x-parallel-passage" osisRef="Gen.1.1" osisID="Gen.1.1!crossReference.p1">`<br />`<reference osisRef="1Chr.1.35-1Chr.1.37" type="parallel"/>`<br />`</note>`


## CF_addScripRefLinks.txt 
Paratext publications typically contain localized scripture references found in cross-reference notes, footnotes, introductions and other reference material. These references are an invaluable study aid. However, they often are unable to function as hyperlinks until converted from localized textual references to standardized universal references. This control file tells the parser how to search the text for textual scripture references, and how to translate them into standardized hyperlinks.

Descriptions below may refer to extended references. An extended reference is a series of individual scripture references which together form a single sentence. An example of an extended reference is: See also Gen 4:4-6, verses 10-14 and chapter 6. The parser searches the text for extended references, and then parses each reference individually, in order, remembering the book and chapter context of the previous reference.

SETTING | DESCRIPTION
------- | -----------
**`<osis-abbreviation>`** | To assign a localized book name or abbreviation to the corresponding osis book abbreviation, use the following form:<br />`Gen = The book of Genesis`<br />The osis abbreviation on the left of the equal sign may appear on multiple lines. Each line assigns a localized name or abbreviation on the right to its osis abbreviation on the left. Names on the right are not Perl regular expressions, but they are case insensitive. Listed book names do not need to include any prefixes of `PREFIXES` or suffixes of `SUFFIXES` for the book names to be parsed correctly.
**CHAPTER_TERMS** | A Perl regular expression matching localized words/phrases which will be understood as meaning "chapter". Example:<br />`CHAPTER_TERMS:(psalm\|chap)`
**CHAPTER_TO_VERSE_TERMS** | A Perl regular expression matching characters that are used to separate the chapter from the verse in textual references. Example:<br />`CHAPTER_TO_VERSE_TERMS:(:)`
**COMMON_REF_TERMS** | A Perl regular expression matching phrases or characters which should be ignored within an extended textual reference. When an error is generated because an extended textual reference was incompletely parsed, parsing may have been terminated by a word or character which should instead be ignored. Adding it to COMMON_REF_TERMS may allow the textual reference to parse completely. Example:<br />`COMMON_REF_TERMS:(but not\|a\|b)`
**CONTEXT_BOOK** | Textual references do not always include the book being referred to. Then the target book must be discovered from the context of the reference. Where the automated context search fails to discover the correct book, the `CONTEXT_BOOK` setting should be used. It takes the following form:<br />`CONTEXT_BOOK: Gen if-xpath ancestor::osis:div[1]`<br />Where `Gen` is any osis book abbreviation, `if-xpath` is a required keyword, and what follows is any xpath expression. The xpath will be evaluated for each textual reference and if it evaluates as true then the given book will be used as the context book for that reference.
**CONTINUATION_TERMS** | A Perl regular expression matching characters that are used to indicate a chapter or verse range. Example:<br />`CONTINUATION_TERMS:(to\|-)`
**CURRENT_BOOK_TERMS** | A Perl regular expression matching localized words/phrases which will be understood as meaning "the current book". Example:<br />`CURRENT_BOOK_TERMS:(this book)`
**CURRENT_CHAPTER_TERMS** | A Perl regular expression matching localized words/phrases which will be understood as meaning "the current chapter". Example:<br />`CURRENT_CHAPTER_TERMS:(this chapter)`
**FIX** | If the parser fails to properly convert any particular textual reference, FIX can be used to correct or skip it. It has the following form:<br />`FIX: Gen.1.5 Linking: "7:1-8" = "<r Gen.7.1>7:1</r><r Gen.8>-8</r>"`<br />After FIX follows the line from the log file where the extended reference of concern was logged. Replace everything after the equal sign with a shorthand for the fix with the entire fix enclosed by double quotes. Or, remove everything after the equal sign to skip the extended reference entirely. The fix shorthand includes each reference enclosed in r tags with the correct osisID.
**ONLY_XPATH** | Similar to SKIP_XPATH but suspected textual references will be skipped unless the given xpath expression evaluates as true.
**PREFIXES** | A Perl regular expression matching characters or language prefixes that may appear before other terms, including book names, chapter and verse terms etc. These terms are treated as part of the word they prefix but are otherwise ignored. Example:<br />`PREFIXES:(\(\|")`
**REF_END_TERMS** | A Perl regular expression matching characters that are required to end an extended textual reference. Example:<br />`REF_END_TERMS:(\.\|")`
**SEPARATOR_TERMS** | A Perl regular expression matching words or characters that are to be understood as separating individual references within an extended reference. Example:<br />`SEPARATOR_TERMS:(also\|and\|or\|,)`
**SKIP_XPATH** | When a section or category of text should be skipped by the parser SKIP_XPATH can be used. It takes the following form:<br />`SKIP_XPATH: ancestor::osis:div[@type='introduction']`<br />The given xpath expression will be evaluated for every suspected textual scripture reference, and if it evaluates as true, it will be left alone.
**SUFFIXES** | A Perl regular expression matching characters or language suffixes that may appear after other terms, including book names, chapter and verse terms etc. These terms are treated as part of the word that precedes them but are otherwise ignored. Some languages have many grammatical suffixes and including them in SUFFIXES can improve the parsability of such langauges. Example:<br />`SUFFIXES:(\)\|s)`
**VERSE_TERMS** | A Perl regular expression matching localized words/phrases which will be understood as meaning "verse". Example:<br />`VERSE_TERMS:(verse)`
**WORK_PREFIX** | Sometimes textual references are to another work. For instance a Children's Bible may contain references to an actual Bible translation. To change the work to which references apply, the WORK_PREFIX setting should be used. It takes the following form:<br />`WORK_PREFIX: LEZ if-xpath //@osisIDWork='LEZCB'`<br />Where `LEZ` is any project code to be referenced, `if-xpath` is a required keyword, and what follows is any xpath expression. The xpath will be evaluated for each textual reference and if it evaluates as true then LEZ will be used as the work prefix for that reference.


## CF_addFootnoteLinks.txt 
When translators include study notes that reference other study notes, this command file can be used to parse references to footnotes and convert them into working hyperlinks. This conversion requires that CF_addScripRefLinks.txt is also performed.

SETTING | DESCRIPTION
------- | -----------
**COMMON_TERMS** | See CF_addScripRefLinks.txt
**CURRENT_VERSE_TERMS** | See CF_addScripRefLinks.txt
**FIX** | Used to fix a problematic reference. Each instance has the form:<br />`LOCATION='book.ch.vs' AT='ref-text' and REPLACEMENT='exact-replacement'`<br />Where `LOCATION` is the context of the fix, AT is the text to be fixed, and `REPLACEMENT` is the fix. If `REPLACEMENT` is 'SKIP', there will be no footnote reference link.
**FOOTNOTE_TERMS** | A Perl regular expression matching terms that are to be converted into footnote links.
**ONLY_XPATH** | See CF_addScripRefLinks.txt
**ORDINAL_TERMS** | A list of ordinal:term pairs where ordinal is `( \d \| prev \| next \| last )` and term is a localization of that ordinal to be searched for in the text. Example:<br />`ORDINAL_TERMS:(1:first\|2:second\|prev:preceding)`
**SKIP_XPATH** | See CF_addScripRefLinks.txt
**STOP_REFERENCE** | A Perl regular expression matching where scripture references stop and footnote references begin. This is only needed if an error is generated because the parser cannot find the transition. For instance: 'See verses 16:1-5 and 16:14 footnotes' might require the regular expression: `verses[\s\d:-]+and` to delineate between the scripture and footnote references.
**SUFFIXES** | See CF_addScripRefLinks.txt


## CF_addDictLinks.xml 
Many Bible translations are accompanied by reference materials, such as glossaries, maps and tables. Hyperlinks to this material, and between these materials, are helpful study aids. Translators may mark the words or phrases which reference a particular glossary entry or map. But often only the location of a reference is marked, while the exact target (the lemma) of the reference is not. Sometimes no references are marked, even though they exist throughout the translation. This command file's purpose is to convert all these kinds of textual references into strictly standardized working hyperlinks.

Glossary references marked by translators are called explicit references. If the target of an explicit reference cannot be determined, a conversion error is logged. USFM 3 explicit references may include their target lemma in the `lemma` attribute value. If there are multiple sub-publications which share the same lemma in their glossaries, disambiguation may still be required, however. Two additional `\w` tag attributes may be used for disambiguation: `x-context` to specify the context of the target glossary (usually a scope value), and `x-dup` to specify the number of the duplicate lemma as it appears in CF_addDictLinks.xml.

Marked and unmarked references are parsed from the text using the match elements of the CF_addDictLinks.xml file. Element attributes in this XML file are used to control where and how the match elements are to be used. Letters in parentheses indicate the following attribute value types:

(A): value is the accumulation of the element's own value and any ancestor element values. But a positive attribute (one whose name doesn't begin with 'not') will cancel any negative attribute ancestors.

(B): true or false

(C): one or more space separated osisRef values OR one or more comma separated Paratext references.

(R): one or more space separated osisRef values

(X): xpath expression


ATTRIBUTE | DESCRIPTION
--------- | -----------
**XPATH (AX)** | The `match` element will only be applied to text nodes for which this xpath value evaluates as true.
**context (AC)** | The `match` element will only be applied to text nodes included in this context value.
**dontLink (B)** | If `true`, then the `match` element will instead undo reference links, rather than create them.
**multiple (B)** | If the value is `false`, only the first match candidate for an entry will be linked per chapter or keyword. If `match`, the first match candidate per match element may be linked per chapter or keyword. If `true`, there are no such limitations.
**noOutboundLinks (B)** | This attribute is only allowed on `entry` elements. It prohibits the parser from parsing the entry's own glossary text for links. Thus there may be reference links to the entry, but the entry text itself will not be parsed for outgoing links to anything else.
**notContext (AC)** | The `match` element will not be applied to text nodes included in this context value.
**notExplicit (BC)** | If the value is `true` (or else contains a context matching the text node) the `match` element will not be applied to explicitly marked references.
**notXPATH (AX)** | The `match` element will not be applied to text nodes for which this xpath value evaluates as true.
**onlyExplicit (BC)** | If the value is `true` (or else contains a context matching the text node) the `match` element will only be applied to explicitly marked references.
**onlyNewTestament (B)** | If `true`, the `match` element will only be applied to text nodes in the New Testament.
**onlyOldTestament (B)** | If `true`, the `match` element will only be applied to text nodes in the Old Testament.
**osisRef (R)** | This attribute is only allowed on `entry` elements and is required. It contains a space separated list of work prefixed osisRef values which are the target(s) of the entry's child `match` elements.

ELEMENT | DESCRIPTION
------- | -----------
**addDictLinks** | The root element.
**div** | Used to organize groups of entries
**entry** | Text matching any child match element will be linked with the osisRef attribute value.
**name** | The name of the parent entry.
**match** | Contains a Perl regular expression used to search text for links to the parent entry. For a match element to create a link, its attributes and those of its ancestor elements must be properly satisfied.

NOTE: For case insensitive matches to work, all match text must be surrounded by the `\Q...\E` quote operators. If a match is failing, consider this first. This is not a normal Perl rule, but is required because Perl doesn't properly handle case for some languages. Match patterns can be any Perl regex, but only the `i` flag is supported. The last matching parenthetical group will become the text of the link, unless there is a group named `link` (using Perl's `?'link'` notation) in which case that group will become the text of the link.


# osis2osis 

## SYNOPSIS 
When a translation is to be converted into multiple scripts, osis2osis can be used to simplify the work of conversion. The osis2osis program is flexible and controlled by CF_osis2osis.txt. Source script SFM may be converted using sfm2osis, then the resulting OSIS file and the source script's `config.conf` may be converted directly to the other scripts using osis2osis.

The osis2osis script can also be used to convert all control files from one script to another, allowing sfm2osis to subsequently create the OSIS file. This is useful when translators provide multiple sets of source files of different scripts, so that only control files need to be converted from one script to another.


## CF_osis2osis.txt 
The following settings are supported:

SETTING | DESCRIPTION
------- | -----------
**SourceProject** | A required entry specifying the source project to convert from.
**CC** | Convert control and project files using the previously selected MODE. The path is relative to the source project and should not begin with `.` or `/`. The keyword `DICTMOD` can be used in place of the dictionary subdirectory. Example: `CC: DICTMOD/images/*`
**CCOSIS** | Convert an OSIS file using the previously selected MODE. Examples: `CCOSIS: <code>` or `CCOSIS: <code>DICT`
**Mode[copy]** | Copy the listed file or file glob from the source project to the current project. Files could be images, css, etc. Paths are relative to their project main directory.
**Mode[script]** | Use the given script to do the conversion. The script path is relative to the project directory. The script needs to take two arguments: input-file and output-file
**Mode[transcode]** | Use the function `transcode(<string>)` defined in the Perl script whose path is given. Example: `SET_MODE_Transcode: script.pl`
**Mode[cctable]** | Use a CC table to do the conversion. CC tables are no longer supported by SIL. Use SET_MODE_Script instead.
**Config\[.+\]** | Set the value of a config entry. The `config.conf` file itself should be converted using `CC: config.conf`. An entry for a particular section can be set using `SET_Config[<section>+<entry>]: <value>`
**SkipNodesMatching** | Don't convert the text of nodes selected by an xpath expression.
**SkipStringsMatching** | Don't convert the text of strings matching a Perl regular expression.


# osis2ebooks 

## SYNOPSIS 
Create epub and azw3 eBooks from OSIS files. Once Paratext SFM files have been converted to OSIS XML, eBooks can be created from the OSIS sources. Both the MAINMOD and DICTMOD OSIS files are integrated into an eBook publication. If there are sub-publications as part of the translation, eBooks for each of these will also be created. Optionally a separate eBook for each Bible book may be created.

The following `config.conf` entries control eBook production:

ENTRY | DESCRIPTION
----- | -----------
**MakeTypes** | Select which type, or types, of publications to make: `(AUTO \| azw3 \| epub)`. Default is `AUTO`.
**MakeSet[tran]** | Select whether to create a single ePublication containing everything in the OSIS file: `(true \| false \| AUTO)`.
**MakeSet[subpub]** | Select whether to create separate outputs for individual sub-publications within the OSIS file: `(true \| false \| AUTO \| <scope> \| first \| last)`.
**MakeSet[book]** | Select whether to create separate ePublications for individual Bible books within the OSIS file: `(true \| false \| AUTO \| <OSIS-book> \| first \| last)`.


# osis2html 

## SYNOPSIS 
Create HTML from OSIS files. Once Paratext SFM files have been converted to OSIS XML, HTML can be created from the OSIS sources. Both the MAINMOD and DICTMOD OSIS files are integrated together with a table-of-contents and comprehensive navigational links.


# osis2sword 

## SYNOPSIS 
Create CrossWire SWORD modules from OSIS files. Once Paratext files have been converted to OSIS XML, CrossWire SWORD modules may be created. A Bible, GenBook or Commentary SWORD module will be generated from the MAINMOD OSIS file. If there is a DICTMOD OSIS file it will be converted to a dictionary SWORD module. The two SWORD modules will be integrated together by a table-of-contents, glossary and navigational links that will appear in each Bible book introduction and dictionary keyword.


# osis2gobible 

## SYNOPSIS 
Create Java-ME JAR apps from OSIS files. Once Paratext files have been converted to OSIS XML, osis2gobible utilizes Go Bible Creator to produce these apps for feature phones.

Default control files will be copied from a `defaults` directory (see `./bin/convert -h defaults`). This includes the Go Bible Creator user interface localization file and the app icon. These files may be customized per project, or customized for a group of projects, depending on which `defaults` directory is used.

Jar files whose file name contains a number are maximum 512kb in size, for phones with Jar size limitations. Jar files ending with `_s` have simplified character sets, for phones with character limitations. Character set transliteration for simplified and normal GoBible character sets is controlled by these `defaults` files: `gobible / <type>Char.txt` where `<type>` is `simple` or `normal`.


# CrossWire 

## Non-standard config.conf entries 
The following are SWORD `config.conf` entries which are not part of the CrossWire standard.

ENRTY | DESCRIPTION
----- | -----------
**AudioCode** | A publication code for associated audio. Multiple modules having different scripts may reference the same audio.
**KeySort** | This entry enables localized list sorting by character collation. Square brackets are used to separate any arbitrary case sensitive regular expressions which are to be treated as single characters during the sort comparison. Also, a single set of curly brackets can be used around a regular expression which matches any characters/patterns that need to be ignored during the sort comparison. IMPORTANT: Any square or curly bracket within regular expressions must have an additional backslash before it. NOTE: The regular expression processor currently in use does not support look-around assertions.
**Scope** | A 'scope' is a specific way of listing the contents of Bible publications. It is generally a space separated list of OSIS book abbreviations in verse system order (see `./bin/convert -h OSIS_ABBR`). When used in directory names, file names or config.conf entry names, spaces should be replaced by underscores. Example: `Ruth_Esth_Jonah`. Continuous ranges of more than two books are shortened using '-'. Example: `Matt-Rev`.

