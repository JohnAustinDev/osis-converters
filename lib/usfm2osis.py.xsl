<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <import href="./common/functions.xsl"/>
  
  <!-- By default copy everything as is, for all modes -->
  <template mode="#all" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <template match="/">
    <!-- pass1 moves TOC milestones out of paragraphs -->
    <variable name="pass1"><apply-templates mode="pass1"/></variable>
    <!-- pass2 moves TOC milestones out of sections divs -->
    <apply-templates mode="pass2" select="$pass1"/>
  </template>
  
  <!-- Throw an error if there are unexpected verse div ancestors. This 
  helps indicate if usfm2osis.py did not properly close div elements 
  like \periph -->
  <template mode="pass1" match="verse[@osisID]">
    <variable name="bad" 
      select="ancestor::div[not(matches(@type, '(section|book)', 'i'))][1]"/>
    <if test="$bad">
      <call-template name="Error">
<with-param name="msg">This div should not contain verses: <value-of select="oc:printNode($bad)"/></with-param>
      </call-template>
    </if>
    <next-match/>
  </template>
  
  <!-- usfm2osis.py puts scope title content within a reference element, 
  but they are not actually reference links. So this fixes them. -->
  <template mode="pass1" match="reference[ancestor::title[@type='scope']]">
    <apply-templates mode="#current"/>
  </template>
  
  <!-- usfm2osis.py may output notes having n="", so remove these empty 
  n attributes -->
  <template mode="pass1" match="@n[parent::note][. = '']"/>
  
  <!-- glossary keywords should never have optional line breaks or other 
  markup in them -->
  <template mode="pass1" match="seg[@type='keyword']">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <value-of select="string()"/>
      <for-each select="element()">
        <call-template name="Warn">
<with-param name="msg">Keyword child element was converted to text: <value-of select="oc:printNode(.)"/></with-param>
<with-param name="exp">Keywords must not contain child elements, only text.</with-param>
        </call-template>
      </for-each>
    </copy>
  </template>
  
  <!-- osis-converters uses \toc tags for eBook TOC entries, but 
  usfm2osis.py only expects them at the beginning of a file, before any 
  paragraphs or section divs, and so it does not close these elements  
  upon TOC markers as it should. So this fixes that problem by closing   
  paragraphs and section divs at TOC milestones. -->
  <template mode="pass1" match="p[child::milestone[starts-with(@type, 'x-usfm-toc')]]">
    <apply-templates mode="#current" 
      select="oc:expelElements(., child::milestone[starts-with(@type, 'x-usfm-toc')], (), true())"/>
  </template>
  
  <template mode="pass2" match="div[matches(@type,'[Ss]ection')][child::milestone[starts-with(@type, 'x-usfm-toc')]]">
    <apply-templates mode="#current" 
      select="oc:expelElements(., child::milestone[starts-with(@type, 'x-usfm-toc')], (), true())"/>
  </template>
  
</stylesheet>
