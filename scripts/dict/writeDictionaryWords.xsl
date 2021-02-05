<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/writeDictionaryWords.xsl"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT writes a default (initial) DictionaryWords.xml file for a glossary OSIS file -->
 
  <import href="../functions/functions.xsl"/>
  
  <param name="anyEnding" select="oc:sarg('anyEnding', /, 'false')"/>
  
  <param name="notXPATH_default" select="oc:sarg('notXPATH_default', /, 
    'ancestor-or-self::*[self::osis:caption or self::osis:figure or self::osis:title or self::osis:name or self::osis:lb]')"/>
  
  <param name="output"/>
  
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="yes"/>
  
  <variable name="MOD" select="//osisText/@osisIDWork"/>
  
  <template match="/">
  
    <!-- Save all target osisRef values, and their associated infos -->
    <variable name="link_targets" as="element(oc:target)*">
      <for-each select="(descendant::seg[@type='keyword'] | descendant::milestone)
          [@osisID][not(ancestor::div[@subType='x-aggregate'])]">
        <oc:target osisRef="{concat($MOD, ':' , replace(@osisID, '\.dup\d+!toc', '!toc'))}" 
                name="{oc:decodeOsisRef(replace(@osisID, '(\.dup\d+|![^!]+)+$', ''))}"
                scope="{ancestor::div[@scope][@scope != 'NAVMENU'][last()]/@scope}"/>
      </for-each>
    </variable>
    
    <!-- Create an entry element for each target name -->
    <variable name="entries" as="element(oc:entry)*">
      <for-each select="distinct-values($link_targets/@name)">
      
        <variable name="matcheElements">
          <!-- the following regex matches separators between keyword variants -->
          <variable name="variants" select="tokenize(., '\s*[,;\[\]\(\)…]\s*')"/>
          <for-each select="if (count($variants) = 1) then . else (., $variants)">
            <choose>
              <when test="$anyEnding = 'true' and string-length(.) &#62; 3">
                <variable name="words">
                  <for-each select="tokenize(., '\s+')">
                    <sequence select="concat('\Q', ., '\E\S*')"/>
                  </for-each>
                </variable>
                <element name="match" namespace="http://github.com/JohnAustinDev/osis-converters">
                  <value-of select="concat(
                      if (matches($words, '^\\Q\w')) then '/\b(' else '/(',
                      $words,
                      ')/i'
                    )"/>
                </element>
              </when>
              <when test="string-length(.)">
                <element name="match" namespace="http://github.com/JohnAustinDev/osis-converters">
                  <value-of select="concat(
                      if (matches(., '^\w')) then '/\b(\Q' else '/(\Q', 
                      ., 
                      if (matches(., '\w$')) then '\E)\b/i' else '\E)/i'
                    )"/>
                </element>
              </when>
            </choose>
          </for-each>
        </variable>
          
        <element name="entry" namespace="http://github.com/JohnAustinDev/osis-converters">
          <attribute name="myMaxMatchLength" select="max($matcheElements/oc:match/string-length())"/>
          <element name="name" namespace="http://github.com/JohnAustinDev/osis-converters">
            <value-of select="."/>
          </element>
          <for-each select="$matcheElements/oc:match">
            <sort select="string-length(.)" data-type="number" order="descending"/>
            <sequence select="."/>
          </for-each>
        </element>
        
      </for-each>
    </variable>
        
    <call-template name="Note">
<with-param name="msg">Writing default DictionaryWords.xml (anyEnding=<value-of select="$anyEnding"/>): <value-of select="$output"/> from: <value-of select="base-uri()"/>.</with-param>
    </call-template>
    <comment>
  IMPORTANT: 
  For case insensitive matches using /match/i to work, ALL text MUST be 
  surrounded by the \Q...\E quote operators. If a match is failing, 
  consider this first. This is not a normal Perl rule, but is required 
  because Perl doesn't properly handle case for Turkish-like languages.

  USE THE FOLLOWING ATTRIBUTES TO CONTROL LINK PLACEMENT:

  Boolean attributes:
  IMPORTANT: default is false for boolean attributes
  onlyNewTestament = "true|false"
  onlyOldTestament = "true|false"
  
  dontLink = "true|false" where true means match elements should instead 
        block the creation of any link.

  multiple="false|match|true" to control the number of links per context,
        where context is Bible chapter, glossary entry, div, or note. A
        'false' (default) value limits each entry element to one link per 
        context, a value of 'match' limits each match element to one link 
        per context, and 'true' removes all limitations.
        
  notExplicit="false|true|context" where 'true' means the match elements 
        should NOT be applied to explicitly marked glossary entries in 
        the text. A space separated list of contexts is true only for 
        the given contexts.
        
  onlyExplicit="false|true|context" where 'true' means the match elements 
        should ONLY be applied to explicitly marked glossary entries in 
        the text. A space separated list of contexts is true only for 
        the given contexts.

  Non-Boolean attributes:
  IMPORTANT: non-boolean attribute values are CUMULATIVE, so if the same 
  attribute appears in multiple ancestors, each ancestor value is 
  accumalated. However, 'context' and 'XPATH' attributes CANCEL the    
  effect of ancestor 'notContext' and 'notXPATH' attributes respectively.

  context = A space separated list of osisRefs or comma separated list of 
         Paratext refs in which to create links. Or ALL means all Bible 
         books.
         
  notContext = A space separated list of osisRefs or comma separated list 
         of Paratext refs in which not to create links.
         
  XPATH = An xpath expression to be applied to each text node, where a
          non-null result means search the node for possible links.
          
  notXPATH = An xpath expression to be applied to each text node, where
          a non-null result means skip that node.

  ENTRY ELEMENTS MAY CONTAIN THE FOLLOWING ATTRIBUTES:
  osisRef = A space separated list of osisID targets. This attribute is 
          required for all entry elements.
  noOutboundLinks = "true|false" where 'true' limits the target from
          containing any links itself.

  Match patterns can be any perl match regex, but the only flag that has 
  any effect is the 'i' flag. The last matching parenthetical group, or 
  else a group named 'link' (with ?'link'...) will become the link's 
  inner text.
    </comment><text>
</text>
    <dictionaryWords version="1.0" xmlns="http://github.com/JohnAustinDev/osis-converters">
      <div notXPATH="{$notXPATH_default}">
        
        <for-each-group select="$link_targets" group-by="@scope" 
            xmlns="http://www.w3.org/1999/XSL/Transform">
          <sort select="string-length(current-grouping-key())" data-type="number" order="descending"/>
          
          <element name="div" namespace="http://github.com/JohnAustinDev/osis-converters">
            <if test="string-length(current-grouping-key())">
              <attribute name="context" select="current-grouping-key()"/>
            </if>
            <for-each-group select="current-group()" group-by="@name">
              <sort data-type="number" order="descending" 
                    select="$entries[string(child::oc:name) = current-grouping-key()]/@myMaxMatchLength"/>
              
              <element name="entry" namespace="http://github.com/JohnAustinDev/osis-converters">
                <attribute name="osisRef" select="me:osisRefs(current-group()/@osisRef)"/>
                <sequence select="$entries[string(child::oc:name) = current-grouping-key()]/node()"/>
              </element>
            </for-each-group>
          </element>
          
        </for-each-group>

      </div>
    </dictionaryWords>
  </template>
  
  <!-- Only reference the first of any duplicates, otherwise osisRef
  trimming will result in unpredictable targetting. -->
  <function name="me:osisRefs" as="xs:string">
    <param name="osisRefs" as="attribute(osisRef)+"/>
    
    <variable name="all" as="xs:string+" select="distinct-values($osisRefs)"/>
    <variable name="dups" as="xs:double*" select="for $i in $all 
        return if (matches($i, '\.dup\d$')) 
               then number(replace($i, '^.*\.dup(\d)$', '$1')) 
               else 10"/>
    <variable name="out" select="for $i in $all 
      return if ( matches($i, '\.dup\d$') and 
                  number(number(replace($i, '^.*\.dup(\d)$', '$1'))) != min($dups) )
             then '' else $i"/>
      <value-of select="normalize-space(string-join($out, ' '))"/>
  </function>
</stylesheet>
