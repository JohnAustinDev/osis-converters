<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <import href="./functions/functions.xsl"/>
  
  <!-- By default copy everything as is, for all modes -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <!-- osis-converters uses \toc tags for eBook TOC entries, but usfm2osis.py only expects 
  them at the beginning of a file, before any paragraphs or section divs, and so it does not 
  close them upon TOC markers as it should. So this fixes that by closing paragraphs and 
  section divs at TOC milestones. -->
  <template match="document-node()">
    <!-- pass1 moves TOC milestones out of paragraphs -->
    <variable name="pass1"><apply-templates/></variable>
    <!-- pass2 moves TOC milestones out of sections divs -->
    <apply-templates mode="pass2" select="$pass1"/>
  </template>

  <template match="p[child::milestone[starts-with(@type, 'x-usfm-toc')]]">
    <apply-templates select="oc:expelElements(., ./child::milestone[starts-with(@type, 'x-usfm-toc')], true())"/>
  </template>
  
  <template mode="pass2" match="div[matches(@type,'[Ss]ection')][child::milestone[starts-with(@type, 'x-usfm-toc')]]">
    <apply-templates select="oc:expelElements(., ./child::milestone[starts-with(@type, 'x-usfm-toc')], true())"/>
  </template>
  
  <!-- usfm2osis.py puts scope title content within a reference element, but they are not 
  actually reference links. So this fixes them. -->
  <template match="reference[ancestor::title[@type='scope']]"><apply-templates/></template>
  
  <!-- usfm2osis.py may output notes having n="", so remove these empty n attributes -->
  <template match="note[@n='']"><copy><apply-templates select="node()|@*[not(name()='n')]" mode="identity"/></copy></template>
  
  <!-- glossary keywords should never have optional line breaks or other markup in them -->
  <template match="seg[@type='keyword']">
    <copy>
      <apply-templates select="@*"/>
      <value-of select="string()"/>
      <for-each select="element()">
        <call-template name="Warn">
<with-param name="msg">Keyword child element was converted to text: <value-of select="oc:printNode(.)"/></with-param>
<with-param name="exp">Keywords may contain no child elements, only text.</with-param>
        </call-template>
      </for-each>
    </copy>
  </template>
  
</stylesheet>
