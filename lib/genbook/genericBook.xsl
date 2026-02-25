<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">

  <!-- This stylesheet converts usfm2osis.py osis into osis-converters Generic
  Book osis markup. The childrensBible.xsl stylesheet was the starting point
  for this stylesheet. -->

  <!--
    These SWORD OSIS generic books are entirely structured by following the
    milestone[@type='x-usfm-toc2'] TOC elements. Their @n attribute specifies
    exact hierarchy level and chapter title. The result will have this
    structure:
    <osis>
      <osisText>
        <header/>
        Root chapter is unused (SEE NOTE **)
        <div type="book" osisID="Chapter 1">
          <milestone type="x-usfm-toc2" @n="[level1]Chapter 1">

          <div type="chapter" osisID="Chapter 1/1">
            <milestone type="x-usfm-toc2" @n="[level2]Chapter 1/1">

            <div type="chapter" osisID="Chapter 1/1/1">
              <milestone type="x-usfm-toc2" @n="[level3]Chapter 1/1/1">

              <div type="section">
                  <div type="subSection">
                  </div>
              </div>

            </div>
          </div>
        </div>
        <div type="book" osisID="Chapter 2">...</div>
        ...
      </osisText>
    </osis>

    ** - root is not displayed by xulsword as of Feb 2026, because it is not
         used by any CrossWire sword module I checked. Although it was seen to
         be written IF not enclosed in a div and/or has no text content(?).
  -->

  <import href="../common/functions.xsl"/>

  <!-- Use \toc1, \toc2 or \toc3 tags for creating the TOC -->
  <param name="TOC" select="oc:conf('TOC', /)"/>

  <template mode="#all" match="node()|@*" name="identity">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>

  <template match="/">
    <!-- Re-section the entire OSIS file by removing all divs, then use
    TOC milestones to re-structure it with all new divs -->
    <variable name="pass1">
      <apply-templates mode="removeAllStructure" select="."/>
    </variable>
    <variable name="pass2">
      <apply-templates mode="restructure" select="$pass1/node()"/>
    </variable>
    <apply-templates mode="final" select="$pass2/node()"/>
  </template>

  <template mode="removeAllStructure" match="div | chapter | verse">
    <apply-templates mode="#current"/>
  </template>

  <template mode="restructure" match="osisText">
    <copy>
      <apply-templates mode="#current" select="@*"/>

      <for-each select="header">
        <apply-templates mode="#current" select="."/>
      </for-each>

      <!-- To include all content without utilizing the root chapter, the first
      element MUST be a level1 TOC milestone; so if it is not, then create and
      insert one using a new tree. -->
      <choose>
        <when test="./element()[not(self::header)][1][
            self::milestone[@type=concat('x-usfm-toc', $TOC)]
            [contains(@n, '[level1]')]
          ]">
          <sequence select="oc:writeChapter(
            (),
            ./node()[not(self::header)][not(self::comment())],
            1
          )"/>
        </when>
        <otherwise>
          <variable name="title" select="
            /osis/osisText/header/work
            [@osisWork = /osis/osisText/@osisIDWork]
            /title/string()"/>
          <variable name="topToc" as="element()">
            <osis:milestone
              type="x-usfm-toc{$TOC}"
              n="[level1]{$title}"
              osisID="BIBLE_TOP"
              resp="x-oc"/>
          </variable>
          <variable name="newTree">
            <osis:nt>
              <for-each select="(
                  $topToc,
                  ./node()[not(self::header)][not(self::comment())]
                )">
                <sequence select="."/>
              </for-each>
            </osis:nt>
          </variable>
          <sequence select="oc:writeChapter((), $newTree/nt/node(), 1)"/>
        </otherwise>
      </choose>
    </copy>
  </template>

  <!-- Keywords are treated as TOC elements by osis2xhtml.xsl, so change
  them to something else-->
  <template mode="final" match="seg[@type='keyword']">
    <osis:hi type="italic" subType="x-keyword">
      <osis:hi type="bold">
        <apply-templates mode="#current" select="node()"/>
      </osis:hi>
    </osis:hi>
  </template>

  <!-- Chapter Label titles are removed by osis2xhtml.xsl, so remove
  the type attribute for them.-->
  <template mode="final" match="title/@type['x-chapterLabel']"/>

  <!-- Make line groups indented -->
  <template mode="final" match="l[@level = '1']">
    <copy>
      <attribute name="type">x-indent</attribute>
      <apply-templates mode="#current" select="node()|@*"/>
    </copy>
  </template>

  <!-- Remove soft-hyphens from chapter names (osisIDs) -->
  <template mode="final" match="div[@osisID]/@osisID">
    <copy>
      <value-of select="replace(., codepoints-to-string(173), '')"/>
    </copy>
  </template>

  <!-- If $tocElement is not empty, output a div having the corresponding
  osisID (necessary for SWORD's xml2gbs importer), then in either case
  output the $nodes using oc:writeChapterContent() by passing the appropriate
  level number. -->
  <function name="oc:writeChapter" as="node()*">
    <param name="tocElement" as="element()?"/>
    <param name="nodes" as="node()*"/>
    <param name="level" as="xs:integer"/>

    <choose>
      <when test="$tocElement">
        <variable
          name="title"
          select="replace($tocElement/@n, '^(\[[^\]]*\])+', '')"/>
        <variable name="nextLevel" select="$level + 1"/>
        <variable
          name="type"
          select="if ($level = 1) then 'book' else 'chapter'"/>
        <osis:div type="{ $type }" osisID="{ oc:encodeOsisRef($title) }">
          <sequence select="$tocElement"/>
          <sequence select="oc:writeChapterContent($nodes, $nextLevel)"/>
        </osis:div>
      </when>
      <otherwise>
        <sequence select="oc:writeChapterContent($nodes, $level)"/>
      </otherwise>
    </choose>
  </function>

  <!-- Output $nodes unchanged unless one or more are TOC milestones of level
  $level, in which case output grouped $nodes inside new chapter div(s). -->
  <function name="oc:writeChapterContent" as="node()*">
    <param name="nodes" as="node()*"/>
    <param name="level" as="xs:integer"/>

    <for-each-group select="$nodes"
        group-adjacent="
          count(
            preceding::milestone[@type=concat('x-usfm-toc', $TOC)]
            [contains(@n, concat('[level', $level, ']'))]
          ) +
          count(
            self::milestone[@type=concat('x-usfm-toc', $TOC)]
            [contains(@n, concat('[level', $level, ']'))]
          )">
      <choose>
        <when test="current-group()[1][
            self::milestone[@type=concat('x-usfm-toc', $TOC)]
            [contains(@n, concat('[level', $level, ']'))]
          ]">
          <sequence select="oc:writeChapter(
            current-group()[1],
            current-group()[position() > 1],
            $level
          )"/>
        </when>
        <otherwise>
          <for-each select="current-group()">
            <call-template name="identity"/>
          </for-each>
        </otherwise>
      </choose>
    </for-each-group>
  </function>

</stylesheet>
