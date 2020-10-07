<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT takes an OSIS file which may have been fitted to a 
  SWORD standard verse system by fitToVerseSystem() and reverts it back 
  to its custom verse system. Also all references that were retargeted 
  are reverted (including cross-references from external sources) so 
  that the resulting OSIS file's references are correct according to the 
  custom verse system. Also, markup associated with the fixed verse 
  system is removed, leaving only the source verse system markup. !-->
  
  <!-- By default copy everything as is -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <!-- Revert chapter/verse milestones to their original source elements -->
  <template match="milestone[matches(@type,'^x\-vsys\-(.*?)\-(start|end)$')]" priority="50">
    <variable name="elem" select="replace(@type, '^x\-vsys\-(.*?)\-(start|end)$', '$1')"/>
    <element name="{$elem}" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
      <apply-templates select="@*[not(name() = 'type')]"/>
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
  <template match="*[@resp = 'x-vsys']" priority="50"/>
  
  <!-- Revert osisRef values to their original source values -->
  <template match="@osisRef[parent::*[@annotateType = 'x-vsys-source']]" priority="50">
    <attribute name="osisRef" select="parent::*/@annotateRef"/>
  </template>

  <!-- Remove these attributes -->
  <template match="@annotateType[. = 'x-vsys-source'] |
                   @annotateRef[parent::*[@annotateType = 'x-vsys-source']]"
            priority="50"/>
                   
  <template match="/" priority="59">
    <message>NOTE: Running osis2sourceVerseSystem.xsl</message>
    <next-match/>
  </template>

</stylesheet>
