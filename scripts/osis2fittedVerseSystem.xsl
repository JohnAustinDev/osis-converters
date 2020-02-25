<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT takes an OSIS file which may have been fitted to a SWORD standard   
  verse system by fitToVerseSystem() and removes all source verse system markup so 
  that the resulting OSIS file only contains the fitted verse system !-->
  
  <!-- By default copy everything as is -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <!-- Remove all x-vsys milestones -->
  <template match="milestone[starts-with(@type, 'x-vsys')]" priority="5"/>
  
  <!-- Remove x-vsys-source annotateRefs -->
  <template match="@annotateRef[parent::*[@annotateType= 'x-vsys-source']]" priority="5"/>
  
  <!-- Remove all x-vsys attributes -->
  <template match="@*[starts-with(., 'x-vsys-')]" priority="5"/>
  
  <!-- Remove x-vsys resp attributes -->
  <template match="@resp['x-vsys']" priority="5"/>

</stylesheet>