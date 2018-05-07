<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT takes an OSIS Bible file which has been fitted to a SWORD standard verse  
  system by fitToVerseSystem() and reverts it back to its custom verse system. All
  references are also reverted (including externally added cross-references) so that
  the resulting OSIS file's references are correct according to the custom verse system !-->
 
  <import href="./functions.xsl"/>
  
  <!-- By default copy everything as is -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <!-- Remove some x-vsys tags that were added by fitToVerseSystem() -->
  <template match="verse[@type='x-vsys-fitted']"/>
  <template match="hi[@subType='x-alternate']">
    <!-- Remove only <hi> that were added by fitToVerseSystem() !-->
    <if test="generate-id() != generate-id(
      preceding::milestone[@annotateType='x-vsys-fitted'][1]/
      following::text()[normalize-space()][not(ancestor::hi[@subType='x-alternate'])][1]/
      preceding-sibling::*[1])">
      <call-template name="identity"/>
    </if>
  </template>
  
  <!-- Revert saved x-vsys tags to what they were before fitToVerseSystem() -->
  <template match="milestone[starts-with(@type, 'x-vsys')][ends-with(@type, '-start') or ends-with(@type, '-end')]" priority="2">
    <variable name="elemName" select="replace(@type, '^x\-vsys\-(.*?)\-(start|end)$', '$1')"/>
    <element name="{$elemName}" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
      <if test="ends-with(@type, '-start')">
        <attribute name="osisID" select="@annotateRef"/>
        <attribute name="sID" select="@annotateRef"/>
      </if>
      <if test="ends-with(@type, '-end')">
        <attribute name="eID" select="@annotateRef"/>
      </if>
    </element>
  </template>
  
  <!-- Convert osisRefs to the source verse system -->
  <template match="*[@annotateType='x-vsys-source'][@annotateRef]">
    <copy>
      <attribute name="osisRef" select="@annotateRef"/>
      <attribute name="annotateRef" select="@osisRef"/>
      <attribute name="annotateType" select="'x-vsys-fixed'"/>
      <apply-templates select="node()|@*[not(name()=('osisRef', 'annotateRef', 'annotateType'))]"/>
    </copy>
  </template>

</stylesheet>
