<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/osis2fb2"
 xmlns:oo="http://github.com/JohnAustinDev/osis-converters/osis2other"
 xmlns:fb2="http://www.gribuser.ru/xml/fictionbook/2.0"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:xlink="http://www.w3.org/1999/xlink"
 xmlns:xs="http://www.w3.org/2001/XMLSchema">

  <!-- TRANSFORM A BIBLE OSIS FILE, AND ITS REFERENCE FILES, INTO AN FB2 FILE
    To run this transform from the command line:
    $ saxonb-xslt -ext:on -xsl:osis2fb2.xsl -s:main.osis.xml -o:output.fb2
  -->

  <import href="../common/functions.xsl"/>

  <import href="../whitespace.xsl"/>

  <import href="./osis2other.xsl"/>

  <variable name="target" select="'fb2'"/>

  <!-- Don't convert Unicode SOFT HYPHEN to "&shy;" in html output files.
  Because SOFT HYPHENs are currently being stripped out by the Calibre
  EPUB output plugin, and they break html in browsers (without first
  defining the entity). To reinstate &shy; uncomment the following line and
  add 'use-character-maps="xhtml-entities"' to <output name="htmlfiles"/> below -->
  <!-- <character-map name="xhtml-entities"><output-character character="&#xad;" string="&#38;shy;"/></character-map> !-->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no"/>

  <!-- ROOT TEMPLATE -->
  <template match="/">
    <call-template name="oc:prepareRunTime"/>

    <call-template name="Log">
      <with-param name="msg">
      isChildrensBible = <value-of select="$isChildrensBible"/>
      isGenericBook = <value-of select="$isGenericBook"/>
      doCombineGlossaries = <value-of select="$doCombineGlossaries"/>
      includeNavMenuLinks = <value-of select="$includeNavMenuLinks"/>
      glossaryToc = <value-of select="$glossaryToc"/>
      keywordFile = <value-of select="$keywordFile"/>
      eachChapterIsFile = <value-of select="$eachChapterIsFile"/>
      </with-param>
    </call-template>

    <variable name="preprocessedMainOSIS0">
      <call-template name="preprocessMain"/>
    </variable>

    <variable name="preprocessedRefOSIS0">
      <call-template name="preprocessDict"/>
    </variable>

    <variable name="combinedGlossary">
      <call-template name="combinedGlossary"/>
    </variable>

    <variable name="preprocessedMainOSIS">
      <variable name="removeDivs">
        <apply-templates mode="removeDivs" select="$preprocessedMainOSIS0"/>
      </variable>
      <apply-templates mode="sections" select="$removeDivs"/>
    </variable>

    <variable name="preprocessedRefOSIS">
      <variable name="removeDivs">
        <apply-templates mode="removeDivs" select="$preprocessedRefOSIS0"/>
      </variable>
      <apply-templates mode="sections" select="$removeDivs"/>
    </variable>

    <result-document href="preprocessedOSIS.xml">
      <for-each select="($preprocessedMainOSIS, $preprocessedRefOSIS)">
        <apply-templates mode="whitespace.xsl" select="."/>
      </for-each>
      <sequence select="$preprocessedMainOSIS"/>
    </result-document>

    <variable name="fb2">
      <call-template name="fb2">
        <with-param name="currentTask" select="'write-output'" tunnel="yes"/>
        <with-param name="preprocessedMainOSIS" select="$preprocessedMainOSIS" tunnel="yes"></with-param>
        <with-param name="combinedGlossary" select="$combinedGlossary" tunnel="yes"></with-param>
        <with-param name="preprocessedRefOSIS" select="$preprocessedRefOSIS" tunnel="yes"/>
      </call-template>
    </variable>

    <apply-templates mode="whitespace.xsl" select="$fb2"/>

    <call-template name="oc:cleanupRunTime"/>
  </template>

  <!-- FB2 STRUCTURAL TEMPLATE -->
  <template name="fb2">
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>

    <element name="FictionBook" namespace="http://www.gribuser.ru/xml/fictionbook/2.0">
      <namespace name="xlink">http://www.w3.org/1999/xlink</namespace>

      <fb2:stylesheet type="text/css">
        <for-each select="tokenize($css, '\s*,\s*')">
          <if test="unparsed-text-available(.)">
            <text>&#xa;</text><value-of select="unparsed-text(.)"/>
          </if>
          <if test="not(unparsed-text-available(.))">
            <call-template name="Error"><with-param name="msg" select="concat('Could not find CSS file: ', .)"/></call-template>
          </if>
        </for-each>
      </fb2:stylesheet>

      <description xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
        <title-info>
          <genre>religion</genre>
          <author>
            <first-name></first-name>
            <last-name><xsl:sequence select="oc:locConf('CopyrightHolder', 'ru', .)"/></last-name>
          </author>
          <book-title>
            <xsl:sequence select="oc:locConf('TranslationTitle', 'ru', .)"/>
          </book-title>
          <lang>
            <xsl:sequence select="replace(oc:locConf('Lang', 'ru', .), '-.*$', '')"/>
          </lang>
        </title-info>
        <document-info>
          <author>
            <first-name></first-name>
            <last-name><xsl:sequence select="oc:locConf('CopyrightHolder', 'ru', .)"/></last-name>
          </author>
          <program-used>osis-converters</program-used>
          <date><xsl:sequence select="current-date()"/></date>
          <id><xsl:sequence select="generate-id()"/></id>
          <version><xsl:sequence select="oc:locConf('Version', 'ru', .)"/></version>
        </document-info>
        <publish-info>
            <publisher>
              <xsl:sequence select="oc:locConf('CopyrightHolder', 'ru', .)"/>
            </publisher>
        </publish-info>
      </description>

      <fb2:body>
        <for-each select="($preprocessedMainOSIS | $preprocessedRefOSIS)">
          <apply-templates mode="tran" select="."/>
        </for-each>
      </fb2:body>

      <if test="($preprocessedMainOSIS | $preprocessedRefOSIS)//note">
        <fb2:body name="notes">
          <fb2:title><fb2:p>Footnotes</fb2:p></fb2:title>
          <for-each select="($preprocessedMainOSIS | $preprocessedRefOSIS)//note">
            <fb2:section id="{oc:id(@osisID)}">
              <fb2:title>
                <fb2:p>
                  <call-template name="getFootnoteSymbol">
                    <with-param name="parentName" select="'p'"/>
                  </call-template>
                </fb2:p>
              </fb2:title>
              <fb2:p><apply-templates mode="tran"/></fb2:p>
            </fb2:section>
          </for-each>
        </fb2:body>
      </if>

      <for-each select="($preprocessedMainOSIS | $preprocessedRefOSIS)//figure">
        <variable name="type" select="
          if (ends-with(lower-case(./@src), 'jpg'))
          then 'jpeg'
          else replace(lower-case(./@src), '^.*?([^\.]+)$', '$1')"/>
        <fb2:binary id="{oo:imageID(.)}" content-type="image/{$type}">
          <value-of select="oc:read-binary-resource(./@src)"/>
        </fb2:binary>
      </for-each>

    </element>
  </template>

  <!-- The fb2:section parent must be body or section, and its siblings must
  also be section elements. OSIS chapter, keyword and TOC milestone elements
  will all be transformed into fb2:section elements. So this preprocess step
  insures the fb2:section schema will be met after that transformation. This
  step follows these other preprocess steps that have already been run:
    preprocess_removeSectionDivs
    preprocess_expelChapterTags
    preprocess_glossTocMenus
    preprocess_addGroupAttribs
  The strategy for FB2 is to remove all div elements and flatten all input
  documents. Then successively group children by tocElement level 1, 2 then 3
  where each group leader is either a TOC element or child[1]. NOTE: child[1]
  always leads the first group and may or may not be a TOC element!
  IMPORTANT: In the FB2 standard, the detached TOC is determined entirely by
  the fb2:section elements, whereas the inline TOC is a collection of links.
  -->
  <template mode="removeDivs sections" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>

  <template mode="removeDivs" priority="1" match="div[@type='x-keyword']">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>

  <template mode="removeDivs" match="header"/>

  <template mode="removeDivs" match="div">
    <if test="@osisID"><osis:seg type="x-osisID" osisID="{@osisID}"/></if>
    <apply-templates mode="#current"/>
  </template>

  <!-- Mark sectionLevelFB2 elements with the level to be used for subsequent
  grouping into fb2 sections during the sections mode. These section elements
  will solely determine the FB2 detached TOC. Also write explicit TOC levels to
  each TOC element because otherwise oo:getTocLevel(.) will no longer work
  properly after the removeDivs mode transformation! -->
  <template mode="removeDivs" priority="2" match="
      chapter[@sID] |
      div[@type='x-keyword'] |
      milestone[@type=concat('x-usfm-toc', $TOC)]">
    <variable name="tocElement" select="
      if (self::div[@type='x-keyword']) then .//seg[@type='keyword'][1] else ."/>
    <variable name="fullTitle" select="oo:getTocFullTitle($tocElement)"/>
    <variable name="level" select="oo:getTocLevel($tocElement)"/>
    <choose>
      <when test="
        contains($fullTitle, '[no_toc]') or
        contains($fullTitle, '[only_inline_toc]')">
        <next-match/>
      </when>
      <otherwise>
        <copy>
          <apply-templates mode="#current" select="@*"/>
          <if test="not(self::div[@type='x-keyword'])">
            <sequence select="me:getTocLevelAttribute(.)"/>
          </if>
          <attribute name="sectionLevelFB2" select="$level"/>
          <apply-templates mode="#current"/>
        </copy>
      </otherwise>
    </choose>
  </template>

  <!-- Each TOC element must have explicit toclevel, which happens for most toc
  elements in the above template. But although glossary keywords are grouped
  using their parent div, their seg descendant is the actual tocElement. So add
  @n to those too now. -->
  <template mode="removeDivs" match="seg[@type='keyword']">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <sequence select="me:getTocLevelAttribute(.)"/>
      <apply-templates mode="#current"/>
    </copy>
  </template>

  <!-- TODO: The sectionLevelFB2 attributes are no longer needed or used now. -->
  <!--<template mode="sections" priority="1" match="@sectionLevelFB2"/>-->

  <template mode="sections" match="osisText">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <sequence select="me:sections(./node(), 1)"/>
    </copy>
  </template>

  <function name="me:getTocLevelAttribute" as="attribute()">
    <param name="tocElement" as="element()"/>
    <variable name="fullTitle" select="oo:getTocFullTitle($tocElement)"/>
    <attribute name="n" select="
      concat(
        '[level', oo:getTocLevel($tocElement), ']',
        replace($fullTitle, '\[level\d\]', '')
      )"/>
  </function>

  <function name="me:sections">
    <param name="children" as="node()*"/>
    <param name="level" as="xs:integer"/>
    <choose>
      <when test="$children[@sectionLevelFB2 = $level]">
        <for-each-group select="$children" group-starting-with="*[@sectionLevelFB2 = $level]">
          <choose>
            <when test="current()[not(@sectionLevelFB2)]">
              <if test="current-group()//text()[normalize-space()]">
                <call-template name="ErrorBug">
<with-param name="msg">Text of FB2 must not proceed the first TOC entry: <value-of select="string(current-group())"/></with-param>
                </call-template>
              </if>
            </when>
            <otherwise>
              <!-- Since section id comes from the first contained toc element,
              and since a section which has section children will reference the
              same toc element as its first section child, the id of the parent
              must get '.parent' appended to keep it unique. -->
              <variable name="isParent" select="
                current-group()[@sectionLevelFB2 = $level + 1]"/>
              <variable name="osisID" select="
                concat(
                  current()/descendant-or-self::*[@osisID][1]/@osisID,
                  if ($isParent) then '.parent' else ''
                )"/>
              <osis:div type="fb2:section" osisID="{$osisID}" subType="level{$level}">
                <sequence select="me:sections(current-group(), $level + 1)"/>
              </osis:div>
            </otherwise>
          </choose>
        </for-each-group>
      </when>
      <when test="$level = 1">
        <osis:div type="fb2:section" subType="level{$level}">
          <apply-templates mode="sections" select="$children"/>
        </osis:div>
      </when>
      <otherwise>
        <apply-templates mode="sections" select="$children"/>
      </otherwise>
    </choose>
  </function>

</stylesheet>
