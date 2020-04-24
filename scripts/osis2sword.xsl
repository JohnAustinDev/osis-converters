<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- Prepare osis-converters OSIS for import using CrossWire tei2mod (after ModuleTools osis2sword.xsl) -->
  
  <!-- Filter out any marked elements which are not intended for this conversion -->
  <include href="./conversion.xsl"/>
  
  <!-- SWORD requires the fixed (or fitted) verse system rather than a customized one -->
  <include href="./osis2fittedVerseSystem.xsl"/>
  
  <variable name="isBible" select="/osis/osisText/header/work[@osisWork = /osis/osisText/@osisIDWork]/type[@type='x-bible']"/>
  
  <template match="/">
    <call-template name="Note"><with-param name="msg">Running osis2sword.xsl</with-param></call-template>
    <if test="$removedINT">
      <call-template name="Note">
<with-param name="msg">Removed <value-of select="count($removedINT)"/> Bible INT feature div(s).</with-param>
      </call-template>
    </if>
    <if test="$myTrimRef">
      <call-template name="Note">
<with-param name="msg">Trimmed <value-of select="count($myTrimRef)"/> multi-target references.</with-param>
      </call-template>
    </if>
    
    <copy>
      <variable name="pass1"><apply-templates select="node()"/></variable>
      <apply-templates select="$pass1" mode="dashes"/>
    </copy>
  </template>
  
  <!-- Shorten glossary osisRefs with multiple targets, since SWORD only handles a single target -->
  <template match="reference[starts-with(@type, 'x-gloss')][contains(@osisRef, ' ')]/@osisRef" priority="3">
    <attribute name="osisRef" select="replace(replace(., ' .*$', ''), '\.dup\d+$', '')"/>
  </template>
  
  <!-- SWORD uses the aggregated glossary, so forward dupicate entries to the aggregated entry -->
  <template match="reference[starts-with(@type, 'x-gloss')][matches(@osisRef, '\.dup\d+$')]/@osisRef" priority="2">
    <attribute name="osisRef" select="replace(., '\.dup\d+$', '')"/>
  </template>
  
  <!-- Remove duplicate glossary keywords (since the aggregated glossary is used) -->
  <template match="div[contains(@type, 'duplicate')][ancestor::div[@type='glossary']]"/>
  
  <!-- Remove duplicate material in Bibles that is also included in the dictionary module for the INT feature -->
  <variable name="removedINT" select="//div[$isBible][@annotateType='x-feature'][@annotateRef='INT']"/>
  <template match="div[. intersect $removedINT]"/>
  
  <!-- Remove chapter navmenus from Bibles (SWORD front-ends handle this functionality)-->
  <template match="list[$isBible][@subType='x-navmenu'][following-sibling::*[1][self::chapter[@eID]]]"/>
  
  <!-- Remove x-external attribute since SWORD handles them like any other reference -->
  <template match="reference[@subType='x-external']/@subType"/>
  
  <!-- Remove composite cover images from SWORD modules -->
  <template match="figure[@subType='x-comp-publication']"/>
  
  <!-- Remove empty titles/index etc, which break some front ends -->
  <template match="title[not(normalize-space(string()))] | index"/>
  
  <!-- Trim references that target removed Bible INT divs -->
  <variable name="myRemovedOsisIDs" as="xs:string" select="string-join(
    ($DICTMOD_DOC | $MAINMOD_DOC)/descendant::*[@osisID]
    [ancestor::div[$isBible][@annotateType='x-feature'][@annotateRef='INT']]/
    @osisID/concat(oc:myWork(.),':',replace(.,'^[^:]*:','')), ' ')"/>
  <variable name="myTrimRef" as="attribute(osisRef)*" 
      select="//reference[not(ancestor::*[starts-with(@subType,'x-navmenu')])]
              [tokenize(@osisRef, '\s+') = tokenize($myRemovedOsisIDs, '\s+')]/@osisRef"/>
  <template match="@osisRef[. intersect $myTrimRef]" priority="4">
    <attribute name="osisRef" 
      select="replace(replace(oc:trimOsisRef(., $myRemovedOsisIDs), ' .*$', ''), '\.dup\d+$', '')"/>
  </template>
  
  <!-- Prefix 2 dashes to $uiIntroduction keyword, or one dash to $uiDictionary, and update all 
  osisRefs to them. This puts these two keywords at the top of the SWORD DICT module. -->
  <variable name="reftext" select="for $i in ($REF_introductionINT, $REF_dictionary) 
                                   return oc:decodeOsisRef(tokenize($i, ':')[2])"/>
  <template mode="dashes" match="seg[@type='keyword'][normalize-space(text()) and text() = $reftext]">
    <variable name="text" select="concat(
      if (text() = oc:decodeOsisRef(tokenize($REF_introductionINT, ':')[2])) 
      then '--' else '-', 
      ' ', text())"/>
    <copy>
      <apply-templates mode="dashes" select="@*"/>
      <attribute name="osisID" select="oc:encodeOsisRef($text)"/>
      <value-of select="$text"/>
    </copy>
  </template>
  <template mode="dashes" match="@osisRef[. = ($REF_introductionINT, $REF_dictionary)]">
    <variable name="osisRef" as="attribute()">
      <attribute name="osisRef" select="concat( $DICTMOD, ':', 
        if (. = $REF_introductionINT) then '_45__45__32_' else '_45__32_', 
        tokenize(., ':')[2] )"/>
    </variable>
    <apply-templates mode="dashes" select="$osisRef"/>
  </template>

</stylesheet>
