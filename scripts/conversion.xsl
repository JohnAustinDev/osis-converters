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
  
  <import href="./functions.xsl"/><!-- needed for reporting results and refRedirects -->

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
  <variable name="refRedirects" select="$DICTMOD_DOC/descendant::seg[@type='keyword']
    [ancestor::*[@annotateType='x-conversion'][$conversion and not($conversion = tokenize(@annotateRef, '\s+'))]]"/>
  <variable name="refRedirected" as="element(reference)*" select="/descendant::reference[not(ancestor::*[starts-with(@subType,'x-navmenu')])]
    [tokenize(@osisRef, ' ') = $refRedirects/concat($DICTMOD,':',replace(@osisID,'^[^:]*:',''))]"/>
  
  <!-- Report results -->
  <template match="/">
    <call-template name="Note">
<with-param name="msg">Running conversion.xsl</with-param>
    </call-template>
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
    <if test="$removePrevNextLinks">
      <call-template name="Note">
        <with-param name="msg">Removed all keyword prev/next navmenu links because of glossary removal.</with-param>
      </call-template>
    </if>
    <if test="$refRedirected">
      <call-template name="Note">
        <with-param name="msg">Redirected <value-of select="count($refRedirected)"/> references(s) to removed glossaries.</with-param>
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
  
  <template match="reference[. intersect $refRedirected]/@osisRef">
    <variable name="osisRef" as="xs:string?" select="string-join(
        (for $i in tokenize(., ' ') return 
        if ($i = $refRedirects/concat($DICTMOD,':',replace(@osisID,'^[^:]*:',''))) then '' else $i)
      , ' ')"/>
    <attribute name="osisRef" select="if ($osisRef) then $osisRef else ."/>
    <if test="not($osisRef)">
      <call-template name="Error">
<with-param name="msg">Reference to removed glossary could not be forwarded: <value-of select="."/></with-param>
      </call-template>
    </if>
  </template>
  
</stylesheet>
