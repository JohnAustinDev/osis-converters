<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- Prepare osis-converters OSIS for import using CrossWire tei2mod with ModuleTools osis2sword.xsl -->
  
  <!-- SWORD requires a fixed (or fitted) verse system rather than a customized one -->
  <import href="./osis2fittedVerseSystem.xsl"/>
  
  <variable name="isBible" select="/osis/osisText/header/work[@osisWork = /osis/osisText/@osisIDWork]/type[@type='x-bible']"/>
  
  <!-- Shorten glossary osisRefs containing multiple targets, since SWORD only handles one -->
  <template match="reference[starts-with(@type, 'x-gloss')][contains(@osisRef, ' ')]/@osisRef" priority="5">
    <attribute name="osisRef" select="replace(replace(., ' .*$', ''), '\.dup\d+$', '')"/>
  </template>
  
  <!-- SWORD uses the aggregated glossary, so forward dupicate entries to the aggregated entry -->
  <template match="reference[starts-with(@type, 'x-gloss')][matches(@osisRef, '\.dup\d+$')]/@osisRef" priority="3">
    <attribute name="osisRef" select="replace(., '\.dup\d+$', '')"/>
  </template>
  
  <!-- Remove duplicate glossary keywords -->
  <template match="div[contains(@type, 'duplicate')][ancestor::div[@type='glossary']]"/>
  
  <!-- Remove duplicate material in Bibles which is also included in the dictionary module -->
  <template match="div[@resp='duplicate']">
    <if test="not($isBible)"><copy><apply-templates select="node()|@*"/></copy></if>
  </template>
  
  <!-- Remove chapter navmenus from Bibles -->
  <template match="list[@subType='x-navmenu'][following-sibling::*[1][self::chapter[@eID]]]">
    <if test="not($isBible)"><copy><apply-templates select="node()|@*"/></copy></if>
  </template>
  
  <!-- Remove x-external attributes -->
  <template match="reference[@subType='x-external']/@subType"/>
  
  <!-- Remove composite cover images from SWORD modules -->
  <template match="figure[@subType='x-comp-publication']"/>

</stylesheet>
