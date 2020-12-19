<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT takes an OSIS file which was fitted to a SWORD standard 
  verse system by fitToVerseSystem() and reverts it back to its custom 
  source verse system. All references that were retargeted are reverted 
  (including cross-references from external sources) so that the result-
  ing OSIS file's references are correct according to the custom verse 
  system. Also, markup associated with the fixed verse system is removed, 
  leaving only the source verse system markup. !-->
  
  <import href="./whitespace.xsl"/>
  
  <template match="/">
    <variable name="source"><call-template name="osis2sourceVerseSystem.xsl"/></variable>
    <variable name="whitespace"><apply-templates mode="whitespace.xsl" select="$source"/></variable>
    <sequence select="$whitespace"/>
  </template>
  
  <template mode="osis2sourceVerseSystem.xsl" match="/" name="osis2sourceVerseSystem.xsl">
    <message>NOTE: Running osis2sourceVerseSystem.xsl</message>
    <apply-templates mode="source" select="."/>
  </template>
  
  <!-- By default copy everything as is -->
  <template mode="source" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <!-- Move the content of x-vsys-moved divs to their source locations -->
  <template mode="source" match="div[@annotateType = 'x-vsys-moved']" priority="2"/>
  <template mode="source" match="div[@type = 'x-vsys-moved']"  priority="2">
    <for-each select="//div[@annotateType = 'x-vsys-moved'][@annotateRef = current()/@osisID]">
      <choose>
        <when test="@resp = 'x-vsys-moved'"><apply-templates mode="#current"/></when>
        <otherwise><copy><apply-templates mode="#current" select="node()|@*"/></copy></otherwise>
      </choose>
    </for-each>
  </template>
  
  <!-- Revert chapter/verse milestones to their original source elements -->
  <template mode="source" match="milestone[matches(@type,'^x\-vsys\-(.*?)\-(start|end)$')]" priority="1">
    <variable name="elem" select="replace(@type, '^x\-vsys\-(.*?)\-(start|end)$', '$1')"/>
    <element name="{$elem}" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
      <apply-templates mode="#current" select="@*[not(name() = 'type')]"/>
      <if test="ends-with(@type, '-start')">
        <attribute name="osisID" select="@annotateRef"/>
        <attribute name="sID" select="@annotateRef"/>
      </if>
      <if test="ends-with(@type, '-end')">
        <attribute name="eID" select="@annotateRef"/>
      </if>
    </element>
  </template>
  
  <!-- Remove these elements (includes x-vsys alternate verses) -->
  <template mode="source" match="*[@resp = 'x-vsys']"/>
  
  <!-- Revert osisRef values to their original source values -->
  <template mode="source" match="@osisRef[parent::*[@annotateType = 'x-vsys-source']]">
    <attribute name="osisRef" select="parent::*/@annotateRef"/>
  </template>

  <!-- Remove these attributes -->
  <template mode="source" match="@annotateType[. = ('x-vsys-source', 'x-vsys-moved')] |
      @annotateRef[parent::*[@annotateType = ('x-vsys-source', 'x-vsys-moved')]]"/>

</stylesheet>
