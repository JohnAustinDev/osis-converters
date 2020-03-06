<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0" 
  xmlns="http://www.w3.org/1999/XSL/Transform" 
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:my="osis-converters/scripts/namespace.xsl"
  xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
 
  <!-- Remove unnecessary osis prefixes and normalize whitespace -->
  <template match="node()|@*">
    <copy><apply-templates select="node()|@*"/></copy>
  </template>
  
  <template match="text()" priority="1">
    <copy-of select="replace(., '[\s\n]+', ' ')"/>
  </template>
  
  <template match="*[namespace-uri()='http://www.bibletechnologies.net/2003/OSIS/namespace']" priority="1">
    <if test="my:breakBefore(.)"><text>&#xa;</text><if test="ancestor::work"><text>  </text></if></if>
    <element name="{local-name()}" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
      <apply-templates select="node()|@*"/>
      <if test="my:breakAfter(.)"><text>&#xa;</text></if>
    </element>
  </template>
  
  <template match="comment()"><text>&#xa;</text><copy/></template>
  
  <!-- Determine elements with line-breaks before/after -->
  <function name="my:breakBefore" as="xs:boolean">
    <param name="element" as="element()"/>
    <value-of 
      select="matches(local-name($element),'^(p|lb|figure|title|list|item|lg|l|osis|osisText|div|chapter)$')
              or $element[self::milestone[starts-with(@type,'x-usfm-toc') or @type='x-vsys-verse-start']]
              or $element[ancestor-or-self::header] or $element[self::verse[@sID]]"/>
  </function>
  <function name="my:breakAfter" as="xs:boolean">
    <param name="element" as="element()"/>
    <value-of 
      select="matches(local-name($element),'^(osis|osisText|header|work|div|list|lg)$')"/>
  </function>
  
</stylesheet>
