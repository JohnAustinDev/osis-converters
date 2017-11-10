<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT will do the following:
  1) End paragraphs at TOC milestones
  -->
  
  <import href="./functions.xsl"/>
  
  <!-- By default copy everything as is, for all modes -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <template match="p[descendant::milestone[starts-with(@type, 'x-usfm-toc')]]">
    <variable name="keepChildren" select="./node()[. &#60;&#60; current()//milestone[starts-with(@type, 'x-usfm-toc')][1]]"/>
    <if test="$keepChildren">
      <copy><apply-templates select="@*"/>
        <for-each select="$keepChildren"><apply-templates select="."/></for-each>
      </copy>
    </if>
    <for-each select="./node() except $keepChildren"><apply-templates select="."/></for-each>
  </template>
  
</stylesheet>
