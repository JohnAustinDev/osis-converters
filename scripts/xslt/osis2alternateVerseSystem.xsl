<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <import href="./functions.xsl"/>
  
  <!-- By default copy everything as is, for all modes -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <!-- Convert x-alt-verse-system milestone back to verse -->
  <template match="milestone[@annotateType='x-alt-verse-system']" priority="2">
    <element name="verse" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
      <if test="@type='x-alt-verse-start'">
        <attribute name="osisID" select="@annotateRef"/>
        <attribute name="sID" select="@annotateRef"/>
      </if>
      <if test="@type='x-alt-verse-end'">
        <attribute name="eID" select="@annotateRef"/>
      </if>
    </element>
  </template>
  
  <!-- Convert osisRef back to source verse system -->
  <template match="*[@annotateType='x-alt-verse-system'][@annotateRef]">
    <copy>
      <attribute name="osisRef" select="@annotateRef"/>
      <apply-templates select="node()|@*[not(name()=('osisRef', 'annotateRef', 'annotateType'))]"/>
    </copy>
  </template>
  
  <!-- Remove added x-targ-verse-system verse tags and associated alternate verse numbers-->
  <template match="verse[@type='x-targ-verse-system']"/>
  <template match="hi[@subType='x-alternate']">
    <if test="generate-id() != generate-id(
      preceding::milestone[@annotateType='x-alt-verse-system'][1]/
      following::text()[normalize-space()][not(ancestor::hi[@subType='x-alternate'])][1]/
      preceding-sibling::*[1])">
      <call-template name="identity"/>
    </if>
  </template>

</stylesheet>
