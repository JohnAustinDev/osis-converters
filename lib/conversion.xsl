<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- Implements the 'conversion' and 'not_conversion' periph instruc-
  tions which filter out elements marked for removal during particular 
  conversions. When $DICTMOD_DOC is set, this stylesheet also adjusts 
  multi-target references referencing removed keyword osisIDs, and an 
  error is generated if keyword removal results in broken links. -->
  
  <import href="./common/functions.xsl"/><!-- needed for reporting results and removedKeywords -->

  <param    name="conversion" as="xs:string"/>
  <param    name="notConversion" as="xs:string" select="$conversion"/>
  <variable name="conv"    as="xs:string*" select="tokenize($conversion, '\s+')"/>
  <variable name="notConv" as="xs:string*" select="tokenize($notConversion, '\s+')"/>
  
  <!-- Filter out refs that target elements of removed conversion 
  material in both DICTMOD and MAINMOD. NOTE: x-conversion keeps the
  marked element if any listed type matches one listed in $conv, while 
  x-notConversion removes it if any listed type matches one of $conv. -->
  <variable name="removedOsisIDs" as="xs:string*" select="
    ($MAINMOD_DOC/descendant::*[@osisID]
      [ ancestor::*[@annotateType='x-conversion']
          [count($conv) and not($conv  = tokenize(@annotateRef, '\s+'))] |
        ancestor::*[@annotateType='x-notConversion']
          [count($notConv) and $notConv = tokenize(@annotateRef, '\s+')]
      ]/oc:osisRef(@osisID, $MAINMOD)
    ),
    ($DICTMOD_DOC/descendant::*[@osisID]
      [ ancestor::*[@annotateType='x-conversion']
          [count($conv) and not($conv  = tokenize(@annotateRef, '\s+'))] |
        ancestor::*[@annotateType='x-notConversion']
          [count($notConv) and $notConv = tokenize(@annotateRef, '\s+')]
      ]/oc:osisRef(@osisID, $DICTMOD)
    )"/>
                                          
  <template match="/"><call-template name="conversion.xsl"/></template>
  
  <template mode="conversion.xsl" match="/" name="conversion.xsl">
    <message>NOTE: Running conversion.xsl</message>
    
    <variable name="removeElements" select="
      //*[@annotateType='x-conversion']
         [count($conv) and not($conv  = tokenize(@annotateRef, '\s+'))] |
      //*[@annotateType='x-notConversion']
         [count($notConv) and $notConv = tokenize(@annotateRef, '\s+')]"/>
  
    <variable name="removeGlossary" select="$removeElements[self::div[@type='glossary']]"/>
    
    <variable name="removeKeywords" select="$removeGlossary/descendant::seg[@type='keyword']"/>
    
    <!-- This must be the same selection that navigationMenu.xsl used to generate prev/next links -->
    <variable name="sortedGlossaryKeywords" 
        select="//div[@type='glossary']//div[starts-with(@type, 'x-keyword')]
                                            [not(@type = 'x-keyword-duplicate')]
                                            [not(ancestor::div[@scope='NAVMENU'])]
                                            [not(ancestor::div[@annotateType='x-feature'][@annotateRef='INT'])]"/>
    
    <!-- If certain glossaries are removed, remove prev-next navmenu links 
    from keywords, because otherwise some links will be broken. -->
    <variable name="removePrevNextLinks" as="xs:boolean" 
      select="boolean($sortedGlossaryKeywords/descendant::seg[@type='keyword'] intersect $removeKeywords)"/>
                
    <apply-templates mode="conversion" select=".">
      <with-param name="removeElements"      select="$removeElements"      tunnel="yes"/>
      <with-param name="removePrevNextLinks" select="$removePrevNextLinks" tunnel="yes"/>
    </apply-templates>
  
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
  </template>
  
  <!-- By default copy everything as is -->
  <template mode="conversion" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <!-- Remove any marked elements -->
  <template mode="conversion" match="element()" priority="1">
    <param name="removeElements" as="element()*" tunnel="yes"/>
    <if test="not(. intersect $removeElements)"><next-match/></if>
  </template>
  
  <!-- Remove prevnext links that are no longer valid -->
  <template mode="conversion" match="item[@subType = 'x-prevnext-link']
                                         [ancestor::div[starts-with(@type, 'x-keyword')]]">
    <param name="removePrevNextLinks" as="xs:boolean" tunnel="yes"/>
    <if test="not($removePrevNextLinks)"><next-match/></if>
  </template>

  <!-- Process osisRef attributes -->
  <template mode="conversion" match="@osisRef">
    <attribute name="osisRef" 
      select="replace(oc:filter_osisRef(., true(), $removedOsisIDs), '\.dup\d+!toc', '!toc')"/>
  </template>
  
</stylesheet>
