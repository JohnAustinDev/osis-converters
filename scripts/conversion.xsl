<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- Implements the 'conversion' periph instruction which filters out 
  elements marked for removal during particular conversions. When 
  $DICTMOD_DOC is set, this stylesheet adjusts multi-target references 
  referencing removed keyword osisIDs, and an error is generated if 
  keyword removal causes broken links. -->
  
  <import href="./functions/functions.xsl"/><!-- needed for reporting results and removedKeywords -->

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
  <!-- Remove any marked elements -->
  <template match="*[. intersect $removeElements]" priority="40"/>
  
  <!-- If certain glossaries are removed, remove prev-next navmenu links 
  from keywords, because some will be broken -->
  <variable name="removePrevNextLinks" as="xs:boolean" 
    select="boolean($sortedGlossaryKeywords/descendant::seg[@type='keyword'] intersect $removeKeywords)"/>
  <template match="item[@subType = 'x-prevnext-link']
                       [$removePrevNextLinks]
                       [ancestor::div[starts-with(@type, 'x-keyword')]]" 
            priority="40"/>
  
  <!-- Remove dupN part of TOC milestones and osisRefs because it has 
  been assumed that only one of the duplicate TOC entries will remain 
  for a given conversion. -->
  <template match="@osisID[matches(., '\.dup\d+!toc')]">
    <attribute name="osisID" select="replace(., '\.dup\d+!toc', '!toc')"/>
  </template>
  
  <!-- Filter out refs that target elements of removed conversion 
  material of both DICTMOD and MAINMOD. -->
  <variable name="removedOsisIDs" as="xs:string*" 
      select="($MAINMOD_DOC/descendant::*[@osisID][ ancestor::*[@annotateType='x-conversion']
              [$conversion and not($conversion = tokenize(@annotateRef, '\s+'))] ]
              /oc:osisRef(@osisID, $MAINMOD)),
              ($DICTMOD_DOC/descendant::*[@osisID][ ancestor::*[@annotateType='x-conversion']
              [$conversion and not($conversion = tokenize(@annotateRef, '\s+'))] ]
              /oc:osisRef(@osisID, $DICTMOD))"/>
  
  <template match="@osisRef" priority="40">
    <attribute name="osisRef" 
      select="replace(oc:filter_osisRef(., true(), $removedOsisIDs), '\.dup\d+!toc', '!toc')"/>
  </template>
  
  <!-- Report results -->
  <template match="/" priority="49">
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
    
    <if test="boolean($DICTMOD) and not(boolean($DICTMOD_DOC) and boolean($MAINMOD_DOC))">
      <call-template name="Warn">
<with-param name="msg">References to any removed osisIDs are not being checked.</with-param>
<with-param name="exp">Pass DICTMOD_URI and MAINMOD_DOC to conversion.xsl to enable checking and forwarding of these references.</with-param>
      </call-template>
    </if>
    
    <next-match/>
  </template>
  
</stylesheet>
