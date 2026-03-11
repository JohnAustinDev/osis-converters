<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
  xmlns="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:my="osis-converters/lib/whitespace.xsl"
  xmlns:fb2="http://www.gribuser.ru/xml/fictionbook/2.0"
  xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">

  <!-- This script only effects white-space and element qualified names.
  - It replaces qualified name with local-name for elements of top namespace.
  - It collapses runs of spaces to a single space.
  - It removes all new-lines, except those that are escaped by '\'.
  - Then it adds new-lines before and/or after designated tags.
  -->

  <template match="/"><call-template name="whitespace.xsl"/></template>

  <template mode="whitespace.xsl" match="/" name="whitespace.xsl">
    <message>NOTE: Running whitespace.xsl <value-of select="local-name()"/></message>
    <apply-templates select="." mode="whitespace" />
  </template>

  <!-- By default copy everything as is -->
  <template mode="whitespace" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>

  <!-- Normalize all tags sharing the root element's namespace -->
  <template mode="whitespace" match="*" priority="1">
    <choose>
      <when test="namespace-uri() = /*/namespace-uri()">
        <if test="my:breakBefore(.)">
          <text>&#xa;</text><if test="ancestor::work | ancestor::fb2:description"><text>  </text></if>
        </if>
        <element name="{local-name()}" namespace="{/*/namespace-uri()}">
          <if test=". intersect /*"><copy-of select="namespace::*"/></if>
          <apply-templates mode="#current" select="node()|@*"/>
          <if test="my:breakAfter(.)"><text>&#xa;</text></if>
        </element>
      </when>
      <otherwise>
        <copy><apply-templates mode="#current" select="node()|@*"/></copy>
      </otherwise>
    </choose>
  </template>

  <template mode="whitespace" match="text()" priority="1">
    <!-- Regex does not support Perl (?<!\\)\n look-behind for preserving
    escaped new-lines in some config entries, so use an interim xNLx -->
    <variable name="text1" select="replace(., '\\\n', 'xNLx')"/>

    <!-- Convert sequential \s and \n chars to a single space, everywhere -->
    <variable name="text2" select="replace($text1, '[\s\n]+', ' ')"/>

    <variable name="text3" select="replace($text2, 'xNLx', '\\&#xa;')"/>

    <variable name="TextChildRequired" select="
      if (/*/namespace-uri() = 'http://www.bibletechnologies.net/2003/OSIS/namespace')
      then '^(figure|title|head|item|p|l)$'
      else (if (/*/namespace-uri() = 'http://www.gribuser.ru/xml/fictionbook/2.0')
      then 'NONE'
      else 'NONE')"/>

    <!-- Remove redundant spaces where line breaks will be added (but not if $t
    elements would no longer have a text node child!). Removal is required for
    whitespace.xsl to be idempotent. -->
    <variable name="tcrRE" select="
      if (matches(local-name(parent::*), $TextChildRequired))
      then '\S'
      else ''"/>
    <choose>
      <when test="./following-sibling::node()[1][self::*] and
                  my:breakBefore(./following-sibling::node()[1])">
        <value-of select="replace($text3, ' $', '')"/>
      </when>
      <when test="parent::*//text()[last()][. intersect current()] and
                  my:breakAfter(./parent::*)">
        <value-of select="replace($text3, concat($tcrRE, ' $'), '')"/>
      </when>
      <otherwise><value-of select="$text3"/></otherwise>
    </choose>
  </template>

  <template mode="whitespace" match="comment()" priority="1"><text>&#xa;</text><copy/></template>

  <!-- Elements that will have line-breaks before their start-tag -->
  <function name="my:breakBefore" as="xs:boolean">
    <param name="element" as="element()"/>

    <variable name="rootNS" select="root($element)/*/namespace-uri()"/>
    <variable name="LineBreakBefore" select="
      if ($rootNS = 'http://www.bibletechnologies.net/2003/OSIS/namespace')
      then '^(lb|figure|title|head|list|item|p|lg|l|osis|osisText|div|chapter|table|row)$'
      else (if ($rootNS = 'http://www.gribuser.ru/xml/fictionbook/2.0')
      then '^(FictionBook|stylesheet|description|body|section|title|subtitle|p|empty\\-line|binary)$'
      else 'NONE')"/>

    <choose>
      <!-- No element immediately following a verse start marker (or its following
      none-verse-marker milestones) will have a line break inserted before it. -->
      <when test="$element/preceding-sibling::*
        [not(self::milestone[not(ends-with(@type, 'verse-start'))])]
        [1]
        [self::verse[@sID] or self::milestone[ends-with(@type, 'verse-start')]]">
        <value-of select="false()"/>
      </when>
      <otherwise>
        <value-of
          select="matches(local-name($element), $LineBreakBefore)
              or $element[self::verse[@sID]]
              or $element[self::milestone[starts-with(@type,'x-usfm-toc')]]
              or $element[ancestor-or-self::header]
              or $element[ancestor-or-self::fb2:description]"/>
      </otherwise>
    </choose>
  </function>

  <!-- Elements that will have line-breaks before their end-tag -->
  <function name="my:breakAfter" as="xs:boolean">
    <param name="element" as="element()"/>

    <variable name="rootNS" select="root($element)/*/namespace-uri()"/>
    <variable name="LineBreakAfter" select="
      if ($rootNS = 'http://www.bibletechnologies.net/2003/OSIS/namespace')
      then '^(osis|osisText|header|work|div|list|lg|table)$'
      else (if ($rootNS = 'http://www.gribuser.ru/xml/fictionbook/2.0')
      then '^(FictionBook|stylesheet|description|body|section)$'
      else 'NONE')"/>

    <value-of
      select="matches(local-name($element), $LineBreakAfter)"/>
  </function>

</stylesheet>
