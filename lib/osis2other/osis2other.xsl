<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:oo="http://github.com/JohnAustinDev/osis-converters/osis2other"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:html="http://www.w3.org/1999/xhtml"
 xmlns:fb2="http://www.gribuser.ru/xml/fictionbook/2.0"
 xmlns:xlink="http://www.w3.org/1999/xlink"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 exclude-result-prefixes="#all">

  <!-- This stylesheet contains function and template utilities for converting
  OSIS into other formats. -->

  <!-- A comma separated list of css and css-referenced files (such as fonts) -->
  <param name="css" select="oc:sarg('css', /, 'ebible.css,module.css')"/>

  <!-- Output HTML5 markup -->
  <param name="html5" select="oc:sarg('html5', /, 'false')"/>

  <!-- Settings used to control the transform -->
  <param name="CombineGlossaries" select="oc:conf('CombineGlossaries', /)"/> <!-- CombineGlossaries: 'AUTO', 'true' or 'false' -->

  <param name="glossaryToc" select="oc:sarg('glossaryToc', /,
    if ($SCRIPT_NAME = 'osis2ebooks') then 'no' else 'AUTO')"/>              <!-- ARG_glossaryToc: 'AUTO', 'single' or 'letter' -->
  <param name="keywordFile" select="oc:sarg('keywordFile', /,
    if ($SCRIPT_NAME = 'osis2ebooks') then 'single' else 'AUTO')"/>          <!-- ARG_keywordFile: 'AUTO', 'single', 'letter' or 'glossary' -->
  <param name="chapterFiles" select="oc:sarg('chapterFiles', /,
    if ($SCRIPT_NAME = 'osis2ebooks') then 'no' else 'yes')"/>               <!-- ARG_chapterFiles: 'yes' or 'no' -->
  <param name="navMenuLinks" select="oc:sarg('navMenuLinks', /,
    if ($SCRIPT_NAME='osis2ebooks') then 'no' else 'yes')"/>                 <!-- ARG_navMenuLinks: 'yes' or 'no' -->
  <param name="noEpub3Markup" select="oc:sarg('noEpub3Markup', /,
    if ($SCRIPT_NAME='osis2ebooks') then 'no' else 'yes')"/>                 <!-- ARG_noEpub3Markup: 'yes' or 'no' -->

  <!-- Osis-converters config entries used by this transform -->
  <param name="DEBUG" select="oc:csys('DEBUG', /)"/>

  <param name="TOC" select="oc:conf('TOC', /)"/>

  <param name="TitleCase" select="oc:conf('TitleCase', /)"/>

  <param name="TitleTOC" select="oc:conf('TitleTOC', /)"/>

  <param name="FullResourceURL" select="oc:conf('FullResourceURL', /)"/><!-- '' or 'false' turns this feature off -->

  <param name="tocWidth" select="xs:integer(number(oc:sarg('tocWidth', /, '50')))"/><!-- in chars, is ARG_tocWidth in config.conf -->

  <param name="averageCharWidth" select="number(oc:sarg('averageCharWidth', /, '1.1'))"/><!-- in CSS ch units, is ARG_averageCharWidth in config.conf -->

  <param name="backFullWidth" select="xs:integer(number(oc:sarg('backFullWidth', /, '20')))"/><!-- is ARG_backFullWidth in config.conf -->

  <param name="introFullWidth" select="xs:integer(number(oc:sarg('introFullWidth', /, '20')))"/><!-- is ARG_introFullWidth in config.conf -->

  <param name="keywordFileAutoThresh" select="xs:integer(number(oc:sarg('keywordFileAutoThresh', /, '10')))"/><!-- is ARG_keywordFileAutoThresh in config.conf -->

  <variable name="eachChapterIsFile" as="xs:boolean" select="$chapterFiles = 'yes'"/>
  <variable name="includeNavMenuLinks" as="xs:boolean" select="$navMenuLinks = 'yes'"/>
  <variable name="epub3Markup" as="xs:boolean" select="$noEpub3Markup != 'yes'"/>
  <variable name="htmext" select="'.html'"/>

  <!-- FB2 default settings -->
  <variable name="EnableFB2CSS" select="false()"/>
  <variable name="EnableFB2FullResourceURL" select="false()"/>

  <!-- The main input OSIS file must contain a work element corresponding to each
     OSIS file referenced in the project. But osis-converters supports a single
     dictionary OSIS file only, which contains all reference material. -->
  <variable name="mainInputOSIS" select="/"/>
  <variable name="referenceOSIS" as="document-node()?"
      select="if ($isChildrensBible or $isGenericBook)
              then ()
              else /osis/osisText/header/work[@osisWork != /osis/osisText/@osisIDWork]/
                doc(concat(tokenize(document-uri(/), '[^/]+$')[1], @osisWork, '.xml'))"/>

  <variable name="doCombineGlossaries" select="if ($CombineGlossaries = 'AUTO')
      then false() else $CombineGlossaries = 'true' "/>

  <variable name="CombindedGlossaryTitle" select="
      //work[boolean($DICTMOD) and @osisWork = $DICTMOD]/title[1]"/>

  <!-- USFM file types output by CrossWire's usfm2osis.py -->
  <variable name="usfmType" select="('front', 'introduction', 'back', 'concordance',
      'glossary', 'index', 'gazetteer', 'x-other', 'titlePage', 'x-halfTitlePage',
      'x-promotionalPage', 'imprimatur', 'publicationData', 'x-foreword', 'preface',
      'tableofContents', 'x-alphabeticalContents', 'x-tableofAbbreviations',
      'x-chronology', 'x-weightsandMeasures', 'x-mapIndex', 'x-ntQuotesfromLXX',
      'coverPage', 'x-spine', 'x-tables', 'x-dailyVerses')" as="xs:string+"/>

  <variable name="REF_BibleTop" select="concat($MAINMOD,':BIBLE_TOP')"/>
  <variable name="REF_DictTop" select="if ($DICTMOD) then concat($DICTMOD,':DICT_TOP') else ''"/>

  <!-- A main inline Table Of Contents is placed after the first TOC milestone. -->
  <variable name="mainTocMilestone" select="
      /descendant::milestone[@type=concat('x-usfm-toc', $TOC)]
      [not(oo:getTocInstructions(.) = 'no_toc')][1]"/>

  <!-- #################################################################### -->
  <!--                        TABLE OF CONTENTS                             -->
  <!-- ####################################################################

  There are two TOCs: 1) eBook TOC marked with title="level-N" attri-
  butes, and 2) inline TOC which appears inline with the text as a
  series of links. All TOC elements must have an osisID, without a work
  prefix (this may be insured during the preprocess step). The following
  OSIS elements, by default, will generate both an eBook TOC and an
  inline TOC entry:

             ELEMENT                           DESCRIPTION
  milestone[@osisID]             -From USFM \tocN tags, where N
           [@type='x-usfm-tocN']  corresponds to this XSLT's $TOC param.
                                  The TOC entry name comes from the "n"
                                  attribute value.
  chapter[@osisID][@sID]         -From USFM \c tags. The TOC entry name
                                  comes from a following \cl or \cp USFM
                                  tag: title[@type='x-chapterLabel']
  seg[@osisID][@type='keyword']  -From USFM \k ...\k* tags. The TOC
                                  entry name comes from child text nodes

  By default, TOC hierarchy is determined from OSIS hierarchy. However
  an explicit TOC level and/or explicit title may be specified for any
  entry. An explicit title may be specified using an "n" attribute,
  which may also be prepended with special INSTRUCTIONS.

  EXAMPLE:
  <milestone type="x-usfm-toc2" n="[level1]My Title"/>

  The recognized INSTRUCTIONS which may appear at the beginning of an
  "n" attribute value of any of the above TOC generating elements are
  the following:

  see &help('TABLE OF CONTENTS') for INSTRUCTIONS doc -->
  <function name="oc:getMainInlineTOC" as="element()*">
    <param name="preprocessedMainOSIS" as="document-node()"/>
    <param name="preprocessedRefOSIS" as="document-node()"/>
    <param name="combinedGlossary" as="document-node()"/>

    <variable name="listElementDoc">
      <sequence select="oo:getTocListItems(
          $preprocessedMainOSIS,
          $preprocessedMainOSIS,
          $preprocessedRefOSIS,
          $combinedGlossary)"/>
      <!-- If combining glossaries, put the combined glossary first,
      then any non-glossary material after it -->
      <if test="$doCombineGlossaries">
        <sequence select="oo:getTocListItems(
            $combinedGlossary,
            $preprocessedMainOSIS,
            $preprocessedRefOSIS,
            $combinedGlossary)"/>
      </if>
      <!-- Next is either non-glossary material in reference OSIS (if
      combiningGlossaries) or else everything in reference OSIS -->
      <sequence select="oo:getTocListItems(
          $preprocessedRefOSIS,
          $preprocessedMainOSIS,
          $preprocessedRefOSIS,
          $combinedGlossary)"/>
    </variable>

    <if test="count($listElementDoc/*)">
      <choose>
        <when test="$target = 'html'">
          <html:div id="root-toc">
            <sequence select="oo:getInlineToc($listElementDoc, true())"/>
          </html:div>
        </when>
        <when test="$target = 'fb2'">
          <sequence select="oo:getInlineToc($listElementDoc, true())"/>
        </when>
      </choose>
    </if>
  </function>

  <function name="oo:getElementInlineTOC" as="element()*">
    <param name="tocElement" as="element()"/>
    <param name="preprocessedMainOSIS"/>
    <param name="preprocessedRefOSIS"/>
    <param name="combinedGlossary"/>

    <variable name="listElementDoc">
      <sequence select="oo:getTocListItems(
          oo:origElement(
            $tocElement,
            $preprocessedMainOSIS,
            $preprocessedRefOSIS,
            $combinedGlossary
          ),
          $preprocessedMainOSIS,
          $preprocessedRefOSIS,
          $combinedGlossary
        )"/>
    </variable>

    <if test="count($listElementDoc/*)">
      <sequence select="
        oo:getInlineToc($listElementDoc, false())"/>
    </if>
  </function>

  <function name="oo:getInlineToc" as="element()*">
    <param name="listdoc" as="document-node()"/>
    <param name="isTopTOC" as="xs:boolean"/>

    <choose>
      <when test="$target = 'html'">
        <sequence select="oo:getInlineTocHTML($listdoc, $isTopTOC)"/>
      </when>
      <when test="$target = 'fb2'">
        <fb2:empty-line/>
        <for-each select="$listdoc/fb2:a">
          <fb2:p><sequence select="."/></fb2:p>
        </for-each>
        <fb2:empty-line/>
      </when>
    </choose>
  </function>

  <function name="oo:getInlineTocHTML" as="element(html:div)">
    <param name="listdoc" as="document-node()"/>
    <param name="isTopTOC" as="xs:boolean"/>
    <!-- Inline TOCs by default display as lists of inline-block links
    all sharing an equal width that are a maximum of tocWidth characters
    wide, which may occupy the full width of the page. The two excep-
    tions are: Bible book lists which are limited to three columns, and
    the main TOC menu, whose links are displayed in three vertical sub-
    sections, each having links which are either all half-width (maximum
    tocWidth/2 characters wide) or all full-width (maximum tocWidth
    characters wide).
    Main TOC Menu:
        1) INTRODUCTION links
        2) SCRIPTURE links
        3) REFERENCE (back material) links
    These sub-sections of the Main TOC each display links differently:
    INTRODUCTION: Normally displayed as half-table width links. But if
                  there are more than introFullWidth characters in any
                  intro link, or only one intro link and scripture links
                  are full-width, then all intro links become full-table
                  width (to minimize overall TOC width and give a bal-
                  anced look). When there are an odd number of half-
                  table width intro links, the first link is centered by
                  itself.
    SCRIPTURE:    Normally displayed as full-table width links. But if
                  there are more than 5 they become half-table width.
                  Half-table width bookGroup or bookSubGroup links are
                  centered on a row by themselves, as is the last book
                  when there are an odd number of half-table width book
                  links.
    REFERENCE:    Normally displayed as half-table width links. But if
                  there are more than backFullWidth characters in any
                  back link, or only one back link and scripture link
                  is full-width, then all back links become full-table
                  width. When there are an odd number of half-table
                  width back links, the last link is centered by itself. -->
    <variable name="fullWidthElements" select="
        $listdoc/html:li[oo:isFullWidth(., $isTopTOC)]"/>
    <variable name="halfWidthElements" select="
        $listdoc/html:li[not(. intersect $fullWidthElements)]"/>
    <variable name="chars" select="
        if ($isTopTOC)
        then max(
            (
              $halfWidthElements/(2*string-length(string())),
              $fullWidthElements/string-length(string())
            )
          )
        else max($listdoc/html:li/string-length(string()))"/>
    <variable name="wChars" select="
        if ($chars &#62; $tocWidth) then $tocWidth else $chars"/>

    <html:div>
      <attribute name="class">xsl-inline-toc</attribute>
      <!-- this div allows margin auto to center, which doesn't work with
      ul/ol -->
      <html:div>
        <choose>
          <!-- main TOC is fixed width and children are specified as % in css -->
          <when test="$isTopTOC">
            <!-- The main TOC is fixed width and child li are specified as % in css. To fit the text:
            width = 6px + $averageCharWidth*(4+wChars/2) ch + 12px + $averageCharWidth*(4+wChars/2) ch + 6px
            or: max-width of parent at 100% = 24px + $averageCharWidth*(8+wChars) ch + 1ch for chapter inline block fudge -->
            <variable name="ch" select="
                floor(0.5 + 10*$averageCharWidth*(8+$wChars)) div 10"/>
            <attribute name="style" select="
                concat('max-width:calc(24px + ', $ch+1, 'ch)')"/>
          </when>
          <!-- book TOCs are max 3 columns -->
          <when test="
              $listdoc/html:li[tokenize(@class,'\s+') = 'xsl-book-link']">
            <attribute name="style" select="
                concat(
                  'max-width:',
                  ceiling(3.5*$averageCharWidth*(4+$wChars)),
                  'ch'
                )"/>
          </when>
        </choose>
        <for-each-group select="$listdoc/html:li"
            group-adjacent="oo:section(., $isTopTOC)">
          <variable name="sectionIsFullWidth" as="xs:boolean"
            select="oo:isFullWidth(current-group()[1], $isTopTOC)"/>
          <variable name="maxWCharsSection" as="xs:double"
              select="
              if ($sectionIsFullWidth)
              then $tocWidth
              else $tocWidth div 2"/>
          <variable name="charsSection" as="xs:double"
              select="
              max(
                current-group()[not(tokenize(@class, '\s+') = 'xsl-atoz')]/
                string-length(string())
              )"/>
          <variable name="wCharsSection" as="xs:double"
              select="
              if ($charsSection &#62; $maxWCharsSection)
              then $maxWCharsSection
              else $charsSection"/>
          <variable name="ch_section" as="xs:double"
              select="
              floor(0.5 + 10 * $averageCharWidth * (4 + $wCharsSection)) div 10"/>
          <html:ol>
            <attribute name="class">
              <variable name="class" as="xs:string+">
                <value-of select="oo:section(current-group()[1], $isTopTOC)"/>
                <if test="$sectionIsFullWidth">
                  <value-of select="'xsl-full-width'"/>
                </if>
                <if test="count(
                      current-group()[tokenize(@class,'\s+') = 'xsl-book-link']
                    ) mod 2 = 1">
                  <value-of select="'xsl-odd-books'"/>
                </if>
                <if test="count(current-group()) mod 2 = 1">
                  <value-of select="'xsl-odd'"/>
                </if>
                <if test="$charsSection &#60;= $maxWCharsSection">
                  <value-of select="'xsl-short'"/>
                </if>
              </variable>
              <value-of select="string-join(distinct-values($class), ' ')"/>
            </attribute>
            <for-each select="current-group()">
              <copy>
                <copy-of select="@*"/>
                <attribute name="style">
                  <variable name="style" as="xs:string*">
                    <variable name="Hem" as="xs:double" select="
                        1 + ceiling(
                            if ($isTopTOC and oo:isFullWidth(., $isTopTOC))
                            then string-length(string()) div $wCharsSection
                            else $charsSection div $wCharsSection
                          )"/>
                    <value-of select="
                        concat('min-height:calc(', $Hem, 'em + 3px)')"/>
                    <!-- Width is not specified for top-TOC at the li level because it is specified
                    at a higher div level. The A-to-Z button width is not specified because it
                    is allowed to be wider than all other button links in its list. -->
                    <if test="
                        not($isTopTOC) and
                        not(tokenize(@class, '\s+') = 'xsl-atoz')">
                      <value-of select="concat('width:', $ch_section, 'ch')"/>
                    </if>
                  </variable>
                  <value-of select="string-join($style, '; ')"/>
                </attribute>
                <copy-of select="node()"/>
              </copy>
            </for-each>
          </html:ol>
        </for-each-group>
      </html:div>
    </html:div>
  </function>
  <function name="oo:section" as="xs:string">
    <param name="elem" as="element()"/>
    <param name="isTopTOC" as="xs:boolean"/>
    <value-of select="
        if (not($isTopTOC))
        then concat(tokenize($elem/@class,'\s+')[1], '-section')
        else if (contains($elem/@class,'xsl-book'))
        then 'xsl-scrip'
        else if ($elem/following::*[contains(@class,'xsl-book')])
        then 'xsl-intro'
        else 'xsl-back'"/>
  </function>
  <function name="oo:isFullWidth" as="xs:boolean">
    <param name="elem" as="element()"/>
    <param name="isTopTOC" as="xs:boolean"/>

    <variable name="section" select="oo:section($elem, $isTopTOC)"/>
    <variable name="siblings" select="$elem/parent::node()/child::node()
                                   [oo:section(., $isTopTOC) = $section]"/>
    <variable name="scripElems" select="$elem/parent::node()/child::node()
                                   [oo:section(., $isTopTOC) = 'xsl-scrip']"/>
    <variable name="fullWidthChars" select="
        if ($section = 'xsl-intro')
        then $introFullWidth
        else $backFullWidth"/>
    <choose>
      <when test="not($isTopTOC)">
        <value-of select="true()"/>
      </when>
      <when test="$section = 'xsl-scrip'">
        <value-of select="count($siblings) &#60;= 5"/>
      </when>
      <otherwise>
        <value-of select="
            (max($siblings/string-length(string())) &#62;= $fullWidthChars) or
            (count($siblings) = 1 and count($scripElems) &#60;= 5)"/>
      </otherwise>
    </choose>
  </function>

  <!-- Returns a series of list entry elements, one for every TOC entry that is
  a step below tocNode in the hierarchy. A class is added according to the type
  of entry. EBook glossary keyword lists with greater than
  $glossaryTocAutoThresh entries are pared down to list only the first of each
  letter. IMPORTANT: tocNode MUST be the document-node of, or an element
  within, the preprocessedMainOSIS, preprocessedRefOSIS or combinedGlossary.-->
  <function name="oo:getTocListItems" as="element()*">
    <param name="tocNode" as="node()"/><!-- tocElement or document-node -->
    <param name="preprocessedMainOSIS"/>
    <param name="preprocessedRefOSIS"/>
    <param name="combinedGlossary"/>

    <variable name="isTopTOC" select="$tocNode[self::document-node()]"/>
    <variable name="docWork" select="oc:docWork($tocNode)"/>
    <variable name="isMainNode" select="$docWork = $MAINMOD"/>
    <variable name="isDictNode" select="$docWork = $DICTMOD"/>
    <variable name="myTocLevel" as="xs:integer" select="
        if ($isTopTOC)
        then 0
        else oo:getTocLevel($tocNode)"/>
    <variable name="sourceDir" select="
        concat(
          '/html/',
          if ($isTopTOC)
            then oo:getFileName($mainTocMilestone)
            else oo:getFileName($tocNode)
        )"/>

    <if test="
        $myTocLevel &#60; 3 and
        not(
          oo:getTocInstructions($tocNode) = ('not_parent', 'no_inline_toc')
        )">
      <variable name="subentries" as="element()*">
        <choose>
          <!-- Generic Books including Children's Bibles -->
          <when test="($isChildrensBible or $isGenericBook) and $isTopTOC">
            <sequence select="$tocNode//
                milestone[@type=concat('x-usfm-toc', $TOC)]
                [contains(@n, '[level1]')][not(@isMainTocMilestone)]"/>
          </when>
          <when test="$isChildrensBible or $isGenericBook">
            <variable name="followingTocs" select="$tocNode/following::
                milestone[@type=concat('x-usfm-toc', $TOC)]
                [contains(@n, concat('[level',($myTocLevel+1),']'))]"/>
            <variable name="nextSibling"   select="$tocNode/following::
                milestone[@type=concat('x-usfm-toc', $TOC)]
                [contains(@n, concat('[level',$myTocLevel,']'))][1]"/>
            <sequence select="if ($nextSibling) then
                $followingTocs[. &#60;&#60; $nextSibling] else
                $followingTocs"/>
          </when>
          <!-- chapter start tag -->
          <when test="$tocNode/self::chapter[@sID]">
            <sequence select="
                ( $tocNode/following::seg[@type='keyword'] |
                  $tocNode/following::milestone
                    [@type=concat('x-usfm-toc', $TOC)]
                )[not(oo:getTocInstructions(.) = 'no_toc')]
                except $tocNode/following::chapter[@eID]
                  [@eID = $tocNode/@sID]/following::*
              "/>
          </when>
          <!-- otherwise use toclevel for this TOC element -->
          <otherwise>
            <variable name="followingTocCandidates" select="
                ( root($tocNode)//chapter[@sID] |
                  root($tocNode)//seg[@type='keyword'] |
                  root($tocNode)//milestone[@type=concat('x-usfm-toc', $TOC)]
                )[. &#62;&#62; $tocNode]
                  [not($isTopTOC and @isMainTocMilestone = 'true')]
                  [not(
                    $isTopTOC and self::*[contains(@n, '[no_main_inline_toc]')]
                  )]
                  [not(
                    ancestor::div[@type='glossary'][@subType='x-aggregate']
                  )]
                  [not(oo:getTocInstructions(.) = 'no_toc')]"/>
            <variable name="nextTocSP" select="
                if ($isTopTOC)
                then ()
                else $tocNode/following::*[. intersect $followingTocCandidates]
                  [oo:getTocLevel(.) &#60;= $myTocLevel][1]"/>
            <sequence select="
                $followingTocCandidates[oo:getTocLevel(.) = $myTocLevel + 1]
                [not($nextTocSP) or not(. intersect $nextTocSP)]
                [not($nextTocSP) or not(. &#62;&#62; $nextTocSP)]"/>
          </otherwise>
        </choose>
      </variable>
      <variable name="onlyKeywordFirstLetter" as="xs:boolean" select="
          not($isMainNode) and
          ($SCRIPT_NAME = 'osis2ebooks') and
          (
            count($subentries[@type='keyword']) &#62;=
            xs:integer(number($glossaryTocAutoThresh))
          ) and
          count(distinct-values(
            $subentries[@type='keyword']/oc:keySortLetter(text())
          )) &#62; 1"/>
      <for-each select="$subentries">
        <if test="not( $onlyKeywordFirstLetter and
                       boolean(self::seg[@type='keyword']) and
                       oc:skipGlossaryEntry(.)
                      )">
          <variable name="liClass" as="xs:string+">
            <variable name="class" as="xs:string+">
              <choose>
                <when test="self::chapter"
                > xsl-chapter-link </when>
                <when test="self::seg"
                > xsl-keyword-link </when>
                <when test="
                    $isChildrensBible and
                    $isTopTOC and
                    count(
                      preceding::milestone[contains(@n,'[level1]')]
                      [@type=concat('x-usfm-toc', $TOC)]
                    ) = (2,3)"
                > xsl-bookGroup-link </when>
                <when test="$isChildrensBible and $isTopTOC"
                > xsl-other-link </when>
                <when test="$isDictNode and oo:isGlossaryTOC(.)"
                > xsl-glossary-link</when>
                <when test="oo:isBookIntroTOC(.)"
                > xsl-book-introduction-link </when>
                <when test="oo:isBookTOC(.)"
                > xsl-book-link </when>
                <when test="oo:isBookSubGroupTOC(.)"
                > xsl-bookSubGroup-link </when>
                <when test="oo:isBookGroupTOC(.)"
                > xsl-bookGroup-link </when>
                <otherwise
                > xsl-other-link </otherwise>
              </choose>
              <value-of select="oc:getTocInstructions(.)"/>
              <if test="ancestor::div[@subType='x-navmenu-all-keywords']"
              > xsl-atoz </if>
            </variable>
            <value-of select="normalize-space(string-join($class, ' '))"/>
          </variable>
          <variable name="href" select="
            if ($target = 'html')
            then oc:uriToRelativePath(
                $sourceDir,
                concat('/html/', oo:getFileName(.), '#', oc:id(@osisID))
              )
            else concat('#', oc:id(@osisID))"/>
          <variable name="link" as="xs:string">
            <choose>
              <when test="self::chapter[@osisID]">
                <value-of select="tokenize(@osisID, '\.')[last()]"/>
              </when>
              <when test="
                  ancestor::div[@type='x-keyword']
                  [@subType = 'x-navmenu-all-keywords']">
                <value-of select="concat(
                    oc:keySortLetter(
                        ancestor::div[@type='x-keyword']/
                        descendant::reference[1]/string()
                      ),
                    '-',
                    oc:keySortLetter(
                        ancestor::div[@type='x-keyword']/
                        descendant::reference[last()]/string()
                      )
                  )"/>
              </when>
              <when test="
                  ancestor::div[@type='x-keyword']
                  [@subType = 'x-navmenu-letter']">
                <value-of select="
                  oc:keySortLetter(
                    ancestor::div[@type='x-keyword']/
                    descendant::seg[@type='keyword'][1]/string()
                  )"/>
              </when>
              <when test="
                  $onlyKeywordFirstLetter and
                  self::seg[@type='keyword']">
                <value-of select="oc:keySortLetter(text())"/>
              </when>
              <when test="matches(text(), '^\-')">
                <value-of select="text()"/>
              </when>
              <otherwise>
                <value-of select="oc:titleCase(oo:getTocTitle(.))"/>
              </otherwise>
            </choose>
          </variable>
          <choose>
            <when test="$target = 'html'">
              <html:li>
                <attribute name="class" select="$liClass"/>
                <!-- two divs are needed to center vertically -->
                <html:div>
                  <html:div>
                    <html:a>
                      <attribute name="href" select="$href"/>
                      <value-of select="$link"/>
                    </html:a>
                  </html:div>
                </html:div>
              </html:li>
            </when>
            <when test="$target = 'fb2'">
              <fb2:a xlink:href="{$href}"><value-of select="$link"/></fb2:a>
            </when>
          </choose>
        </if>
      </for-each>
    </if>
  </function>

  <function name="oo:isGlossaryTOC" as="xs:boolean">
    <param name="x" as="node()"/>
    <sequence select="boolean(
        $x intersect $x/ancestor::div[@type='glossary'][1]/
        descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]
        [not(oo:getTocClasses(.) = 'no_toc')])"/>
  </function>

  <function name="oo:isChildrensBibleSectionTOC" as="xs:boolean">
    <param name="x" as="node()"/>
    <sequence select="$isChildrensBible and boolean(
      $x[
        self::milestone[@type=concat('x-usfm-toc', $TOC)]
        [not(oo:getTocClasses(.) = 'no_toc')]
      ]/parent::dir[@type='majorSection'])"/>
  </function>

  <function name="oo:isBookIntroTOC" as="xs:boolean">
    <param name="x" as="node()"/>
    <sequence select="not(oo:isBookTOC($x)) and boolean(
        $x[
          self::milestone[@type=concat('x-usfm-toc', $TOC)]
          [not(oo:getTocClasses(.) = 'no_toc')]
        ][ancestor::div[@type='book']]
        [
          following::chapter[1] intersect
          ancestor::div[@type='book'][1]/descendant::chapter[1]
        ])"/>
  </function>

  <function name="oo:isBookTOC" as="xs:boolean">
    <param name="x" as="node()"/>
    <sequence select="boolean(
      $x intersect $x/ancestor::div[@type='book'][1]/
      milestone[@type=concat('x-usfm-toc', $TOC)][1]
      [not(oo:getTocClasses(.) = 'no_toc')]
      [
        following::chapter[1] intersect
        ancestor::div[@type='book'][1]/descendant::chapter[1]
      ])"/>
  </function>

  <function name="oo:isBookSubGroupTOC" as="xs:boolean">
    <param name="x" as="node()"/>
    <choose>
      <when test="
        not($x[self::milestone[@type=concat('x-usfm-toc', $TOC)]]) or
        oo:getTocClasses($x) = 'no_toc'">
        <sequence select="false()"/>
      </when>
      <when test="$x[contains(@n, '[bookSubGroup]')]">
        <sequence select="true()"/>
      </when>
      <otherwise>
        <sequence select="boolean(
            $x/ancestor::div
            [parent::div[@type='bookGroup']]
            [not(@type='book')]
            [preceding-sibling::div[1][@type='book']]
            [$x intersect descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]]
          )"/>
      </otherwise>
    </choose>
  </function>

  <function name="oo:isBookGroupTOC" as="xs:boolean">
    <param name="x" as="node()"/>
    <sequence select="boolean(
      $x intersect $x/ancestor::div[@type='bookGroup'][1]/
      descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]
      [not(oo:getTocClasses(.) = 'no_toc')]
      [
        . &#60;&#60;
        ancestor::div[@type='bookGroup'][1]/
        descendant::div[@type='book'][1]
      ]
      [not(contains(@n, '[bookSubGroup]'))]
    )"/>
  </function>

  <function name="oo:isBibleIntroTOC" as="xs:boolean">
    <param name="x" as="node()"/>
    <sequence select="boolean($x intersect $x/ancestor::osisText/
      div[not(@type = ('book', 'bookGroup'))]
        [. &#60;&#60; parent::osisText/div[@type='bookGroup'][1]]/
      descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]
      [not(oo:getTocClasses(.) = 'no_toc')])"/>
  </function>

  <function name="oo:isParentTOC" as="xs:boolean">
    <param name="x" as="node()"/>
    <sequence select="boolean(
        $x[
          self::milestone[@type=concat('x-usfm-toc', $TOC)]
          [not(oo:getTocClasses(.) = 'no_toc')]
          [oo:getTocClasses(.) = 'parent']
        ]
      ) or boolean(
        not(oo:getTocClasses($x) = ('no_toc', 'not_parent')) and
        (
          oo:isGlossaryTOC($x) or
          oo:isBibleIntroTOC($x) or
          oo:isBookTOC($x) or
          oo:isBookGroupTOC($x) or
          (oo:isBookSubGroupTOC($x) and oo:getTocLevel($x) = 1) or
          oo:isChildrensBibleSectionTOC($x)
        ))"/>
  </function>

  <function name="oo:getParentTOC" as="element(milestone)?">
    <param name="x" as="node()"/>
    <choose>
      <when test="oo:isGlossaryTOC($x) or
                  oo:isChildrensBibleSectionTOC($x) or
                  oo:isBookGroupTOC($x) or
                  oo:isBibleIntroTOC($x)">
        <sequence select="()"/>
      </when>
      <when test="oo:isBookIntroTOC($x)">
        <variable name="p1" select="$x/ancestor::div[@type='book'][1]/
          descendant::milestone[oo:isBookTOC(.)][1]"/>
        <variable name="p2" select="if ($p1) then $p1 else
          $x/ancestor::div[@type='bookGroup'][1]/
          descendant::milestone[oo:isBookGroupTOC(.)][1]"/>
        <sequence select="if (not($p2))
          then () else if (oo:isParentTOC($p2))
          then $p2 else oo:getParentTOC($p2)"/>
      </when>
      <when test="oo:isBookTOC($x)">
        <!-- really, p should use oo:isBookSubGroupTOC(.)[ancestor::div[contains(@scope, $x/@osisID)]
        but @scope needs to be a book list to work right. -->
        <variable name="p" select="$x/ancestor::div[@type='bookGroup'][1]/
          descendant::milestone[oo:isBookGroupTOC(.) or oo:isBookSubGroupTOC(.)]
          [. &#60;&#60; $x][last()]"/>
        <sequence select="if (not($p))
          then () else if (oo:isParentTOC($p))
          then $p else oo:getParentTOC($p)"/>
      </when>
      <when test="oo:isBookSubGroupTOC($x)">
        <variable name="p" select="$x/ancestor::div[@type='bookGroup'][1]/
          descendant::milestone[oo:isBookGroupTOC(.)][1]"/>
        <sequence select="if (not($p))
          then () else if (oo:isParentTOC($p))
          then $p else oo:getParentTOC($p)"/>
      </when>
      <otherwise>
        <sequence select="$x/ancestor::div
          [starts-with(@type, 'book') or parent::osisText][1]/
          descendant::milestone
          [@type=concat('x-usfm-toc', $TOC)][oo:isParentTOC(.)]
          [. &#60;&#60; $x][last()]"/>
      </otherwise>
    </choose>
  </function>

  <!-- getTocLevel returns an integer which is the TOC hierarchy level
  of the tocElement; where 1 is the hightest possible level and 3 is the
  lowest (deeper levels will throw an ERROR as they are not supported by
  eBook readers). IMPORTANT: the tocElement MUST be either the
  oo:origElement(.) or have an explicit TOC level (ie. [level2]). -->
  <function name="oo:getTocLevel" as="xs:integer">
    <param name="tocElement" as="element()"/>

    <variable name="toclevelEXPLICIT" as="xs:integer" select="
      if (matches($tocElement/@n, '\[level(\d)\]'))
      then (xs:integer(replace($tocElement/@n, '^.*?\[level(\d)\].*$', '$1')))
      else 0"/>
    <variable name="parentTOC" as="element(milestone)?"
      select="oo:getParentTOC($tocElement)"/>
    <variable name="result" as="xs:integer">
      <choose>
        <when test="$toclevelEXPLICIT != 0">
          <value-of select="$toclevelEXPLICIT"/>
        </when>
        <when test="$parentTOC">
          <value-of select="1 + oo:getTocLevel($parentTOC)"/>
        </when>
        <otherwise><value-of select="1"/></otherwise>
      </choose>
    </variable>
    <choose>
      <when test="$result &#62; 3">
        <value-of select="3"/>
        <call-template name="Warn">
<with-param name="msg">Maximum TOC level exceeded (<value-of select="$result"/> &#62; 3) defaulting to 3: <value-of select="oc:printNode($tocElement)"/></with-param>
<with-param name="exp">EBook readers handle up to 3 levels of TOC. Use [levelN] TOC instructions to reduce the hierarchy level.</with-param>
        </call-template>
      </when>
      <otherwise><value-of select="$result"/></otherwise>
    </choose>
  </function>

  <!-- oo:getTocInstructions returns all TOC instructions of a TOC element.
  IMPORTANT: the tocElement MUST be either the oo:origElement(.) or have
  an explicit TOC level (ie. [level2]).
  These are TOC elements:
    milestone[@type=concat('x-usfm-toc', $TOC)]
    chapter[@sID]
    seg[@type='keyword'] -->
  <function name="oo:getTocInstructions" as="xs:string*">
    <param name="tocElement" as="node()?"/>

    <if test="$tocElement[self::element()]">
      <variable name="instructions" as="xs:string*">
        <if test="$tocElement/ancestor-or-self::div
            [@annotateType='x-feature' and @annotateRef='NO_TOC']">
          <value-of select="'no_toc'"/>
        </if>
        <if test="$tocElement[@n]">
          <analyze-string select="$tocElement/@n" regex="\[([^\]]+)\]">
            <matching-substring>
              <value-of select="regex-group(1)"/>
            </matching-substring>
          </analyze-string>
        </if>
      </variable>
      <sequence select="distinct-values($instructions)"/>
    </if>
  </function>

  <!-- oo:getTocClasses returns all classes associated with a TOC element,
  which includes any TOC instructions. IMPORTANT: the tocElement MUST be either
  the oo:origElement(.) or have an explicit TOC level (ie. [level2]).
  These are TOC elements:
    milestone[@type=concat('x-usfm-toc', $TOC)]
    chapter[@sID]
    seg[@type='keyword'] -->
  <function name="oo:getTocClasses" as="xs:string*">
    <param name="tocElement" as="node()?"/>

    <if test="$tocElement[self::element()]">
      <variable name="instructions" as="xs:string*"
        select="oo:getTocInstructions($tocElement)"/>
      <sequence select="distinct-values((
          if (not($instructions = 'no_toc')) then 'xsl-toc-entry' else '',
          $instructions,
          oc:getClasses($tocElement)) )"/>
    </if>
  </function>

  <!-- oo:getTocAttributes returns attributes for transformed TOC
  elements. The title attribute is used Calibre for building the TOC.
  IMPORTANT: the tocElement MUST be either the oo:origElement(.)
  or have an explicit TOC level (ie. [level2]).
  These are TOC elements:
    milestone[@type=concat('x-usfm-toc', $TOC)]
    chapter[@sID]
    seg[@type='keyword'] -->
  <function name="oo:getTocAttributes" as="attribute()+">
    <param name="tocElement" as="element()"/>
    <variable name="classes" select="oo:getTocClasses($tocElement)"/>

    <attribute name="id" select="oc:id($tocElement/@osisID)"/>

    <if test="$target = 'html'">
      <attribute name="class" select="
        normalize-space(string-join($classes, ' '))"/>

      <if test="not($classes = ('no_toc', 'only_inline_toc'))">
        <attribute name="title" select="
          concat('toclevel-', oo:getTocLevel($tocElement))"/>
      </if>
    </if>
  </function>

  <!-- oo:origElement returns the element from the original preprocessed osis
  file having the same osisID as the passed element, for elements that need
  context for TOC determination. Otherwise element is simply returned. -->
  <function name="oo:origElement" as="element()">
    <param name="element" as="element()"/>
    <param name="preprocessedMainOSIS"/>
    <param name="preprocessedRefOSIS"/>
    <param name="combinedGlossary"/>
    <choose>
      <when test="$element[@osisID]
          [ self::milestone[@type=concat('x-usfm-toc', $TOC)] or
            self::seg[@type='keyword'] ]">
        <variable name="result" as="element()?">
          <choose>
            <when test="
                $element/ancestor::osisText[1]/@osisIDWork =
                $preprocessedMainOSIS/descendant-or-self::osisText[1]/@osisIDWork">
              <sequence select="key('osisID', $element/@osisID, $preprocessedMainOSIS)"/>
            </when>
            <when test="
                $element/ancestor::osisText[1]/@osisIDWork =
                $preprocessedRefOSIS/descendant-or-self::osisText[1]/@osisIDWork">
              <sequence select="key('osisID', $element/@osisID, $preprocessedRefOSIS)"/>
            </when>
            <otherwise>
              <sequence select="key('osisID', $element/@osisID, $combinedGlossary)"/>
            </otherwise>
          </choose>
        </variable>
        <if test="
            not($result) and
            not($element/@osisID = 'CombindedGlossary')
          ">
          <call-template name="ErrorBug">
<with-param name="msg">oo:origElement() found no original element: <value-of select="oc:printNode($element)"/></with-param>
          </call-template>
        </if>
        <sequence select="if ($result) then $result else $element"/>
      </when>
      <otherwise><sequence select="$element"/></otherwise>
    </choose>
  </function>

  <!-- oo:getTocTitle returns the string title of a tocElement (without any
  prefixed TOC instructions). If an 'n' attribute is present with a title,
  it will override the default title.
  These are TOC elements (others will Error):
    milestone[@type=concat('x-usfm-toc', $TOC)]
    chapter[@sID]
    seg[@type='keyword'] -->
  <function name="oo:getTocTitle" as="xs:string">
    <param name="tocElement0" as="element()"/>

    <variable name="tocElement" as="element()">
      <choose>
        <when test="$tocElement0[self::milestone][oo:isBookTOC($tocElement0)]/
          parent::*/milestone[@type=concat('x-usfm-toc', $TitleTOC)][1][@n]">
          <sequence select="$tocElement0/
          parent::*/milestone[@type=concat('x-usfm-toc', $TitleTOC)][1][@n]"/>
        </when>
        <otherwise><sequence select="$tocElement0"/></otherwise>
      </choose>
    </variable>

    <variable name="tocTitleEXPLICIT" select="
      if ($tocElement/@n)
      then replace($tocElement/@n, '^(\[[^\]]*\])+', '')
      else ''"/>

    <variable name="tocTitleOSIS">
      <choose>
        <!-- milestone TOC -->
        <when test="$tocElement0[self::milestone[@type=concat('x-usfm-toc', $TOC)]]">
          <value-of select="$tocTitleEXPLICIT"/>
        </when>
        <!-- chapter TOC -->
        <when test="$tocElement[self::chapter[@sID]]">
          <variable name="chapterLabel" as="element(title)?">
            <apply-templates mode="chapterLabel" select="
              $tocElement/following::title[@type='x-chapterLabel'][1]
              [following::chapter[1][@eID=$tocElement/@sID]]" />
          </variable>
          <choose>
            <when test="$chapterLabel">
              <value-of select="normalize-space(string($chapterLabel))"/>
            </when>
            <otherwise><value-of select="tokenize($tocElement/@sID, '\.')[last()]"/></otherwise>
          </choose>
        </when>
        <!-- glossary keyword TOC -->
        <when test="$tocElement[self::seg[@type='keyword']]">
          <value-of select="string($tocElement)"/>
        </when>
        <!-- otherwise error -->
        <otherwise>
          <call-template name="ErrorBug">
<with-param name="msg">oo:getTocTitle() argument 1 is not a TOC element: <value-of select="oc:printNode($tocElement0)"/></with-param>
          </call-template>
        </otherwise>
      </choose>
    </variable>
    <!-- final result -->
    <value-of select="if ($tocTitleEXPLICIT) then $tocTitleEXPLICIT else $tocTitleOSIS"/>
  </function>
  <template mode="chapterLabel" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  <template mode="chapterLabel" match="note"/>

  <!-- #################################################################### -->
  <!--                 PRE-PROCESS THE MAIN OSIS FILE                        -->
  <!-- #################################################################### -->

  <!-- OSIS pre-processing templates greatly speed up processing that
  requires node copying/deleting/modification. -->
  <template mode="preprocess
                  preprocess_removeSectionDivs
                  preprocess_expelChapterTags
                  preprocess_glossTocMenus
                  preprocess_addGroupAttribs" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>

  <template mode="preprocess" match="osis">
    <if test="not($mainTocMilestone)">
      <call-template name="Error">
<with-param name="msg">No main TOC milestone was found.</with-param>
<with-param name="exp">Add a TOC tag at the beginning of the main document.</with-param>
      </call-template>
    </if>
    <next-match/>
  </template>

  <!-- preprocess
  The x-aggregate glossary is copied to the combined glossary whenever it is used
  (therefore x-keyword-duplicate keywords are NOT included in the combined glossary).
  This means that links to x-keyword-duplicate keywords need to be redirected to
  their aggregated entries by the 'reference' template. -->
  <template mode="preprocess"
    match="div[@type='glossary'][@subType='x-aggregate'] |
           div[@type='glossary'][$doCombineGlossaries][not(ancestor::osis[@isCombinedGlossary])] |
           div[@annotateType='x-feature'][@annotateRef='INT'][oc:docWork(.) = $DICTMOD] |
           div[@scope='NAVMENU']"/>
  <template mode="preprocess" match="list[@resp='x-oc'][@subType='x-navmenu']"/>
  <!-- These variables are used to match any removed DICTMOD INT keywords to
  a Bible intro title, to fix any references to those keywords. -->
  <variable name="INT_osisID" as="xs:string*" select="$referenceOSIS/descendant::div
      [self::div[@annotateType='x-feature'][@annotateRef='INT'] | self::div[@scope='NAVMENU']]/
      descendant::*[@osisID]/replace(@osisID, '^[^:]*:', '')"/>
  <variable name="INT_title" as="xs:string*" select="for $id in $INT_osisID return oc:decodeOsisRef($id)"/>
  <variable name="INT_titleElement" as="element(title)*"
      select="$mainInputOSIS/descendant::div[@annotateType='x-feature'][@annotateRef='INT']/
              descendant::title[string() = $INT_title]
                                              "/>
  <template mode="preprocess" match="reference[@osisRef]/@osisRef">
    <!-- x-glossary and x-glosslink references may have multiple targets;
    remove any that don't resolve, and keep only the first that does. -->
    <variable name="docwork" select="oc:docWork(.)"/>
    <variable name="osisRef1" select="(
        for $r in tokenize(., '\s+') return
        if ( oc:work($r, $docwork) != $DICTMOD or oc:key('osisID', $referenceOSIS, $DICTMOD, oc:ref($r)) )
        then $r else ''
      )[normalize-space()][1]"/>

    <!-- when using the combined glossary, redirect duplicates to the combined glossary -->
    <variable name="osisRef2" select="if ($doCombineGlossaries) then
                                      replace($osisRef1, '\.dup\d+', '') else
                                      $osisRef1"/>
    <!-- Insure osisRef has workid prefix. -->
    <variable name="osisRef" as="xs:string" select="
      if (contains($osisRef2, ':'))
      then $osisRef2
      else concat($docwork, ':', $osisRef2)"/>

    <variable name="result" as="xs:string">
      <choose>
        <when test=". = ($REF_introduction, $REF_introductionINT)">
          <value-of select="$REF_BibleTop"/>
        </when>
        <when test=". = $REF_dictionary">
          <value-of select="$REF_DictTop"/>
        </when>
        <!-- forward removed Dict INT keyword references to the matching Bible INT introduction title -->
        <when test="count($INT_osisID) and
                    tokenize($osisRef,':')[1] = $DICTMOD and
                    tokenize($osisRef,':')[2] = $INT_osisID">
          <variable name="ref" select="if (tokenize($osisRef,':')[2] = $INT_titleElement/oc:encodeOsisRef(string())) then
                                      concat($MAINMOD,':',tokenize($osisRef,':')[2], '!INT') else
                                      concat($MAINMOD,':BIBLE_TOP')"/>
          <value-of select="$ref"/>
          <call-template name="Note">
<with-param name="msg">Forwarding INT reference <value-of select="$osisRef2"/> to <value-of select="$ref"/></with-param>
          </call-template>
        </when>
        <otherwise>
          <value-of select="$osisRef"/>
        </otherwise>
      </choose>
    </variable>
    <attribute name="osisRef" select="$result"/>
  </template>
  <template mode="preprocess" match="milestone[@type=concat('x-usfm-toc', $TOC)]">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <if test="self::*[. intersect $mainTocMilestone]">
        <attribute name="isMainTocMilestone" select="'true'"/>
      </if>
      <if test="not(@osisID) or not(matches(@osisID, '\S'))">
        <attribute name="osisID" select="generate-id(.)"/>
      </if>
      <if test="not(ancestor::div[@type='glossary']) and
                not(matches(@n, '\[(inline_toc_first|inline_toc_last)\]'))">
        <attribute name="n" select="concat(if (oc:docWork(.) = $MAINMOD)
                                           then '[inline_toc_first]'
                                           else '[inline_toc_last]', @n)"/>
      </if>
      <apply-templates mode="#current"/>
    </copy>
  </template>
  <template mode="preprocess" match="title[oc:docWork(.) = $MAINMOD]
                                          [ancestor::div[@annotateType='x-feature'][@annotateRef='INT']]
                                          [string() = $INT_title]">
    <copy><!-- !INT extension allows reference mode=html Scripture ref check -->
      <apply-templates mode="#current" select="@*"/>
      <attribute name="osisID" select="concat(oc:encodeOsisRef(string()),'!INT')"/>
      <apply-templates mode="#current"/>
    </copy>
    <call-template name="Note">
<with-param name="msg">Adding INT osisID <value-of select="concat(oc:encodeOsisRef(string()),'!INT')"/></with-param>
    </call-template>
  </template>
  <!-- osisIDs do not have workid prefixes -->
  <template mode="preprocess" match="@osisID">
    <attribute name="osisID" select="replace(., '^[^:]*:', '')"/>
    <if test="tokenize(.,':')[2] and tokenize(.,':')[1] != oc:docWork(.)">
      <call-template name="Error">
<with-param name="msg">An element's osisID had a work prefix that was different than its work: <value-of select="."/></with-param>
      </call-template>
    </if>
  </template>

  <!-- preprocess_removeSectionDivs -->
  <template mode="preprocess_removeSectionDivs" match="div[ends-with(lower-case(@type), 'section')]">
    <apply-templates mode="preprocess_removeSectionDivs"/>
  </template>

  <!-- preprocess_expelChapterTags -->
  <template mode="preprocess_expelChapterTags" match="*[parent::div[@type='book']]">
    <variable name="book" select="parent::*/@osisID"/>
    <sequence select="oc:expelElements(., descendant::chapter[starts-with(@sID, concat($book, '.'))], (), false())"/>
  </template>

  <!-- preprocess_glossTocMenus -->
  <template mode="preprocess_glossTocMenus" match="div[@type='glossary']">
    <variable name="my_glossaryToc" as="xs:string"
      select="if (count(distinct-values(descendant::seg[@type='keyword']/oc:keySortLetter(text()))) = 1) then 'single' else
              if ( $glossaryToc = 'letter' or
                   ($glossaryToc = 'AUTO' and
                     count(descendant::div[starts-with(@type,'x-keyword')]) &#62;= $glossaryTocAutoThresh)
                 ) then 'letter'
              else 'single'"/>
    <variable name="my_keywordFile"
      select="if (count(descendant::seg[@type='keyword']) = 1) then 'glossary' else
              if (self::div[@annotateType='x-feature' and @annotateRef='NO_TOC']) then 'single' else
              if ($keywordFile != 'AUTO') then $keywordFile else
              if (count(descendant::div[starts-with(@type, 'x-keyword')]) &#60; $keywordFileAutoThresh) then 'glossary'
              else 'letter'"/>
    <call-template name="Note">
<with-param name="msg">Glossary menus: <value-of select="oc:getDivTitle(.)"/>, my_glossaryToc=<value-of select="$my_glossaryToc"/>, my_keywordFile=<value-of select="$my_keywordFile"/></with-param>
    </call-template>
    <variable name="glossary" as="element(div)">
      <copy>
        <choose>
          <when test="$my_glossaryToc = 'letter' and $my_keywordFile = 'single'">
            <apply-templates mode="#current" select="@*"/>
            <variable name="keywords" as="node()*">
              <apply-templates mode="#current"/>
            </variable>
            <sequence select="oc:setKeywordTocInstruction($keywords, '[no_toc]')"/>
            <sequence select="oc:glossaryMenu(., 'no', 'yes', false())"/>
          </when>
          <when test="$my_glossaryToc = 'letter'">
            <!-- copy everything except x-keyword divs, which are replaced by
            glossaryMenu() because last arg is true() -->
            <copy-of select="@* | node()[not(self::div[starts-with(@type,'x-keyword')])]"/>
            <sequence select="oc:glossaryMenu(., 'no', 'yes', true())"/>
          </when>
          <otherwise>
            <apply-templates mode="#current" select="node()|@*"/>
          </otherwise>
        </choose>
      </copy>
    </variable>
    <!-- A huge speedup is gained by calculating a glossaryGroup attribute
    here, rather than calculating groups in divideFiles and getFileName -->
    <apply-templates mode="preprocess_addGroupAttribs" select="$glossary">
      <with-param name="my_keywordFile" select="$my_keywordFile" tunnel="yes"/>
    </apply-templates>
  </template>
  <template mode="preprocess_addGroupAttribs" match="div[@type='glossary']">
    <copy>
      <apply-templates mode="preprocess_addGroupAttribs" select="@*"/>
      <attribute name="glossaryGroup" select="'0'"/>
      <apply-templates mode="preprocess_addGroupAttribs"/>
    </copy>
  </template>
  <template mode="preprocess_addGroupAttribs" match="div[starts-with(@type,'x-keyword')]">
    <param name="my_keywordFile" tunnel="yes"/>
    <copy>
      <apply-templates mode="preprocess_addGroupAttribs" select="@*"/>
      <variable name="group" as="xs:integer">
        <choose>
          <when test="$my_keywordFile = 'single'">
            <value-of select="1 + count(preceding::div[starts-with(@type, 'x-keyword')])"/>
          </when>
          <when test="$my_keywordFile = 'letter'">
            <value-of select="count(distinct-values(
              (preceding::div | self::div)/descendant::seg[@type='keyword']/
                (
                  if (ancestor::div[@subType='x-navmenu-all-keywords']) then string()
                  else oc:keySortLetter(string())
                )
            ))"/>
          </when>
          <otherwise><value-of select="0"/></otherwise>
        </choose>
      </variable>
      <attribute name="glossaryGroup" select="$group"/>
      <apply-templates mode="preprocess_addGroupAttribs"/>
    </copy>
  </template>

  <!-- #################################################################### -->
  <!--                TRANSFORM OSIS INTO OTHER MARKUP                      -->
  <!-- #################################################################### -->

  <!-- All text nodes are copied -->
  <template mode="tran" match="text()"><copy/></template>

  <!-- By default, attributes are dropped -->
  <template mode="tran" match="@*"/>

  <!-- ...except @osisID which are used as link targets -->
  <template mode="tran" match="@osisID" name="osisID">
    <if test="$target = 'html'">
      <attribute name="id" select="oc:id(.)"/>
    </if>
    <if test="$target = 'fb2'">
      <!-- osisID attributes are stripped during FB2 postprocessing, once id
      targets are finalized. -->
      <attribute name="osisID" select="@osisID"/>
    </if>
  </template>

  <!-- By default, elements get their namespace changed from OSIS to the other,
  with a class attribute added (and other attributes dropped) -->
  <template mode="tran" match="*">
    <variable name="ns" select="
      if ($target = 'html')
      then 'http://www.w3.org/1999/xhtml'
      else (if ($target = 'fb2')
      then 'http://www.gribuser.ru/xml/fictionbook/2.0'
      else 'unknown')"/>
    <element name="{local-name()}" namespace="{$ns}">
      <call-template name="classedContent">
        <with-param name="parentName" select="local-name()"/>
      </call-template>
    </element>
  </template>

  <!-- Remove these elements entirely (x-chapterLabel is handled by oo:getTocTitle())-->
  <template mode="tran" match="
    header |
    chapter[@eID] |
    verse[@eID] |
    title[@type='runningHead'] |
    title[@type='x-chapterLabel'] |
    index |
    milestone"/>

  <!-- Remove these tags (keeping their content) -->
  <template mode="tran" match="osis | osisText | name | reference[ancestor::title[@type='scope']]">
    <apply-templates mode="tran"/>
  </template>

  <!-- FB2 sections with title:
  @type='fb2:section' was added during FB2 precrocessing.-->
  <template mode="tran" priority="2" match="div[@type='fb2:section']">
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    <variable name="tocElement" select="
      descendant-or-self::*[
        self::chapter[@sID] or
        self::seg[@type='keyword'] or
        self::milestone[@type=concat('x-usfm-toc', $TOC)]
      ][1]"/>
    <choose>
      <when test="$target = 'html'"><next-match/></when>
      <when test="$target = 'fb2'">
        <variable name="content0" as="node()*">
          <apply-templates mode="tran"/>
        </variable>
        <variable name="content" as="node()*" select="
          $content0[
            descendant-or-self::text()[normalize-space()] or
            descendant-or-self::fb2:empty-line or
            descendant-or-self::fb2:image or
            descendant-or-self::fb2:tmpOsisID
          ]"/>
        <if test="$content">
          <choose>
            <when test="@position = '1'">
              <fb2:annotation>
                <!-- FB2 annotation elements cannot contain images -->
                <sequence select="oo:fb2SectionContent($content[not(self::fb2:image)])"/>
              </fb2:annotation>
            </when>
            <otherwise>
              <fb2:section>
                <if test="@osisID">
                  <attribute name="id" select="oc:id(@osisID)"/>
                </if>
                <fb2:title>
                  <fb2:p id="{concat('p.2.', generate-id(.))}">
                    <value-of select="
                      if ($tocElement)
                      then oc:titleCase(oo:getTocTitle(oo:origElement(
                          $tocElement,
                          $preprocessedMainOSIS,
                          $preprocessedRefOSIS,
                          $combinedGlossary
                        )))
                      else ''"/>
                  </fb2:p>
                </fb2:title>
                <sequence select="oo:fb2SectionContent($content)"/>
              </fb2:section>
            </otherwise>
          </choose>
        </if>
      </when>
    </choose>
  </template>

  <!-- Verses -->
  <template mode="tran" priority="3" match="verse[@sID] | hi[@subType='x-alternate']">
    <param name="doWrite" tunnel="yes"/>
    <!-- skip verse numbers that are immediately followed by p, lg, l, list, item or canonical title,
    since their templates will write verse numbers inside themselves using WriteEmbededVerse-->
    <if test="$doWrite or not(self::*[
        following-sibling::*[1]
        [self::p or self::lg or self::l or self::list or self::item or self::title[@canonical='true']]
      ])">
      <next-match/>
    </if>
  </template>
  <template mode="tran" match="verse[@sID]"><call-template name="WriteVerseNumber"/></template>

  <!-- Chapters -->
  <template mode="tran" match="chapter[@sID and @osisID]">
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    <variable name="tocInstructions" select="oo:getTocInstructions(.)"/>
    <variable name="chapterLabel" select="
      following::title[@type='x-chapterLabel'][1]
      [following::chapter[1][@eID=current()/@sID]]" />
    <variable name="tocTitle0" select="oo:getTocTitle(.)"/>
    <variable name="tocTitle">
      <choose>
        <when test="$chapterLabel">
          <!-- x-chapterLabel titles may contain other elements such as
          footnotes which need to be output -->
          <apply-templates mode="tran" select="$chapterLabel/node()"/>
        </when>
        <otherwise>
          <value-of select="$tocTitle0"/>
        </otherwise>
      </choose>
    </variable>
    <if test="$target = 'html'">
      <html:h1>
        <sequence select="oo:getTocAttributes(.)"/>
        <sequence select="$tocTitle"/>
      </html:h1>
    </if>
    <if test="$target = 'fb2' and $tocInstructions = 'no_toc'">
      <!-- No FB2 section will have this osisID, so keep a potential link
      target. -->
      <fb2:tmpOsisID osisID="{@osisID}"/>
      <fb2:tmpOsisID osisID="{oc:id(@osisID)}"/>
    </if>
    <!-- non-Bible chapters also get inline TOC -->
    <if test="
        oc:docWork(.) != $MAINMOD and
        not($tocInstructions = 'no_toc')">
      <choose>
        <when test="$target = 'html'">
          <html:h1 class="xsl-nonBibleChapterLabel">
            <value-of select="$tocTitle"/>
          </html:h1>
          <sequence select="oo:getElementInlineTOC(
              .,
              $preprocessedMainOSIS,
              $preprocessedRefOSIS,
              $combinedGlossary
            )"/>
        </when>
        <when test="$target = 'fb2'">
          <sequence select="oo:getElementInlineTOC(
              .,
              $preprocessedMainOSIS,
              $preprocessedRefOSIS,
              $combinedGlossary
            )"/>
        </when>
      </choose>
    </if>
  </template>

  <!-- Glossary keywords -->
  <template mode="tran" priority="2" match="seg[@type='keyword']">
    <choose>
      <when test="$target = 'html'">
        <html:dfn>
          <sequence select="oo:getTocAttributes(.)"/>
          <value-of select="oo:getTocTitle(.)"/>
        </html:dfn>
      </when>
      <when test="$target = 'fb2'">
        <if test="oo:getTocInstructions(.) = 'no_toc'">
          <!-- No FB2 section will have this osisID, so keep a potential link
          target. -->
          <fb2:tmpOsisID osisID="{@osisID}"/>
          <fb2:tmpOsisID osisID="{oc:id(@osisID)}"/>
        </if>
        <fb2:strong>
          <value-of select="oo:getTocTitle(.)"/>
        </fb2:strong>
      </when>
    </choose>
  </template>

  <!-- Glossary entries -->
  <template mode="tran" priority="3" match="div[starts-with(@type,'x-keyword')]">
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    <variable name="disambigHeading" as="node()*">
      <if test="
          not(ancestor-or-self::div[@resp='x-oc']) and
          not($doCombineGlossaries) and
          oo:getTocLevel(.//seg[@type='keyword'][1]) = 1 and
          count(distinct-values(
            $preprocessedRefOSIS//div[@type='glossary']/
            oc:getDivScopeTitle(.)
          )) &#62; 1">
        <variable name="heading" as="node()*">
          <call-template name="keywordDisambiguationHeading"/>
        </variable>
        <apply-templates mode="tran" select="$heading"/>
      </if>
    </variable>
    <choose>
      <when test="$target = 'html'">
        <!-- Add an ebook page-break if there is more than one keyword in the glossary.
        NOTE: Calibre splits files at these CSS page breaks. -->
        <variable name="needPageBreak" as="xs:boolean" select="$SCRIPT_NAME = 'osis2ebooks' and
          count(ancestor::div[@type='glossary']/descendant::seg[@type='keyword']) &#62; 1"/>
        <html:div>
          <variable name="classes" select="oc:getClasses(.)"/>
          <attribute name="class" select="if (not($needPageBreak)) then $classes else
            normalize-space(string-join((tokenize($classes, ' '), 'osis-milestone', 'pb'), ' '))"/>
          <sequence select="$disambigHeading"/>
          <apply-templates mode="tran"/>
        </html:div>
      </when>
      <when test="$target = 'fb2'">
        <sequence select="$disambigHeading"/>
        <apply-templates mode="tran"/>
      </when>
    </choose>
  </template>

  <!-- Titles -->
  <template mode="tran" match="title">
    <choose>
      <when test="$target = 'html'">
        <element name="h{if (@level) then @level else '1'}" namespace="http://www.w3.org/1999/xhtml">
          <if test="@osisID"><attribute name="id" select="oc:id(@osisID)"/></if>
          <call-template name="classes"/>
          <if test="@canonical='true'">
            <call-template name="WriteEmbededChapter"/>
            <call-template name="WriteEmbededVerse"/>
          </if>
          <apply-templates mode="tran"/>
        </element>
      </when>
      <when test="$target = 'fb2'">
        <variable name="content" as="node()*">
          <if test="@canonical='true'">
            <call-template name="WriteEmbededVerse"/>
          </if>
          <apply-templates mode="tran"/>
        </variable>
        <fb2:empty-line/>
        <fb2:subtitle>
          <sequence select="oo:getClassedContent(., 'subtitle', $content, '')"/>
        </fb2:subtitle>
        <if test="@osisID">
          <fb2:tmpOsisID osisID="{@osisID}"/>
          <fb2:tmpOsisID osisID="{oc:id(@osisID)}"/>
        </if>
      </when>
    </choose>
  </template>

  <!-- Parallel passage titles become secondary titles !-->
  <template mode="tran" match="title[@type='parallel']">
    <choose>
      <when test="$target = 'html'">
        <html:h2>
          <call-template name="classedContent"/>
        </html:h2>
      </when>
      <when test="$target = 'fb2'">
        <fb2:empty-line/>
        <fb2:subtitle>
          <call-template name="classedContent">
            <with-param name="parentName" select="'subtitle'"/>
          </call-template>
        </fb2:subtitle>
      </when>
    </choose>
  </template>

  <!-- OSIS elements which will become spans with a special class !-->
  <template mode="tran" match="catchWord |
                                foreign |
                                hi |
                                rdg |
                                signed |
                                transChange">
    <choose>
      <when test="$target = 'html'">
        <html:span>
          <call-template name="classedContent"/>
        </html:span>
      </when>
      <when test="$target = 'fb2'">
        <call-template name="classedContent"/>
      </when>
    </choose>
  </template>

  <template mode="tran" match="cell">
    <choose>
      <when test="$target = 'html'">
        <html:td>
        <call-template name="classedContent"/>
      </html:td>
    </when>
      <when test="$target = 'fb2'">
        <fb2:td id="{concat('td.1.', generate-id(.))}">
          <call-template name="classedContent">
            <with-param name="parentName" select="'td'"/>
          </call-template>
        </fb2:td>
      </when>
    </choose>
  </template>

  <template mode="tran" match="caption">
    <choose>
      <when test="$target = 'html'">
        <element name="{if ($html5 = 'true') then 'figcaption' else 'div'}"
            namespace="http://www.w3.org/1999/xhtml">
          <call-template name="classedContent"/>
        </element>
      </when>
      <when test="$target = 'fb2'">
        <fb2:emphasis>
          <call-template name="classedContent">
            <with-param name="parentName" select="'emphasis'"/>
          </call-template>
        </fb2:emphasis>
      </when>
    </choose>
  </template>

  <template mode="tran" priority="4" match="div[@type='introduction']">
    <next-match/>
    <choose>
      <when test="$target = 'html'"><html:hr/></when>
      <!-- TODO: FB2 schema limits these: <when test="$target = 'fb2'"><fb2:empty-line/></when>-->
    </choose>
  </template>

  <template mode="tran" match="figure">
    <param name="contextFile" select="oo:getFileName(.)" tunnel="yes"/>
    <choose>
      <when test="$target = 'html'">
        <element name="{if ($html5 = 'true') then 'figure' else 'div'}"
            namespace="http://www.w3.org/1999/xhtml">
          <call-template name="classes"/>
          <html:img src="{oc:uriToRelativePath(concat('/html/', $contextFile), @src)}" alt="{@src}"/>
          <apply-templates mode="tran"/>
        </element>
      </when>
      <when test="$target = 'fb2'">
        <fb2:image xlink:href="{concat('#image.', replace(./@src, '^.*/', ''))}"/>
        <apply-templates mode="tran"/>
      </when>
    </choose>
  </template>

  <template mode="tran" match="head">
    <choose>
      <when test="$target = 'html'">
        <html:h2>
          <call-template name="classedContent"/>
        </html:h2>
      </when>
      <when test="$target = 'fb2'">
        <choose>
          <when test="parent::list">
            <!-- already output in list template -->
          </when>
          <otherwise>
            <fb2:empty-line/>
            <fb2:subtitle>
              <call-template name="classedContent">
                <with-param name="parentName" select="'subtitle'"/>
              </call-template>
            </fb2:subtitle>
          </otherwise>
        </choose>
      </when>
    </choose>
  </template>

  <template mode="tran" match="item[@subType='x-prevnext-link'][ancestor::div[starts-with(@type, 'x-keyword')]]">
    <if test="$doCombineGlossaries"><next-match/></if>
  </template>

  <template mode="tran" match="item">
    <variable name="content" as="node()*">
      <if test="$target != 'fb2'">
        <call-template name="WriteEmbededChapter"/>
      </if>
      <call-template name="WriteEmbededVerse"/>
      <apply-templates mode="tran"/>
    </variable>
    <choose>
      <when test="$target = 'html'">
        <html:li>
          <sequence select="oo:getClassedContent(., 'li', $content, '')"/>
        </html:li>
      </when>
      <when test="$target = 'fb2'">
        <fb2:tr align="left">
          <fb2:td id="{concat('td.2.', generate-id(.))}">
            <sequence select="oo:getClassedContent(., 'td', $content, '')"/>
          </fb2:td>
        </fb2:tr>
      </when>
    </choose>
  </template>

  <template mode="tran" match="lb">
    <choose>
      <when test="@type = 'x-optional'"/>
      <when test="$target = 'html' and @type = 'x-hr'">
        <html:hr><call-template name="classes"/></html:hr>
      </when>
      <when test="$target = 'html'">
        <html:br><call-template name="classes"/></html:br>
      </when>
      <when test="$target = 'fb2'">
        <!-- empty-line cannot occur in poem (which osis:lg becomes)
        or some other elements -->
        <if test="not(ancestor::lg or ancestor::table or ancestor::list)">
          <fb2:empty-line/>
        </if>
      </when>
    </choose>
  </template>

  <!-- usfm2osis.py follows the OSIS manual recommendation for selah as a line element
  which differs from the USFM recommendation for selah. According to USFM 2.4 spec,
  selah is: "A character style. This text is frequently right aligned, and rendered
  on the same line as the previous poetic text..." !-->
  <template mode="tran" match="l">
    <variable name="content" as="node()*">
       <if test="$target != 'fb2'">
        <call-template name="WriteEmbededChapter"/>
      </if>
      <call-template name="WriteEmbededVerse"/>
      <apply-templates mode="tran"/>
    </variable>
    <choose>
      <when test="$target = 'html'">
        <choose>
          <when test="@type = 'selah'"/>
          <when test="following-sibling::l[1][@type='selah']">
            <!-- Consecutive selah l elements are all output together within the
            preceding div. Selah must not be the first line in a linegroup, or it
            will be ignored. -->
            <variable name="content2">
              <sequence select="$content"/>
              <html:i class="xsl-selah">
                <for-each select="following-sibling::l[@type='selah']
                    [ count(preceding-sibling::l[@type='selah'][. &#62;&#62; current()]) =
                      count(preceding-sibling::l[. &#62;&#62; current()]) ]">
                  <text> </text>
                  <apply-templates mode="tran"/>
                </for-each>
              </html:i>
            </variable>
            <html:div>
              <sequence select="oo:getClassedContent(., 'div', $content2, '')"/>
            </html:div>
          </when>
          <otherwise>
            <html:div>
              <sequence select="oo:getClassedContent(., 'div', $content, '')"/>
            </html:div>
          </otherwise>
        </choose>
      </when>
      <when test="$target = 'fb2'">
        <fb2:v id="{concat('v.1.', generate-id(.))}">
          <sequence select="oo:getClassedContent(., 'v', $content, '')"/>
        </fb2:v>
      </when>
    </choose>
  </template>

  <template mode="tran" match="lg">
    <choose>
      <when test="$target = 'html'">
        <html:div>
          <call-template name="classedContent"/>
        </html:div>
      </when>
      <when test="$target = 'fb2'">
        <fb2:poem id="{concat('poem.1.', generate-id(.))}">
          <fb2:stanza>
            <apply-templates mode="tran"/>
          </fb2:stanza>
        </fb2:poem>
      </when>
    </choose>
  </template>

  <template mode="tran" match="list">
    <param name="currentTask" tunnel="yes"/>
    <choose>
      <when test="$target = 'html'">
        <variable name="ol" as="element(html:ol)">
          <html:ol >
            <call-template name="classedContent"/>
          </html:ol>
        </variable>
        <!-- OSIS allows list to contain head and lb children, but EPUB2 validator
        doesn't allow <h> or <br/> children of ul -->
        <variable name="ol2" select="oc:expelElements($ol,
            $ol/*[contains(@class, 'osis-head') or contains(@class, 'osis-lb')],
            (),
            boolean($currentTask='get-filenames'))"/>
        <for-each select="$ol2">
          <if test="not(boolean(self::html:ol)) or count(child::*)">
            <sequence select="."/>
          </if>
        </for-each>
      </when>
      <when test="$target = 'fb2'">
        <variable name="content" as="node()*">
          <apply-templates mode="tran"/>
        </variable>
        <variable name="class" select="oc:getClasses(.)"/>
        <if test="$content[1][self::head]">
          <fb2:empty-line/>
          <fb2:subtitle>
            <sequence select="
              oo:getClassedContent((), 'subtitle', $content[1], '')"/>
          </fb2:subtitle>
        </if>
        <fb2:table id="{concat('table.1.', generate-id(.))}">
          <sequence select="
              oo:getClassedContent(., 'table', $content[not(position()=1 and self::head)], '')"/>
        </fb2:table>
      </when>
    </choose>
  </template>

  <template mode="tran" match="list[@subType='x-navmenu'][following-sibling::*[1][self::chapter[@eID]]]">
    <if test="$eachChapterIsFile"><next-match/></if>
  </template>

  <template mode="tran" priority="2" match="milestone[@type=concat('x-usfm-toc', $TOC)]">
    <param name="currentTask" tunnel="yes"/>
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>

    <variable name="tocTitle" select="
      oc:titleCase(oo:getTocTitle(oo:origElement(
          .,
          $preprocessedMainOSIS,
          $preprocessedRefOSIS,
          $combinedGlossary
        )))"/>

    <!-- [inline_toc_last] writes the inline TOC just before the
    following TOC milestone, even if the following is [no_toc] -->
    <for-each select="preceding::milestone[@type=concat('x-usfm-toc', $TOC)][1]
                      [contains(@n, '[inline_toc_last]')]">
      <sequence select="oo:getElementInlineTOC(
          ., $preprocessedMainOSIS, $preprocessedRefOSIS, $combinedGlossary
        )"/>
    </for-each>

    <choose>
      <when test="oo:getTocInstructions(.) = 'no_toc'">
        <if test="$target = 'fb2'">
          <!-- No FB2 section will have this osisID, so keep a potential link
          target. -->
          <fb2:tmpOsisID osisID="{@osisID}"/>
          <fb2:tmpOsisID osisID="{oc:id(@osisID)}"/>
        </if>
      </when>
      <otherwise>
        <!-- If this is the first milestone in a Bible, then first write the main
        TOC (but FB2 creates its own main inline TOC, so it's not needed for FB2). -->
        <variable name="mainInlineTOC" select="
          if (@isMainTocMilestone = 'true' and $target != 'fb2')
          then oc:getMainInlineTOC(
              $preprocessedMainOSIS,
              $preprocessedRefOSIS,
              $combinedGlossary
            )
          else ()"/>
        <variable name="inlineTOC" as="element()*" select="oo:getElementInlineTOC(
            ., $preprocessedMainOSIS, $preprocessedRefOSIS, $combinedGlossary
          )"/>

        <!-- The <div><small> was chosen because milestone TOC text is hidden
        by CSS, and non-CSS implementations should have this text de-emphasized
        since it is not part of the orignal book -->
        <if test="$target = 'html'">
          <html:div>
            <sequence select="oo:getTocAttributes(.)"/>
            <html:small>
              <html:i><value-of select="$tocTitle"/></html:i>
            </html:small>
          </html:div>
        </if>

        <!-- If there is a mainInlineTOC or inlineTOC with this milestone TOC,
        then write out a visible title. -->
        <if test="$mainInlineTOC or $inlineTOC">
          <choose>
            <when test="$target = 'html'">
              <html:h1><value-of select="$tocTitle"/></html:h1>
            </when>
            <!-- FB2 milestone toc title already appears as section title -->
            <when test="$target = 'fb2'"/>
          </choose>
        </if>

        <if test="$mainInlineTOC"><sequence select="$mainInlineTOC"/></if>

        <!-- If a glossary disambiguation title is needed, then write that out. -->
        <if test="
            not($doCombineGlossaries) and
            oo:getTocLevel(.) = 1 and
            count(distinct-values(
              $preprocessedRefOSIS//div[@type='glossary']/oc:getDivScopeTitle(.)
            )) &#62; 1">
          <variable name="heading">
            <call-template name="keywordDisambiguationHeading">
              <with-param name="noName" select="'true'"/>
            </call-template>
          </variable>
          <apply-templates mode="tran" select="$heading"/>
        </if>

        <!-- Finally output the inline TOC -->
        <if test="not(contains(@n, '[inline_toc_last]'))">
          <sequence select="$inlineTOC"/>
        </if>
      </otherwise>
    </choose>
  </template>

  <template mode="tran" priority="3" match="milestone[@type=concat('x-usfm-toc', $TOC)][preceding-sibling::seg[@type='keyword']]">
    <param name="currentTask" tunnel="yes"/>
    <if test="$currentTask = 'write-output'">
      <call-template name="Note">
        <with-param name="msg">
Dropping redundant TOC milestone in keyword <value-of select="preceding-sibling::seg[@type='keyword'][1]"/>: <value-of select="oc:printNode(.)"/>
        </with-param>
      </call-template>
    </if>
  </template>

  <template mode="tran" priority="2" match="milestone[@type='pb']">
    <choose>
      <when test="$target = 'html'">
        <html:p>
          <call-template name="classedContent"/>
        </html:p>
      </when>
      <when test="$target = 'fb2'">
        <fb2:p id="{concat('p.3.', generate-id(.))}">
          <call-template name="classedContent">
            <with-param name="parentName" select="'p'"/>
          </call-template>
        </fb2:p>
      </when>
    </choose>
  </template>

  <template mode="tran" match="note">
    <choose>
      <when test="$target = 'html'">
        <html:sup>
          <html:a href="#{oc:id(@osisID)}" id="textsym.{oc:id(@osisID)}">
            <if test="$epub3Markup">
              <attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'noteref'"/>
            </if>
            <call-template name="getFootnoteSymbol"/>
          </html:a>
        </html:sup>
      </when>
      <when test="$target = 'fb2'">
        <fb2:a xlink:href="#{oc:id(@osisID)}" type="note">
          <fb2:sup>
            <call-template name="getFootnoteSymbol">
              <with-param name="parentName" select="'x'"/>
            </call-template>
          </fb2:sup>
        </fb2:a>
      </when>
    </choose>
  </template>

  <template mode="tran" match="p">
    <param name="currentTask" tunnel="yes"/>
    <variable name="content" as="node()*">
      <if test="$target != 'fb2'">
        <call-template name="WriteEmbededChapter"/>
      </if>
      <call-template name="WriteEmbededVerse"/>
      <apply-templates mode="tran"/>
    </variable>
    <choose>
      <when test="$target = 'html'">
        <variable name="p" as="element(html:p)">
          <html:p>
            <sequence select="oo:getClassedContent(., 'p', $content, '')"/>
          </html:p>
        </variable>
        <!-- Block elements as descendants of p do not validate epub, so expel
        those. Also expel page-breaks. -->
        <sequence select="oc:expelElements(
            $p,
            $p/descendant::*[
                matches(@class, '(^|\s)(pb|osis\-figure)(\s|$)') or
                matches(local-name(), '^h\d')
              ],
            (),
            boolean($currentTask = 'get-filenames')
          )"/>
      </when>
      <when test="$target = 'fb2'">
        <variable name="contentFB2" as="node()*">
          <fb2:p id="{concat('p.4.', generate-id(.))}">
            <sequence select="oo:getClassedContent(., 'p', $content, '')"/>
          </fb2:p>
        </variable>
        <!-- Expel elements not allowed as p children by the FB2 schema. -->
        <sequence select="oc:expelElements(
            $contentFB2,
            $contentFB2/child::*[
              not(local-name() = (
                'strong', 'emphasis', 'style', 'a', 'strikethrough', 'sub',
                'sup', 'code', 'image', 'tmpOsisID'))
              ],
            (),
            false()
          )"/>
      </when>
    </choose>
  </template>

  <template mode="tran" match="reference[@subType='x-other-resource']">
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="contextFile" select="oo:getFileName(.)" tunnel="yes"/>
    <choose>
      <when test="$target = 'html'">
        <choose>
          <when test="$FullResourceURL and $FullResourceURL != 'false'">
            <variable name="file"
              select="oo:getFileNameOfRef($preprocessedMainOSIS/descendant::div[@type='book'][last()]/@osisID)"/>
            <variable name="href" select="oc:uriToRelativePath(
                concat('/html/', $contextFile),
                concat('/html/', $file, '#fullResourceURL'))"/>
            <html:a href="{$href}"><call-template name="classedContent"/></html:a>
          </when>
          <otherwise>
            <html:span><call-template name="classedContent"/></html:span>
          </otherwise>
        </choose>
      </when>
      <when test="$target = 'fb2'">
        <choose>
          <when test="
              $EnableFB2FullResourceURL and
              $FullResourceURL and
              $FullResourceURL != 'false'">
            <fb2:a xlink:href="#fullResourceURL">
              <call-template name="classedContent">
                <with-param name="parentName" select="'x'"/>
              </call-template>
            </fb2:a>
          </when>
          <otherwise>
            <apply-templates mode="tran"/>
          </otherwise>
        </choose>
      </when>
    </choose>
  </template>

  <!-- references with href are used by this transform to reference specific files -->
  <template mode="tran" match="reference[@href]">
    <param name="contextFile" select="oo:getFileName(.)" tunnel="yes"/>
    <choose>
      <when test="$target = 'html'">
        <variable name="href"
          select="oc:uriToRelativePath(concat('/html/', $contextFile), @href)"/>
        <html:a href="{$href}">
          <call-template name="classedContent"/>
        </html:a>
      </when>
      <when test="$target = 'fb2'">
        <next-match/>
      </when>
    </choose>
  </template>

  <template mode="tran" match="reference">
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="contextFile" select="oo:getFileName(.)" tunnel="yes"/>

    <!-- All osisRef attributes should have a workid from preprocessing. -->
    <variable name="workid" select="tokenize(@osisRef, ':')[1]"/>
    <variable name="osisRef" select="tokenize(@osisRef, ':')[2]"/>

    <!-- The isScriptureRef variable is used to get a big speedup, by not looking up the
    Scripture reference targets to get their source file. The cost is that references to
    main-OSIS file osisIDs other than $REF_BibleTop and those containing '!' will fail. -->
    <variable name="isScriptureRef" as="xs:boolean" select="
      @osisRef != $REF_BibleTop and
      $preprocessedMainOSIS/osis/osisText/header/work[@osisWork = $workid]/
        type[@type='x-bible'] and
      not(contains(@osisRef, '!'))"/>
    <variable name="targetElement" as="element()*">
      <choose>
        <when test="
          $isScriptureRef or
          @osisRef = ($REF_BibleTop, $REF_DictTop)"/>
        <otherwise>
          <sequence select="
            oo:targetElement(
              @osisRef,
              ($preprocessedMainOSIS, $preprocessedRefOSIS, $combinedGlossary)
            )"/>
        </otherwise>
      </choose>
    </variable>
    <variable name="file" as="xs:string?">
      <choose>
        <when test="$target = 'fb2'">fb2</when>
        <when test="not($osisRef)"/>
        <when test="$isScriptureRef">
          <value-of select="oo:getFileNameOfRef(@osisRef)"/>
        </when>
        <when test="@osisRef = $REF_BibleTop">
          <value-of select="oo:getFileName($preprocessedMainOSIS)"/>
        </when>
        <when test="@osisRef = $REF_DictTop">
          <value-of select="if ($doCombineGlossaries) then
                            oo:getFileName($combinedGlossary) else
                            oo:getFileName($preprocessedRefOSIS)"/>
        </when>
        <otherwise><!-- references to non-bible -->
          <choose>
            <when test="count($targetElement) = 1">
              <value-of select="oo:getFileName($targetElement)"/>
            </when>
            <when test="count($targetElement) = 0">
              <call-template name="Error">
<with-param name="msg">Target osisID not found for <value-of select="oc:printNode(.)"/> when osisRef is <value-of select="@osisRef"/></with-param>
              </call-template>
            </when>
            <otherwise>
              <call-template name="Error">
<with-param name="msg">Multiple targets with same osisID (<value-of select="count($targetElement)"/>) when osisRef is <value-of select="@osisRef"/></with-param>
              </call-template>
            </otherwise>
          </choose>
        </otherwise>
      </choose>
    </variable>
    <variable name="htmlID" as="xs:string?">
      <choose>
        <when test="not($file)"/>
        <when test="not($isScriptureRef)">
          <value-of select="oc:id($osisRef)"/>
        </when>
        <when test="@osisRef = ($REF_BibleTop, $REF_DictTop)">
          <value-of select="if ($target = 'fb2') then $osisRef else ''"/>
        </when>
        <otherwise>  <!--other refs are to Scripture, so jump to first verse of range  -->
          <variable name="osisRefStart" select="tokenize($osisRef, '\-')[1]"/>
          <variable name="spec" select="count(tokenize($osisRefStart, '\.'))"/>
          <variable name="verse" select="if ($spec=1) then
                                         concat($osisRefStart, '.1.1') else
                                        ( if ($spec=2) then
                                          concat($osisRefStart, '.1') else
                                          $osisRefStart )"/>
          <value-of select="
            if ($target = 'fb2') then $verse else oc:id($verse)"/>
        </otherwise>
      </choose>
    </variable>
    <variable name="fragment" select="if ($htmlID) then concat('#', $htmlID) else ''"/>
    <choose>
      <when test="not($file)">
        <apply-templates mode="tran"/>
        <call-template name="Error">
<with-param name="msg">Could not determine source file for <value-of select="string()"/> osisRef="<value-of select="@osisRef"/>"</with-param>
        </call-template>
      </when>
      <when test="$target = 'html'">
        <variable name="href"
            select="oc:uriToRelativePath(
                      concat('/html/', $contextFile),
                      concat('/html/', $file, $fragment))"/>
        <html:a href="{$href}">
          <call-template name="classedContent"/>
        </html:a>
      </when>
      <when test="$target = 'fb2'">
        <choose>
          <when test="oo:isGlossaryNote(.)">
            <apply-templates mode="tran"/>
            <fb2:a xlink:href="{$fragment}.note" type="note">
              <fb2:sup>
                <call-template name="getFootnoteSymbol">
                  <with-param name="parentName" select="'x'"/>
                </call-template>
              </fb2:sup>
            </fb2:a>
          </when>
          <otherwise>
            <fb2:a xlink:href="{$fragment}">
              <call-template name="classedContent">
                <with-param name="parentName" select="'x'"/>
              </call-template>
            </fb2:a>
          </otherwise>
        </choose>
      </when>
    </choose>
  </template>

  <template mode="tran" match="row">
    <choose>
      <when test="$target = 'html'">
        <html:tr>
          <call-template name="classedContent"/>
        </html:tr>
      </when>
      <when test="$target = 'fb2'">
        <fb2:tr align="left">
          <apply-templates mode="tran"/>
        </fb2:tr>
      </when>
    </choose>
  </template>

  <template mode="tran" match="seg">
    <choose>
      <when test="$target = 'html'">
        <html:span>
          <call-template name="classedContent"/>
        </html:span>
      </when>
      <when test="$target = 'fb2'">
        <call-template name="classedContent"/>
      </when>
    </choose>
  </template>

  <!-- During FB2 preprocessing these divs were emptied and left as holding
  places for osisIDs. Now they are transformed into fb2 elements until
  their final use and removal during FB2 postprocessing. -->
  <template mode="tran" priority="5" match="div[@emptied]">
    <if test="@osisID">
      <fb2:tmpOsisID osisID="{@osisID}"/>
      <fb2:tmpOsisID osisID="{oc:id(@osisID)}"/>
    </if>
  </template>

  <!-- #################################################################### -->
  <!--                     POSTPROCESS OUTPUT                               -->
  <!-- #################################################################### -->

  <!-- Post processing results in a BIG speedup vs using mode='tran' -->
  <template mode="postprocess" match="node()|@*">
    <copy><apply-templates mode="postprocess" select="node()|@*"/></copy>
  </template>
  <!-- Don't output duplicate inline-TOC tites -->
  <template mode="postprocess" match="html:h1 | html:h2 | html:h3" priority="2">
    <variable name="precedingTOC" select="self::*[contains(@class, 'osis-title')]/
        preceding::text()[normalize-space()][1]/ancestor::html:div[contains(@class, 'xsl-inline-toc')][1]"/>
    <variable name="duplicateTitle"
        select="lower-case($precedingTOC[1]/preceding::text()[normalize-space()][1][parent::html:h1]) = lower-case(string())"/>
    <if test="not($duplicateTitle)"><next-match/></if>
  </template>
  <!-- Remove html prefixes -->
  <template mode="postprocess" match="*[namespace-uri()='http://www.w3.org/1999/xhtml']" priority="1">
   <element name="{local-name()}" namespace="http://www.w3.org/1999/xhtml">
     <apply-templates mode="postprocess" select="node()|@*"/>
   </element>
  </template>

  <!-- #################################################################### -->
  <!--                      UTILITY TEMPLATES                               -->
  <!-- #################################################################### -->

  <template name="preprocessMain">
    <variable name="preprocess">
      <apply-templates mode="preprocess" select="/"/>
    </variable>
    <choose>
      <when test="
        $target = 'fb2' or
        $eachChapterIsFile or
        $isChildrensBible or
        $isGenericBook">
        <variable name="removeSectionDivs">
          <apply-templates mode="preprocess_removeSectionDivs" select="$preprocess"/>
        </variable>
        <apply-templates mode="preprocess_expelChapterTags" select="$removeSectionDivs"/>
      </when>
      <otherwise><sequence select="$preprocess"/></otherwise>
    </choose>
  </template>

  <template name="preprocessDict">
    <variable name="preprocess">
      <apply-templates mode="preprocess" select="$referenceOSIS"/>
    </variable>
    <apply-templates mode="preprocess_glossTocMenus" select="$preprocess"/>
  </template>

  <template name="combinedGlossary">
    <if test="$doCombineGlossaries">
      <variable name="combinedGlossary_0">
        <variable name="combinedKeywords" as="element(div)*"
            select="$referenceOSIS/descendant::div[@type='glossary']/
                      descendant::div[starts-with(@type, 'x-keyword')]
                                    [not(@type = 'x-keyword-duplicate')]
                                    [not(ancestor::div[@scope='NAVMENU'])]"/>
        <if test="$combinedKeywords">
          <call-template name="WriteCombinedGlossary">
            <with-param name="combinedKeywords" select="$combinedKeywords"/>
          </call-template>
        </if>
        <for-each select="$referenceOSIS/descendant::div[@type='glossary']
          [child::node()[not(self::div[starts-with(@type, 'x-keyword')])]
                        [descendant-or-self::text()[normalize-space()]] ]">
          <call-template name="Warn">
<with-param name="msg">Dropping non-keyword text from glossary '<value-of select="oc:getDivTitle(.)"/>': <value-of select="normalize-space(string-join(node()[not(self::div[starts-with(@type, 'x-keyword')])][descendant-or-self::text()[normalize-space()]],' '))"/></with-param>
<with-param name="exp">To keep this text, set CombineGlossaries=false in config.conf.</with-param>
          </call-template>
        </for-each>
      </variable>
      <variable name="combinedGlossary_1">
        <apply-templates mode="preprocess" select="$combinedGlossary_0"/>
      </variable>
      <apply-templates mode="preprocess_glossTocMenus" select="$combinedGlossary_1"/>
    </if>
  </template>

  <!-- Write a single glossary that combines all other glossaries together.
  Note: x-keyword-duplicate entries are dropped because they are included in
  the x-aggregate glossary -->
  <template name="WriteCombinedGlossary">
    <param name="combinedKeywords" as="element(div)+"/>
    <osis:osis isCombinedGlossary="yes">
      <osis:osisText osisRefWork="{$DICTMOD}" osisIDWork="{$DICTMOD}">
        <osis:div type="glossary">
          <osis:milestone
            type="x-usfm-toc{$TOC}"
            n="[level1]{$CombindedGlossaryTitle}"
            osisID="CombindedGlossary"/>
          <osis:title type="main">
            <value-of select="$CombindedGlossaryTitle"/>
          </osis:title>
          <for-each select="$combinedKeywords">
            <sort select="oc:keySort(.//seg[@type='keyword'])" data-type="text" order="ascending"
              collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
            <apply-templates mode="addDisambiguationHeading" select="."/>
          </for-each>
        </osis:div>
      </osis:osisText>
    </osis:osis>
  </template>
  <template mode="addDisambiguationHeading" match="node()|@*">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <if test="
          self::div[starts-with(@type, 'x-keyword')]
          [not(ancestor::div[@subType='x-aggregate'])]
          [descendant::seg[@type='keyword']]
        ">
        <call-template name="keywordDisambiguationHeading"/>
      </if>
      <apply-templates mode="#current"/>
    </copy>
  </template>

  <!-- When keywords are aggregated or the combined glossary is used,
  titles indicate a keyword's source -->
  <template name="keywordDisambiguationHeading" as="element()*">
    <param name="noScope"/>
    <param name="noName"/>
    <if test="not($noScope) or not($noName)">
      <variable name="content" as="node()*">
        <if test="not($noScope)">
          <osis:title level="3" subType="x-glossary-scope">
            <value-of select="oc:getDivScopeTitle(
                if (ancestor::div[@type='glossary'])
                then ancestor::div[@type='glossary'][1]
                else preceding::div[@type='glossary'][1]
              )"/>
          </osis:title>
        </if>
        <if test="not($noName)">
          <osis:title level="3" subType="x-glossary-title">
            <value-of select="oc:getDivTitle(
                if (ancestor::div[@type='glossary'])
                then ancestor::div[@type='glossary'][1]
                else preceding::div[@type='glossary'][1]
              )"/>
          </osis:title>
        </if>
      </variable>
      <if test="$target = 'html'">
        <osis:div subType="x-title-aggregate">
          <sequence select="$content"/>
        </osis:div>
      </if>
      <if test="$target = 'fb2'">
        <sequence select="$content"/>
      </if>
    </if>
  </template>

  <!-- This template may be called from any element. It adds a class attribute
  according to tag, level, type, subType, role and class -->
  <template name="classes">
    <choose>
      <when test="$target = 'html'">
        <attribute name="class" select="oc:getClasses(.)"/>
      </when>
      <when test="$target = 'fb2'">
        <call-template name="Error">
          <with-param name="msg">Cannot call template 'classes' with FB2.</with-param>
          <with-param name="die">yes</with-param>
        </call-template>
      </when>
    </choose>
  </template>

  <template name="classedContent">
    <param name="parentName" select="''" as="xs:string"/>
    <variable name="content" as="node()*">
      <apply-templates mode="#current"/>
    </variable>
    <sequence select="oo:getClassedContent(., $parentName, $content, '')"/>
  </template>

  <!-- This template may be called from any note. It returns a symbol or
  number based on that note's type and context -->
  <template name="getFootnoteSymbol">
    <param name="class" select="''"/>
    <param name="parentName" select="''"/>

    <choose>
      <when test="@type='x-glossary'">
        <variable name="ec" select="
          normalize-space(string-join(($class, 'xsl-gloss-symbol'), ' '))"/>
        <sequence select="oo:getClassedContent(., $parentName, '†', $ec)"/>
      </when>
      <when test="oo:inChapter(.) and not(@type='crossReference')">
        <variable name="ec" select="
          normalize-space(string-join(($class, 'xsl-fnote-symbol'), ' '))"/>
        <sequence select="oo:getClassedContent(., $parentName, '*', $ec)"/>
      </when>
      <when test="oo:inChapter(.) and @subType='x-parallel-passage'">
        <variable name="ec" select="
          normalize-space(string-join(($class, 'xsl-crnote-symbol'), ' '))"/>
        <sequence select="oo:getClassedContent(., $parentName, '•', $ec)"/>
      </when>
      <when test="oo:inChapter(.)">
        <variable name="ec" select="
          normalize-space(string-join(($class, 'xsl-crnote-symbol'), ' '))"/>
        <sequence select="oo:getClassedContent(., $parentName, '+', $ec)"/>
      </when>
      <otherwise>
        <variable name="noteSymbol">
          <value-of select="'['"/>
            <call-template name="getFootnoteNumber"/>
          <value-of select="']'"/>
        </variable>
        <variable name="ec" select="
          normalize-space(string-join(($class, 'xsl-note-number'), ' '))"/>
        <sequence select="oo:getClassedContent(., $parentName, $noteSymbol, $ec)"/>
      </otherwise>
    </choose>
  </template>

  <!-- This template may be called from any note. It returns the number
  of that note within its output file -->
  <template name="getFootnoteNumber">
    <choose>
      <when test="ancestor-or-self::div[@glossaryGroup]"><!-- glossaries -->
        <variable name="myGroup" as="xs:integer" select="ancestor-or-self::div[@glossaryGroup][1]/@glossaryGroup"/>
        <variable name="firstOfMyGroup" as="element(div)"
          select="ancestor-or-self::div[@glossaryGroup][last()]/descendant-or-self::div[@glossaryGroup=$myGroup][1]"/>
        <value-of select="count(preceding::note) - count($firstOfMyGroup/preceding::note) + 1"/>
      </when>
      <when test="ancestor::div[@type='book']"><!-- books -->
        <value-of select="count(preceding::note) - count(ancestor::div[@type='book'][1]/preceding::note) + 1"/>
      </when>
      <when test="ancestor::div[@type='bookGroup']"><!-- bookGroup introductions -->
        <value-of select="count(preceding::note[not(ancestor::div[@type='book'])]) -
                          count(ancestor::div[@type='bookGroup'][1]/preceding::note[not(ancestor::div[@type='book'])]) + 1"/>
      </when>
      <when test="oc:docWork(.) = $MAINMOD"><!-- main introduction -->
        <value-of select="count(preceding::note[not(ancestor::div[@type='bookGroup'])]) + 1"/>
      </when>
      <otherwise>
        <value-of select="count(preceding::note) - count(ancestor::div[last()]/preceding::note) + 1"/>
      </otherwise>
    </choose>
  </template>

    <!-- This template should be called from: p, l, item and canonical title.
  It outputs a chapter number when the context element is the first of all
  such elements to begin within the chapter. -->
  <template name="WriteEmbededChapter">
    <variable name="isInVerse" select="
      boolean(preceding::verse[1]/@sID = following::verse[1]/@eID) or
      boolean(preceding::verse[1]/@sID = descendant::verse[1]/@eID)"/>
    <if test="$isInVerse and preceding::chapter[@sID][1]
              [ following::*[ self::p | self::l | self::item | self::title[@canonical='true'] ][1]
                intersect current()
              ]">
      <variable name="ch" select="tokenize(preceding::chapter[@sID][1]/@osisID, '\.')[last()]"/>
      <choose>
        <when test="$target = 'html'">
          <html:span class="xsl-chapter-number"><value-of select="$ch"/></html:span>
        </when>
        <when test="$target = 'fb2'">
          <fb2:subtitle class="xsl-chapter-number">
            <value-of select="$ch"/>
          </fb2:subtitle>
        </when>
      </choose>
    </if>
  </template>

  <!-- This template should be called from: p, l, item and canonical title.
  It outputs a verse number if the context element should contain an
  embedded verse number -->
  <template name="WriteEmbededVerse">
    <variable name="isInVerse" select="
      boolean(preceding::verse[1]/@sID = following::verse[1]/@eID) or
      boolean(preceding::verse[1]/@sID = descendant::verse[1]/@eID)"/>
    <if test="$isInVerse">
      <!-- Write any verse -->
      <if test="self::*[
          preceding-sibling::*[1][self::verse[@sID]] |
          self::l[parent::lg[child::l[1] intersect current()][preceding-sibling::*[1][self::verse[@sID]]]] |
          self::item[parent::list[child::item[1] intersect current()][preceding-sibling::*[1][self::verse[@sID]]]]
      ]">
        <call-template name="WriteVerseNumber"/>
      </if>
      <!-- Write any alternate verse -->
      <for-each select="
          self::*/preceding-sibling::*[1][self::hi[@subType='x-alternate']] |
          self::l/parent::lg[child::l[1] intersect current()]/preceding-sibling::*[1][self::hi[@subType='x-alternate']] |
          self::item/parent::list[child::l[1] intersect current()]/preceding-sibling::*[1][self::hi[@subType='x-alternate']]">
        <apply-templates mode="tran" select=".">
          <with-param name="doWrite" select="true()" tunnel="yes"/>
        </apply-templates>
      </for-each>
    </if>
  </template>

  <!-- This template should be called from: p and l. -->
  <template name="WriteVerseNumber">
    <variable name="osisID" select="if (@osisID) then @osisID else preceding::*[@osisID][1]/@osisID"/>
    <variable name="first" select="tokenize($osisID, '\s+')[1]"/>
    <variable name="last" select="tokenize($osisID, '\s+')[last()]"/>
    <variable name="v" select="
      if ($first = $last)
      then tokenize($first, '\.')[last()]
      else concat(tokenize($first, '\.')[last()], '-', tokenize($last, '\.')[last()])"/>
    <!-- output hyperlink targets for every verse in the verse system -->
    <for-each select="tokenize($osisID, '\s+')">
      <if test="$target = 'html'">
        <html:span>
          <attribute name="id" select="oc:id(.)"/>
        </html:span>
      </if>
      <if test="$target = 'fb2'">
        <fb2:tmpOsisID osisID="{.}"/>
      </if>
    </for-each>
    <!-- then verse numner(s) -->
    <if test="$target = 'html'">
      <html:sup class="xsl-verse-number"><value-of select="$v"/></html:sup>
    </if>
    <if test="$target = 'fb2'">
      <fb2:sup><value-of select="$v"/></fb2:sup>
    </if>
  </template>

  <!-- #################################################################### -->
  <!--                      UTILITY FUNCTIONS                               -->
  <!-- #################################################################### -->

  <function name="oc:getClasses" as="xs:string">
    <param name="x" as="element()"/>
    <value-of select="normalize-space(string-join((
        concat('osis-', $x/local-name()),
        $x/@type,
        $x/@subType,
        $x/@role,
        $x/@class,
        if ($x/@level) then concat('level-', $x/@level) else ''), ' ')
      )"/>
  </function>

  <function name="oo:getClassedContent">
    <param name="context" as="element()?"/>
    <param name="parentName" as="xs:string"/>
    <param name="content0"/>
    <param name="extraClasses" as="xs:string"/>
    <variable name="class" select="
      if ($context)
      then normalize-space(string-join(($extraClasses, oc:getClasses($context)), ' '))
      else normalize-space($extraClasses)"/>
    <!-- fb2:subtitle cannot contain empty-line elements -->
    <variable name="content" select="
      if ($parentName = 'subtitle')
      then $content0[not(self::fb2:empty-line)]
      else $content0"/>
    <choose>
      <when test="$target = 'html'">
        <if test="$class">
          <attribute name="class" select="$class"/>
        </if>
        <sequence select="$content"/>
      </when>
      <when test="$target = 'fb2'">
        <choose>
          <when test="$parentName = 'x'">
            <!-- x insures unstyled always -->
            <sequence select="$content"/>
          </when>
          <when test="
              $EnableFB2CSS and
              matches($parentName, '^(p|v|subtitle|table|text\-author)$')">
            <if test="$class"><attribute name="style" select="$class"/></if>
            <sequence select="$content"/>
          </when>
          <when test="$EnableFB2CSS and $class">
            <fb2:style>
              <attribute name="name" select="$class"/>
              <sequence select="$content"/>
            </fb2:style>
          </when>
          <when test="
              not($EnableFB2CSS) and
              (
                not($parentName) or
                matches($parentName, '^(p|v|subtitle|text\-author)$')
              )">
            <!-- Unimplemented OSIS hi type: small-caps -->
            <choose>
              <when test="matches(
                    concat(' ', $class, ' '),
                    ' (bold) ',
                    'i'
                  )">
                <fb2:strong><sequence select="$content"/></fb2:strong>
              </when>
              <when test="matches(
                    concat(' ', $class, ' '),
                    ' (italic|emphasis|osis\-(rdg|catchWord|foreign)) ',
                    'i'
                  )">
                <fb2:emphasis><sequence select="$content"/></fb2:emphasis>
              </when>
              <when test="matches(
                    concat(' ', $class, ' '),
                    ' (line\-through) ',
                    'i'
                  )">
                <fb2:strikethrough><sequence select="$content"/></fb2:strikethrough>
              </when>
              <when test="matches(
                    concat(' ', $class, ' '),
                    ' (sub) ',
                    'i'
                  )">
                <fb2:sub><sequence select="$content"/></fb2:sub>
              </when>
              <when test="matches(
                    concat(' ', $class, ' '),
                    ' (super) ',
                    'i'
                  )">
                <fb2:sup><sequence select="$content"/></fb2:sup>
              </when>
              <when test="matches(
                    concat(' ', $class, ' '),
                    ' (acrostic|underline|illuminated|osis\-signed) ',
                    'i'
                  )">
                <fb2:code><sequence select="$content"/></fb2:code>
              </when>
              <otherwise>
                <sequence select="$content"/>
              </otherwise>
            </choose>
          </when>
          <otherwise>
            <sequence select="$content"/>
          </otherwise>
        </choose>
      </when>
    </choose>
  </function>

  <function name="oo:inChapter" as="xs:boolean">
    <param name="node" as="node()"/>
    <variable name="workid" select="root($node)/osis/osisText[1]/@osisIDWork"/>
    <value-of select="
      boolean(
        root($node)/osis/osisText/header/
        work[@osisWork = $workid]/type[@type='x-bible']
      ) and (
          boolean(
            $node/preceding::chapter[1]/@sID =
            $node/following::chapter[1]/@eID
          ) or
          boolean(
            $node/preceding::chapter[1]/@sID =
            $node/descendant::chapter[1]/@eID
          ) or
          boolean($node/ancestor::title[@canonical='true'])
      )"/>
  </function>

  <function name="oo:isGlossaryNote" as="xs:boolean">
    <param name="reference" as="element(reference)"/>
    <value-of select="
      $reference[@type='x-glossary'] and
      not($reference/@osisRef = ($REF_BibleTop, $REF_DictTop)) and
      not(contains($reference/@osisRef, '!')) and
      not($reference[ancestor::note]) and
      oo:inChapter($reference)"/>
  </function>

  <function name="oo:targetElement" as="element()*">
    <param name="osisRef" as="xs:string"/>
    <param name="docs" as="node()+"/>
    <variable name="workid" select="tokenize($osisRef, ':')[1]"/>
    <variable name="osisRef" select="tokenize($osisRef, ':')[2]"/>
    <for-each select="$docs/osis/osisText[@osisIDWork = $workid]">
      <sequence select="key('osisID', $osisRef, root(.))"/>
    </for-each>
  </function>

  <function name="oo:fb2SectionContent" as="element()+">
    <param name="fb2Content" as="node()*"/>
    <!-- FB2 schema requires pType content after a section title. -->
    <choose>
      <when test="
          $fb2Content[descendant-or-self::text()[normalize-space()]] or
          $fb2Content[
            descendant-or-self::*[local-name() = ('image', 'empty-line')]
          ]">
        <variable name="doc">
          <fb2:tmp><sequence select="$fb2Content"/></fb2:tmp>
        </variable>
        <!-- FB2 schema also requires that all section children only be
        particular elements. -->
        <for-each select="$doc/fb2:tmp/node()">
          <choose>
            <when test="oo:okSectionChild(.)">
              <sequence select="."/>
              <!-- If an image is first, it cannot be followed by another image
              according to the schema, but once it's followed by a non-image,
              there is no longer any restriction on max number of consecutive
              images. -->
              <if test="
                  self::fb2:image and
                  not(preceding-sibling::*[local-name() = (
                      'p', 'poem', 'subtitle', 'cite',
                      'empty-line', 'table', 'image'
                    )]) and
                  following-sibling::*[local-name() = (
                      'p', 'poem', 'subtitle', 'cite',
                      'empty-line', 'table', 'image'
                    )][1][self::fb2:image]">
                <fb2:empty-line/>
              </if>
            </when>
            <when test="./preceding-sibling::node()[1][not(oo:okSectionChild(.))]"/>
            <otherwise>
              <fb2:p id="{concat('p.5.', generate-id(.))}">
                <sequence select=". | ./following-sibling::node()[
                  . &#60;&#60; current()/following-sibling::*[oo:okSectionChild(.)][1]
                ]"/>
              </fb2:p>
            </otherwise>
          </choose>
        </for-each>
      </when>
      <otherwise>
        <fb2:p id="{concat('p.6.', generate-id($fb2Content[1]))}">
          <sequence select="$fb2Content[descendant-or-self::fb2:tmpOsisID]"/>
        </fb2:p>
      </otherwise>
    </choose>
  </function>

  <function name="oo:okSectionChild" as="xs:boolean">
    <param name="node" as="node()"/>
    <value-of select="
      $node[self::fb2:section] or
      $node[self::fb2:annotation] or
      $node[self::fb2:p] or
      $node[self::fb2:poem] or
      $node[self::fb2:subtitle] or
      $node[self::fb2:cite] or
      $node[self::fb2:empty-line] or
      $node[self::fb2:table] or
      $node[self::fb2:image] or
      $node[self::fb2:tmpOsisID]"/>
  </function>

  <function name="oo:getFileName" as="xs:string">
    <param name="node" as="node()"/>
    <choose>
      <when test="$target = 'html'">
        <sequence select="oo:getFileNameHTML($node)"/>
      </when>
      <otherwise>
        <value-of select="''"/>
      </otherwise>
    </choose>
  </function>

  <!-- This function may be called on any node. It returns the output
  file that contains the node -->
  <function name="oo:getFileNameHTML" as="xs:string">
    <param name="node1" as="node()"/>

    <variable name="node" as="node()"
        select="if ($node1/ancestor-or-self::div) then $node1 else
                $node1/(descendant::div | following::div)[1]"/>

    <variable name="root" select="if ($node/ancestor-or-self::osis[@isCombinedGlossary]) then
                                  'comb' else
                                  oc:docWork($node)"/>
    <variable name="refUsfmType" select="$node/ancestor-or-self::div[@type=$usfmType][last()]"/>
    <variable name="refUsfmTypeDivNum" select="0.5 +
                                               0.5*(count($refUsfmType/descendant-or-self::div[@type=$usfmType])) +
                                               count($refUsfmType/preceding::div[@type=$usfmType])"/>
    <variable name="book" select="$node/ancestor-or-self::div[@type='book'][last()]/(
        if (not(matches(@osisID, '[^ -~]')) and string-length(@osisID) &#60;= 12)
        then @osisID
        else concat('div', count(preceding::div))
      )"/>
    <!-- The group selects below must be the same as the corresponding
    group-adjacent attributes of the divideFiles templates. Otherwise
    the transform will fail while trying to write to an already written
    and closed file. -->
    <choose>
      <!-- Children's Bible nodes -->
      <when test="$isChildrensBible">
        <variable name="group" select="0.5 + 0.5*count($node/ancestor-or-self::div[@type='chapter']) +
                                       count($node/preceding::div[@type='chapter'])"/>
        <value-of select="concat($root, '_Chbl_c', $group, $htmext)"/>
      </when>
      <!-- Book nodes -->
      <when test="$book">
        <variable name="group" select="count($node/descendant-or-self::chapter[starts-with(@sID, concat($book, '.'))]) +
                                       count($node/preceding::chapter[starts-with(@sID, concat($book, '.'))])"/>
        <value-of select="concat($root, '_', $book, if ($eachChapterIsFile) then concat('/ch', $group) else '', $htmext)"/>
      </when>
      <!-- BookGroup introduction nodes -->
      <when test="$node/ancestor::div[@type='bookGroup']">
        <variable name="group" select="0.5 + 0.5*count($node/descendant-or-self::div[@type='book']) +
                                       count($node/preceding::div[@type='book'])"/>
        <value-of select="concat($root, '_bookGroup-introduction_', $group, $htmext)"/>
      </when>
      <!-- Main module introduction nodes -->
      <when test="$root = $MAINMOD">
        <variable name="group" select="0.5 + 0.5*count($node/descendant-or-self::div[@type='bookGroup']) +
                                       count($node/preceding::div[@type='bookGroup'])"/>
        <value-of select="concat($root, '_module-introduction', (if ($group &#60; 1) then '' else concat('_', $group)), $htmext)"/>
      </when>
      <!-- Reference OSIS glossary nodes -->
      <when test="$node/ancestor-or-self::div[@type='glossary']">
        <variable name="my_keywordFile"
          select="if (count($refUsfmType/descendant::seg[@type='keyword']) = 1) then 'glossary' else
                  if ($refUsfmType[@annotateType='x-feature' and @annotateRef='NO_TOC']) then 'single' else
                  if ($keywordFile != 'AUTO') then $keywordFile else
                  if (count($refUsfmType/descendant::div[starts-with(@type, 'x-keyword')]) &#60; $keywordFileAutoThresh) then 'glossary'
                  else 'letter'"/>
        <variable name="suffix">
          <choose>
            <when test="$my_keywordFile = 'single'">
              <value-of>K</value-of>
            </when>
            <when test="$my_keywordFile = 'letter'">
              <value-of>L</value-of>
            </when>
            <otherwise>
              <value-of>G</value-of>
            </otherwise>
          </choose>
        </variable>
        <variable name="group">
          <if test="$my_keywordFile = ('single', 'letter')">
            <value-of select="$node/
              (ancestor-or-self::div[@glossaryGroup][1] | preceding::div[@glossaryGroup])[last()]/
              @glossaryGroup"/>
          </if>
        </variable>
        <value-of select="if ($root = 'comb') then
            concat($root, '_glossary', '/', $suffix, if ($group) then $group else '', $htmext) else
            concat($root, '_glossary', '/div', $refUsfmTypeDivNum, '_', $suffix, if ($group) then $group else '', $htmext)"/>
      </when>
      <!-- non-glossary refUsfmType nodes -->
      <when test="$refUsfmType">
        <value-of select="concat($root, '_', $refUsfmType/@type, '/div', $refUsfmTypeDivNum, $htmext)"/>
      </when>
      <!-- unknown type nodes (osis-converters gives osisIDs to top level divs, so use osisID)-->
      <otherwise>
        <value-of select="concat($root, '_', oc:id($node/ancestor::div[parent::osisText]/@osisID), $htmext)"/>
      </otherwise>
    </choose>
  </function>

  <!-- This template may be called with a Bible osisRef string. It does
  the same thing as oo:getFileName but is much faster. -->
  <function name="oo:getFileNameOfRef" as="xs:string">
    <param name="osisRef" as="xs:string"/>
    <if test="contains($osisRef, ':') and not(starts-with($osisRef, concat($MAINMOD, ':')))">
      <call-template name="Error">
<with-param name="msg">Bible reference <value-of select="$osisRef"/> targets a work other than <value-of select="$MAINMOD"/></with-param>
      </call-template>
    </if>
    <variable name="osisRef2" select="replace($osisRef, '^[^:]*:', '')" as="xs:string"/>
    <value-of select="concat($MAINMOD, '_',
                             tokenize($osisRef2, '\.')[1],
                             ( if (not($eachChapterIsFile)) then '' else
                               concat('/ch', tokenize($osisRef2, '\.')[2]) ),
                             $htmext)"/>
  </function>

</stylesheet>
