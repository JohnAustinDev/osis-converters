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

  <param name="keywords"/>

  <param name="date"/>

  <param name="year"/>

  <param name="translator"/>

  <param name="fb2publisher"/>

  <variable name="target" select="'fb2'"/>

  <variable name="EnableFB2CSS" select="false()"/>

  <variable name="EnableFB2FullResourceURL" select="false()"/>

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

    <!-- write debug OSIS file snapshot just before transformation -->
    <result-document href="preprocessedOSIS.xml">
      <for-each select="(
            $preprocessedMainOSIS_FB2,
            $preprocessedRefOSIS_FB2,
            $combinedGlossary_FB2
          )">
        <apply-templates mode="whitespace.xsl" select="."/>
      </for-each>
    </result-document>

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

    <variable name="glossNotes" select="
      $inputOSIS/descendant::reference[oo:isGlossaryNote(.)]/
      oo:targetElement(@osisRef, $inputOSIS)[self::seg[@type='keyword']]"/>

    <variable name="isbn" select="
      $inputOSIS[1]/descendant::work[@osisWork = $MAINMOD][1]/
      identifier[@type='ISBN'][1]/text()"/>

    <element name="FictionBook"
      namespace="http://www.gribuser.ru/xml/fictionbook/2.0">
      <namespace name="xlink">http://www.w3.org/1999/xlink</namespace>

      <if test="$EnableFB2CSS">
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
      </if>

      <description xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
        <title-info>
          <genre>religion</genre>
          <author>
            <first-name></first-name>
            <last-name>
              <xsl:value-of select="oc:locConf('CopyrightHolder', 'ru', .)"/>
            </last-name>
          </author>
          <book-title>
            <xsl:value-of select="oc:locConf('TranslationTitle', 'ru', .)"/>
          </book-title>
          <xsl:if test="$keywords">
            <keywords><xsl:value-of select="$keywords"/></keywords>
          </xsl:if>
          <xsl:if test="$date">
            <date><xsl:value-of select="$date"/></date>
          </xsl:if>
          <coverpage><image xlink:href="#cover.jpg"/></coverpage>
          <lang>
            <xsl:value-of select="
              replace(oc:locConf('Lang', 'en', .), '-.*$', '')"/>
          </lang>
          <xsl:if test="$translator">
            <translator><xsl:value-of select="$translator"/></translator>
          </xsl:if>
        </title-info>
        <document-info>
          <author>
            <first-name></first-name>
            <last-name>
              <xsl:value-of select="oc:locConf('CopyrightHolder', 'ru', .)"/>
            </last-name>
          </author>
          <program-used>osis-converters</program-used>
          <date><xsl:value-of select="current-date()"/></date>
          <id><xsl:value-of select="generate-id()"/></id>
          <version>
            <!-- The FB2 schema requires version to be xs:float -->
            <xsl:value-of select="replace(
                oc:locConf('Version', 'ru', .), '^(\d+\.\d+).*?$', '$1'
              )"/>
          </version>
          <xsl:if test="$fb2publisher">
            <publisher><xsl:value-of select="$fb2publisher"/></publisher>
          </xsl:if>
        </document-info>
        <publish-info>
          <book-name>
            <xsl:value-of select="oc:locConf('TranslationTitle', 'ru', .)"/>
          </book-name>
          <publisher>
            <xsl:value-of select="oc:locConf('CopyrightHolder', 'ru', .)"/>
          </publisher>
          <xsl:if test="$year">
            <year><xsl:value-of select="$year"/></year>
          </xsl:if>
          <xsl:if test="$isbn">
            <isbn><xsl:value-of select="$isbn"/></isbn>
          </xsl:if>
        </publish-info>
      </description>

      <fb2:body>
        <for-each select="$inputOSIS">
          <apply-templates mode="tran" select="."/>
        </for-each>
      </fb2:body>

      <if test="$inputOSIS/descendant::note or $glossNotes">
        <fb2:body name="notes">
          <!-- glossary keywords as notes (included also in TOC) -->
          <for-each select="$glossNotes">
            <variable name="keyword" as="node()*" select="text()"/>
            <!-- remove disambiguation headings and keyword -->
            <variable name="body" as="node()*">
              <variable name="filteredOsis">
                <apply-templates mode="filterOsisGlossNoteBody" select="
                  ancestor::div[starts-with(@type, 'x-keyword')][1]/node()"/>
              </variable>
              <apply-templates mode="tran" select="$filteredOsis"/>
            </variable>
            <fb2:section id="{oc:id(@osisID)}.note">
              <!-- no title for notes (or TOC blows up!) -->
              <sequence select="oo:fb2SectionContent(me:formattedNote(
                  $keyword, true(), $body
                ))"/>
            </fb2:section>
          </for-each>
          <!-- regular notes -->
          <for-each select="$inputOSIS/descendant::note">
            <variable name="symbol">
              <call-template name="getFootnoteSymbol">
                <with-param name="parentName" select="'x'"/>
              </call-template>
            </variable>
            <variable name="body" as="node()*">
              <apply-templates mode="tran"/>
            </variable>
            <fb2:section id="{oc:id(@osisID)}">
              <!-- no title for notes (or TOC blows up!) -->
              <sequence select="
                oo:fb2SectionContent(me:formattedNote(
                    $symbol, false(), $body
                  ))"/>
            </fb2:section>
          </for-each>
          <!-- FullResourceURL note -->
          <if test="
              $EnableFB2FullResourceURL and
              $FullResourceURL and
              $FullResourceURL != 'false' and
              boolean(
                $inputOSIS/descendant::reference[@subType='x-other-resource']
              )">
            <fb2:section id="fullResourceURL">
              <fb2:p>
                <fb2:strong>
                  <sequence select="oo:getClassedContent(
                        (), 'x', '+', 'xsl-note-head xsl-crnote-symbol'
                      )"/>
                </fb2:strong>
                <text> </text>
                <value-of select="$FullResourceURL"/>
              </fb2:p>
            </fb2:section>
          </if>
        </fb2:body>
      </if>

      <for-each select="
        distinct-values(('cover.jpg', $inputOSIS/descendant::figure/@src))">
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

  <!-- Identity template for many modes -->
  <template mode="
      removeDivsFB2
      sectionsFB2
      postprocessFB2
      filterOsisGlossNoteBody
      formattedBody"
      match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>

  <!-- Glossary note body filter mode -->
  <template mode="filterOsisGlossNoteBody" match="title[
      @subType=('x-glossary-scope', 'x-glossary-title')
    ]"/>
  <template mode="filterOsisGlossNoteBody" match="seg[@type='keyword']"/>
  <template mode="filterOsisGlossNoteBody" match="
    p[child::seg[@type='keyword']][not(child::text())]"/>

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
  ument must come first (before the first text node) or an error is thrown.
  IMPORTANT: In the FB2 standard, the detached TOC is determined entirely by
  the fb2:section elements, whereas the inline TOC is still just a collection
  of links.
  -->

  <!-- mode removeDivsFB2 -->

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
      then descendant::seg[@type='keyword'][1]
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
      <attribute name="isNote" select="
          if ( ancestor::div[@type='glossary'][1]
            [@scope='NAVMENU' or @annotateRef='INT'] )
          then 'no'
          else 'yes'"/>
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
  verses and osisIDs must be re-targetted to one of these elements with an
  id. -->
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

<!-- TODO: Large FB2 will not load in Calibre due to the number of notes. But
does load in Android FBReader. In Calibre, notes appear in the TOC which makes
it far too large!
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

<!-- Since note popups might only show the first p, the first p should not be
just a heading. So if the body starts with a paragraph, insert the heading
into the beginning of that paragraph, otherwise create a paragraph containing
the heading and the following body nodes up to the firstNoParaChild element.
Or if there is no firstNoParaChild element, then create a p containing the
heading and all body nodes. -->
  <function name="me:formattedNote" as="node()*">
    <param name="heading" as="node()*"/>
    <param name="useSeparator" as="xs:boolean"/>
    <param name="body" as="node()*"/>
    <variable name="formattedHead" as="element(fb2:strong)">
      <fb2:strong><sequence select="$heading"/></fb2:strong>
    </variable>
    <variable name="formattedBody">
      <fb2:tmp>
        <apply-templates mode="formattedBody" select="$body"/>
      </fb2:tmp>
    </variable>
    <variable name="separator" select="
      if ($useSeparator and matches(
          string($formattedBody),
          oc:uniregex('^\s*[\p{gc=L}\p{gc=N}]')
        ))
      then ' - '
      else ' '"/>
    <variable name="firstP" as="element(fb2:p)?" select="
      $formattedBody/fb2:tmp/fb2:p[1]"/>
    <variable name="firstNode" as="node()?" select="
      $formattedBody/fb2:tmp/node()
      [not(self::text()[not(normalize-space())])]
      [1]"/>
    <variable name="firstNoParaChild" as="element()?" select="
      $formattedBody/fb2:tmp/*[
        not(local-name() = (
          'strong',
          'emphasis',
          'style',
          'a',
          'strikethrough',
          'sub',
          'sup',
          'code',
          'image'
        ))
      ][1]"/>
    <choose>
      <when test="$firstP and $firstP is $firstNode">
        <for-each select="$firstP">
          <copy>
            <copy-of select="@*"/>
            <sequence select="$formattedHead"/>
            <sequence select="$separator"/>
            <copy-of select="node()"/>
          </copy>
        </for-each>
        <sequence select="$formattedBody/fb2:tmp/node()[not(. is $firstP)]"/>
      </when>
      <when test="$firstNoParaChild">
        <fb2:p>
          <sequence select="$formattedHead"/>
          <sequence select="$separator"/>
          <sequence select="
            $formattedBody/fb2:tmp/node()[. &#60;&#60; $firstNoParaChild]"/>
        </fb2:p>
        <sequence select="
          $formattedBody/fb2:tmp/node()[
            . is $firstNoParaChild or
            . &#62;&#62; $firstNoParaChild
          ]"/>
      </when>
      <otherwise>
        <fb2:p>
          <sequence select="$formattedHead"/>
          <sequence select="$separator"/>
          <sequence select="$formattedBody/fb2:tmp/node()"/>
        </fb2:p>
      </otherwise>
    </choose>
  </function>
  <!-- Drop nodes without text unless they are image etc. -->
  <template mode="formattedBody" priority="1" match="*">
    <if test="
        normalize-space(string()) or
        descendant-or-self::*[
          local-name() = ('image', 'tmpOsisID', 'empty-line')
        ]">
      <next-match/>
    </if>
  </template>
  <!-- The id attribute causes FBReader for Linux to show footnotes as empty,
  and id is totally unnecessary in footnote bodies, which never contain link
  targets. -->
  <template mode="formattedBody" match="@id"/>

  <function name="me:sections">
    <param name="children" as="node()*"/>
    <param name="level" as="xs:integer"/>
    <choose>
      <when test="$children[@sectionLevelFB2 = $level]">
        <for-each-group select="$children" group-starting-with="*[@sectionLevelFB2 = $level]">
          <variable name="descOsisID" select="
              current()/descendant-or-self::*[@osisID][1]/@osisID"/>
          <variable name="osisID" select="
            if ($descOsisID)
            then $descOsisID
            else concat('unknown.', generate-id(current()))"/>
          <choose>
            <when test="
                current()[not(@sectionLevelFB2)] and
                not(current-group()/
                  descendant-or-self::*[local-name() = ('figure', 'lb')]
                ) and
                not(current-group()/
                  descendant-or-self::text()[normalize-space()]
                )">
              <!-- without text content, this should render to nothing as FB2 -->
              <sequence select="me:sections(current-group(), $level + 1)"/>
            </when>
            <otherwise>
              <osis:div
                  type="fb2:section"
                  position="{position()}"
                  osisID="{$osisID}"
                  subType="level{$level}">
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
