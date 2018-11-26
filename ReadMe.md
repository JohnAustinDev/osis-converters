# osis-converters
Converts [USFM](http://paratext.org/about/usfm#usfmDocumentation) to 
[OSIS](http://www.crosswire.org/osis/), 
[SWORD](http://www.crosswire.org/wiki/Main_Page) modules, 
[GoBible](http://www.crosswire.org/wiki/Projects:Go_Bible) Java-ME apps, 
html, EPUB, MOBI, and FB2 files.

## use:
Place [USFM](http://paratext.org/about/usfm#usfmDocumentation) files in 
a directory: `/some-path/MODULE_NAME/sfm/`

At a Linux or Git Bash prompt:

    osis-converters$ ./sfm2all.pl /some-path/MODULE_NAME

Which will output:
* A SWORD Bible module (from all USFM Bible book files)
* A SWORD Glossary module (if there are USFM glossary files).
* An HTML Bible and glossary (if there are USFM glossary files)
* GoBible Java-ME apps.
* EPUB, FB2, and MOBI eBook Bibles.
* Comprehensive OSIS files with glossary, parsed Scripture references, 
and cross-reference links.
* Default control files, which can be fine tuned as needed/desired.
* A descriptive log file with helpful hints and suggestions.


# osis-converters output files
By default, all files created by osis-converters are put in a directory called 'output'. This directory contains all the electronic media files and log files (and temporary files) created by osis-converters. Inside the output directory you will find some or all of the following files:

**MOD.xml** (where MOD will be the module name) - This is the OSIS file (OSIS being a flavor of XML). This is the single most important output file. It is the source file for all other media files. The OSIS file is intended to provide the easiest and most reliable conversion to any other electronic format. USFM files cannot be directly converted into some electronic formats (due to verse system requirements), and other formats would be partially functional (due to lack of hyperlink and container information), or there would be unnecessary errors (because of loose validation) and in any case the USFM specifications are Byzantine and difficult to work with. So the OSIS file is very useful.

**OUT_sfm2all_MOD.txt** (where MOD will be the module name) - All files that begin with 'OUT_' are output log files. Each osis-converters script produces its own log file telling you everything about the conversion process (however the 'sfm2all' script simply calls each osis-converters script in proper order, so this particular log file is almost empty). You MUST read through every log file carefully. Inside a log file you might discover lines that begin with the following labels:
* ERROR: - These are problems that you MUST fix. There should be a description of how to fix each error. Any errors in the sfm2osis log should be fixed before trying to fix errors in any other log file! Start by fixing the FIRST error listed in the file. You will find that fixing the first error in the file will often fix other errors that follow it. But, if you start by trying to fix the second error, or later errors, you may truly be wasting your time! So you would do well to forget about the second error until after you have fixed the first one. So after doing what the first error message said to fix the problem, re-run only the particular script which produced the log file (do NOT run sfm2all.pl again which will only waste more of your precious time). Look to see that the error has disappeared and then attack the new first error in the file, repeating this until there are no errors left.
* WARNING: - These are possible problems, but you must read and understand each warning message so that you can decide whether it is OK as is, or whether you should do something to remove the warning.
* NOTE: - These are for your information, just so you know what osis-converters is doing at that time. They help in debugging and fixing errors.
* REPORT: - Reports certain conversion results in a way that helps you see the big picture and helps you see how things may have changed compared to a previous run.

**sword/** and **MOD.zip** (where MOD will be the module name) - This is the Crosswire SWORD module. It can be used with any SWORD compatible program or device.

**eBook/** - EPUBs and other eBooks

**html/** - HTML files

**GoBible/** - GoBible Java-ME apps for old style feature phones

**tmp/** - Temporary and debugging files created during the conversion process. These files can be extremely useful when trying to fix errors.

-----

# Crosswire OSIS format
The intention is to follow the [OSIS specification and handbook](https://www.crosswire.org/osis/) as closely as possible as well as [Crosswire best practice](http://wiki.crosswire.org/OSIS_Tutorial). Although there are a few minor deviations:

## Comparison of .conf files to CrossWire .conf

These xulsword specific .conf file entries may be inluded:

* `LangSortOrder = AaBbCcDdEe...` Is used by xulsword to sort the keys of
a dictionary/glossary in original alphabetical order.
* `AudioCode = SOMECODE` Sometimes multiple modules will use the same 
audio files, such as when a translation has multiple modules with 
different scripts. This allows all these modules to reference the same 
audio files.

## Comparison of OSIS files to CrossWire OSIS

Osis-converters utilizes CrossWire's [usfm2osis.py](https://github.com/refdoc/Module-tools) script for the
initial USFM to OSIS conversion (when possible). Additionally, the OSIS 
subType attribute is used to pass optional CSS classes to front-ends. 
Optional CSS classes supported by [xulsword](https://github.com/JohnAustinDev/xulsword) are:

* x-p-first (for drop-caps)
* x-text-image (for images embedded in text)
* x-parallel-passage (for parallel passages cross references)
* x-ref-cb (for reference title links found in Children's Bibles) 

## Deprecated (no longer output by osis-converters)

* `TabLabel` conf entry was replaced by the standard entry: `Abbreviation`.
* `GlobalOptionFilter = OSISDictionary` was replaced by the standard 
`OSISReferenceLinks` filter.
* Tags like `<div type="x-Synodal-non-canonical">` are no longer used 
since non-canonical material is completely left out of all OSIS files 
to facilitate simpler and quicker runtime detection of v11n coverage.
* `DictionaryModule = <DictModName>` has been replaced by the standard
`Companion` config entry.
* `ReferenceBible = <BibleModName>` was used by xulsword to prefer the 
listed Bible module when showing Scripture reference previews found in 
the module. Now, the reference Bible is included within each 
reference's osisRef, like this: `osisRef="MyRefBible:Matt.1.1"`.
* IMP format is no longer used. Osis-converters now generates TEI dictionaries according to CrossWire's
recommendations. CrossWire encourages 
the use of [TEI P5](http://www.crosswire.org/wiki/TEI_Dictionaries) for 
dictionary markup.


