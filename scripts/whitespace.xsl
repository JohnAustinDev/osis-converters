<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0" 
  xmlns="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:my="osis-converters/scripts/whitespace.xsl"
  xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
 
  <template match="node()|@*" priority="-1">
    <copy><apply-templates select="node()|@*"/></copy>
  </template>
  
  <!-- Convert sequential \s and \n chars to a single space, everywhere -->
  <template match="text()">
    <!-- regex does not support Perl (?<!\\)\n look-behind, so... -->
    <variable name="pass1" select="replace(., '\\\n', 'xNLx')"/>
    <variable name="pass2" select="replace($pass1, '[\s\n]+', ' ')"/>
    <value-of select="replace($pass2, 'xNLx', '\\&#xa;')"/>
  </template>
  
  <!-- Put \n only before and/or after certain tags. Remove osis prefixes. -->
  <template match="*[ namespace-uri() = 'http://www.bibletechnologies.net/2003/OSIS/namespace' ]">
    <if test="my:breakBefore(.) and not(preceding-sibling::*[not(self::milestone)][1][self::verse[@sID]])">
      <text>&#xa;</text><if test="ancestor::work"><text>  </text></if>
    </if>
    <element name="{local-name()}" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
      <apply-templates select="node()|@*"/>
      <if test="my:breakAfter(.)"><text>&#xa;</text></if>
    </element>
  </template>
  
  <template match="comment()"><text>&#xa;</text><copy/></template>
  
  <!-- Elements that may have line-breaks before (if not preceding by verse[sID]) -->
  <function name="my:breakBefore" as="xs:boolean">
    <param name="element" as="element()"/>
    <value-of 
      select="matches(local-name($element),'^(lb|figure|title|head|list|item|p|lg|l|osis|osisText|div|chapter|table|row)$')
              or $element[self::milestone[starts-with(@type,'x-usfm-toc')]]
              or $element[ancestor-or-self::header]
              or $element[self::verse[@sID]]
              or $element[self::hi[@subType='x-alternate']]"/>
  </function>
  
  <!-- Elements that will have line-breaks after -->
  <function name="my:breakAfter" as="xs:boolean">
    <param name="element" as="element()"/>
    <value-of 
      select="matches(local-name($element),'^(osis|osisText|header|work|div|list|lg|table)$')"/>
  </function>
  
</stylesheet>
