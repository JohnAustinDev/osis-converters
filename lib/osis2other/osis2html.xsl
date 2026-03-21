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

    html/files.html   - Each book, section, chapter (if eachChapterIsFile
                        is true) and keyword are written to separate
                        html files. These files are linked by an auto
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
      glossaryToc = <value-of select="$glossaryToc"/>
      keywordFile = <value-of select="$keywordFile"/>
      eachChapterIsFile = <value-of select="$eachChapterIsFile"/>
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

    <!--<result-document href="preprocessedMainOSIS.xml"><sequence select="$preprocessedMainOSIS"/></result-document>-->

    <!-- processProject must be run twice: once to return file names and a second time
    to write the files. Trying to do both at once results in the following error:
    "XTDE1480: Cannot switch to a final result destination while writing a temporary tree" -->
    <variable name="htmlFiles" as="xs:string*">
      <call-template name="processProject">
        <with-param name="currentTask" select="'get-filenames'" tunnel="yes"/>
        <with-param name="preprocessedMainOSIS" select="$preprocessedMainOSIS" tunnel="yes"/>
        <with-param name="combinedGlossary" select="$combinedGlossary" tunnel="yes"/>
        <with-param name="preprocessedRefOSIS" select="$preprocessedRefOSIS" tunnel="yes"/>
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
          <xsl:value-of select="//work[@osisWork = $MAINMOD]/publisher[@type='x-CopyrightHolder']
            [not(@xml:lang)][1]/text()"/>
        </dc:publisher>
        <dc:title>
          <xsl:value-of select="//work[@osisWork = $MAINMOD]/title
            [not(@xml:lang)][1]/text()"/>
        </dc:title>
        <dc:language>
          <xsl:value-of select="//work[@osisWork = $MAINMOD]/language[1]/text()"/>
        </dc:language>
        <dc:identifier scheme="ISBN">
          <xsl:value-of select="//work[@osisWork = $MAINMOD]/identifier[@type='ISBN'][1]/text()"/>
        </dc:identifier>
        <dc:creator opf:role="aut">
          <xsl:value-of select="//work[@osisWork = $MAINMOD]/publisher[@type='x-CopyrightHolder']
            [not(@xml:lang)][1]/text()"/>
        </dc:creator>
      </metadata>
      <manifest>
        <xsl:for-each select="$htmlFiles">
          <item
            href="html/{.}"
            id="{oc:id(replace(., concat('\', $htmext, '$'), ''))}"
            media-type="application/xhtml+xml"/>
        </xsl:for-each>
        <xsl:for-each select="distinct-values((//figure/@src, $preprocessedRefOSIS//figure/@src))">
          <item>
            <xsl:attribute name="href" select="if (starts-with(., './')) then substring(., 3) else ."/>
            <xsl:attribute name="id" select="oc:id(tokenize(., '/')[last()])"/>
            <xsl:attribute name="media-type">
              <choose xmlns="http://www.w3.org/1999/XSL/Transform">
                <when test="matches(lower-case(.), '(jpg|jpeg|jpe)')">image/jpeg</when>
                <when test="ends-with(lower-case(.), 'gif')">image/gif</when>
                <when test="ends-with(lower-case(.), 'png')">image/png</when>
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
              <item href="{if (starts-with(., './')) then substring(., 3) else .}" id="{oc:id(.)}" media-type="text/css"/>
            </xsl:when>
            <xsl:when test="ends-with(lower-case(.), 'ttf')">
              <item href="{if (starts-with(., './')) then . else concat('./', .)}" id="{oc:id(.)}" media-type="application/x-font-truetype"/>
            </xsl:when>
            <xsl:when test="ends-with(lower-case(.), 'otf')">
              <item href="{if (starts-with(., './')) then substring(., 3) else .}" id="{oc:id(.)}" media-type="application/vnd.ms-opentype"/>
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
      <with-param name="preprocessedMainOSIS" select="$preprocessedMainOSIS" tunnel="yes"></with-param>
      <with-param name="combinedGlossary" select="$combinedGlossary" tunnel="yes"></with-param>
      <with-param name="preprocessedRefOSIS" select="$preprocessedRefOSIS" tunnel="yes"/>
    </call-template>

  </template>

  <!-- Main process-project loop -->
  <template name="processProject">
    <param name="currentTask" tunnel="yes"/>
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>

    <call-template name="Log">
<with-param name="msg"><text>&#xa;</text>CURRENT-TASK: <value-of select="$currentTask"/></with-param>
    </call-template>

    <apply-templates mode="divideFiles" select="$preprocessedMainOSIS"/>

    <apply-templates mode="divideFiles" select="$combinedGlossary"/>

    <apply-templates mode="divideFiles" select="$preprocessedRefOSIS"/>

  </template>

  <!-- THE OSIS FILE IS SEPARATED INTO INDIVIDUAL HTML FILES BY THE FOLLOWING TEMPLATES
  All osisText children are assumed to be div elements (others are ignored). Children's
  Bibles are contained within a single div[@type='book']. Bibles and reference material
  are contained in div[@type=$usfmType], div[@type='book'], and div[@type='bookGroup']
  and any other divs are unexpected but are handled fine if they have an osisID. -->
  <template mode="divideFiles" match="node()"><apply-templates mode="#current"/></template>

  <!-- FILE: module-introduction -->
  <template mode="divideFiles" match="osisText">
    <choose>
      <!-- If this is the top of an x-bible OSIS file, group all initial divs as the introduction -->
      <when test="oc:docWork(.) = $MAINMOD and //work[@osisWork=$MAINMOD]/type[@type='x-bible']">
        <for-each-group select="div"
            group-adjacent="0.5 + 0.5*count(self::div[@type='bookGroup']) +
                            count(preceding::div[@type='bookGroup'])">
          <choose>
            <when test="self::div[@type='bookGroup']">
              <call-template name="osisbookgroup"/>
            </when>
            <otherwise>
              <call-template name="ProcessFile">
                <with-param name="fileNodes" select="current-group()"/>
              </call-template>
            </otherwise>
          </choose>
        </for-each-group>
      </when>
      <otherwise><apply-templates mode="#current" select="div"/></otherwise>
    </choose>
  </template>

  <!-- FILE: divs not handled elsewhere -->
  <template mode="divideFiles" name="otherdiv" match="div">
    <call-template name="ProcessFile">
      <with-param name="fileNodes" select="node()"/>
    </call-template>
  </template>

  <!-- FILE: bookGroup-introduction -->
  <template mode="divideFiles" name="osisbookgroup" match="div[@type='bookGroup']">
    <for-each-group select="node()"
        group-adjacent="0.5 + 0.5*count(self::div[@type='book']) +
                        count(preceding::div[@type='book'])">
      <choose>
        <when test="self::div[@type='book']">
          <call-template name="osisbook"/>
        </when>
        <otherwise>
          <call-template name="ProcessFile">
            <with-param name="fileNodes" select="current-group()"/>
          </call-template>
        </otherwise>
      </choose>
    </for-each-group>
  </template>

  <!-- FILE: Bible books and Children's Bibles -->
  <template mode="divideFiles" name="osisbook" match="div[@type='book']">
    <choose>
      <when test="$isChildrensBible">
        <for-each-group select="node()"
          group-adjacent="0.5 + 0.5*count(self::div[@type='chapter']) +
                          count(preceding::div[@type='chapter'])">
          <call-template name="ProcessFile">
            <with-param name="fileNodes" select="current-group()"/>
          </call-template>
        </for-each-group>
      </when>
      <!-- FILE (when $eachChapterIsFile): Bible chapters -->
      <when test="self::div[@type='book'] and $eachChapterIsFile">
        <variable name="book" select="@osisID"/>
        <for-each-group select="node()"
            group-adjacent="count(descendant-or-self::chapter[starts-with(@sID, concat($book, '.'))]) +
                            count(preceding::chapter[starts-with(@sID, concat($book, '.'))])">
          <call-template name="ProcessFile">
            <with-param name="fileNodes" select="current-group()"/>
          </call-template>
        </for-each-group>
      </when>
      <otherwise><call-template name="otherdiv"/></otherwise>
    </choose>
  </template>

  <!-- FILE: reference 'glossary' divs (which may contain keywords) -->
  <template mode="divideFiles" match="div[@type='glossary']">
    <variable name="my_keywordFile"
      select="if (count(descendant::seg[@type='keyword']) = 1) then 'glossary' else
              if (self::div[@annotateType='x-feature' and @annotateRef='NO_TOC']) then 'single' else
              if ($keywordFile != 'AUTO') then $keywordFile else
              if (count(descendant::div[starts-with(@type, 'x-keyword')]) &#60; $keywordFileAutoThresh) then 'glossary'
              else 'letter'"/>
    <call-template name="Note">
<with-param name="msg">Processing glossary '<value-of select="oc:getDivTitle(.)"/>', my_keywordFile=<value-of select="$my_keywordFile"/></with-param>
    </call-template>
    <choose>
      <when test="$my_keywordFile = ('single', 'letter')">
        <for-each-group select="node()"
          group-adjacent="(ancestor-or-self::div[@glossaryGroup][1] | preceding::div[@glossaryGroup][1])[last()]/
                          @glossaryGroup">
          <call-template name="ProcessFile">
            <with-param name="fileNodes" select="current-group()"/>
          </call-template>
        </for-each-group>
      </when>
      <otherwise>
        <call-template name="otherdiv"/>
      </otherwise>
    </choose>
  </template>

  <!-- ProcessFile may be called with any element that should initiate a new output
   file above. It writes the file's contents and adds it to manifest and spine -->
  <template name="ProcessFile">
    <param name="fileNodes" as="node()*"/>
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>

    <!-- A currentTask param is necessary because identical template match sets
    are required for multiple modes (ie. a single template element must have
    multiple modes), yet the template content must also be adjusted according
    mode (something XSLT 2.0 modes alone can't do). -->
    <param name="currentTask" tunnel="yes"/>

    <if test="boolean($fileNodes/descendant::text()[normalize-space()] |
                      $fileNodes/descendant-or-self::figure |
                      $fileNodes/descendant-or-self::milestone[@type=concat('x-usfm-toc', $TOC)])">
      <variable name="fileName" select="oo:getFileName(.)"/>

      <choose>
        <when test="$currentTask = 'get-filenames'"><value-of select="$fileName"/></when>
        <otherwise>

          <variable name="fileXHTML_0">
            <apply-templates mode="tran" select="$fileNodes"/>
            <if test="$includeNavMenuLinks and not($isChildrensBible) and not($isGenericBook)">

              <!-- Prev/next links only appear when their targets are within the same
              div as current but are in different html files than current. -->
              <variable name="previousFileNode" select="$fileNodes[1]/
                   preceding::text()[normalize-space()][1]"/>
              <variable name="prevIsSameDiv" select="$previousFileNode/ancestor-or-self::div[last()] intersect
                                                         $fileNodes[1]/ancestor-or-self::div[last()]"/>
              <variable name="previousFile" select="if ($previousFileNode) then oo:getFileName($previousFileNode) else ''"/>

              <variable name="followingFileNode" select="$fileNodes[last()]/
                   following::text()[normalize-space()][1]"/>
              <variable name="follIsSameDiv" select="$followingFileNode/ancestor-or-self::div[last()] intersect
                                                     $fileNodes[last()]/ancestor-or-self::div[last()]"/>
              <variable name="followingFile" select="if ($followingFileNode) then oo:getFileName($followingFileNode) else ''"/>

              <!-- Intro and Gloss links only appear when their targets are in a different
              file than current. Gloss links go to the top of the current glossary -->
              <variable name="introFile" select="oo:getFileName($preprocessedMainOSIS)"/>
              <variable name="myglossary" select="if ($doCombineGlossaries) then
                $combinedGlossary/descendant::div[@type='glossary'][1] else $fileNodes[1]/ancestor::div[@type='glossary']"/>
              <variable name="glossFile" select="if ($myglossary) then oo:getFileName($myglossary) else ''"/>
              <apply-templates mode="tran"
                  select="oc:getNavmenuLinks(
                    if ($previousFile != $fileName and $prevIsSameDiv) then
                        concat('&amp;href=/html/', $previousFile)  else '',
                    if ($followingFile != $fileName and $follIsSameDiv) then
                        concat('&amp;href=/html/', $followingFile) else '',
                    if ($introFile != $fileName) then
                        concat('&amp;href=/html/', $introFile) else '',
                    if ($glossFile != $fileName and $glossFile and
                        not($myglossary[@annotateType='x-feature' and @annotateRef='NO_TOC'])) then (
                        concat('&amp;href=/html/', $glossFile, '&amp;text=',
                                if ($myglossary)
                                then oc:getDivTitle($myglossary)
                                else $uiDictionary)
                        ) else ())">
                <with-param name="contextFile" select="$fileName" tunnel="yes"/>
              </apply-templates>
            </if>
          </variable>
          <variable name="fileXHTML">
            <apply-templates mode="postprocess" select="$fileXHTML_0"/>
          </variable>

          <variable name="fileNotes_0">
            <call-template name="noteSections">
              <with-param name="nodes" select="$fileNodes"/>
            </call-template>
          </variable>
          <variable name="fileNotes">
            <apply-templates mode="postprocess" select="$fileNotes_0"/>
          </variable>

          <call-template name="WriteFile">
            <with-param name="fileName" select="$fileName"/>
            <with-param name="OSISelement" select="$fileNodes[1]"/>
            <with-param name="fileXHTML" select="$fileXHTML"/>
            <with-param name="fileNotes" select="$fileNotes"/>
          </call-template>

        </otherwise>
      </choose>
    </if>
  </template>

  <!-- Write an html file -->
  <template name="WriteFile">
    <param name="fileName" as="xs:string"/>
    <param name="OSISelement" as="node()"/>
    <param name="fileXHTML" as="node()+"/>
    <param name="fileNotes" as="node()*"/>
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>

    <variable name="topElement" select="$OSISelement/parent::*" as="element()"/>
    <variable name="isMainNode" select="oc:docWork($topElement) = $MAINMOD"/>
    <call-template name="Log">
      <with-param name="msg" select="concat('-------- writing: ', $fileName)"/>
    </call-template>
    <!-- Each MOBI footnote must be on single line, or they will not display correctly in MOBI popups!
  Therefore indent="no" is a requirement for html outputs. -->
    <result-document
        href="html/{$fileName}"
        format="htmlfiles"
        indent="{if ($SCRIPT_NAME='osis2ebooks') then 'no' else 'yes'}">
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta name="generator" content="OSIS"/>
          <title><xsl:value-of select="$fileName"/></title>
          <meta http-equiv="Default-Style" content="text/html; charset=utf-8"/>
          <xsl:for-each select="tokenize($css, '\s*,\s*')">
            <xsl:if test="ends-with(lower-case(.), 'css')">
              <link href="{oc:uriToRelativePath(concat('/html/', oo:getFileName($topElement)), .)}"
                    type="text/css" rel="stylesheet"/>
            </xsl:if>
          </xsl:for-each>
        </head>
        <body>
          <xsl:attribute name="class" select="normalize-space(string-join(distinct-values(
              ('calibre',
               root($OSISelement)//work[@osisWork = oc:docWork(.)]/type/@type,
               $topElement/ancestor-or-self::*[@scope][1]/@scope,
               for $x in tokenize($fileName, '[_/\.]') return $x,
               $topElement/@type,
               $topElement/@subType)
              ), ' '))"/>
          <!-- the following div is needed because non-block children <body> cause eBook validation to fail -->
          <div><xsl:sequence select="$fileXHTML"/></div>
          <xsl:sequence select="$fileNotes"/>
          <!-- If there are links to FullResourceURL then add a crossref
          section at the end of the last book, with a link to FullResourceURL -->
          <xsl:if test="$FullResourceURL and $FullResourceURL != 'false' and
            boolean($topElement intersect $preprocessedMainOSIS/descendant::div[@type='book'][last()]) and
            boolean(($preprocessedMainOSIS | $preprocessedRefOSIS)//reference[@subType='x-other-resource'])">
            <div class="xsl-crossref-section">
              <hr/><xsl:text>&#xa;</xsl:text>
              <div id="fullResourceURL" class="xsl-crossref">
                <xsl:if test="$epub3Markup">
                  <xsl:attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'footnote'"/>
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
  </template>

  <!-- Write footnote and cross reference sections -->
  <template name="noteSections">
    <param name="nodes"/>
    <variable name="footnotes">
      <apply-templates mode="footnotes" select="$nodes"/>
    </variable>
    <if test="$footnotes/descendant::text()[normalize-space()]">
      <html:div class="xsl-footnote-section">
        <html:hr/><text>&#xa;</text>
        <sequence select="$footnotes"/>
      </html:div>
    </if>
    <variable name="crossrefs">
      <apply-templates mode="crossrefs" select="$nodes"/>
    </variable>
    <if test="$crossrefs/descendant::text()[normalize-space()]">
      <html:div class="xsl-crossref-section">
        <html:hr/><text>&#xa;</text>
        <sequence select="$crossrefs"/>
      </html:div>
    </if>
  </template>

  <template mode="footnotes crossrefs" match="node()"><apply-templates mode="#current"/></template>
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

</stylesheet>
