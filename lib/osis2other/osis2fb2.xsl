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

    <!-- write debug OSIS file snapshot just before transformation -->
    <result-document href="preprocessedOSIS.xml">
      <for-each select="(
            $preprocessedMainOSIS,
            $preprocessedRefOSIS,
            $combinedGlossary
          )">
        <apply-templates mode="whitespace.xsl" select="."/>
      </for-each>
    </result-document>

    <!-- transform OSIS to FB2 -->
    <variable name="fb2">
      <call-template name="fb2">
        <with-param name="docs" tunnel="yes" select="(
            $preprocessedMainOSIS |
            $preprocessedRefOSIS |
            $combinedGlossary
          )"/>
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
    <param name="docs" tunnel="yes"/>

    <variable name="glossNotes" select="
      $docs/descendant::reference[oo:isGlossaryNote(.)]/
      oo:targetElement(@osisRef, $docs)[self::seg[@type='keyword']]"/>

    <variable name="isbn" select="
      $docs[1]/descendant::work[@osisWork = $MAINMOD][1]/
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
        <for-each select="$docs">
          <apply-templates mode="tran" select="."/>
        </for-each>
      </fb2:body>

      <if test="$docs/descendant::note or $glossNotes">
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
          <for-each select="$docs/descendant::note">
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
                $docs/descendant::reference[@subType='x-other-resource']
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
        distinct-values(('cover.jpg', $docs/descendant::figure/@src))">
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

  <!-- mode postprocessFB2 -->

  <template mode="postprocessFB2" match="@osisID"/>

  <template mode="postprocessFB2" match="fb2:tmpOsisID"/>

  <!-- Only the certain FB2 elements may have ids (image, p, v, poem, cite,
  epigraph, annotation, section, table and td). Therefore links targetting
  verses and osisIDs must be re-targetted to one of these elements having an
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

<!-- functions -->

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

</stylesheet>
