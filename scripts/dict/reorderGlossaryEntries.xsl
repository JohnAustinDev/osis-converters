<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT will find all glossaries matching glossaryRegex and re-order their keywords according to KeySort -->

  <import href="../functions.xsl"/>
  
  <param name="glossaryRegex" select="oc:sarg('glossaryRegex', /, '')"/>
  
  <!-- By default copy everything as is, for all modes -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <template match="/">
    <call-template name="Note"><with-param name="msg">Running reorderGlossaryEntries.xml with glossaryRegex=<value-of select="$glossaryRegex"/></with-param></call-template>
    <next-match/>
  </template>
  
  <template match="div[@type='glossary'][not(@subType) or @subType != 'x-aggregate'][$glossaryRegex = 'true' or matches(oc:getGlossaryName(.), $glossaryRegex)]">
    <call-template name="Note"><with-param name="msg">Re-ordering entries in glossary: <value-of select="oc:getGlossaryName(.)"/></with-param></call-template>
    <copy><apply-templates select="@*"/>
      <for-each-group 
        select="node()" 
        group-adjacent="2*count(preceding::seg[@type='keyword']) + 
        (if (generate-id(descendant-or-self::seg[@type='keyword'][1]) = generate-id(ancestor::div[@type='glossary'][1]/descendant::seg[@type='keyword'][1])) then 1 else 0)">
        <sort select="oc:keySort(current-group()/descendant-or-self::seg[@type='keyword'][1]/string())" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
        <apply-templates select="current-group()"/>
      </for-each-group>
    </copy>
  </template>
  
</stylesheet>
