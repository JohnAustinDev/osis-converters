##Comparison of OSIS files to CrossWire OSIS

Osis-converters now emulates the markup generated by CrossWire's 
usfm2osis.py. But additionally the OSIS subType attribute is used to 
pass optional CSS classes to front-ends. Optional CSS classes supported 
by xulsword are:

* x-p-first (for drop-caps)
* x-text-image (for images embedded in text)
* x-parallel-passage (for parallel passages cross references)
* x-ref-cb (for reference title links found in Children's Bibles) 

##Comparison of .conf files to CrossWire .conf

These scripts also add some xulsword specific .conf file entries:

* `DictionaryModule = <DictModName>` is used by xulsword to know to look for 
a companion dictionary. 

##Comparison of IMP files to CrossWire IMP

The IMP Dictionary/Glossary markup is done using OSIS tags. CrossWire 
encourages the use of TEI P5 for dictionary markup. Once xulsword and 
other front-ends fully support TEI, osis-converters may be modified to 
output TEI dictionaries. 

##Deprecated or no longer utilized

* `TabLabel` conf entry was replaced by the standard entry: `Abbreviation`.
* `GlobalOptionFilter = OSISDictionary` was replaced by the standard 
`OSISReferenceLinks` filter.
* Tags like `<div type="x-Synodal-non-canonical">` are no longer used 
since non-canonical material is completely left out of all OSIS files 
to facilitate simpler and quicker runtime detection of v11n coverage.
* `ReferenceBible = <BibleModName>` was used by xulsword to prefer the 
listed Bible module when showing Scripture reference previews found in 
the module. Soon, the reference Bible will be included within each 
reference's osisRef, like this: `osisRef="MyRefBible:Matt.1.1"`. So the 
.conf param `ReferenceBible` will be unnecessary and is deprecated. 

##A note about cross reference notes

The `<note type="crossReference">` tags added by addScripRefLinks.pl are 
inserted from a list of cross references. The cross references in this 
list have no presentational text, because they are used for many 
different languages. Although xulsword ignores presentational text 
within `<note type="crossReference">` tags (auto-generating it based 
on UI locale instead), some front-ends do rely on it. So the script adds 
presentational text as follows:

    <note type="crossReference" osisRef="Gen.1.1" osisID="Gen.1.1!crossReference.n1">
        <reference osisRef="Job.38.4-Job.38.7">1,</reference>
        <reference osisRef="Ps.32.6">2,</reference>
        <reference osisRef="Ps.135.5">3</reference>
    </note>
