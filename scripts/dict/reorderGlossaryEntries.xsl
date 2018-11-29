<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT will find all glossaries matching glossaryRegex and re-order their keywords according to LangSortOrder -->

  <import href="../functions.xsl"/>
  
  <param name="glossaryRegex"/>
  
  <!-- By default copy everything as is, for all modes -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <template match="div[@type='glossary'][@subType!='x-aggregate'][matches(oc:getGlossaryName(.), $glossaryRegex)]">
    <copy><apply-templates select="@*"/>
      <for-each-group select="node()" group-adjacent="count(preceding::seg[@type='keyword'])">
        <sort select="oc:langSortOrder(current-group()/descendant-or-self::seg[@type='keyword'][1]/string(), root(.)//description[@type='x-sword-config-LangSortOrder'][ancestor::work/@osisWork = root(.)/descendant::osisText[1]/@osisIDWork])" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
        <apply-templates select="current-group()"/>
      </for-each-group>
    </copy>
  </template>
  
</stylesheet>
