<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- Prepare osis-converters OSIS for import using CrossWire tei2mod 
  (after running ModuleTools osis2sword.xsl) -->
  
  <!-- SWORD requires the fixed (or fitted) verse system rather than the 
  customized verse system -->
  <include href="./osis2fittedVerseSystem.xsl"/>
  
  <!-- Filter out any marked elements which are not intended for this 
  conversion -->
  <include href="./conversion.xsl"/>
  
  <variable name="type" select="/osis/osisText/header/work
    [@osisWork = /osis/osisText/@osisIDWork]
    /type/string()"/>
  
  <template match="/" priority="30">
    <copy>
      <variable name="pass1"><apply-templates select="node()"/></variable>
      <apply-templates select="$pass1" mode="pass2"/>
    </copy>
  </template>
  
  <!-- Remove all non-Bible material that is not within a glossary div -->
  <template match="div[$type = 'Glossary'][parent::osisText][not(@type = 'glossary')]"/>
  
  <!-- Remove duplicate glossary keywords (since the aggregated glossary is used) -->
  <template match="div[contains(@type, 'duplicate')][ancestor::div[@type='glossary']]"/>
  
  <!-- Remove duplicate material in Bibles that is also included in the 
  dictionary module for the INT feature -->
  <variable name="removedINT" select="//div[$type = 'Bible']
      [@annotateType='x-feature'][@annotateRef='INT']"/>
  <template match="div[. intersect $removedINT]"/>
  
  <!-- Remove chapter navmenus from Bibles (SWORD front-ends handle this 
  functionality)-->
  <template match="list[$type = 'Bible'][@subType='x-navmenu'][following-sibling::*[1][self::chapter[@eID]]]"/>
  
  <!-- Remove x-external attribute since SWORD handles them like any 
  other reference -->
  <template match="@subType[. = 'x-external'][parent::reference]"/>
  
  <!-- Remove composite cover images from SWORD modules -->
  <template match="figure[@subType='x-comp-publication']"/>
  
  <!-- Remove empty titles/index etc, which break some front ends -->
  <template match="title[not(normalize-space(string()))] | index"/>
  
  <!-- Remove TOC milestones, which are not supported for SWORD -->
  <template match="milestone[starts-with(@type, 'x-usfm-toc')]"/>
  
  <variable name="removedFeatureRefs" as="xs:string*" 
      select="$MAINMOD_DOC/descendant::*[@osisID]
              [ancestor::div[@annotateType='x-feature'][@annotateRef='INT']]
              /oc:osisRef(@osisID, $MAINMOD)"/>
  <variable name="removedDictNonGloss" as="xs:string*"
      select="$DICTMOD_DOC/descendant::*[@osisID]
              [not(ancestor::div[@type = 'glossary'])]
              /oc:osisRef(@osisID, $DICTMOD)"/>
  <template match="@osisRef" priority="99">
    <variable name="conversion"><!-- conversion.xsl -->
      <oc:tmp><next-match/></oc:tmp>
    </variable>
    <!-- Remove osisRefs targetting removed Bible INT divs and DICTMOD
    non-glossary targets -->
    <variable name="osisRef0" 
      select="oc:filter_osisRef($conversion/*/@osisRef, true(), 
      ($removedFeatureRefs, $removedDictNonGloss))"/>
    <!-- SWORD uses the aggregated glossary, so forward duplicate 
    entries to the aggregated entry -->
    <variable name="osisRef1" select="replace($osisRef0, '\.dup\d+', '')"/>
    <!-- Remove refs to !toc targets, which are not supported for SWORD -->
    <variable name="osisRef2" select="normalize-space(replace($osisRef1, '\S+!toc', ''))"/>
    <!-- Trim any remaining multi target refs -->
    <attribute name="osisRef" select="replace($osisRef2, ' .*$', '')"/>
    <if test="matches($osisRef2, ' .*$')">
      <call-template name="Warn">
<with-param name="msg">Removing secondary targets of <value-of select="parent::*/string()"/> osisRef="<value-of select="$osisRef2"/>"</with-param>
      </call-template>
    </if>
  </template>
  
  <!-- Prefix 2 dashes to $uiIntroduction keyword, or one dash to 
  $uiDictionary, and update all osisRefs to them. This puts these two 
  keywords at the top of the SWORD DICT module. -->
  <variable name="reftext" select="for $i in ($REF_introductionINT, $REF_dictionary) 
                                   return oc:decodeOsisRef(tokenize($i, ':')[2])"/>
  <template mode="pass2" match="seg[@type='keyword'][normalize-space(text()) and text() = $reftext]">
    <variable name="text" select="concat(
      if (text() = oc:decodeOsisRef(tokenize($REF_introductionINT, ':')[2])) 
      then '--' else '-', 
      ' ', text())"/>
    <copy>
      <apply-templates mode="pass2" select="@*"/>
      <attribute name="osisID" select="oc:encodeOsisRef($text)"/>
      <value-of select="$text"/>
    </copy>
  </template>
  <template mode="pass2" match="@osisRef">
    <attribute name="osisRef" 
      select="if (. = ($REF_introductionINT, $REF_dictionary)) 
              then concat($DICTMOD, ':', if (. = $REF_introductionINT) 
              then '_45__45__32_' else '_45__32_', tokenize(., ':')[2]) 
              else ."/>
  </template>
  
  <!-- Report results -->
  <template match="/" priority="39">
  
    <call-template name="Note">
<with-param name="msg">Running osis2sword.xsl</with-param>
    </call-template>
    
    <if test="$removedINT">
      <call-template name="Note">
<with-param name="msg">Removed <value-of select="count($removedINT)"/> Bible INT feature div(s).</with-param>
      </call-template>
    </if>
    
    <next-match/>
  </template>

</stylesheet>
