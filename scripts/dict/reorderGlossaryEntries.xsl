<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT will find all glossaries matching glossaryRegex and 
  re-order their keywords according to KeySort -->

  <import href="../common/functions.xsl"/>
  
  <param name="glossaryRegex" select="oc:sarg('glossaryRegex', /, '')"/>
  
  <!-- By default copy everything as is, for all modes -->
  <template mode="#all" match="node()|@*" name="identity">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <template match="/">
    <call-template name="Note">
<with-param name="msg">Running reorderGlossaryEntries.xml with glossaryRegex=<value-of select="$glossaryRegex"/></with-param>
   </call-template>
    <next-match/>
  </template>
  
  <template match="div[@type='glossary'][not(@subType = 'x-aggregate')]
                      [ $glossaryRegex = 'true' 
                        or matches(oc:getDivTitle(.), $glossaryRegex) ]">    
    <copy>
      <apply-templates select="@*"/>
      <for-each-group select="node()" 
        group-adjacent="count(descendant-or-self::seg[@type='keyword']) + 
                        count(preceding::seg[@type='keyword'])">
        <sort select="oc:keySort(
            current-group()/descendant-or-self::seg[@type='keyword'] )" 
          data-type="text" order="ascending" 
          collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
        <apply-templates select="current-group()"/>
      </for-each-group>
    </copy>
    
    <call-template name="Note">
<with-param name="msg">Re-ordering entries in glossary: <value-of select="oc:getDivTitle(.)"/></with-param>
    </call-template>
    
  </template>
  
</stylesheet>
