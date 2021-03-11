<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/CF_addDictLinks.xsl"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT writes a default (initial) CF_addDictLinks.xml file for a glossary OSIS file -->
 
  <import href="../common/functions.xsl"/>
  
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
<with-param name="msg">Writing default CF_addDictLinks.xml (anyEnding=<value-of select="$anyEnding"/>): <value-of select="$output"/> from: <value-of select="base-uri()"/>.</with-param>
    </call-template>
    <addDictLinks version="1.0" xmlns="http://github.com/JohnAustinDev/osis-converters">
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
    </addDictLinks>
  </template>
  
  <!-- Only reference the first of any duplicates, otherwise osisRef
  trimming will result in unpredictable targeting. -->
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
