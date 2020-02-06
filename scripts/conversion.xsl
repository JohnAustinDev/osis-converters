<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- Implements the 'conversion' periph instruction which, when active, filters 
  out any marked elements which are not intended for this conversion -->
  
  <import href="./functions.xsl"/><!-- only needed for reporting results -->

  <param name="conversion"/>
  
  <variable name="removeElements" select="//*[@annotateType='x-conversion'][$conversion and not($conversion = tokenize(@annotateRef, '\s+'))]"/>
  
  <variable name="removeGlossary" select="$removeElements[self::div[@type='glossary']]"/>
  
  <!-- Report results -->
  <template match="/">
    <if test="$removeElements">
      <call-template name="Note">
        <with-param name="msg">Removed <value-of select="count($removeElements)"/> marked element(s) during conversion to '<value-of select="$conversion"/>'.</with-param>
      </call-template>
    </if>
    <if test="$removeGlossary">
      <call-template name="Note">
        <with-param name="msg">Of those removed, <value-of select="count($removeGlossary)"/> element(s) are glossaries.</with-param>
      </call-template>
    </if>
    <next-match/>
  </template>
  
  <!-- Remove any marked elements -->
  <template match="*[. intersect $removeElements]" priority="10"/>
  
  <!-- If any glossary is removed, remove prev-next navmenu links from keywords, because some will be broken -->
  <template match="item[boolean($removeGlossary)][@subType='x-prevnext-link'][ancestor::div[starts-with(@type, 'x-keyword')]]" priority="10"/>
  
</stylesheet>
