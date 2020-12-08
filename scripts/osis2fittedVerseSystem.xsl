<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT takes an OSIS file which was fitted to a SWORD standard 
  verse system by fitToVerseSystem() and removes any source verse system 
  markup so the resulting OSIS file only contains the fitted verse system !-->
  
  <include href="./whitespace.xsl"/>
  
  <template match="/">
    <copy>
      <variable name="pass1"><apply-templates/></variable>
      <apply-templates mode="whitespace" select="$pass1/node()"/>
    </copy>
  </template>
  
  <!-- By default copy everything as is -->
  <template match="node()|@*">
    <copy><apply-templates select="node()|@*"/></copy>
  </template>
  
  <!-- Remove these tags -->
  <template match="div[@resp = 'x-vsys-moved'][@annotateType='x-vsys-moved']">
    <apply-templates select="node()|@*"/>
  </template>
  
  <!-- Remove these elements -->
  <template match="milestone[@resp = 'x-vsys'] |
                   *[@resp = 'x-vsys-moved'] |
                   milestone[matches(@type,'^x\-vsys\-(.*?)\-(start|end)$')]"
            priority="50"/>
  
  <!-- Remove these attributes -->
  <template match="@annotateType[. = ('x-vsys-source', 'x-vsys-moved')] |
                   @annotateRef[parent::*[@annotateType = ('x-vsys-source', 'x-vsys-moved')]] | 
                   @resp[. = 'x-vsys']"
            priority="50"/>
  
  <!-- Remove verse numbers that are redundant in the fitted verse system -->
  <template match="hi[starts-with(@subType, 'x-alternate-')]"/>
            
  <template match="/" priority="59">
    <message>NOTE: Running osis2fittedVerseSystem.xsl</message>
    <next-match/>
  </template>
  
</stylesheet>
