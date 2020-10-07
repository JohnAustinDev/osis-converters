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
  
  <!-- Do two passes over the data -->
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
    <if test="matches($osisRef2, ' .*$')">
      <call-template name="Warn">
<with-param name="msg">Removing secondary targets of osisRef="<value-of select="$osisRef2"/>"</with-param>
      </call-template>
    </if>
    <variable name="osisRef3" select="replace($osisRef2, ' .*$', '')"/>
    <!-- Insure SWORD Scripture ranges are one chapter or less, by keeping only the initial verse of multi-chapter ranges. -->
    <variable name="isMultiChapter" select="contains($osisRef3, '-') and 
        not(matches($osisRef3, '^([^:]+:)?([^\.]+\.\d+)\.(\d+)\-(\2)\.(\d+)$'))"/>
    <if test="$isMultiChapter">
      <call-template name="Warn">
<with-param name="msg">Only first verse of multi-chapter reference will be kept: osisRef="<value-of select="tokenize($osisRef3, '-')[1]"/>"</with-param>
<with-param name="exp">Some SWORD front-ends like xulsword cannot handle multi-chapter reference ranges.</with-param>
      </call-template>
    </if>
    <attribute name="osisRef" select="if ($isMultiChapter)
                                      then tokenize($osisRef3, '-')[1]
                                      else $osisRef3"/>
  </template>
  
  <!-- Prefix 2 dashes to $uiIntroduction keyword, or one dash to 
  $uiDictionary, and update all osisRefs to these. This puts these two 
  keywords at the top of the SWORD DICT module. Also fix a xulsword 
  issue handling colons.-->
  <variable name="reftext" select="for $i in ($REF_introductionINT, $REF_dictionary) 
                                   return oc:decodeOsisRef(tokenize($i, ':')[2])"/>
  <template mode="pass2" match="seg[@type='keyword']">
    <variable name="text1">
      <choose>
        <when test="self::seg[normalize-space(text()) and text() = $reftext]">
          <value-of select="concat(
            if (text() = oc:decodeOsisRef(tokenize($REF_introductionINT, ':')[2])) 
            then '--' else '-', 
            ' ', text())"/>
        </when>
        <otherwise><value-of select="text()"/></otherwise>
      </choose>
    </variable>
    
    <variable name="text" select="replace($text1, ':', '-')"/>
    <if test="$text != $text1">
      <call-template name="Note">
<with-param name="msg">The xulsword front-end does not allow ':' in keywords. Changing '<value-of select="$text1"/>' to '<value-of select="$text"/>'</with-param>
      </call-template>
    </if>
    
    <copy>
      <apply-templates mode="pass2" select="@*"/>
      <attribute name="osisID" select="oc:encodeOsisRef($text)"/>
      <value-of select="$text"/>
    </copy>
  </template>
  <template mode="pass2" match="@osisRef">
    <variable name="osisRef1" 
      select="if (. = ($REF_introductionINT, $REF_dictionary)) 
              then concat($DICTMOD, ':', if (. = $REF_introductionINT) 
              then '_45__45__32_' else '_45__32_', tokenize(., ':')[2]) 
              else ."/>
    <!-- A harmless work around for xulsword which doesn't handle ':' keywords -->
    <variable name="osisRef2" select="concat(tokenize($osisRef1, ':')[1], ':', 
      oc:encodeOsisRef(replace(oc:decodeOsisRef(tokenize($osisRef1, ':')[2]), ':', '-')))"/>
    <attribute name="osisRef" select="if (tokenize($osisRef1, ':')[1] = $DICTMOD and not(contains($osisRef1, '!'))) 
      then $osisRef2 else $osisRef1"/>
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
