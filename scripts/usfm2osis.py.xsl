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
  
  <!-- osis-converters uses \tocN tags for eBook TOC entries, but usfm2osis.py only expects 
  them at the beginning of a file, before any paragraphs or section divs, and so it does not 
  close them upon TOC markers. So this fixes that by closing paragraphs and section divs at
  TOC milestones. -->
  <template match="p[descendant::milestone[starts-with(@type, 'x-usfm-toc')]] | 
                   div[matches(@type,'[Ss]ection')][descendant::milestone[starts-with(@type, 'x-usfm-toc')]]">
    <apply-templates select="oc:expelElements(., ./descendant::milestone[starts-with(@type, 'x-usfm-toc')], false())"/>
  </template>
  
  <!-- usfm2osis.py puts scope title content within a reference element, but they are not 
  actually reference links. So this fixes them. -->
  <template match="reference[ancestor::title[@type='scope']]"><apply-templates/></template>
  
  <!-- usfm2osis.py may output notes having n="", so remove these empty n attributes -->
  <template match="note[@n='']"><copy><apply-templates select="node()|@*[not(name()='n')]" mode="identity"/></copy></template>
  
</stylesheet>
