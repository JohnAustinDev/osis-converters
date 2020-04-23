<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT writes a default (initial) DictionaryWords.xml file for a glossary OSIS file -->
 
  <import href="../functions/functions.xsl"/>
  
  <param name="anyEnding" select="oc:sarg('anyEnding', /, 'false')"/>
  
  <param name="notXPATH_default" select="oc:sarg('notXPATH_default', /, 
    'ancestor-or-self::*[self::osis:caption or self::osis:figure or self::osis:title or self::osis:name or self::osis:lb]')"/>
  
  <param name="OUTPUT_FILE"/>
  
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="yes"/>
  
  <variable name="MOD" select="//osisText/@osisIDWork"/>
  
  <template match="/">
  
    <!-- Save all target osisRef values, and their associated info -->
    <variable name="link_targets" as="element(oc:target)*">
      <for-each select="(descendant::seg[@type='keyword'] | descendant::milestone)
          [@osisID][not(ancestor::div[@subType='x-aggregate'])]">
        <oc:target osisRef="{concat($MOD, ':' , @osisID)}" 
                name="{oc:decodeOsisRef(replace(@osisID, '(\.dup\d+|![^!]+)$', ''))}"
                scope="{ancestor::div[@scope][@scope != 'NAVMENU'][last()]/@scope}"/>
      </for-each>
    </variable>
    
    <!-- Create an entry element for each target name -->
    <variable name="entries" as="element(oc:entry)*">
      <for-each select="distinct-values($link_targets/@name)">
        <!-- these are seen as separators between keyword variants -->
        <variable name="matches">
          <for-each select="tokenize(., '\s*[,;\[\]\(\)…]\s*')">
            <choose>
              <when test="$anyEnding = 'true' and string-length(.) &#62; 3">
                <variable name="words">
                  <for-each select="tokenize(., '\s+')">
                    <sequence select="concat('\Q', ., '\E', '\S*')"/>
                  </for-each>
                </variable>
                <element name="match" namespace="http://github.com/JohnAustinDev/osis-converters">
                  <value-of select="concat('/\b(', string-join($words, ' '), ')\b/i')"/>
                </element>
              </when>
              <when test="string-length(.)">
                <element name="match" namespace="http://github.com/JohnAustinDev/osis-converters">
                  <value-of select="concat('/\b(\Q', ., '\E)\b/i')"/>
                </element>
              </when>
            </choose>
          </for-each>
        </variable>
          
        <element name="entry" namespace="http://github.com/JohnAustinDev/osis-converters">
          <attribute name="myMaxMatchLength" select="max($matches/oc:match/string-length())"/>
          <element name="name" namespace="http://github.com/JohnAustinDev/osis-converters">
            <value-of select="."/>
          </element>
          <for-each select="$matches/oc:match">
            <sort select="string-length(.)" data-type="number" order="descending"/>
            <sequence select="."/>
          </for-each>
        </element>
      </for-each>
    </variable>
        
    <call-template name="Note">
<with-param name="msg">Writing default DictionaryWords.xml (anyEnding=<value-of select="$anyEnding"/>): <value-of select="$OUTPUT_FILE"/> from: <value-of select="base-uri()"/>.</with-param>
    </call-template>
    <comment>
  IMPORTANT: 
  For case insensitive matches using /match/i to work, ALL text MUST be surrounded 
  by the \\Q...\\E quote operators. If a match is failing, consider this first!
  This is not a normal Perl rule, but is required because Perl doesn't properly handle case for Turkish-like languages.

  USE THE FOLLOWING BOOLEAN &amp; NON-BOOLEAN ATTRIBUTES TO CONTROL LINK PLACEMENT:

  Boolean:
  IMPORTANT: default is false for boolean attributes
  onlyNewTestament="true|false"
  onlyOldTestament="true|false"
  dontLink="true|false" to specify matched text should NOT get linked to ANY entry

  multiple="false|match|true" to allow match elements to link more than once per entry-name or match per context (default is false)
  notExplicit="true|false" selects if match(es) should NOT be applied to explicitly marked glossary entries in the text
  onlyExplicit="true|false" selects if match(es) should ONLY be applied to explicitly marked glossary entries in the text

  Non-Boolean:
  IMPORTANT: non-boolean attribute values are CUMULATIVE, so if the same 
  attribute appears in multiple ancestors, each ancestor value is 
  accumalated. Also, 'context' and 'XPATH' attributes CANCEL the effect   
  of ancestor 'notContext' and 'notXPATH' attributes respectively.

  context="space separated list of osisRefs or comma separated list of Paratext refs" in which to create links. Or an empty value, or ALL, means all Bible books.
  notContext="space separated list of osisRefs or comma separated list of Paratext refs" in which not to create links
  XPATH="xpath expression" to be applied on each text node to keep text nodes that return non-null
  notXPATH="xpath expression" to be applied on each text node to skip text nodes that return non-null

  ENTRY ELEMENTS MAY ALSO CONTAIN THE FOLLOWING ATTRIBUTES:
  &#60;entry osisRef="The osisID of a keyword to link to. This attribute is required."
         noOutboundLinks="true|false: Set to true and the entry's text with not contain links to other entries."&#62;

  Match patterns can be any perl match regex. The last matching 
  parenthetical group, or else a group named 'link' with (?'link'...), 
  will become the link's inner text.
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
                <attribute name="osisRef" select="string-join(current-group()/@osisRef, ' ')"/>
                <sequence select="$entries[string(child::oc:name) = current-grouping-key()]/node()"/>
              </element>
            </for-each-group>
          </element>
          
        </for-each-group>

      </div>
    </dictionaryWords>
  </template>
  
</stylesheet>
