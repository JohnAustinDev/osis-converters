<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0" 
  xmlns="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:my="osis-converters/scripts/whitespace.xsl"
  xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
  
  <!-- This script only effects white-space and 'osis:' prefixed element
  names. It removes the 'osis:' prefixes from all element names. It 
  collapses runs of spaces to a single space. It removes all new-lines 
  (except those that are escaped by '\'). Then it re-writes new-lines
  before and/or after the designated elements and comment nodes (to 
  facilitate human readability of the OSIS file). -->
  
  <template match="/" priority="-1">
    <apply-templates mode="whitespace"/>
  </template>
 
  <!-- The 'whitespace' mode to allows other stylesheets to apply the
  whitespace stylesheet after all other stylesheets -->
  <template mode="whitespace" match="node()|@*" priority="-1">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <template mode="whitespace" match="text()">
    <!-- Regex does not support Perl (?<!\\)\n look-behind for preserving
    escaped new-lines in some config entries, so use an interim xNLx -->
    <variable name="text1" select="replace(., '\\\n', 'xNLx')"/>
    
    <!-- Convert sequential \s and \n chars to a single space, everywhere -->
    <variable name="text2" select="replace($text1, '[\s\n]+', ' ')"/>
    
    <variable name="text3" select="replace($text2, 'xNLx', '\\&#xa;')"/>
    
    <!-- Remove redundant spaces where there will be breakBefore/breakAfter
    new-lines (but not when $t elements would no longer have a text node child).
    Removal of these extra spaces allows whitespace.xsl to be idempotent. -->
    <variable name="t" select="if (matches(local-name(),'^(figure|title|head|item|p|l)$')) then '\S' else ''"/>
    <choose>
      <when test="./following-sibling::node()[1][self::*] and 
                  my:breakBefore(./following-sibling::node()[1])">
        <value-of select="replace($text3, ' $', '')"/>
      </when>
      <when test="parent::*//text()[last()][. intersect current()] and 
                  my:breakAfter(./parent::*)">
        <value-of select="replace($text3, concat($t, ' $'), '')"/>
      </when>
      <otherwise><value-of select="$text3"/></otherwise>
    </choose>

  </template>
  
  <!-- Write \n only before selected start/end tags (and remove any osis prefixes). -->
  <template mode="whitespace" match="*[ namespace-uri() = 'http://www.bibletechnologies.net/2003/OSIS/namespace' ]">
    <if test="my:breakBefore(.)">
      <text>&#xa;</text><if test="ancestor::work"><text>  </text></if>
    </if>
    <element name="{local-name()}" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
      <apply-templates mode="#current" select="node()|@*"/>
      <if test="my:breakAfter(.)"><text>&#xa;</text></if>
    </element>
  </template>
  
  <template mode="whitespace" match="comment()"><text>&#xa;</text><copy/></template>
  
  <!-- Elements that will have line-breaks before their start-tag if not preceded by verse[sID] -->
  <function name="my:breakBefore" as="xs:boolean">
    <param name="element" as="element()"/>
    <choose>
      <!-- No element following a verse tag will get a break before it -->
      <when test="$element/preceding-sibling::*[not(self::milestone[not(ends-with(@type, 'verse-start'))])][1]
                  [self::verse[@sID] or self::milestone[ends-with(@type, 'verse-start')]]">
        <value-of select="false()"/>
      </when>
      <otherwise>
        <value-of 
          select="matches(local-name($element),'^(lb|figure|title|head|list|item|p|lg|l|osis|osisText|div|chapter|table|row)$')
              or $element[self::verse[@sID]]
              or $element[self::milestone[starts-with(@type,'x-usfm-toc')]]
              or $element[ancestor-or-self::header]"/>
      </otherwise>
    </choose>
  </function>
  
  <!-- Content elements that will have line-breaks before their end-tag -->
  <function name="my:breakAfter" as="xs:boolean">
    <param name="element" as="element()"/>
    <value-of 
      select="matches(local-name($element),'^(osis|osisText|header|work|div|list|lg|table)$')"/>
  </function>
  
</stylesheet>
