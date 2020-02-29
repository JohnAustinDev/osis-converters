<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- Implements the 'conversion' periph instruction which, when 
  active, filters out any marked elements which are not intended for 
  this conversion. When $DICTMOD_DOC is set, this stylesheet also 
  adjusts multi-target references referencing removed keyword osisIDs,   
  and an error is generated if keyword removal causes broken links. -->
  
  <import href="./functions.xsl"/><!-- needed for reporting results and removedKeywords -->

  <param name="conversion"/>
  
  <variable name="removeElements" select="//*[@annotateType='x-conversion'][$conversion and not($conversion = tokenize(@annotateRef, '\s+'))]"/>
  
  <variable name="removeGlossary" select="$removeElements[self::div[@type='glossary']]"/>
  
  <variable name="removeKeywords" select="$removeGlossary/descendant::seg[@type='keyword']"/>
  
  <!-- This must be the same selection that navigationMenu.xsl used to generate prev/next links -->
  <variable name="sortedGlossaryKeywords" 
      select="//div[@type='glossary']//div[starts-with(@type, 'x-keyword')]
                                          [not(@type = 'x-keyword-duplicate')]
                                          [not(ancestor::div[@scope='NAVMENU'])]
                                          [not(ancestor::div[@annotateType='x-feature'][@annotateRef='INT'])]"/>
  <variable name="removePrevNextLinks" as="xs:boolean" 
    select="boolean($sortedGlossaryKeywords/descendant::seg[@type='keyword'] intersect $removeKeywords)"/>
    
  <!-- For both Bible and Dict reference redirects, reading of the Dict is necessary -->
  <variable name="removedKeywords" select="$DICTMOD_DOC/descendant::seg[@type='keyword']
    [ancestor::*[@annotateType='x-conversion'][$conversion and not($conversion = tokenize(@annotateRef, '\s+'))]]"/>
  <variable name="refTrimmed" as="element(reference)*" select="/descendant::reference[not(ancestor::*[starts-with(@subType,'x-navmenu')])]
    [tokenize(@osisRef, '\s+') = $removedKeywords/concat($DICTMOD,':',replace(@osisID,'^[^:]*:',''))]"/>
  
  <!-- Report results -->
  <template match="/">
    <call-template name="Note">
<with-param name="msg">Running conversion.xsl</with-param>
    </call-template>
    <if test="$removeElements">
      <call-template name="Note">
        <with-param name="msg">Removed <value-of select="count($removeElements)"/> div(s) marked as '<value-of select="string-join(distinct-values($removeElements/tokenize(@annotateRef, '\s+')), ' ')"/>' during conversion to '<value-of select="$conversion"/>'.</with-param>
      </call-template>
    </if>
    <if test="$removeGlossary">
      <call-template name="Note">
        <with-param name="msg">Of those removed, <value-of select="count($removeGlossary)"/> div(s) are glossaries.</with-param>
      </call-template>
    </if>
    <if test="$removePrevNextLinks">
      <call-template name="Note">
        <with-param name="msg">Removed keyword prev/next navmenu links due to this glossary removal.</with-param>
      </call-template>
    </if>
    <if test="$refTrimmed">
      <call-template name="Note">
        <with-param name="msg">Trimmed <value-of select="count($refTrimmed)"/> references to removed glossary keywords from multi-target references(s).</with-param>
      </call-template>
    </if>
    <if test="$DICTMOD and not($DICTMOD_DOC) and not(oc:myWork(.)=$DICTMOD and not($removeGlossary))">
      <call-template name="Warn">
<with-param name="msg">References to <value-of select="if ($removeKeywords) then count($removeKeywords) else 'any'"/> removed keywords are NOT checked.</with-param>
<with-param name="exp">Pass DICTMOD_URI to conversion.xsl to enable checking and forwarding of these references.</with-param>
      </call-template>
    </if>
    <next-match/>
  </template>
  
  <!-- Remove any marked elements -->
  <template match="*[. intersect $removeElements]" priority="10"/>
  
  <!-- If certain glossaries are removed, remove prev-next navmenu links from keywords, because some will be broken -->
  <template match="item[@subType='x-prevnext-link'][$removePrevNextLinks][ancestor::div[starts-with(@type, 'x-keyword')]]" priority="10"/>
  
  <template match="reference[. intersect $refTrimmed]/@osisRef">
    <variable name="osisRef" as="xs:string?" select="string-join(
        (for $i in tokenize(., '\s+') return 
        if ($i = $removedKeywords/concat($DICTMOD,':',replace(@osisID,'^[^:]*:',''))) then '' else $i)
      , ' ')"/>
    <attribute name="osisRef" select="if ($osisRef) then normalize-space($osisRef) else ."/>
    <if test="not($osisRef)">
      <call-template name="Error">
<with-param name="msg">Reference to removed glossary keyword: <value-of select="."/></with-param>
<with-param name="exp">You are using the conversion feature to remove a glossary from the 
<value-of select="$conversion"/> conversion, but there are references to the glossary's keyword(s), 
which are now broken. You may assign multiple target osisID's to these 
references, at least one of which must target a kept glossary keyword.</with-param>
      </call-template>
    </if>
  </template>
  
</stylesheet>
