<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT takes an OSIS file which was fitted to a SWORD standard 
  verse system by fitToVerseSystem() and removes any source verse system 
  markup so the resulting OSIS file only contains the fitted verse system !-->
  
  <import href="./whitespace.xsl"/>
  
  <template match="/">
    <variable name="fitted"><call-template name="osis2fittedVerseSystem.xsl"/></variable>
    <variable name="whitespace"><apply-templates mode="whitespace.xsl" select="$fitted"/></variable>
    <sequence select="$whitespace"/>
  </template>
  
  <template mode="osis2fittedVerseSystem.xsl" match="/" name="osis2fittedVerseSystem.xsl">
    <message>NOTE: Running osis2fittedVerseSystem.xsl</message>
    <apply-templates mode="fitted" select="."/>
  </template>
  
  <!-- By default copy everything as is -->
  <template mode="fitted" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <!-- Remove these tags -->
  <template mode="fitted" match="div[@resp = 'x-vsys-moved'][@annotateType='x-vsys-moved']" priority="1">
    <apply-templates mode="#current"/>
  </template>
  
  <!-- Remove these elements -->
  <template mode="fitted" match="milestone[@resp = 'x-vsys'] |
      *[@resp = 'x-vsys-moved'] |
      milestone[matches(@type,'^x\-vsys\-(.*?)\-(start|end)$')]"/>
  
  <!-- Remove these attributes -->
  <template mode="fitted" match="@annotateType[. = ('x-vsys-source', 'x-vsys-moved')] |
                   @annotateRef[parent::*[@annotateType = ('x-vsys-source', 'x-vsys-moved')]] | 
                   @resp[. = 'x-vsys']"/>
  
  <!-- Remove verse numbers that are redundant in the fitted verse system -->
  <template mode="fitted" match="hi[starts-with(@subType, 'x-alternate-')]"/>
  
</stylesheet>
