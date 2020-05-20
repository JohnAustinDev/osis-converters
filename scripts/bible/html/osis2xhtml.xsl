<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/osis2xhtml"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
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
                        
    xhtml/files.xhtml - Each book, section, chapter (if eachChapterIsFile 
                        is true) and keyword are written to separate
                        html files. These files are linked by an auto
                        generated inline table-of-contents. Also to 
                        facilitate Calibre table-of-content generation, 
                        title="toclevel-N" attributes are written.
  
  This transform may be run by placing osis2xhtml.xsl, functions.xsl and 
  referenced OSIS files in the same directory. Then run: 
  $ saxonb-xslt -ext:on -xsl:osis2xhtml.xsl -s:main_osis.xml -o:content.opf
  -->
  
  <import href="./functions.xsl"/>
 
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
  
  <param name="FullResourceURL" select="oc:conf('FullResourceURL', /)"/><!-- '' or 'false' turns this feature off -->
  
  <param name="tocWidth" select="xs:integer(number(oc:sarg('tocWidth', /, '50')))"/><!-- in chars, is ARG_tocWidth in config.conf -->
  
  <param name="averageCharWidth" select="number(oc:sarg('averageCharWidth', /, '1.1'))"/><!-- in CSS ch units, is ARG_averageCharWidth in config.conf -->
  
  <param name="backFullWidth" select="xs:integer(number(oc:sarg('backFullWidth', /, '20')))"/><!-- is ARG_backFullWidth in config.conf -->
  
  <param name="introFullWidth" select="xs:integer(number(oc:sarg('introFullWidth', /, '20')))"/><!-- is ARG_introFullWidth in config.conf -->
  
  <param name="keywordFileAutoThresh" select="xs:integer(number(oc:sarg('keywordFileAutoThresh', /, '10')))"/><!-- is ARG_keywordFileAutoThresh in config.conf -->
  
  <param name="glossaryTocAutoThresh" select="xs:integer(number(oc:sarg('glossaryTocAutoThresh', /, '20')))"/><!-- is ARG_glossaryTocAutoThresh in config.conf -->
  
  <variable name="eachChapterIsFile" as="xs:boolean" select="$chapterFiles = 'yes'"/>
  <variable name="includeNavMenuLinks" as="xs:boolean" select="$navMenuLinks = 'yes'"/>
  <variable name="epub3Markup" as="xs:boolean" select="$noEpub3Markup != 'yes'"/>
  <variable name="isChildrensBible" select="boolean(/osis:osis/osis:osisText/osis:header/
                                            osis:work[@osisWork=/osis:osis/osis:osisText/@osisIDWork]/
                                            osis:type[@type='x-childrens-bible'])"/>
  
  <!-- The main input OSIS file must contain a work element corresponding to each 
     OSIS file referenced in the project. But osis-converters supports a single 
     dictionary OSIS file only, which contains all reference material. -->
  <variable name="referenceOSIS" as="document-node()?" 
      select="if ($isChildrensBible) then () else /osis/osisText/header/work[@osisWork != /osis/osisText/@osisIDWork]/
              doc(concat(tokenize(document-uri(/), '[^/]+$')[1], @osisWork, '.xml'))"/>
  
  <variable name="doCombineGlossaries" select="if ($CombineGlossaries = 'AUTO') then 
          (if ($referenceOSIS//div[@type='glossary'][@subType='x-aggregate']) then true() else false()) 
          else $CombineGlossaries = 'true' "/>
          
  <variable name="CombGlossaryTitle" select="//work[boolean($DICTMOD) and @osisWork = $DICTMOD]/title[1]"/>
  
  <!-- USFM file types output by CrossWire's usfm2osis.py -->
  <variable name="usfmType" select="('front', 'introduction', 'back', 'concordance', 
      'glossary', 'index', 'gazetteer', 'x-other', 'titlePage', 'x-halfTitlePage', 
      'x-promotionalPage', 'imprimatur', 'publicationData', 'x-foreword', 'preface', 
      'tableofContents', 'x-alphabeticalContents', 'x-tableofAbbreviations', 
      'x-chronology', 'x-weightsandMeasures', 'x-mapIndex', 'x-ntQuotesfromLXX', 
      'coverPage', 'x-spine', 'x-tables', 'x-dailyVerses')" as="xs:string+"/>
      
  <!-- A main inline Table Of Contents is placed after the first TOC milestone sibling 
       following the OSIS header, or, if there isn't such a milestone, one will be created. -->
  <variable name="mainTocMilestone" select="if (not($isChildrensBible)) then 
      /descendant::milestone[@type=concat('x-usfm-toc', $TOC)][not(contains(@n, '[no_toc]'))][1]
      [. &#60;&#60; /descendant::div[starts-with(@type,'book')][1]] else
      /descendant::milestone[@type=concat('x-usfm-toc', $TOC)][not(contains(@n, '[no_toc]'))][1]"/>
      
  <variable name="REF_BibleTop" select="concat($MAINMOD,':BIBLE_TOP')"/>
  <variable name="REF_DictTop" select="if ($DICTMOD) then concat($DICTMOD,':DICT_TOP') else ''"/>

  <variable name="mainInputOSIS" select="/"/>
  
  <!-- Don't convert Unicode SOFT HYPHEN to "&shy;" in xhtml output files. 
  Because SOFT HYPHENs are currently being stripped out by the Calibre 
  EPUB output plugin, and they break xhtml in browsers (without first  
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
      doCombineGlossaries = <value-of select="$doCombineGlossaries"/>
      includeNavMenuLinks = <value-of select="$includeNavMenuLinks"/>
      glossaryToc = <value-of select="$glossaryToc"/>
      keywordFile = <value-of select="$keywordFile"/>
      eachChapterIsFile = <value-of select="$eachChapterIsFile"/>
      </with-param>
    </call-template>
    
    <!-- Preprocess for a BIG speedup -->
    <!-- main OSIS -->
    <call-template name="Log">
<with-param name="msg"><text>&#xa;</text>CURRENT-TASK: preprocess</with-param>
    </call-template>
    
    <variable name="preprocessedMainOSIS">
      <variable name="preprocess">
        <apply-templates mode="preprocess" select="/"/>
      </variable>
      <choose>
        <when test="$eachChapterIsFile or $isChildrensBible">
          <variable name="removeSectionDivs">
            <apply-templates mode="preprocess_removeSectionDivs" select="$preprocess"/>
          </variable>
          <apply-templates mode="preprocess_expelChapterTags" select="$removeSectionDivs"/>
        </when>
        <otherwise><sequence select="$preprocess"/></otherwise>
      </choose>
    </variable>
<!--<result-document href="preprocessedMainOSIS.xml"><sequence select="$preprocessedMainOSIS"/></result-document>-->
   
    <!-- combined glossary -->
    <variable name="combinedGlossary">
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
    </variable>
<!--<result-document href="combinedGlossary.xml"><sequence select="$combinedGlossary"/></result-document>-->
    
    <!-- reference OSIS -->
    <variable name="preprocessedRefOSIS">
      <variable name="preprocess">
        <apply-templates mode="preprocess" select="$referenceOSIS"/>
      </variable>
      <apply-templates mode="preprocess_glossTocMenus" select="$preprocess"/>
    </variable>
<!--<result-document href="preprocessedRefOSIS.xml"><sequence select="$preprocessedRefOSIS"/></result-document>-->
    
    <variable name="xhtmlFiles" as="xs:string*">
      <!-- processProject must be run twice: once to return file names and a second time
      to write the files. Trying to do both at once results in the following error:
      "XTDE1480: Cannot switch to a final result destination while writing a temporary tree" -->
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
          <xsl:value-of select="//work[@osisWork = $MAINMOD]/publisher[@type='x-CopyrightHolder']/text()"/>
        </dc:publisher>
        <dc:title>
          <xsl:value-of select="//work[@osisWork = $MAINMOD]/title/text()"/>
        </dc:title>
        <dc:language>
          <xsl:value-of select="//work[@osisWork = $MAINMOD]/language/text()"/>
        </dc:language>
        <dc:identifier scheme="ISBN">
          <xsl:value-of select="//work[@osisWork = $MAINMOD]/identifier[@type='ISBN']/text()"/>
        </dc:identifier>
        <dc:creator opf:role="aut">
          <xsl:value-of select="//work[@osisWork = $MAINMOD]/publisher[@type='x-CopyrightHolder']/text()"/>
        </dc:creator>
      </metadata>
      <manifest>
        <xsl:for-each select="$xhtmlFiles">
          <item href="xhtml/{.}" id="{oc:id(replace(.,'\.xhtml$',''))}" media-type="application/xhtml+xml"/>
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
        <xsl:for-each select="$xhtmlFiles">
          <itemref idref="{oc:id(replace(.,'\.xhtml$',''))}"/>
        </xsl:for-each>
      </spine>
    </package>
    
    <call-template name="processProject">
      <with-param name="currentTask" select="'write-xhtml'" tunnel="yes"/>
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
  
  <!-- Write a single glossary that combines all other glossaries together. 
  Note: x-keyword-duplicate entries are dropped because they are included in 
  the x-aggregate glossary -->
  <template name="WriteCombinedGlossary">
    <param name="combinedKeywords" as="element(div)+"/>
    <osis:osis isCombinedGlossary="yes">
      <osis:osisText osisRefWork="{$DICTMOD}" osisIDWork="{$DICTMOD}">
        <osis:div type="glossary">
          <osis:milestone type="x-usfm-toc{$TOC}" n="[level1]{$CombGlossaryTitle}"/>
          <osis:title type="main">
            <value-of select="$CombGlossaryTitle"/>
          </osis:title>
          <for-each select="$combinedKeywords">
            <sort select="oc:keySort(.//seg[@type='keyword'])" data-type="text" order="ascending" 
              collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
            <apply-templates mode="writeCombinedGlossary" select="."/>
          </for-each>
        </osis:div>
      </osis:osisText>
    </osis:osis>
  </template>
  <template mode="writeCombinedGlossary" match="node()|@*">
    <if test="self::seg[@type='keyword'][not(ancestor::div[@subType='x-aggregate'])]">
      <call-template name="keywordDisambiguationHeading"/>
    </if>
    <copy>
      <apply-templates mode="#current" select="node()|@*"/>
    </copy>
  </template>
  
  <!-- When keywords are aggregated or the combined glossary is used, 
  titles indicate a keyword's source -->
  <template name="keywordDisambiguationHeading">
    <param name="noScope"/>
    <param name="noName"/>
    <if test="not($noScope)">
      <osis:title level="3" subType="x-glossary-scope">
        <value-of select="oc:getDivScopeTitle(ancestor::div[@type='glossary'][1])"/>
      </osis:title>
    </if>
    <if test="not($noName)">
      <osis:title level="3" subType="x-glossary-title">
        <value-of select="oc:getDivTitle(ancestor::div[@type='glossary'][1])"/>
      </osis:title>
    </if>
  </template>
  
  <!-- OSIS pre-processing templates to speed up processing that 
  requires node copying/deleting/modification. -->
  <template mode="preprocess 
                  preprocess_removeSectionDivs 
                  preprocess_expelChapterTags
                  preprocess_glossTocMenus
                  preprocess_addGroupAttribs" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <!-- preprocess 
  The x-aggregate glossary is copied to the combined glossary whenever it is used 
  (therefore x-keyword-duplicate keywords are NOT included in the combined glossary). 
  This means that links to x-keyword-duplicate keywords need to be redirected to 
  their aggregated entries by the 'reference' template. -->
  <template mode="preprocess" 
    match="div[@type='glossary'][@subType='x-aggregate'] |
           div[@type='glossary'][$doCombineGlossaries][not(ancestor::osis[@isCombinedGlossary])] |
           div[@annotateType='x-feature'][@annotateRef='INT'][oc:myWork(.) = $DICTMOD] |
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
    <!-- x-glossary and x-glosslink references may have multiple targets, ignore all but the first -->
    <variable name="osisRef1" select="replace(., '\s+.*$', '')"/>
    <!-- when using the combined glossary, redirect duplicates to the combined glossary -->
    <variable name="osisRef2" select="if ($doCombineGlossaries) then 
                                      replace($osisRef1, '\.dup\d+', '') else 
                                      $osisRef1"/>
    <!-- reference osisRefs have workid prefixes -->
    <variable name="osisRef" as="xs:string" select="if (contains($osisRef2,':')) then 
                                                    $osisRef2 else 
                                                    concat(oc:myWork(.),':',$osisRef2)"/>
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
        <attribute name="n" select="concat(if (oc:myWork(.) = $MAINMOD) 
                                           then '[inline_toc_first]' 
                                           else '[inline_toc_last]', @n)"/>
      </if>
      <apply-templates mode="#current"/>
    </copy>
  </template>
  <template mode="preprocess" match="title[oc:myWork(.) = $MAINMOD]
                                          [ancestor::div[@annotateType='x-feature'][@annotateRef='INT']]
                                          [string() = $INT_title]">
    <copy><!-- !INT extension allows reference mode=xhtml Scripture ref check -->
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
    <if test="tokenize(.,':')[2] and tokenize(.,':')[1] != oc:myWork(.)">
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
    <sequence select="oc:expelElements(., descendant::chapter[starts-with(@sID, concat($book, '.'))], false())"/>
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
            <sequence select="oc:glossaryMenu(., false(), false(), true(), false())"/>
          </when>
          <when test="$my_glossaryToc = 'letter'">
            <!-- copy everything except x-keyword divs, which are replaced by 
            glossaryMenu() because last arg is true() -->
            <copy-of select="@* | node()[not(self::div[starts-with(@type,'x-keyword')])]"/>
            <sequence select="oc:glossaryMenu(., false(), false(), true(), true())"/>
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
                  if (ancestor::div[@subType='x-navmenu-atoz']) then string() 
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

  <!-- THE OSIS FILE IS SEPARATED INTO INDIVIDUAL XHTML FILES BY THE FOLLOWING TEMPLATES
  All osisText children are assumed to be div elements (others are ignored). Children's
  Bibles are contained within a single div[@type='book']. Bibles and reference material
  are contained in div[@type=$usfmType], div[@type='book'], and div[@type='bookGroup']
  and any other divs are unexpected but are handled fine if they have an osisID. -->
  <template mode="divideFiles" match="node()"><apply-templates mode="#current"/></template>
  
  <!-- FILE: module-introduction -->
  <template mode="divideFiles" match="osisText">
    <choose>
      <!-- If this is the top of an x-bible OSIS file, group all initial divs as the introduction -->
      <when test="oc:myWork(.) = $MAINMOD and //work[@osisWork=$MAINMOD]/type[@type='x-bible']">
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
    
    <!-- A currentTask param is necessary because identical template 
    selectors are required for multiple modes (ie. a single template 
    element should handle multiple modes), yet template content must 
    also vary by mode (something XSLT 2.0 modes alone can't do) -->
    <param name="currentTask" tunnel="yes"/>
    
    <if test="boolean($fileNodes/descendant::text()[normalize-space()] | 
                      $fileNodes/descendant-or-self::figure | 
                      $fileNodes/descendant-or-self::milestone[@type=concat('x-usfm-toc', $TOC)])">
      <variable name="fileName" select="me:getFileName(.)"/>

      <choose>
        <when test="$currentTask = 'get-filenames'"><value-of select="$fileName"/></when>
        <otherwise>
        
          <variable name="fileXHTML_0">
            <apply-templates mode="xhtml" select="$fileNodes"/>
            <if test="$includeNavMenuLinks and not($isChildrensBible)">
            
              <!-- Prev/next links only appear when their targets are within the same 
              div as current but are in different html files than current. -->
              <variable name="previousFileNode" select="$fileNodes[1]/
                   preceding::text()[normalize-space()][1]"/>
              <variable name="prevIsSameDiv" select="$previousFileNode/ancestor-or-self::div[last()] intersect 
                                                         $fileNodes[1]/ancestor-or-self::div[last()]"/>
              <variable name="previousFile" select="if ($previousFileNode) then me:getFileName($previousFileNode) else ''"/>
              
              <variable name="followingFileNode" select="$fileNodes[last()]/
                   following::text()[normalize-space()][1]"/>
              <variable name="follIsSameDiv" select="$followingFileNode/ancestor-or-self::div[last()] intersect 
                                                     $fileNodes[last()]/ancestor-or-self::div[last()]"/>
              <variable name="followingFile" select="if ($followingFileNode) then me:getFileName($followingFileNode) else ''"/>
              
              <!-- Intro and Gloss links only appear when their targets are in a different 
              file than current. Gloss links go to the top of the current glossary -->
              <variable name="introFile" select="me:getFileName($preprocessedMainOSIS)"/>
              <variable name="myglossary" select="if ($doCombineGlossaries) then 
                $combinedGlossary/descendant::div[@type='glossary'][1] else $fileNodes[1]/ancestor::div[@type='glossary']"/>
              <variable name="glossFile" select="if ($myglossary) then me:getFileName($myglossary) else ''"/>
              <apply-templates mode="xhtml" 
                  select="oc:getNavmenuLinks(
                    if ($previousFile != $fileName and $prevIsSameDiv) then 
                        concat('&amp;href=/xhtml/', $previousFile)  else '',
                    if ($followingFile != $fileName and $follIsSameDiv) then 
                        concat('&amp;href=/xhtml/', $followingFile) else '',
                    if ($introFile != $fileName) then 
                        concat('&amp;href=/xhtml/', $introFile) else '', 
                    if ($glossFile != $fileName and $glossFile) then (
                        concat('&amp;href=/xhtml/', $glossFile, '&amp;text=',
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

  <!-- Post processing results in a BIG speedup vs using mode='xhtml' -->
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
  
  <!-- This function may be called on any node. It returns the output 
  file that contains the node -->
  <function name="me:getFileName" as="xs:string">
    <param name="node1" as="node()"/>
    
    <variable name="node" as="node()" 
        select="if ($node1/ancestor-or-self::div) then $node1 else 
                $node1/(descendant::div | following::div)[1]"/>

    <variable name="root" select="if ($node/ancestor-or-self::osis[@isCombinedGlossary]) then 
                                  'comb' else 
                                  oc:myWork($node)"/>
    <variable name="refUsfmType" select="$node/ancestor-or-self::div[@type=$usfmType][last()]"/>
    <variable name="refUsfmTypeDivNum" select="0.5 + 
                                               0.5*(count($refUsfmType/descendant-or-self::div[@type=$usfmType])) + 
                                               count($refUsfmType/preceding::div[@type=$usfmType])"/>
    <variable name="book" select="$node/ancestor-or-self::div[@type='book'][last()]/@osisID"/>
    <!-- The group selects below must be the same as the corresponding 
    group-adjacent attributes of the divideFiles templates. Otherwise
    the transform will fail while trying to write to an already written 
    and closed file. -->
    <choose>
      <!-- Children's Bible nodes -->
      <when test="$isChildrensBible">
        <variable name="group" select="0.5 + 0.5*count($node/ancestor-or-self::div[@type='chapter']) + 
                                       count($node/preceding::div[@type='chapter'])"/>
        <value-of select="concat($root, '_Chbl_c', $group, '.xhtml')"/>
      </when>
      <!-- Book and chapter nodes -->
      <when test="$book">
        <variable name="group" select="count($node/descendant-or-self::chapter[starts-with(@sID, concat($book, '.'))]) + 
                                       count($node/preceding::chapter[starts-with(@sID, concat($book, '.'))])"/>
        <value-of select="concat($root, '_', $book, if (not($eachChapterIsFile)) then '' else concat('/ch', $group), '.xhtml')"/>
      </when>
      <!-- BookGroup introduction nodes -->
      <when test="$node/ancestor::div[@type='bookGroup']">
        <variable name="group" select="0.5 + 0.5*count($node/descendant-or-self::div[@type='book']) + 
                                       count($node/preceding::div[@type='book'])"/>
        <value-of select="concat($root, '_bookGroup-introduction_', $group, '.xhtml')"/>
      </when>
      <!-- Main module introduction nodes -->
      <when test="$root = $MAINMOD">
        <variable name="group" select="0.5 + 0.5*count($node/descendant-or-self::div[@type='bookGroup']) + 
                                       count($node/preceding::div[@type='bookGroup'])"/>
        <value-of select="concat($root, '_module-introduction', (if ($group &#60; 1) then '' else concat('_', $group)), '.xhtml')"/>
      </when>
      <!-- Reference OSIS glossary nodes -->
      <when test="$node/ancestor-or-self::div[@type='glossary']">
        <variable name="my_keywordFile" 
          select="if (count($refUsfmType/descendant::seg[@type='keyword']) = 1) then 'glossary' else
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
            concat($root, '_glossary', '/', $suffix, if ($group) then $group else '', '.xhtml') else 
            concat($root, '_glossary', '/div', $refUsfmTypeDivNum, '_', $suffix, if ($group) then $group else '', '.xhtml')"/>
      </when>
      <!-- non-glossary refUsfmType nodes -->
      <when test="$refUsfmType">
        <value-of select="concat($root, '_', $refUsfmType/@type, '/div', $refUsfmTypeDivNum, '.xhtml')"/>
      </when>
      <!-- unknown type nodes (osis-converters gives osisIDs to top level divs, so use osisID)-->
      <otherwise>
        <value-of select="concat($root, '_', oc:id($node/ancestor::div[parent::osisText]/@osisID), '.xhtml')"/>
      </otherwise>
    </choose>
  </function>
  
  <!-- This template may be called with a Bible osisRef string. It does
  the same thing as me:getFileName but is much faster. -->
  <function name="me:getFileNameOfRef" as="xs:string">
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
                             '.xhtml')"/>
  </function>
  
  <!-- Write an xhtml file -->
  <template name="WriteFile">
    <param name="fileName" as="xs:string"/>
    <param name="OSISelement" as="node()"/>
    <param name="fileXHTML" as="node()+"/>
    <param name="fileNotes" as="node()*"/>
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    
    <variable name="topElement" select="$OSISelement/parent::*" as="element()"/>
    <variable name="isMainNode" select="oc:myWork($topElement) = $MAINMOD"/>
    <call-template name="Log">
      <with-param name="msg" select="concat('-------- writing: ', $fileName)"/>
    </call-template>
    <!-- Each MOBI footnote must be on single line, or they will not display correctly in MOBI popups! 
  Therefore indent="no" is a requirement for xhtml outputs. -->
    <result-document 
        href="xhtml/{$fileName}"
        format="htmlfiles" 
        indent="{if ($SCRIPT_NAME='osis2ebooks') then 'no' else 'yes'}">
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta name="generator" content="OSIS"/>
          <title><xsl:value-of select="$fileName"/></title>
          <meta http-equiv="Default-Style" content="text/html; charset=utf-8"/>
          <xsl:for-each select="tokenize($css, '\s*,\s*')">
            <xsl:if test="ends-with(lower-case(.), 'css')">
              <link href="{oc:uriToRelativePath(concat('/xhtml/', me:getFileName($topElement)), .)}" 
                    type="text/css" rel="stylesheet"/>
            </xsl:if>
          </xsl:for-each>
        </head>
        <body>
          <xsl:attribute name="class" select="normalize-space(string-join(distinct-values(
              ('calibre', 
               root($OSISelement)//work[@osisWork = oc:myWork(.)]/type/@type, 
               $topElement/ancestor-or-self::*[@scope][1]/@scope, 
               for $x in tokenize($fileName, '[_/\.]') return $x, 
               $topElement/@type, 
               $topElement/@subType)
              ), ' '))"/>
          <!-- If our main OSIS file doesn't have a main TOC milestone, add one -->
          <if test="not($mainTocMilestone) and $isMainNode and 
                    $OSISelement[preceding::node()[normalize-space()][not(ancestor::header)][1][self::header]]" 
              xmlns="http://www.w3.org/1999/XSL/Transform">
            <variable name="pubname" select="//work[child::type[@type='x-bible']][1]/title[1]"/>
            <variable name="title" as="element()+">
              <osis:milestone type="{concat('x-usfm-toc', $TOC)}" n="{$pubname}"/>
              <osis:title type="main"><value-of select="$pubname"/></osis:title>
            </variable>
            <apply-templates mode="xhtml" select="$title"/>
            <sequence select="oc:getMainInlineTOC(root($OSISelement), $combinedGlossary, $preprocessedRefOSIS)"/>
          </if>
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
          <with-param name="classes" 
            select="normalize-space(string-join((me:getClasses(.), 'xsl-note-head'), ' '))"/>
        </call-template>
      </html:a>
      <value-of select="' '"/>
      <apply-templates mode="xhtml"/>
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
          <with-param name="classes" 
            select="normalize-space(string-join((me:getClasses(.), 'xsl-note-head'), ' '))"/>
        </call-template>
      </html:a>
      <value-of select="' '"/>
      <apply-templates mode="xhtml"/>
    </html:div>
    <text>&#xa;</text>
  </template>
  
  <!-- This template may be called from any note. It returns a symbol or 
  number based on that note's type and context -->
  <template name="getFootnoteSymbol">
    <param name="classes" select="''"/>
    <variable name="inChapter" select="preceding::chapter[1]/@sID = following::chapter[1]/@eID or 
                                       preceding::chapter[1]/@sID = descendant::chapter[1]/@eID or 
                                       boolean(ancestor::title[@canonical='true'])"/>
    <choose>
      <when test="$inChapter and not(@type='crossReference')">
        <attribute name="class" select="normalize-space(string-join(($classes, 'xsl-fnote-symbol'), ' '))"/>
        <value-of select="'*'"/>
      </when>
      <when test="$inChapter and @subType='x-parallel-passage'">
        <attribute name="class" select="normalize-space(string-join(($classes, 'xsl-crnote-symbol'), ' '))"/>
        <value-of select="'•'"/>
      </when>
      <when test="$inChapter">
        <attribute name="class" select="normalize-space(string-join(($classes, 'xsl-crnote-symbol'), ' '))"/>
        <value-of select="'+'"/>
      </when>
      <otherwise>
        <attribute name="class" select="normalize-space(string-join(($classes, 'xsl-note-number'), ' '))"/>
        <value-of select="'['"/><call-template name="getFootnoteNumber"/><value-of select="']'"/>
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
      <when test="oc:myWork(.) = $MAINMOD"><!-- main introduction -->
        <value-of select="count(preceding::note[not(ancestor::div[@type='bookGroup'])]) + 1"/>
      </when>
      <otherwise>
        <value-of select="count(preceding::note) - count(ancestor::div[last()]/preceding::note) + 1"/>
      </otherwise>
    </choose>    
  </template>
  
  <!--                  TABLE OF CONTENTS
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
  
  INSTRUCTION                   DESCRIPTION
  [levelN]        - Where N is 1, 2 or 3. Specifies the TOC level.
  [no_toc]        - Means this element is NOT treated as a TOC element.
  [no_inline_toc] - Means this TOC element will not generate an inline
                    TOC. This could result in broken links for non-eBook
                    publications, so use with care.
  [only_inline_toc] - Means this TOC element will only generate an 
                    inline TOC (so not an eBook TOC entry).
  [no_main_inline_toc] - Means this TOC element will not create an entry
                    in the main inline TOC.
  [inline_toc_first] - Means this TOC element will generate an inline
                    TOC before its content. This is default for material
                    which is in a Bible. This instruction does not apply
                    to glossaries.
  [inline_toc_last] - Means this TOC element will generate an inline TOC
                    after its content. This is default for material 
                    which is not in a Bible. This instruction does not
                    apply to glossaries. The inline TOC will appear just
                    before the following TOC milestone, even if that
                    milestone is [no_toc] (so that can be used to place 
                    the inline TOC anywhere within the content).
  [not_parent]    - Used on bookGroup or book  milestone TOC elements.   
                    Means that this section should appear as the first  
                    sibling of the following book or chapter list,   
                    rather than as the parent (parent is default for  
                    book or bookGroup TOC elements).
  Any TEXT following these instructions will be used for the TOC entry 
  name (overriding the default name if there is one). -->
  <function name="oc:getMainInlineTOC" as="element(html:div)?">
    <param name="mainRootNode" as="document-node()"/>
    <param name="combinedGlossary" as="document-node()"/>
    <param name="preprocessedRefOSIS" as="document-node()"/>
    
    <variable name="listElementDoc">
      <sequence select="me:getTocListItems($mainRootNode, true())"/>
      <!-- If combining glossaries, put the combined glossary first, 
      then any non-glossary material after it -->
      <if test="$doCombineGlossaries">
        <sequence select="me:getTocListItems($combinedGlossary, true())"/>
      </if>
      <!-- Next is either non-glossary material in reference OSIS (if 
      combiningGlossaries) or else everything in reference OSIS -->
      <sequence select="me:getTocListItems($preprocessedRefOSIS, true())"/>
    </variable>
    
    <if test="count($listElementDoc/html:li)">
      <html:div id="root-toc">
        <sequence select="me:getInlineTocDiv($listElementDoc, true())"/>
      </html:div>
    </if>
  </function>
  
  <function name="me:getInlineTOC" as="element(html:div)?">
    <param name="tocElement" as="element()"/>
    
    <variable name="listElementDoc">
      <sequence select="me:getTocListItems($tocElement, false())"/>
    </variable>
    
    <if test="count($listElementDoc/html:li)">
      <sequence select="me:getInlineTocDiv($listElementDoc, false())"/>
    </if>
  </function>
  
  <function name="me:getInlineTocDiv" as="element(html:div)">
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
                  back link, or only one back link and scripture links 
                  are full-width, then all back links become full-table 
                  width. When there are an odd number of half-table 
                  width back links, the last link is centered by itself. -->
    <variable name="fullWidthElements" select="$listdoc/html:li[me:isFullWidth(., $isTopTOC)]"/>
    <variable name="halfWidthElements" select="$listdoc/html:li[not(. intersect $fullWidthElements)]"/>
    <variable name="chars" select="if ($isTopTOC) then 
                                       max(($halfWidthElements/(2*string-length(string())), 
                                            $fullWidthElements/string-length(string())
                                       )) else 
                                       max($listdoc/html:li/string-length(string()))"/>
    <variable name="wChars" select="if ($chars &#62; $tocWidth) then $tocWidth else $chars"/>

    <html:div>
      <attribute name="class">xsl-inline-toc</attribute>
      <!-- this div allows margin auto to center, which doesn't work with ul/ol -->
      <html:div>
        <choose>
          <!-- main TOC is fixed width and children are specified as % in css -->
          <when test="$isTopTOC">
            <!-- The main TOC is fixed width and child li are specified as % in css. To fit the text:
            width = 6px + $averageCharWidth*(4+wChars/2) ch + 12px + $averageCharWidth*(4+wChars/2) ch + 6px 
            or: max-width of parent at 100% = 24px + $averageCharWidth*(8+wChars) ch + 1ch for chapter inline block fudge -->
            <variable name="ch" select="floor(0.5 + 10*$averageCharWidth*(8+$wChars)) div 10"/>
            <attribute name="style" select="concat('max-width:calc(24px + ', $ch+1, 'ch)')"/>
          </when>
          <!-- book TOCs are max 3 columns -->
          <when test="$listdoc/html:li[tokenize(@class,'\s+') = 'xsl-book-link']">
            <attribute name="style" select="concat('max-width:', ceiling(3.5*$averageCharWidth*(4+$wChars)), 'ch')"/>
          </when>
        </choose>
        <for-each-group select="$listdoc/html:li" group-adjacent="me:section(., $isTopTOC)">
          <variable name="sectionIsFullWidth" as="xs:boolean" 
            select="me:isFullWidth(current-group()[1], $isTopTOC)"/>
          <variable name="maxWCharsSection" as="xs:double" 
            select="if ($sectionIsFullWidth) then $tocWidth else $tocWidth div 2"/>
          <variable name="charsSection" as="xs:double" 
              select="max(current-group()[not(tokenize(@class, '\s+') = 'xsl-atoz')]/string-length(string()))"/>
          <variable name="wCharsSection" as="xs:double" 
              select="if ($charsSection &#62; $maxWCharsSection) then $maxWCharsSection else $charsSection"/>
          <variable name="ch_section" as="xs:double"
              select="floor(0.5 + 10 * $averageCharWidth * (4 + $wCharsSection)) div 10"/>
          <html:ol>
            <attribute name="class">
              <variable name="class" as="xs:string+">
                <value-of select="me:section(current-group()[1], $isTopTOC)"/>
                <if test="$sectionIsFullWidth">
                  <value-of select="'xsl-full-width'"/>
                </if>
                <if test="count(current-group()[tokenize(@class,'\s+') = 'xsl-book-link']) mod 2 = 1">
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
                    <variable name="Hem" as="xs:double"
                      select="1 + ceiling( if ($isTopTOC and me:isFullWidth(., $isTopTOC)) 
                                           then string-length(string()) div $wCharsSection 
                                           else $charsSection div $wCharsSection )"/>
                    <value-of select="concat('min-height:calc(', $Hem, 'em + 3px)')"/>
                    <!-- Width is not specified for top-TOC at the li level because it is specified
                    at a higher div level. The A-to-Z button width is not specified because it 
                    is allowed to be wider than all other button links in its list. -->
                    <if test="not($isTopTOC) and not(tokenize(@class, '\s+') = 'xsl-atoz')">
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
  <function name="me:section" as="xs:string">
    <param name="elem" as="element()"/>
    <param name="isTopTOC" as="xs:boolean"/>
    <value-of select="if (not($isTopTOC)) then concat(tokenize($elem/@class,'\s+')[1], '-section')
                      else if (contains($elem/@class,'xsl-book')) then 'xsl-scrip' 
                      else if ($elem/following::*[contains(@class,'xsl-book')]) then 'xsl-intro' 
                      else 'xsl-back'"/>
  </function>
  <function name="me:isFullWidth" as="xs:boolean">
    <param name="elem" as="element()"/>
    <param name="isTopTOC" as="xs:boolean"/>
    
    <variable name="section" select="me:section($elem, $isTopTOC)"/>
    <variable name="siblings" select="$elem/parent::node()/child::node()
                                   [me:section(., $isTopTOC) = $section]"/>
    <variable name="scripElems" select="$elem/parent::node()/child::node()
                                   [me:section(., $isTopTOC) = 'xsl-scrip']"/>
    <variable name="fullWidthChars" select="if ($section = 'xsl-intro') 
                                            then $introFullWidth else $backFullWidth"/>
    <choose>
      <when test="not($isTopTOC)">
        <value-of select="true()"/>
      </when>
      <when test="$section = 'xsl-scrip'">
        <value-of select="count($siblings) &#60;= 5"/>
      </when>
      <otherwise>
        <value-of select="max($siblings/string-length(string())) &#62;= $fullWidthChars or 
                          (count($siblings) = 1 and count($scripElems) &#60;= 5)"/>
      </otherwise>
    </choose>
  </function>
  
  <!-- Returns a series of list entry elements, one for every TOC entry that is a 
  step below tocNode in the hierarchy. A class is added according to the type of 
  entry. EBook glossary keyword lists with greater than $glossThresh entries are 
  pared down to list only the first of each letter. -->
  <function name="me:getTocListItems" as="element(html:li)*">
    <param name="tocNode" as="node()"/>
    <param name="isTopTOC" as="xs:boolean"/>
    
    <variable name="isMainNode" select="oc:myWork($tocNode) = $MAINMOD"/>
    <variable name="myTocLevel" as="xs:integer" 
        select="if ($isTopTOC) then 0 else me:getTocLevel($tocNode)"/>
    <variable name="sourceDir" select="concat('/xhtml/', if ($isTopTOC) then 'top.xhtml' else me:getFileName($tocNode))"/>
    <if test="$myTocLevel &#60; 3 and not(matches($tocNode/@n, '\[(not_parent|no_inline_toc)\]'))">
      <variable name="subentries" as="element()*">
        <choose>
          <!-- Children's Bibles -->
          <when test="$isChildrensBible and $isTopTOC">
            <sequence select="$tocNode/ancestor-or-self::div[@type='book'][last()]//
                milestone[@type=concat('x-usfm-toc', $TOC)]
                [contains(@n, '[level1]')][not(. intersect $tocNode)]"/>
          </when>
          <when test="$isChildrensBible">
            <variable name="followingTocs" select="$tocNode/following::
                milestone[@type=concat('x-usfm-toc', $TOC)]
                [contains(@n, concat('[level',($myTocLevel+1),']'))]"/>
            <variable name="nextSibling"   select="$tocNode/following::
                milestone[@type=concat('x-usfm-toc', $TOC)]
                [contains(@n, substring($tocNode/@n, 1, 8))][1]"/>
            <sequence select="if ($nextSibling) then 
                $followingTocs[. &#60;&#60; $nextSibling] else 
                $followingTocs"/>
          </when>
          <!-- chapter start tag -->
          <when test="$tocNode/self::chapter[@sID]">
            <sequence select="( $tocNode/following::seg[@type='keyword'] | 
                                $tocNode/following::milestone[@type=concat('x-usfm-toc', $TOC)]
                              )[not(contains(@n, '[no_toc]'))] except 
                $tocNode/following::chapter[@eID][@eID = $tocNode/@sID]/following::*"/>
          </when>
          <!-- otherwise find the container div for this TOC element -->
          <otherwise>
            <variable name="container" as="node()?" 
                select="if ($isTopTOC) then (root($tocNode)) else
                        if (
                          $tocNode/parent::div[not(@type = ('bookGroup', 'book'))]
                          [parent::div[@type = ('bookGroup', 'book')]]
                          [not(preceding-sibling::*) or parent::div[@type = 'bookGroup']]
                        )
                        then $tocNode/parent::div/parent::div 
                        else $tocNode/ancestor::div[1]"/>
            <variable name="containerTocs" 
                select="( $container//chapter[@sID] | 
                          $container//seg[@type='keyword'] | 
                          $container//milestone[@type=concat('x-usfm-toc', $TOC)]
                        )[. &#62;&#62; $tocNode]
                         [not($isTopTOC and @isMainTocMilestone = 'true')]
                         [not($isTopTOC and self::*[contains(@n, '[no_main_inline_toc]')])]
                         [not(ancestor::div[@type='glossary'][@subType='x-aggregate'])]
                         [not(self::*[contains(@n, '[no_toc]')])]"/>
            <variable name="nextTocSP" select="if ($isTopTOC) then () else 
                $tocNode/following::*[. intersect $containerTocs]
                                     [me:getTocLevel(.) &#60;= $myTocLevel][1]"/>
            <sequence select="$containerTocs[me:getTocLevel(.) = $myTocLevel + 1]
                                            [not(. intersect $nextTocSP)]
                                            [not(. &#62;&#62; $nextTocSP)]"/>
          </otherwise>
        </choose>
      </variable>
      <variable name="onlyKeywordFirstLetter" as="xs:boolean" 
        select="not($isMainNode) and 
                ($SCRIPT_NAME = 'osis2ebooks') and 
                (count($subentries[@type='keyword']) &#62;= xs:integer(number($glossThresh))) and 
                (count(distinct-values($subentries[@type='keyword']/oc:keySortLetter(text()))) &#62; 1)"/>
      <for-each select="$subentries">
        <if test="not( $onlyKeywordFirstLetter and  
                       boolean(self::seg[@type='keyword']) and 
                       oc:skipGlossaryEntry(.)
                      )">
          <html:li>
            <attribute name="class">
              <variable name="class" as="xs:string+">
                <variable name="intros" select="me:getBookGroupIntroductions(.)"/>
                <choose>
                  <when test="self::chapter"> xsl-chapter-link </when>
                  <when test="self::seg"> xsl-keyword-link </when>
                  <when test="count($intros) = 1 and . intersect $intros"> xsl-bookGroup-link </when>
                  <when test=". intersect $intros"> xsl-bookSubGroup-link </when>
                  <when test="parent::div[@type = ('glossary', 'bookGroup', 'book')]">
                    <value-of select="concat(' xsl-', parent::div/@type, '-link ')"/>
                  </when>
                  <otherwise> xsl-other-link </otherwise>
                </choose>
                <value-of select="oc:getTocInstructions(.)"/>
                <if test="ancestor::div[@subType='x-navmenu-atoz']"> xsl-atoz </if>
              </variable>
              <value-of select="normalize-space(string-join($class, ' '))"/>
            </attribute>
            <!-- two divs are needed to center vertically using table-style centering -->
            <html:div>
              <html:div>
                <html:a>
                  <attribute name="href" select="oc:uriToRelativePath(
                      $sourceDir, 
                      concat('/xhtml/', me:getFileName(.), '#', oc:id(@osisID))
                    )"/>
                  <choose>
                    <when test="self::chapter[@osisID]">
                      <value-of select="tokenize(@osisID, '\.')[last()]"/>
                    </when>
                    <when test="ancestor::div[@type='x-keyword'][starts-with(@subType,'x-navmenu')]">
                      <value-of select="text()"/>
                    </when>
                    <when test="$onlyKeywordFirstLetter and self::seg[@type='keyword']">
                      <value-of select="oc:keySortLetter(text())"/>
                    </when>
                    <when test="matches(text(), '^\-')"><value-of select="text()"/></when>
                    <otherwise>
                      <value-of select="oc:titleCase(me:getTocTitle(.))"/>
                    </otherwise>
                  </choose>
                </html:a>
              </html:div>
            </html:div>
          </html:li>
        </if>
      </for-each>
    </if>
  </function>
  
  <!-- me:getTocAttributes returns attribute nodes for a TOC element -->
  <function name="me:getTocAttributes" as="attribute()+">
    <param name="tocElement" as="element()"/>
    
    <variable name="msclasses" as="xs:string*">
      <if test="$tocElement/@n">
        <analyze-string select="$tocElement/@n" regex="\[([^\]]+)\]">
          <matching-substring><value-of select="regex-group(1)"/></matching-substring>
        </analyze-string>
      </if>
    </variable>
    
    <variable name="class" select="normalize-space(string-join(( 
        if (not($msclasses = 'no_toc')) then 'xsl-toc-entry' else '', 
        $msclasses, 
        me:getClasses($tocElement)), ' '))"/>
    
    <attribute name="id" select="oc:id($tocElement/@osisID)"/>
    
    <attribute name="class" select="$class"/>
        
    <if test="not(tokenize($class, ' ') = ('no_toc', 'only_inline_toc'))">
      <attribute name="title" select="concat('toclevel-', me:getTocLevel($tocElement))"/>
    </if>
    
  </function>
  
  <!-- me:getTocTitle returns the title text of tocElement -->
  <function name="me:getTocTitle" as="xs:string">
    <param name="tocElement" as="element()"/>
    
    <variable name="tocTitleEXPLICIT" 
        select="if (matches($tocElement/@n, '^(\[[^\]]*\])+')) then 
                replace($tocElement/@n, '^(\[[^\]]*\])+', '') else if
                ($tocElement/@n) then $tocElement/@n else ''"/>
                
    <variable name="tocTitleOSIS">
      <choose>
        <!-- milestone TOC -->
        <when test="$tocElement/self::milestone[@type=concat('x-usfm-toc', $TOC) and @n]">
          <value-of select="$tocElement/@n"/>
        </when>
        <!-- chapter TOC -->
        <when test="$tocElement/self::chapter[@sID]">
          <variable name="chapterLabel" select="$tocElement/following::title
                                                [@type='x-chapterLabel'][1]
                                                [following::chapter[1][@eID=$tocElement/@sID]]"/>
          <choose>
            <when test="$chapterLabel">
              <value-of select="string($chapterLabel)"/>
            </when>
            <otherwise><value-of select="tokenize($tocElement/@sID, '\.')[last()]"/></otherwise>
          </choose>
        </when>
        <when test="$tocElement/self::seg[@type='keyword']">
          <value-of select="$tocElement"/>
        </when>
        <!-- otherwise error -->
        <otherwise>
          <variable name="errtitle" select="
              concat($tocElement/name(), ' ', count($tocElement/preceding::*[name()=$tocElement/name()]))"/>
          <value-of select="$errtitle"/>
          <call-template name="Error">
<with-param name="msg">Could not determine TOC title of "<value-of select="$errtitle"/>"</with-param>
          </call-template>
        </otherwise>
      </choose>
    </variable>
    
    <value-of select="if ($tocTitleEXPLICIT) then $tocTitleEXPLICIT else $tocTitleOSIS"/>
    
  </function>
  
  <!-- getTocLevel returns an integer which is the TOC hierarchy level of tocElement -->
  <function name="me:getTocLevel" as="xs:integer">
    <param name="tocElement" as="element()"/>
    <variable name="isMainNode" select="oc:myWork($tocElement) = $MAINMOD"/>
    <variable name="toclevelEXPLICIT" select="if (matches($tocElement/@n, '\[level\d\]')) then 
                                                 replace($tocElement/@n, '^.*\[level(\d)\].*$', '$1') else '0'"/>
    <variable name="toclevelOSIS">
      <variable name="parentTocNodes" select="if ($isMainNode) then 
                                                  me:getBibleParentTocNodes($tocElement) else 
                                                  me:getGlossParentTocNodes($tocElement)"/>
      <value-of select="1 + count($parentTocNodes)"/>
    </variable>
    <value-of select="if ($toclevelEXPLICIT != '0') then $toclevelEXPLICIT else $toclevelOSIS"/>
  </function>
  
  <!-- getBibleParentTocNodes may be called with any element and returns milestone* -->
  <function name="me:getBibleParentTocNodes" as="element(milestone)*">
    <param name="x" as="element()"/>
    <!-- A preceding TOC milestone is a 'parent TOC node' if it corresponds to:
      Any TOC entry div containing x.
      OR: the introduction div for the bookGroup which contains x (whenever x is in a bookGroup)
      OR: the first preceding non-book child div of the bookGroup (whenever x is in a book) -->
    <variable name="ancestor_div_TOC_milestones" as="element(milestone)*"
        select="$x/ancestor-or-self::div/(
            child::milestone[@type=concat('x-usfm-toc', $TOC)] | 
            child::*[1][not(self::div)]/child::milestone[@type=concat('x-usfm-toc', $TOC)]
          )[1]" />
   
    <sequence select="$x/preceding::milestone
      [@type=concat('x-usfm-toc', $TOC)]
      [not(contains(@n, '[no_toc]'))]
      [not(contains(@n, '[not_parent]'))]
      [. intersect ($ancestor_div_TOC_milestones | me:getBookGroupIntroductions($x))]"/>
  </function>
  
  <!-- getGlossParentTocNodes may be called with any element and returns (milestone|chapter[@sID])* -->
  <function name="me:getGlossParentTocNodes" as="element()*">
    <param name="x" as="element()"/>
    <!-- A preceding TOC milestone or chapter[@sID] is a 'parent TOC node' if it corresponds to:
      Any TOC entry div containing x.
      OR: Any 'ancestor' chapter where x is between sID-eID chapter milestones -->
    <variable name="ancestor_div_TOC_milestones" as="element(milestone)*"
        select="$x/ancestor-or-self::div/(
            child::milestone[@type=concat('x-usfm-toc', $TOC)][1] | 
            child::*[1][not(self::div)]/child::milestone[@type=concat('x-usfm-toc', $TOC)][1]
          )[1]" />
        
    <variable name="ancestor_TOC_chapters" as="element(chapter)*"
        select="$x/preceding::chapter[@sID][@sID = $x/following::chapter/@eID]" />
        
    <sequence select="( $x/preceding::milestone[@type=concat('x-usfm-toc', $TOC)] | 
                        $x/preceding::chapter[@sID] )
      [not(contains(@n, '[no_toc]'))]
      [not(contains(@n, '[not_parent]'))]
      [. intersect ($ancestor_div_TOC_milestones | $ancestor_TOC_chapters)]" />
  </function>
  
  <!-- Returns the milestone TOC parent(s) of any bookGroup node, which may be one or both of:
       The TESTAMENT INTRODUCTION: the first child div of the bookGroup when it is either the 
       only non-book TOC div or else is immediately followed by another pre-book TOC div. 
       A BOOK-SUB-GROUP INTRODUCTION: the first preceding non-book TOC milestone in the 
       bookGroup which comes after the first book, or possibly that which comes before the first 
       book but only if there are one or more other book sub-group intros after the first book. -->
  <function name="me:getBookGroupIntroductions" as="element(milestone)*">
    <param name="x" as="node()"/>
    
    <variable name="bookGroup" as="element(div)?" 
        select="$x/ancestor-or-self::div[@type='bookGroup']"/>
    
    <variable name="nonBook_TOC_children" as="element(milestone)*" 
        select="$bookGroup/div[not(@type='book')]/milestone[@type=concat('x-usfm-toc', $TOC)]
                [not(contains(@n, '[no_toc]'))]
                [not(contains(@n, '[not_parent]'))]"/>
        
    <variable name="testament_introduction" as="element(milestone)?" 
        select="$bookGroup/child::div[1][@type != 'book']
        [ count($nonBook_TOC_children) = 1 or 
          following-sibling::div[1][@type != 'book']/milestone[@type=concat('x-usfm-toc', $TOC)]
        ]/milestone[@type=concat('x-usfm-toc', $TOC)][1]"/>
        
    <variable name="group_introductions" as="element(milestone)*"
        select="$nonBook_TOC_children[not(. intersect $testament_introduction)]
        [ . &#62;&#62; $bookGroup/div[@type='book'][1] or
        count($nonBook_TOC_children[not(. intersect $testament_introduction)]) &#62; 1 ]"/>
        
    <variable name="my_group_introduction" as="element(milestone)?" 
        select="( $group_introductions[. &#60;&#60; $x] | 
                  $group_introductions[. intersect $x] )[last()]"/>
                  
    <sequence select="($testament_introduction | $my_group_introduction)"/>
  </function>
  
  <!-- This template may be called from any element. It adds a class attribute 
  according to tag, level, type, subType and class -->
  <template name="class"><attribute name="class" select="me:getClasses(.)"/></template>
  <function name="me:getClasses" as="xs:string">
    <param name="x" as="element()"/>
    <value-of select="normalize-space(string-join((
        concat('osis-', $x/local-name()), 
        $x/@type, 
        $x/@subType, 
        $x/@class, 
        if ($x/@level) then concat('level-', $x/@level) else ''), ' ')
      )"/>
  </function>
  
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
      <html:span class="xsl-chapter-number">
        <value-of select="tokenize(preceding::chapter[@sID][1]/@osisID, '\.')[last()]"/>
      </html:span>
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
        <apply-templates mode="xhtml" select=".">
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
    <!-- output hyperlink targets for every verse in the verse system -->
    <for-each select="tokenize($osisID, '\s+')">
      <html:span>
        <attribute name="id" select="oc:id(.)"/>
      </html:span>
    </for-each>
    <!-- then verse numner(s) -->
    <html:sup class="xsl-verse-number">
      <value-of select="if ($first=$last) then tokenize($first, '\.')[last()] else 
          concat(tokenize($first, '\.')[last()], '-', tokenize($last, '\.')[last()])"/>
    </html:sup>
  </template>
  

  <!-- THE FOLLOWING TEMPLATES CONVERT OSIS INTO XHTML MARKUP AS DESIRED -->
  <!-- All text nodes are copied -->
  <template mode="xhtml" match="text()"><copy/></template>
  
  <!-- By default, attributes are dropped -->
  <template mode="xhtml" match="@*"/>
  
  <!-- ...except @osisID which is converted into html id -->
  <template mode="xhtml" match="@osisID">
    <attribute name="id" select="oc:id(.)"/>
  </template>
  
  <!-- By default, elements get their namespace changed from OSIS to XHTML, 
  with a class attribute added (and other attributes dropped) -->
  <template mode="xhtml" match="*">
    <element name="{local-name()}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml" select="node()|@*"/>
    </element>
  </template>
  
  <!-- Remove these elements entirely (x-chapterLabel is handled by me:getTocTitle())-->
  <template mode="xhtml" match="chapter[@eID] |
                                verse[@eID] | 
                                title[@type='runningHead'] |
                                title[@type='x-chapterLabel'] |
                                index | 
                                milestone"/>
  
  <!-- Remove these tags (keeping their content) -->
  <template mode="xhtml" match="name | 
                                seg | 
                                reference[ancestor::title[@type='scope']]">
    <apply-templates mode="xhtml"/>
  </template>
  
  <!-- Verses -->
  <template mode="xhtml" priority="3" match="verse[@sID] | hi[@subType='x-alternate']">
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
  <template mode="xhtml" match="verse[@sID]"><call-template name="WriteVerseNumber"/></template>
  
  <!-- Chapters -->
  <template mode="xhtml" match="chapter[@sID and @osisID]">
    <variable name="chapterLabel"
        select="following::title[@type='x-chapterLabel'][1]
                [following::chapter[1][@eID=current()/@sID]]" />
    <variable name="tocAttributes" select="me:getTocAttributes(.)"/>
    <variable name="tocTitle" select="me:getTocTitle(.)"/>
    <html:h1>
      <sequence select="$tocAttributes"/>
      <choose>
        <when test="$chapterLabel">
          <!-- x-chapterLabel titles may contain other elements such as 
          footnotes which need to be output -->
          <apply-templates mode="xhtml" select="$chapterLabel/node()"/>
        </when>
        <otherwise>
          <value-of select="$tocTitle"/>
        </otherwise>
      </choose>
    </html:h1>
    <!-- non-Bible chapters also get inline TOC (Bible trees do not have a document-node due to preprocessing) -->
    <if test="not(tokenize($tocAttributes/self::attribute(class), ' ') = 'no_toc') 
        and oc:myWork(.) != $MAINMOD">
      <html:h1 class="xsl-nonBibleChapterLabel">
        <value-of select="$tocTitle"/>
      </html:h1>
      <sequence select="me:getInlineTOC(.)"/>
    </if>
  </template>
  
  <!-- Glossary keywords -->
  <template mode="xhtml" priority="2" match="seg[@type='keyword']">
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    <param name="currentTask" tunnel="yes"/>
    <if test="not(ancestor::div[@resp='x-oc']) and 
              not($doCombineGlossaries) and 
              me:getTocLevel(.) = 1 and 
              count(distinct-values($preprocessedRefOSIS//div[@type='glossary']/oc:getDivScopeTitle(.))) &#62; 1"> 
      <variable name="kdh" as="element(osis:title)*">
        <call-template name="keywordDisambiguationHeading"/>
      </variable>
      <apply-templates mode="xhtml" select="$kdh"/>
    </if>
    <html:dfn>
      <sequence select="me:getTocAttributes(.)"/>
      <value-of select="me:getTocTitle(.)"/>
    </html:dfn>
  </template>
  <template mode="xhtml" match="div[starts-with(@type,'x-keyword')]">
    <!-- Add an ebook page-break if there is more than one keyword in the glossary.
    NOTE: Calibre splits files at these CSS page breaks. -->
    <variable name="needPageBreak" as="xs:boolean" select="$SCRIPT_NAME = 'osis2ebooks' and 
      count(ancestor::div[@type='glossary']/descendant::seg[@type='keyword']) &#62; 1"/>
    <html:div>
      <variable name="classes" select="me:getClasses(.)"/>
      <attribute name="class" select="if (not($needPageBreak)) then $classes else 
        normalize-space(string-join((tokenize($classes, ' '), 'osis-milestone', 'pb'), ' '))"/>
      <apply-templates mode="xhtml"/>
    </html:div>
  </template>
  
  <!-- Titles -->
  <template mode="xhtml" match="title">
    <element name="h{if (@level) then @level else '1'}" namespace="http://www.w3.org/1999/xhtml">
      <if test="@osisID"><attribute name="id" select="oc:id(@osisID)"/></if>
      <call-template name="class"/>
      <if test="@canonical='true'">
        <call-template name="WriteEmbededChapter"/>
        <call-template name="WriteEmbededVerse"/>
      </if>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <!-- Parallel passage titles become secondary titles !-->
  <template mode="xhtml" match="title[@type='parallel']">
    <html:h2>
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </html:h2>
  </template>
  
  <!-- OSIS elements which will become spans with a special class !-->
  <template mode="xhtml" match="catchWord | 
                                foreign | 
                                hi | 
                                rdg | 
                                signed |
                                transChange">
    <html:span>
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </html:span>
  </template>
  
  <template mode="xhtml" match="cell">
    <html:td>
      <apply-templates mode="xhtml"/>
    </html:td>
  </template>
  
  <template mode="xhtml" match="caption">
    <element name="{if ($html5 = 'true') then 'figcaption' else 'div'}" 
        namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <template mode="xhtml" priority="1" match="div[@type='introduction']">
    <next-match/>
    <hr xmlns="http://www.w3.org/1999/xhtml"/>
  </template>
  
  <template mode="xhtml" match="figure">
    <param name="contextFile" select="me:getFileName(.)" tunnel="yes"/>
    
    <element name="{if ($html5 = 'true') then 'figure' else 'div'}" 
        namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <html:img src="{oc:uriToRelativePath(concat('/xhtml/', $contextFile), @src)}" alt="{@src}"/>
      <apply-templates mode="xhtml"/>
    </element>
  </template>

  <template mode="xhtml" match="head">
    <html:h2>
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </html:h2>
  </template>
  
  <template mode="xhtml" match="item[@subType='x-prevnext-link'][ancestor::div[starts-with(@type, 'x-keyword')]]">
    <if test="$doCombineGlossaries"><next-match/></if>
  </template>
  
  <template mode="xhtml" match="item">
    <html:li>
      <call-template name="class"/>
      <call-template name="WriteEmbededChapter"/>
      <call-template name="WriteEmbededVerse"/>
      <apply-templates mode="xhtml"/>
    </html:li>
  </template>
  
  <template mode="xhtml" match="lb">
    <html:br><call-template name="class"/></html:br>
  </template>
  
  <!-- usfm2osis.py follows the OSIS manual recommendation for selah as a line element 
  which differs from the USFM recommendation for selah. According to USFM 2.4 spec, 
  selah is: "A character style. This text is frequently right aligned, and rendered 
  on the same line as the previous poetic text..." !-->
  <template mode="xhtml" match="l">
    <choose>
      <!-- Consecutive selah l elements are all output together within the 
      preceding div. Selah must not be the first line in a linegroup, or it
      will be ignored. -->
      <when test="@type = 'selah'"/>
      <when test="following-sibling::l[1][@type='selah']">
        <html:div>
          <call-template name="class"/>
          <call-template name="WriteEmbededChapter"/>
          <call-template name="WriteEmbededVerse"/>
          <apply-templates mode="xhtml"/>
          <html:i class="xsl-selah">
            <for-each select="following-sibling::l[@type='selah']
                [ count(preceding-sibling::l[@type='selah'][. &#62;&#62; current()]) = 
                  count(preceding-sibling::l[. &#62;&#62; current()]) ]">
              <text> </text>
              <apply-templates mode="xhtml"/>
            </for-each>
          </html:i>
        </html:div>
      </when>
      <otherwise>
        <html:div>
          <call-template name="class"/>
          <call-template name="WriteEmbededChapter"/>
          <call-template name="WriteEmbededVerse"/>
          <apply-templates mode="xhtml"/>
        </html:div>
      </otherwise>
    </choose>
  </template>
  
  <template mode="xhtml" match="lg">
    <html:div>
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </html:div>
  </template>
  
  <template mode="xhtml" match="list">
    <param name="currentTask" tunnel="yes"/>
    <variable name="ol" as="element(html:ol)">
      <html:ol >
        <call-template name="class"/>
        <apply-templates mode="xhtml"/>
      </html:ol>
    </variable>
    <!-- OSIS allows list to contain head children, but EPUB2 validator 
    doesn't allow <h> child tags of ul -->
    <variable name="ol2" select="oc:expelElements($ol, 
        $ol/*[contains(@class, 'osis-head')], 
        boolean($currentTask='get-filenames'))"/>
    <for-each select="$ol2">
      <if test="not(boolean(self::html:ol)) or count(child::*)">
        <sequence select="."/>
      </if>
    </for-each>
  </template>
  
  <template mode="xhtml" match="list[@subType='x-navmenu'][following-sibling::*[1][self::chapter[@eID]]]">
    <if test="$eachChapterIsFile"><next-match/></if>
  </template>
  
  <template mode="xhtml" priority="2" match="milestone[@type=concat('x-usfm-toc', $TOC)]">
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    <param name="currentTask" tunnel="yes"/>
    
    <!-- [inline_toc_last] writes the inline TOC just before the 
    following TOC milestone, even if the following is [no_toc] -->
    <for-each select="preceding::milestone[@type=concat('x-usfm-toc', $TOC)][1]
                      [contains(@n, '[inline_toc_last]')]">
      <sequence select="me:getInlineTOC(.)"/>
    </for-each>
    
    <variable name="tocAttributes" select="me:getTocAttributes(.)"/>
    
    <if test="not(tokenize($tocAttributes/self::attribute(class), ' ') = 'no_toc')">
      <variable name="tocTitle" select="oc:titleCase(me:getTocTitle(.))"/>
      <variable name="inlineTOC" as="element(html:div)?" select="me:getInlineTOC(.)"/>
      <!-- The <div><small> was chosen because milestone TOC text is hidden by CSS, and non-CSS 
      implementations should have this text de-emphasized since it is not part of the orignal book -->
      <html:div>
        <sequence select="$tocAttributes"/>
        <html:small><html:i><value-of select="$tocTitle"/></html:i></html:small>
      </html:div>
      <!-- if there is an inlineTOC with this milestone TOC, then write out a title -->
      <if test="@isMainTocMilestone = 'true' or $inlineTOC">
        <html:h1>
          <value-of select="$tocTitle"/>
        </html:h1>
      </if>
      <!-- if this is the first milestone in a Bible, then include the root TOC -->
      <if test="@isMainTocMilestone = 'true'">
        <sequence select="oc:getMainInlineTOC(root(.), $combinedGlossary, $preprocessedRefOSIS)"/>
      </if>
      <!-- if a glossary disambiguation title is needed, then write that out -->
      <if test="not($doCombineGlossaries) and 
                me:getTocLevel(.) = 1 and 
                count(distinct-values(
                  $preprocessedRefOSIS//div[@type='glossary']/oc:getDivScopeTitle(.)
                )) &#62; 1"> 
        <variable name="kdh" as="element(osis:title)*">
          <call-template name="keywordDisambiguationHeading">
            <with-param name="noName" select="'true'"/>
          </call-template>
        </variable>
        <apply-templates mode="xhtml" select="$kdh"/>
      </if>
      <!-- output the inline TOC -->
      <if test="not(contains(@n, '[inline_toc_last]'))">
        <sequence select="$inlineTOC"/>
      </if>
    </if>
  </template>
  
  <template mode="xhtml" priority="3" match="milestone[@type=concat('x-usfm-toc', $TOC)][preceding-sibling::seg[@type='keyword']]">
    <param name="currentTask" tunnel="yes"/>
    <if test="$currentTask = 'write-xhtml'">
      <call-template name="Note">
        <with-param name="msg">
Dropping redundant TOC milestone in keyword <value-of select="preceding-sibling::seg[@type='keyword'][1]"/>: <value-of select="oc:printNode(.)"/>
        </with-param>
      </call-template>
    </if>
  </template>
  
  <template mode="xhtml" priority="2" match="milestone[@type='pb']">
    <html:p>
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </html:p>
  </template>
  
  <template mode="xhtml" match="note">
    <html:sup>
      <html:a href="#{oc:id(@osisID)}" id="textsym.{oc:id(@osisID)}">
        <if test="$epub3Markup">
          <attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'noteref'"/>
        </if>
        <call-template name="getFootnoteSymbol">
          <with-param name="classes" select="me:getClasses(.)"/>
        </call-template>
      </html:a>
    </html:sup>
  </template>
  
  <template mode="xhtml" match="p">
    <param name="currentTask" tunnel="yes"/>
    <variable name="p" as="element(html:p)">
      <html:p>
        <call-template name="class"/>
        <call-template name="WriteEmbededChapter"/>
        <call-template name="WriteEmbededVerse"/>
        <apply-templates mode="xhtml"/>
      </html:p>
    </variable>
    <!-- Block elements as descendants of p do not validate, so expel those. Also expel page-breaks. -->
    <sequence select="oc:expelElements( $p, 
        $p//*[matches(@class, '(^|\s)(pb|osis\-figure)(\s|$)') or matches(local-name(), '^h\d')], 
        boolean($currentTask = 'get-filenames') )"/>
  </template>
  
  <template mode="xhtml" match="reference[@subType='x-other-resource']">
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="contextFile" select="me:getFileName(.)" tunnel="yes"/>
    
    <choose>
      <when test="$FullResourceURL and $FullResourceURL != 'false'">
        <variable name="file" 
          select="me:getFileNameOfRef($preprocessedMainOSIS/descendant::div[@type='book'][last()]/@osisID)"/>
        <variable name="href" select="oc:uriToRelativePath(
            concat('/xhtml/', $contextFile), 
            concat('/xhtml/', $file, '#fullResourceURL'))"/>
        <html:a href="{$href}">
          <call-template name="class"/>
          <apply-templates mode="xhtml"/>
        </html:a>
      </when>
      <otherwise>
        <html:span>
          <call-template name="class"/>
          <apply-templates mode="xhtml"/>
        </html:span>
      </otherwise>
    </choose>
  </template>
  
  <!-- references with href are used by this transform to reference specific files --> 
  <template mode="xhtml" match="reference[@href]">
    <param name="contextFile" select="me:getFileName(.)" tunnel="yes"/>
    <variable name="href" 
        select="oc:uriToRelativePath(concat('/xhtml/', $contextFile), @href)"/>
    <html:a href="{$href}">
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </html:a>
  </template>
  
  <template mode="xhtml" match="reference">
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>
    <param name="contextFile" select="me:getFileName(.)" tunnel="yes"/>
    
    <variable name="workid" select="tokenize(@osisRef, ':')[1]"/>
    <variable name="osisRef" select="tokenize(@osisRef, ':')[2]"/>

    <!-- The isScriptureRef variable is used to get a big speedup, by not looking up the
    Scripture reference targets to get their source file. The cost is that references to
    main-OSIS file osisIDs other than $REF_BibleTop and those containing '!' will fail. -->
    <variable name="isScriptureRef" as="xs:boolean" select="@osisRef != $REF_BibleTop and 
          $preprocessedMainOSIS/osis/osisText/header/work[@osisWork = $workid]/type[@type='x-bible'] and
          not(contains(@osisRef, '!'))"/>
    <variable name="targetElement" as="element()*">
      <choose>
        <when test="$isScriptureRef or @osisRef = ($REF_BibleTop, $REF_DictTop)"/>
        <when test="$workid=$DICTMOD and $doCombineGlossaries">
          <sequence select="$combinedGlossary/descendant::*[tokenize(@osisID, ' ') = $osisRef]"/>
        </when>
        <otherwise>
          <sequence select="($preprocessedMainOSIS | $preprocessedRefOSIS)/osis/osisText[@osisRefWork = $workid]/
                            descendant-or-self::*[tokenize(@osisID, ' ') = $osisRef]"/>
        </otherwise>
      </choose>
    </variable>
    <variable name="file" as="xs:string?">
      <choose>
        <when test="not($osisRef)"/>
        <when test="$isScriptureRef">
          <value-of select="me:getFileNameOfRef(@osisRef)"/>
        </when>
        <when test="@osisRef = $REF_BibleTop">
          <value-of select="me:getFileName($preprocessedMainOSIS)"/>
        </when>
        <when test="@osisRef = $REF_DictTop">
          <value-of select="if ($doCombineGlossaries) then 
                            me:getFileName($combinedGlossary) else 
                            me:getFileName($preprocessedRefOSIS)"/>
        </when>
        <otherwise><!-- references to non-bible -->
          <choose>
            <when test="count($targetElement) = 1">
              <value-of select="me:getFileName($targetElement)"/>
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
        <when test="@osisRef = ($REF_BibleTop, $REF_DictTop)"/>
        <otherwise>  <!--other refs are to Scripture, so jump to first verse of range  -->
          <variable name="osisRefStart" select="tokenize($osisRef, '\-')[1]"/>  
          <variable name="spec" select="count(tokenize($osisRefStart, '\.'))"/>
          <variable name="verse" select="if ($spec=1) then 
                                         concat($osisRefStart, '.1.1') else 
                                        ( if ($spec=2) then 
                                          concat($osisRefStart, '.1') else 
                                          $osisRefStart )"/>
          <value-of select="oc:id($verse)"/>
        </otherwise>
      </choose>
    </variable>
    <variable name="fragment" select="if ($htmlID) then concat('#',$htmlID) else ''"/>
    <choose>
      <when test="not($file)">
        <apply-templates mode="xhtml"/>
        <call-template name="Error">
<with-param name="msg">Could not determine source file for <value-of select="string()"/> osisRef="<value-of select="@osisRef"/>"</with-param>
        </call-template>
      </when>
      <otherwise>
        <variable name="href" 
            select="oc:uriToRelativePath(
                      concat('/xhtml/', $contextFile), 
                      concat('/xhtml/', $file, $fragment))"/>
        <html:a href="{$href}">
          <call-template name="class"/>
          <apply-templates mode="xhtml"/>
        </html:a>
      </otherwise>
    </choose>
  </template>
  
  <template mode="xhtml" match="row">
    <html:tr>
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </html:tr>
  </template>
  
</stylesheet>
