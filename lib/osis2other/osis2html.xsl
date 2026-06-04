<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/osis2html"
 xmlns:oo="http://github.com/JohnAustinDev/osis-converters/osis2other"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:html="http://www.w3.org/1999/xhtml"
 xmlns:epub="http://www.idpf.org/2007/ops"
 exclude-result-prefixes="#all">
  <!--

  OSIS TO HTML
  A main OSIS file and an optional dictionary OSIS file are
  transformed into:

    content.opf       - A manifest of generated and referenced files.
                        This includes html, css, font and image files.

    index.html        - Each TOC section is written to a separate
                        html file. These files are linked by an auto
                        generated inline table-of-contents. Also to
                        facilitate Calibre table-of-content generation,
                        title="toclevel-N" attributes are written.

  This transform may be run by placing osis2html.xsl, functions.xsl and
  referenced OSIS files in the same directory. Then run:
  $ saxonb-xslt -ext:on -xsl:osis2html.xsl -s:main_osis.xml -o:content.opf
  -->

  <import href="../common/functions.xsl"/>

  <import href="./osis2other.xsl"/>

  <variable name="target" select="'html'"/>

  <!-- Don't convert Unicode SOFT HYPHEN to "&shy;" in html output files.
  Because SOFT HYPHENs are currently being stripped out by the Calibre
  EPUB output plugin, and they break html in browsers (without first
  defining the entity). To reinstate &shy; uncomment the following line and
  add 'use-character-maps="xhtml-entities"' to <output name="htmlfiles"/> below -->
  <!-- <character-map name="xhtml-entities"><output-character character="&#xad;" string="&#38;shy;"/></character-map> !-->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" name="htmlfiles"/>

  <!-- The following default output is for the content.opf output file -->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="yes"/>

  <!-- MAIN OSIS ROOT TEMPLATE -->
  <template match="/">

    <call-template name="Log">
      <with-param name="msg">
      isChildrensBible = <value-of select="$isChildrensBible"/>
      isGenericBook = <value-of select="$isGenericBook"/>
      doCombineGlossaries = <value-of select="$doCombineGlossaries"/>
      includeNavMenuLinks = <value-of select="$includeNavMenuLinks"/>
      </with-param>
    </call-template>

    <variable name="preprocessedMainOSIS">
      <call-template name="preprocessMain"/>
    </variable>

    <variable name="combinedGlossary">
      <call-template name="combinedGlossary"/>
    </variable>

    <variable name="preprocessedRefOSIS">
      <call-template name="preprocessDict"/>
    </variable>

    <!-- write debug OSIS file snapshot just before transformation -->
    <result-document href="preprocessedOSIS.xml">
      <for-each select="(
            $preprocessedMainOSIS,
            $preprocessedRefOSIS,
            $combinedGlossary
          )">
        <apply-templates mode="prettyprint" select="."/>
      </for-each>
    </result-document>

    <!-- processProject must be run twice: once to return file names and a second time
    to write the files. Trying to do both at once results in the following error:
    "XTDE1480: Cannot switch to a final result destination while writing a temporary tree" -->
    <variable name="htmlFiles" as="xs:string*">
      <call-template name="processProject">
        <with-param name="currentTask" select="'get-filenames'" tunnel="yes"/>
        <with-param name="docs" tunnel="yes" select="
            (
              $preprocessedMainOSIS,
              $preprocessedRefOSIS,
              $combinedGlossary
            )"/>
      </call-template>
    </variable>

    <!-- content.opf template -->
    <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
      <metadata
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xmlns:opf="http://www.idpf.org/2007/opf"
          xmlns:dcterms="http://purl.org/dc/terms/"
          xmlns:calibre="http://calibre.kovidgoyal.net/2009/metadata"
          xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:publisher>
          <xsl:value-of select="
              //work[@osisWork = $MAINMOD]/
              publisher[@type='x-CopyrightHolder'][not(@xml:lang)][1]/
              text()"/>
        </dc:publisher>
        <dc:title>
          <xsl:value-of select="
              //work[@osisWork = $MAINMOD]/title[not(@xml:lang)][1]/text()"/>
        </dc:title>
        <dc:language>
          <xsl:value-of select="
              //work[@osisWork = $MAINMOD]/language[1]/text()"/>
        </dc:language>
        <dc:identifier scheme="ISBN">
          <xsl:value-of select="
              //work[@osisWork = $MAINMOD]/
              identifier[@type='ISBN'][1]/
              text()"/>
        </dc:identifier>
        <dc:creator opf:role="aut">
          <xsl:value-of select="
              //work[@osisWork = $MAINMOD]/
              publisher[@type='x-CopyrightHolder'][not(@xml:lang)][1]/
              text()"/>
        </dc:creator>
      </metadata>
      <manifest>
        <xsl:for-each select="$htmlFiles">
          <item
            href="{.}"
            id="{oc:id(replace(., concat('\', $htmext, '$'), ''))}"
            media-type="application/xhtml+xml"/>
        </xsl:for-each>
        <xsl:for-each select="
            distinct-values(
              (//figure/@src, $preprocessedRefOSIS//figure/@src)
            )">
          <item>
            <xsl:attribute name="href" select="
                if (starts-with(., './')) then substring(., 3) else ."/>
            <xsl:attribute name="id" select="oc:id(tokenize(., '/')[last()])"/>
            <xsl:attribute name="media-type">
              <choose xmlns="http://www.w3.org/1999/XSL/Transform">
                <when test="matches(lower-case(.), '(jpg|jpeg|jpe)')">
                  <value-of select="'image/jpeg'"/>
                </when>
                <when test="ends-with(lower-case(.), 'gif')">
                  <value-of select="'image/gif'"/>
                </when>
                <when test="ends-with(lower-case(.), 'png')">
                  <value-of select="'image/png'"/>
                </when>
                <otherwise>application/octet-stream</otherwise>
              </choose>
            </xsl:attribute>
          </item>
        </xsl:for-each>
        <xsl:for-each select="tokenize($css, '\s*,\s*')">
          <xsl:choose>
            <!-- In the manifest, css file paths are absolute (do not start
            with . or /) but font files are relative (begin with .) -->
            <xsl:when test="ends-with(lower-case(.), 'css')">
              <item id="{oc:id(.)}" media-type="text/css" href="{
                  if (starts-with(., './')) then substring(., 3) else .}"/>
            </xsl:when>
            <xsl:when test="ends-with(lower-case(.), 'ttf')">
              <item
                id="{oc:id(.)}"
                media-type="application/x-font-truetype"
                href="{
                    if (starts-with(., './')) then . else concat('./', .)}"/>
            </xsl:when>
            <xsl:when test="ends-with(lower-case(.), 'otf')">
              <item
                id="{oc:id(.)}"
                media-type="application/vnd.ms-opentype"
                href="{
                    if (starts-with(., './')) then substring(., 3) else .}"/>
            </xsl:when>
            <xsl:otherwise>
  <xsl:call-template name="Error">
    <xsl:with-param name="msg">Unrecognized type of CSS file:"<xsl:value-of select="."/>"</xsl:with-param>
  </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </manifest>
      <spine toc="ncx">
        <xsl:for-each select="$htmlFiles">
          <itemref idref="{oc:id(replace(., concat('\', $htmext, '$'), ''))}"/>
        </xsl:for-each>
      </spine>
    </package>

    <call-template name="processProject">
      <with-param name="currentTask" select="'write-output'" tunnel="yes"/>
      <with-param name="docs" tunnel="yes" select="
            (
              $preprocessedMainOSIS,
              $preprocessedRefOSIS,
              $combinedGlossary
            )"/>
    </call-template>

  </template>
  <template mode="prettyprint" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  <template mode="prettyprint" priority="1" match="element()">
    <if test="not(preceding::node()[1][matches(string(), '\n$')])">
      <text>&#xa;</text>
    </if>
    <next-match/>
  </template>

  <!-- Main process-project loop -->
  <template name="processProject">
    <param name="currentTask" tunnel="yes"/>
    <param name="docs" tunnel="yes"/>
    <call-template name="Log">
<with-param name="msg"><text>&#xa;</text>CURRENT-TASK: <value-of select="$currentTask"/></with-param>
    </call-template>
    <for-each select="$docs">
      <apply-templates mode="divideFiles" select="."/>
    </for-each>
  </template>

  <!-- All preprocessed OSIS documents will now be split up into separate HTML
  files. Each section that does not have section children will be written to a
  separate file. -->
  <template mode="divideFiles" match="node()"><apply-templates mode="#current"/></template>
  <template mode="divideFiles" match="div[@type='toc-section'][not(descendant::div[@type='toc-section'])]">
    <!-- A currentTask param is necessary because identical template match sets
    are required for multiple modes (ie. a single template element must have
    multiple modes), yet the template content must also be adjusted according
    mode (something XSLT 2.0 modes alone can't do). -->
    <param name="currentTask" tunnel="yes"/>
    <param name="docs" tunnel="yes"/>

    <if test="boolean((
          descendant-or-self::text()[normalize-space()] |
          descendant-or-self::figure |
          descendant-or-self::milestone[@type=concat('x-usfm-toc', $TOC)]
        )[1])">

      <variable name="fileName" select="oo:getFileName(.)"/>

      <choose>
        <when test="$currentTask = 'get-filenames'">
          <value-of select="$fileName"/>
        </when>
        <when test="$currentTask = 'write-output'">
          <variable name="fileXHTML_0">
            <apply-templates mode="tran" select="node()"/>
            <if test="
                $includeNavMenuLinks and
                not(
                  descendant::*
                    [contains(@n, '[level1]')]
                    [not(contains(@n, '[no_toc]'))]
                    [1][@isMainTocMilestone = 'true']
                  ) and
                not($isChildrensBible) and
                not($isGenericBook)">
              <!-- Prev/next links only appear when their targets are within
              the same div as current but are in different html files than
              current. -->
              <variable name="previousFileNode" select="
                  node()[1]/preceding::text()[normalize-space()][1]"/>
              <variable name="prevIsSameDiv" select="
                  $previousFileNode/ancestor-or-self::div[last()]
                  intersect node()[1]/ancestor-or-self::div[last()]"/>
              <variable name="previousFile" select="
                  if ($previousFileNode)
                  then oo:getFileName($previousFileNode)
                  else ''"/>
              <variable name="followingFileNode" select="
                  node()[last()]/following::text()[normalize-space()][1]"/>
              <variable name="follIsSameDiv" select="
                  $followingFileNode/ancestor-or-self::div[last()]
                  intersect node()[last()]/ancestor-or-self::div[last()]"/>
              <variable name="followingFile" select="
                  if ($followingFileNode)
                  then oo:getFileName($followingFileNode)
                  else ''"/>
              <!-- Intro and Gloss links only appear when their targets are in
              a different file than current. Gloss links go to the top of the
              current glossary -->
              <variable name="introFile" select="
                  oo:getFileName(
                    $docs[oc:docWork(.)=$MAINMOD]/
                    descendant::div[@type='toc-section']
                    [1]
                  )"/>
              <!-- Glossary divs have been flattened and are empty elements,
              but the original div attributes are retained -->
              <variable name="myglossary" as="element(div)?" select="
                  if ($doCombineGlossaries)
                  then $docs[child::osis[@isCombinedGlossary='yes']]/
                    descendant::div[@type='glossary'][1]
                  else if (not(node()[1][self::div[@type='glossary']]))
                  then node()[1]/preceding::div[@type='glossary'][1]
                  else ()"/>
              <variable name="glossFile" select="
                  if (count($myglossary))
                  then oo:getFileName(
                      $myglossary/following::*
                      [matches(@n, '\[level\d\]')]
                      [not(contains(@n, '[no_toc]'))]
                      [1]
                    )
                  else ''"/>

              <apply-templates mode="tran" select="
                  oc:getNavmenuLinks(
                    if ($previousFile != $fileName and $prevIsSameDiv)
                      then concat('&amp;href=/', $previousFile)
                      else '',
                    if ($followingFile != $fileName and $follIsSameDiv)
                      then concat('&amp;href=/', $followingFile)
                      else '',
                    if (
                        $introFile and
                        $introFile != $fileName
                      )
                      then concat('&amp;href=/', $introFile)
                      else '',
                    if (
                      $glossFile and
                      $glossFile != $fileName and
                      not(
                        $myglossary[@annotateType='x-feature']
                        [@annotateRef='NO_TOC']
                      )
                    )
                      then (
                        concat(
                            '&amp;href=/',
                            $glossFile,
                            '&amp;text=',
                            if ($myglossary)
                              then oc:getDivTitle($myglossary)
                              else $uiDictionary
                          )
                        )
                      else ()
                  )">
                <with-param name="contextFile" select="$fileName" tunnel="yes"/>
              </apply-templates>

            </if>
          </variable>

          <variable name="fileXHTML">
            <apply-templates mode="postprocess" select="$fileXHTML_0"/>
          </variable>

          <variable name="fileNotes_0">
            <variable name="footnotes">
              <apply-templates mode="footnotes"/>
            </variable>
            <if test="$footnotes/descendant::text()[normalize-space()]">
              <html:div class="xsl-footnote-section">
                <html:hr/><text>&#xa;</text>
                <sequence select="$footnotes"/>
              </html:div>
            </if>
            <variable name="crossrefs">
              <apply-templates mode="crossrefs"/>
            </variable>
            <if test="$crossrefs/descendant::text()[normalize-space()]">
              <html:div class="xsl-crossref-section">
                <html:hr/><text>&#xa;</text>
                <sequence select="$crossrefs"/>
              </html:div>
            </if>
          </variable>

          <variable name="fileNotes">
            <apply-templates mode="postprocess" select="$fileNotes_0"/>
          </variable>

          <call-template name="Log">
            <with-param name="msg" select="concat('-------- writing: ', $fileName)"/>
          </call-template>
          <!-- Each MOBI footnote must be on single line, or they will not display
          correctly in MOBI popups! Therefore indent="no" is a requirement for html
          outputs. -->
          <result-document
              href="{$fileName}"
              format="htmlfiles"
              indent="{if ($SCRIPT_NAME='osis2ebooks') then 'no' else 'yes'}">
            <html xmlns="http://www.w3.org/1999/xhtml">
              <head>
                <meta name="generator" content="OSIS"/>
                <title><xsl:value-of select="$fileName"/></title>
                <meta
                  http-equiv="Default-Style"
                  content="text/html; charset=utf-8"/>
                <xsl:for-each select="tokenize($css, '\s*,\s*')">
                  <xsl:if test="ends-with(lower-case(.), 'css')">
                    <link type="text/css" rel="stylesheet" href="{
                        oc:uriToRelativePath($fileName, .)}"/>
                  </xsl:if>
                </xsl:for-each>
              </head>
              <body>
                <xsl:attribute name="class" select="
                normalize-space(
                  string-join(
                    (
                      string(@classes),
                      tokenize($fileName, '[_/\.]')
                    ),
                    ' '
                  )
                )"/>

                <!-- the following div is needed because non-block children
                of <body> cause eBook validation to fail -->
                <div><xsl:sequence select="$fileXHTML"/></div>
                <xsl:sequence select="$fileNotes"/>
                <!-- If there are links to FullResourceURL then add a crossref
                section at the end of the last book, with a link to FullResourceURL -->
                <xsl:if test="
                    $FullResourceURL and
                    $FullResourceURL != 'false' and
                    boolean($docs//reference[@subType='x-other-resource'] and
                    $fileName = oo:getFileName(
                        $docs[oc:docWork(.)=$MAINMOD]/
                        descendant::div[@type='book'][last()]
                      )
                  )">
                  <div class="xsl-crossref-section">
                    <hr/><xsl:text>&#xa;</xsl:text>
                    <div id="fullResourceURL" class="xsl-crossref">
                      <xsl:if test="$epub3Markup">
                        <xsl:attribute
                          name="epub:type"
                          namespace="http://www.idpf.org/2007/ops"
                          select="'footnote'"/>
                      </xsl:if>
                      <span class="xsl-note-head xsl-crnote-symbol">+</span><xsl:value-of select="' '"/>
                      <xsl:if test="starts-with($FullResourceURL, 'http')">
                        <a href="{$FullResourceURL}"><xsl:value-of select="$FullResourceURL"/></a>
                      </xsl:if>
                      <xsl:if test="not(starts-with($FullResourceURL, 'http'))">
                        <xsl:value-of select="$FullResourceURL"/>
                      </xsl:if>
                    </div>
                  </div>
                </xsl:if>
              </body>
            </html>
          </result-document>
        </when>
      </choose>
    </if>
  </template>

  <template mode="footnotes crossrefs" match="node()">
    <apply-templates mode="#current"/>
  </template>
  <template mode="footnotes" match="note[not(@type) or @type != 'crossReference']">
    <html:div id="{oc:id(@osisID)}" class="xsl-footnote">
      <if test="$epub3Markup">
        <attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'footnote'"/>
      </if>
      <html:a href="#textsym.{oc:id(@osisID)}">
        <call-template name="getFootnoteSymbol">
          <with-param name="class" select="'xsl-note-head'"/>
        </call-template>
      </html:a>
      <value-of select="' '"/>
      <apply-templates mode="tran"/>
    </html:div>
    <text>&#xa;</text>
  </template>
  <template mode="crossrefs" match="note[@type='crossReference']">
    <html:div id="{oc:id(@osisID)}" class="xsl-crossref">
      <if test="$epub3Markup">
        <attribute
          name="epub:type"
          namespace="http://www.idpf.org/2007/ops"
          select="'footnote'"/>
      </if>
      <html:a href="#textsym.{oc:id(@osisID)}">
        <call-template name="getFootnoteSymbol">
          <with-param name="class" select="'xsl-note-head'"/>
        </call-template>
      </html:a>
      <value-of select="' '"/>
      <apply-templates mode="tran"/>
    </html:div>
    <text>&#xa;</text>
  </template>

</stylesheet>
