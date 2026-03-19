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

  <key name="id" match="*[@id]" use="@id"/>

  <output method="xml" version="1.0" encoding="utf-8"
    omit-xml-declaration="no"/>

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
      </with-param>
    </call-template>

    <!-- apply osis2other.xsl preprocessing -->
    <variable name="preprocessedMainOSIS">
      <call-template name="preprocessMain"/>
    </variable>

    <variable name="preprocessedRefOSIS">
      <call-template name="preprocessDict"/>
    </variable>

    <variable name="combinedGlossary">
      <call-template name="combinedGlossary"/>
    </variable>

    <!-- apply osis2fb2.xsl preprocessing -->
    <variable name="preprocessedMainOSIS_FB2">
      <variable name="removeDivs">
        <apply-templates mode="removeDivsFB2" select="$preprocessedMainOSIS"/>
      </variable>
      <apply-templates mode="sectionsFB2" select="$removeDivs"/>
    </variable>

    <variable name="preprocessedRefOSIS_FB2">
      <variable name="removeDivs">
        <apply-templates mode="removeDivsFB2" select="$preprocessedRefOSIS"/>
      </variable>
      <apply-templates mode="sectionsFB2" select="$removeDivs"/>
    </variable>

    <variable name="combinedGlossary_FB2">
      <variable name="removeDivs">
        <apply-templates mode="removeDivsFB2" select="$combinedGlossary"/>
      </variable>
      <apply-templates mode="sectionsFB2" select="$removeDivs"/>
    </variable>

    <!-- write debug OSIS file snapshot just before transformation
    <result-document href="preprocessedOSIS.xml">
      <for-each select="(
            $preprocessedMainOSIS_FB2,
            $preprocessedRefOSIS_FB2,
            $combinedGlossary_FB2
          )">
        <apply-templates mode="whitespace.xsl" select="."/>
      </for-each>
    </result-document> -->

    <!-- transform OSIS to FB2 -->
    <variable name="fb2">
      <call-template name="fb2">
        <with-param name="inputOSIS" select="(
            $preprocessedMainOSIS_FB2 |
            $preprocessedRefOSIS_FB2 |
            $combinedGlossary_FB2
          )"/>
        <with-param name="currentTask" select="'write-output'" tunnel="yes"/>
        <with-param name="preprocessedMainOSIS" select="$preprocessedMainOSIS"
          tunnel="yes"/>
        <with-param name="preprocessedRefOSIS" select="$preprocessedRefOSIS"
          tunnel="yes"/>
        <with-param name="combinedGlossary" select="$combinedGlossary"
          tunnel="yes"/>
      </call-template>
    </variable>

    <!-- postprocess FB2 -->
    <variable name="postProcessFB2">
      <apply-templates mode="postprocessFB2" select="$fb2"/>
    </variable>

    <apply-templates mode="whitespace.xsl" select="$postProcessFB2"/>

    <call-template name="oc:cleanupRunTime"/>
  </template>

  <!-- FB2 STRUCTURAL TEMPLATE -->
  <template name="fb2">
    <param name="inputOSIS"/>
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>

    <element name="FictionBook"
      namespace="http://www.gribuser.ru/xml/fictionbook/2.0">
      <namespace name="xlink">http://www.w3.org/1999/xlink</namespace>

      <fb2:stylesheet type="text/css">
        <for-each select="tokenize($css, '\s*,\s*')">
          <if test="unparsed-text-available(.)">
            <text>&#xa;</text><value-of select="unparsed-text(.)"/>
          </if>
          <if test="not(unparsed-text-available(.))">
            <call-template name="Error">
<with-param name="msg" select="concat('Could not find CSS file: ', .)"/>
            </call-template>
          </if>
        </for-each>
      </fb2:stylesheet>

      <description xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
        <title-info>
          <genre>religion</genre>
          <author>
            <first-name></first-name>
            <last-name>
              <xsl:sequence select="oc:locConf('CopyrightHolder', 'ru', .)"/>
            </last-name>
          </author>
          <book-title>
            <xsl:sequence select="oc:locConf('TranslationTitle', 'ru', .)"/>
          </book-title>
          <lang>
            <xsl:sequence select="
              replace(oc:locConf('Lang', 'ru', .), '-.*$', '')"/>
          </lang>
        </title-info>
        <document-info>
          <author>
            <first-name></first-name>
            <last-name>
              <xsl:sequence select="oc:locConf('CopyrightHolder', 'ru', .)"/>
            </last-name>
          </author>
          <program-used>osis-converters</program-used>
          <date><xsl:sequence select="current-date()"/></date>
          <id><xsl:sequence select="generate-id()"/></id>
          <version>
            <!-- The FB2 schema requires version to be xs:float -->
            <xsl:sequence select="replace(
                oc:locConf('Version', 'ru', .), '^(\d+\.\d+).*?$', '$1'
              )"/>
          </version>
        </document-info>
        <publish-info>
            <publisher>
              <xsl:sequence select="oc:locConf('CopyrightHolder', 'ru', .)"/>
            </publisher>
        </publish-info>
      </description>

      <fb2:body>
        <for-each select="$inputOSIS">
          <apply-templates mode="tran" select="."/>
        </for-each>
      </fb2:body>

      <if test="$inputOSIS//note">
        <fb2:body name="notes">
          <fb2:title>
            <fb2:p id="{concat('p.1.', generate-id(.))}">Footnotes</fb2:p>
          </fb2:title>
          <for-each select="$inputOSIS//note">
            <variable name="content" as="node()*">
              <apply-templates mode="tran"/>
            </variable>
            <if test="$content">
              <fb2:section id="{oc:id(@osisID)}">
                <fb2:title>
                  <fb2:p id="{concat('p.2.', generate-id(.))}">
                    <call-template name="getFootnoteSymbol">
                      <with-param name="parentName" select="'p'"/>
                    </call-template>
                  </fb2:p>
                </fb2:title>
                <sequence select="oo:fb2SectionContent($content)"/>
              </fb2:section>
            </if>
          </for-each>
          <if test="
            $FullResourceURL and
            $FullResourceURL != 'false' and
            boolean($inputOSIS//reference[@subType='x-other-resource'])">
            <fb2:section id="fullResourceURL">
              <fb2:title>
                <fb2:p>
                  <sequence select="oo:getClassedContent(
                      (), 'p', '+', 'xsl-note-head xsl-crnote-symbol'
                    )"/>
                </fb2:p>
              </fb2:title>
              <fb2:p><value-of select="$FullResourceURL"/></fb2:p>
            </fb2:section>
          </if>
        </fb2:body>
      </if>

      <for-each select="distinct-values($inputOSIS//figure/@src)">
        <variable name="type" select="
          if (ends-with(lower-case(.), 'jpg'))
          then 'jpeg'
          else replace(lower-case(.), '^.*?([^\.]+)$', '$1')"/>
        <fb2:binary id="{replace(., '^.*/', 'image.')}"
            content-type="image/{$type}">
          <value-of select="oc:read-binary-resource(.)"/>
        </fb2:binary>
      </for-each>

    </element>
  </template>

  <!-- An fb2:section parent must be body or section, and its siblings must
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
  always leads the first group and so the first TOC element of the main doc-
  ument must come before the first text node.
  IMPORTANT: In the FB2 standard, the detached TOC is determined entirely by
  the fb2:section elements, whereas the inline TOC is still just a collection
  of links.
  -->

  <!-- mode removeDivsFB2 -->

  <template mode="removeDivsFB2 sectionsFB2 postprocessFB2" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>

  <template mode="removeDivsFB2" priority="1" match="div[starts-with(@type, 'x-keyword')]">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>

  <template mode="removeDivsFB2" match="div">
    <osis:div emptied="true">
      <apply-templates mode="#current" select="@*"/>
    </osis:div>
    <apply-templates mode="#current"/>
  </template>

  <!-- Mark sectionLevelFB2 elements with the level to be used for subsequent
  grouping into fb2 sections during the sectionsFB2 mode. These section elements
  will solely determine the FB2 detached TOC. Also write explicit TOC levels to
  each TOC element because otherwise oo:getTocLevel(.) will no longer work
  properly after the removeDivsFB2 mode transformation! -->
  <template mode="removeDivsFB2" priority="2" match="
      chapter[@sID] |
      div[starts-with(@type, 'x-keyword')] |
      milestone[@type=concat('x-usfm-toc', $TOC)]">
    <variable name="tocElement" select="
      if (self::div[starts-with(@type, 'x-keyword')])
      then .//seg[@type='keyword'][1]
      else ."/>
    <variable name="instructions" select="oo:getTocInstructions($tocElement)"/>
    <variable name="level" select="oo:getTocLevel($tocElement)"/>
    <choose>
      <when test="$instructions = ('no_toc', 'only_inline_toc')">
        <next-match/>
      </when>
      <otherwise>
        <copy>
          <if test="not(self::div[starts-with(@type, 'x-keyword')])">
            <attribute name="n" select="me:getN(.)"/>
          </if>
          <attribute name="sectionLevelFB2" select="$level"/>
          <apply-templates mode="#current"
            select="node()|@*[local-name() != 'n']"/>
        </copy>
      </otherwise>
    </choose>
  </template>

  <!-- Each TOC element must have explicit toclevel, which happens for most toc
  elements in the above template. But although glossary keywords are grouped
  using div[starts-with(@type, 'x-keyword')] the descendant seg[@type='keyword']
  is the actual tocElement. So add @n to those too now. -->
  <template mode="removeDivsFB2" match="seg[@type='keyword']">
    <copy>
      <attribute name="n" select="me:getN(.)"/>
      <apply-templates mode="#current"
        select="node()|@*[local-name() != 'n']"/>
    </copy>
  </template>

  <template mode="removeDivsFB2" priority="1" match="comment()"/>
  <template mode="removeDivsFB2" match="title[@type='runningHead']"/>

  <!-- mode sectionsFB2 -->

  <template mode="sectionsFB2" match="osisText">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <sequence select="./header"/>
      <sequence select="me:sections(./node()[not(self::header)], 1)"/>
    </copy>
  </template>

  <template mode="sectionsFB2" priority="1" match="@sectionLevelFB2"/>

  <!-- mode postprocessFB2 -->

  <template mode="postprocessFB2" match="@osisID"/>

  <template mode="postprocessFB2" match="fb2:tmpOsisID"/>

  <!-- Only the certain FB2 elements may have ids (image, p, v, poem, cite,
  epigraph, annotation, section, table and td). Therefore links targetting
  verses and osisIDs must be mapped to an element having an id. -->
  <template mode="postprocessFB2" match="@xlink:href">
    <variable name="id" select="substring(., 2)"/>
    <variable name="linkTarget" select="key('id', $id) | key('osisID', $id)"/>
    <choose>
      <when test="count($linkTarget)">
        <variable name="newID" select="
          concat('#',
            if ($linkTarget[1][@id])
            then $linkTarget[1]/@id
            else $linkTarget[1]/preceding::*[@id][1]/@id
          )"/>
        <choose>
          <when test="$newID">
            <attribute name="xlink:href" select="$newID"/>
          </when>
          <otherwise>
            <call-template name="ErrorBug">
<with-param name="msg">Link target element <value-of select="oc:printNode($linkTarget)"/> could not be mapped.</with-param>
            </call-template>
          </otherwise>
        </choose>
      </when>
      <otherwise>
        <call-template name="ErrorBug">
<with-param name="msg">Link target id or osisID <value-of select="."/> does not exist.</with-param>
        </call-template>
        <next-match/>
      </otherwise>
    </choose>
  </template>

<!-- TODO: Large FB2 will not load due to the number of notes!
Also notes appear in the TOC which makes it far too large!
  <template mode="postprocessFB2" match="fb2:a[contains(@xlink:href, 'crossReference.r')]"/>
  <template mode="postprocessFB2" match="fb2:section[contains(@id, 'crossReference.r')]"/>
-->

  <!-- functions -->

  <function name="me:getN" as="xs:string">
    <param name="tocElement" as="element()"/>
    <variable name="ntitle" select="
      replace($tocElement/@n, '^(\[[^\]]*\])+', '')"/>
    <variable name="level" select="oo:getTocLevel($tocElement)"/>
    <variable name="instructions" as="xs:string+">
      <for-each select="
          (concat('level', $level), oo:getTocInstructions($tocElement))">
        <if test="position() = 1 or not(matches(., '^level\d$'))">
          <value-of select="concat('[', ., ']')"/>
        </if>
      </for-each>
    </variable>
    <value-of select="concat(string-join($instructions, ''), $ntitle)"/>
  </function>

  <function name="me:sections">
    <param name="children" as="node()*"/>
    <param name="level" as="xs:integer"/>
    <choose>
      <when test="$children[@sectionLevelFB2 = $level]">
        <for-each-group select="$children" group-starting-with="*[@sectionLevelFB2 = $level]">
          <!-- Since section id comes from the first contained toc element,
          and since a section which has section children will reference the
          same toc element as its first section child, the id of the parent
          must get 'parent.' prepended to make it unique. -->
          <variable name="isParent" select="
            current-group()[@sectionLevelFB2 = $level + 1]"/>
          <variable name="descOsisID" select="
              current()/descendant-or-self::*[@osisID][1]/@osisID"/>
          <variable name="osisID" select="
            concat(
              if ($isParent) then 'parent.' else '',
              if ($descOsisID)
                then $descOsisID
                else concat('unknown.', generate-id(current()))
            )"/>
          <choose>
            <when test="
                current()[not(@sectionLevelFB2)] and
                not(current-group()//text()[normalize-space()])">
              <!-- without text content, this should render to nothing as FB2 -->
              <sequence select="me:sections(current-group(), $level + 1)"/>
            </when>
            <otherwise>
              <osis:div type="fb2:section" osisID="{$osisID}" subType="level{$level}">
                <sequence select="me:sections(current-group(), $level + 1)"/>
              </osis:div>
              <if test="current()[not(@sectionLevelFB2)]">
                <call-template name="Error">
<with-param name="msg">FB2 text must not proceed the first TOC entry: '<value-of select="string-join(current-group()/normalize-space(string()), ' ')"/>'</with-param>
<with-param name="exp">Add a toc tag or move the existing toc tag before this text.</with-param>
                </call-template>
              </if>
            </otherwise>
          </choose>
        </for-each-group>
      </when>
      <when test="$level = 1">
        <osis:div type="fb2:section" subType="level{$level}">
          <apply-templates mode="sectionsFB2" select="$children"/>
        </osis:div>
      </when>
      <otherwise>
        <apply-templates mode="sectionsFB2" select="$children"/>
      </otherwise>
    </choose>
  </function>

</stylesheet>
