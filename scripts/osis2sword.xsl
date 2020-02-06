<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- Prepare osis-converters OSIS for import using CrossWire tei2mod (after ModuleTools osis2sword.xsl) -->
  
  <!-- Filter out any marked elements which are not intended for this conversion -->
  <include href="./conversion.xsl"/>
  
  <!-- SWORD requires the fixed (or fitted) verse system rather than a customized one -->
  <include href="./osis2fittedVerseSystem.xsl"/>
  
  <variable name="isBible" select="/osis/osisText/header/work[@osisWork = /osis/osisText/@osisIDWork]/type[@type='x-bible']"/>
  
  <!-- Shorten glossary osisRefs with multiple targets, since SWORD only handles a single target -->
  <template match="reference[starts-with(@type, 'x-gloss')][contains(@osisRef, ' ')]/@osisRef" priority="5">
    <attribute name="osisRef" select="replace(replace(., ' .*$', ''), '\.dup\d+$', '')"/>
  </template>
  
  <!-- SWORD uses the aggregated glossary, so forward dupicate entries to the aggregated entry -->
  <template match="reference[starts-with(@type, 'x-gloss')][matches(@osisRef, '\.dup\d+$')]/@osisRef" priority="3">
    <attribute name="osisRef" select="replace(., '\.dup\d+$', '')"/>
  </template>
  
  <!-- Remove duplicate glossary keywords (since the aggregated glossary is used) -->
  <template match="div[contains(@type, 'duplicate')][ancestor::div[@type='glossary']]"/>
  
  <!-- Remove duplicate material in Bibles that is also included in the dictionary module for the INT feature -->
  <template match="div[$isBible][@annotateType='x-feature'][@annotateRef='INT']"/>
  
  <!-- Remove chapter navmenus from Bibles (SWORD front-ends handle this functionality)-->
  <template match="list[$isBible][@subType='x-navmenu'][following-sibling::*[1][self::chapter[@eID]]]"/>
  
  <!-- Remove x-external attribute since SWORD handles them like any other reference -->
  <template match="reference[@subType='x-external']/@subType"/>
  
  <!-- Remove composite cover images from SWORD modules -->
  <template match="figure[@subType='x-comp-publication']"/>

</stylesheet>
