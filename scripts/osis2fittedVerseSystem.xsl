<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT takes an OSIS file which may have been fitted to a 
  SWORD standard verse system by fitToVerseSystem() and removes any 
  source verse system markup so the resulting OSIS file only contains 
  the fitted verse system !-->
  
  <!-- By default copy everything as is -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <!-- Remove these elements -->
  <template match="milestone[@resp = 'x-vsys'] |
                   milestone[matches(@type,'^x\-vsys\-(.*?)\-(start|end)$')]"
            priority="50"/>
  
  <!-- Remove these attributes -->
  <template match="@annotateType[. = 'x-vsys-source'] |
                   @annotateRef[parent::*[@annotateType = 'x-vsys-source']] | 
                   @resp[. = 'x-vsys']"
            priority="50"/>
            
  <template match="/" priority="59">
    <message>NOTE: Running osis2fittedVerseSystem.xsl</message>
    <next-match/>
  </template>
  
</stylesheet>
