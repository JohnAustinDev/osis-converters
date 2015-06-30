##Installation and use
Linux: Run VagrantProvision.sh to install all dependencies.
Windows/OS X: Install [Vagrant](https://www.vagrantup.com/downloads.html), 
[VirtualBox](https://www.virtualbox.org/wiki/Downloads) and 
[Git with GitBash](https://git-scm.com/downloads)

Place [USFM](http://paratext.org/about/usfm#usfmDocumentation) files in 
this directory:
/some-path/MODULE_NAME/sfm/

In Git Bash or a Linux prompt, run:
./sfm2all.pl /some-path/MODULE_NAME

This will output:
* A SWORD Bible module (from all USFM Bible book files)
* A SWORD Glossary module (if there are USFM glossary files).
* GoBible Java-ME apps.
* EPUB, FB2, and MOBI eBook Bibles.
* Comprehensive OSIS files with glossary, parsed Scripture references, 
and cross-reference links.
* Default control files, which can be fine tuned as needed/desired.
* A descriptive log file with helpful hints and suggestions.

If the log file contains errors due to non-conformant SFM etc., control 
files will need adjustment until there are no errors. Warnings are 
generally okay. The log file should be read over carefully. It 
also essentially serves as osis-converters' documentation.

##Comparison of OSIS files to CrossWire OSIS

Osis-converters now utilizes CrossWire's usfm2osis.py script for the
initial USFM to OSIS conversion (when possible). Additionally, the OSIS 
subType attribute is used to pass optional CSS classes to front-ends. 
Optional CSS classes supported by xulsword are:

* x-p-first (for drop-caps)
* x-text-image (for images embedded in text)
* x-parallel-passage (for parallel passages cross references)
* x-ref-cb (for reference title links found in Children's Bibles) 

##Comparison of .conf files to CrossWire .conf

These xulsword specific .conf file entries may be inluded:

* `LangSortOrder = AaBbCcDdEe...` is used by xulsword to sort the keys of
a dictionary/glossary in original alphabetical order.

##Comparison of IMP files to CrossWire IMP

Osis-converters now generates TEI dictionaries according to CrossWire's
recommendations, so use of IMP is now deprecated. CrossWire encourages  
the use of [TEI P5](http://www.crosswire.org/wiki/TEI_Dictionaries) for 
dictionary markup.

##Deprecated (no longer output by osis-converters)

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
the module. Now, the reference Bible will is included within each 
reference's osisRef, like this: `osisRef="MyRefBible:Matt.1.1"`. The
standard `Companion` config entry is also set to the default reference 
Bible(s).
