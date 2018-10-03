<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/osis2xhtml"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:html="http://www.w3.org/1999/xhtml"
 xmlns:epub="http://www.idpf.org/2007/ops">
 
  <!-- TRANSFORM AN OSIS FILE INTO A SET OF CALIBRE PLUGIN INPUT XHTML FILES AND CORRESPONDING CONTENT.OPF FILE
  This transform may be tested from command line (and outputs will appear in the current directory): 
  $ saxonb-xslt -ext:on -xsl:osis2xhtml.xsl -s:main_input_osis.xml -o:content.opf
  -->
 
  <!-- Input parameters which may be passed into this XSLT -->
  <param name="css" select="'ebible.css,module.css'"/> <!-- Comma separated list of css files -->
  <param name="glossthresh" select="20"/>              <!-- Glossary inline TOCs with this number or more glossary entries will only appear by first letter in the inline TOC, unless all entries begin with the same letter.-->
  <param name="html5" select="'false'"/>               <!-- Output HTML5 markup -->
  
  <!-- Don't convert Unicode SOFT HYPHEN to "&shy;" in xhtml output files. 
  Because SOFT HYPHENs are currently being stripped out by the Calibre 
  EPUB output plugin, and they break xhtml in browsers (without first  
  defining the entity). To reinstate &shy; uncomment the following line and  
  add 'use-character-maps="xhtml-entities"' to <output name="xhtml"/> below -->
  <!-- <character-map name="xhtml-entities"><output-character character="&#xad;" string="&#38;shy;"/></character-map> !-->
  
  <!-- Each MOBI footnote must be on single line, or they will not display correctly in MOBI popups! So indent="no" is a requirement for xhtml outputs -->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="no" name="xhtml"/>
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="yes"/><!-- this default output is for the content.opf output file -->
  
  <!-- Use \toc1, \toc2 or \toc3 tags for creating the TOC -->
  <variable name="tocnumber" select="if (/descendant::*[@type='x-osis2xhtml-TOC'][1]) then /descendant::*[@type='x-osis2xhtml-TOC'][1] else 2"/>
  
  <!-- Output EPUB3 footnotes -->
  <variable name="epub3" select="if (/descendant::*[@type='x-osis2xhtml-NoEpub3Markup'][1] = 'true') then 'false' else 'true'"/>
  
  <!-- Optional URL to show for broken links -->
  <variable name="fullResourceURL" select="/descendant::*[@type='x-osis2xhtml-FullResourceURL'][1]"/>
  
  <!-- Set multipleGlossaries 'false' to combine multiple glossaries into one, or 'true' to use them as is -->
  <variable name="multipleGlossaries" select="if (/descendant::*[@type='x-osis2xhtml-MultipleGlossaries'][1] = 'true') then 'true' else 'false'"/>
  
  <!-- Set chapterFiles to 'true' to output Bible books as separate files for each chapter -->
  <variable name="chapterFiles" select="if (/descendant::*[@type='x-osis2xhtml-ChapterFiles'][1] = 'true') then 'true' else 'false'"/>
  
  <!-- Set name to use for the combined glossary -->
  <variable name="combinedGlossaryTitle" select="if (/descendant::*[@type='x-osis2xhtml-CombinedGlossaryTitle'][1]) then /descendant::*[@type='x-osis2xhtml-CombinedGlossaryTitle'][1] else //work[descendant::type[@type='x-glossary']]/title[1]"/>
  
  <!-- The main input OSIS file must contain a work element corresponding to each OSIS file referenced in the project, and all input OSIS files must reside in the same directory -->
  <variable name="referencedOsisDocs" select="//work[@osisWork != //osisText/@osisIDWork]/doc(concat(tokenize(document-uri(/), '[^/]+$')[1], @osisWork, '.xml'))"/>
  
  <!-- USFM file types output by usfm2osis.py are handled by this XSLT -->
  <variable name="usfmType" select="('front', 'introduction', 'back', 'concordance', 'glossary', 'index', 'gazetteer', 'x-other')" as="xs:string+"/>
  
  <!-- A main Table Of Contents is placed after the first TOC milestone sibling after the OSIS header, or if there isn't such a milestone, add one -->
  <variable name="mainTocMilestone" select="/descendant::milestone[@type=concat('x-usfm-toc', $tocnumber)][1][. &#60;&#60; /descendant::div[starts-with(@type,'book')][1]]"/>

  <variable name="mainInputOSIS" select="/"/>

  <!-- MAIN OSIS ROOT TEMPLATE -->
  <template match="/">
    <variable name="osisIDWork" select="/descendant::osisText[1]/@osisIDWork"/>
    
    <variable name="bibleOSIS"><!-- Do Bible preprocessing all at once for a BIG processing speedup as opposed to per-book preprocessing -->
      <variable name="markMainTocMilestone"><apply-templates select="/" mode="bibleOSIS_markMainTocMilestone"/></variable>
      <choose>
        <when test="$chapterFiles = 'true'">
          <variable name="removeSectionDivs"><apply-templates select="$markMainTocMilestone" mode="bibleOSIS_removeSectionDivs"/></variable>
          <apply-templates select="$removeSectionDivs" mode="bibleOSIS_expelChapterTags"/>
        </when>
        <otherwise><sequence select="$markMainTocMilestone"/></otherwise>
      </choose>
    </variable>
    
    <variable name="combinedGlossary">
      <variable name="combinedKeywords" select="$referencedOsisDocs//div[@type='glossary']//div[starts-with(@type, 'x-keyword')][not(@type='x-keyword-duplicate')]"/>
      <if test="$multipleGlossaries = 'false' and $combinedKeywords and count($combinedKeywords/ancestor::div[@type='glossary' and not(@subType='x-aggregate')][last()]) &#62; 1">
        <call-template name="WriteCombinedGlossary"><with-param name="combinedKeywords" select="$combinedKeywords"/></call-template>
      </if>
    </variable>
    <message select="concat('NOTE: ', if (count($combinedGlossary/*)!=0) then 'Combining' else 'Will not combine', ' keywords into a composite glossary. (multipleGlossaries=', $multipleGlossaries, ')')"/>
    
    <variable name="xhtmlFiles" as="xs:string*">
      <call-template name="processProject">
        <with-param name="currentTask" select="'get-filenames'" tunnel="yes"/>
        <with-param name="bibleOSIS" select="$bibleOSIS" tunnel="yes"></with-param>
        <with-param name="combinedGlossary" select="$combinedGlossary" tunnel="yes"/>
      </call-template>
    </variable>
    
    <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
      <metadata 
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
          xmlns:opf="http://www.idpf.org/2007/opf" 
          xmlns:dcterms="http://purl.org/dc/terms/" 
          xmlns:calibre="http://calibre.kovidgoyal.net/2009/metadata" 
          xmlns:dc="http://purl.org/dc/elements/1.1/">
        <dc:publisher><xsl:value-of select="//work[@osisWork = $osisIDWork]/publisher[@type='x-CopyrightHolder']/text()"/></dc:publisher>
        <dc:title><xsl:value-of select="//work[@osisWork = $osisIDWork]/title/text()"/></dc:title>
        <dc:language><xsl:value-of select="//work[@osisWork = $osisIDWork]/language/text()"/></dc:language>
        <dc:identifier scheme="ISBN"><xsl:value-of select="//work[@osisWork = $osisIDWork]/identifier[@type='ISBN']/text()"/></dc:identifier>
        <dc:creator opf:role="aut"><xsl:value-of select="//work[@osisWork = $osisIDWork]/publisher[@type='x-CopyrightHolder']/text()"/></dc:creator>
      </metadata>
      <manifest>
        <xsl:for-each select="$xhtmlFiles"><item href="xhtml/{.}.xhtml" id="{me:id(.)}" media-type="application/xhtml+xml"/></xsl:for-each>
        <xsl:for-each select="distinct-values((//figure/@src, $referencedOsisDocs//figure/@src))">
          <item>
            <xsl:attribute name="href" select="if (starts-with(., './')) then substring(., 3) else ."/>
            <xsl:attribute name="id" select="me:id(tokenize(., '/')[last()])"/>
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
            <xsl:when test="ends-with(lower-case(.), 'css')">
              <item href="{if (starts-with(., './')) then substring(., 3) else .}" id="{me:id(.)}" media-type="text/css"/>
            </xsl:when>
            <xsl:when test="ends-with(lower-case(.), 'ttf')">
              <item href="{if (starts-with(., './')) then substring(., 3) else .}" id="{me:id(.)}" media-type="application/x-font-ttf"/>
            </xsl:when>
            <xsl:when test="ends-with(lower-case(.), 'otf')">
              <item href="{if (starts-with(., './')) then substring(., 3) else .}" id="{me:id(.)}" media-type="application/vnd.ms-opentype"/>
            </xsl:when>
            <xsl:otherwise><xsl:message>ERROR: Unrecognized type of CSS file:"<xsl:value-of select="."/>"</xsl:message></xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </manifest>
      <spine toc="ncx"><xsl:for-each select="$xhtmlFiles"><itemref idref="{me:id(.)}"/></xsl:for-each></spine>
    </package>
    
    <call-template name="processProject">
      <with-param name="currentTask" select="'write-xhtml'" tunnel="yes"/>
      <with-param name="bibleOSIS" select="$bibleOSIS" tunnel="yes"></with-param>
      <with-param name="combinedGlossary" select="$combinedGlossary" tunnel="yes"></with-param>
    </call-template>
    
  </template>
  
  <template name="processProject">
    <param name="currentTask" tunnel="yes"/>
    <param name="bibleOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    <message><value-of select="concat('processProject: currentTask = ', $currentTask, ', combinedGlossary = ', boolean(count($combinedGlossary/*)!=0))"/></message>
    <for-each select="$bibleOSIS"><apply-templates/></for-each>
    <apply-templates select="$combinedGlossary/*"/>
    <for-each select="$referencedOsisDocs"><apply-templates/></for-each>
  </template>
  
  <!-- Write a single glossary that combines all other glossaries together. Note: x-keyword-duplicate entries are dropped because they are included in the x-aggregate glossary -->
  <template name="WriteCombinedGlossary">
    <param name="combinedKeywords" as="element(div)+"/>
    <element name="div" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"><attribute name="type" select="'glossary'"/><attribute name="root-name" select="'comb'"/>
      <milestone type="{concat('x-usfm-toc', $tocnumber)}" n="[level1]{$combinedGlossaryTitle}" xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"/>
      <title type="main" xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"><xsl:value-of select="$combinedGlossaryTitle"/></title>
      <for-each select="$combinedKeywords">
        <sort select="me:langSortOrder(.//seg[@type='keyword'][1]/string(), root(.)//description[@type='x-sword-config-LangSortOrder'][ancestor::work/@osisWork = root(.)/descendant::osisText[1]/@osisIDWork])" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
        <copy-of select="."/>
      </for-each>
    </element>
  </template>
  <function name="me:langSortOrder" as="xs:string">
    <param name="text" as="xs:string"/>
    <param name="order" as="xs:string?"/>
    <if test="$order">
      <value-of>
        <for-each select="string-to-codepoints($text)">
          <choose>
            <when test="matches(codepoints-to-string(.), '[ \p{L}]')">
              <variable name="before" select="substring-before(concat('⇹ ', $order), codepoints-to-string(.))"/>
              <if test="not($before)"><message select="$text"/><message terminate="yes">ERROR: langSortOrder(): Cannot sort aggregate glossary entry '<value-of select="$text"/>'; 'LangSortOrder=<value-of select="$order"/>' is missing the character <value-of select="concat('&quot;', codepoints-to-string(.), '&quot; (codepoint: ', ., ')')"/>.</message></if>
              <value-of select="codepoints-to-string(string-length($before) + 64)"/> <!-- 64 starts at character "A" -->
            </when>
            <otherwise><value-of select="codepoints-to-string(.)"/></otherwise>
          </choose>
        </for-each>
      </value-of>
    </if>
    <if test="not($order)">
      <message>WARNING: langSortOrder(): 'LangSortOrder' is not specified in config.conf. Glossary entries will be ordered in Unicode order.</message>
      <value-of select="$text"/>
    </if>
  </function>
  
  <!-- Bible preprocessing templates to speed up processing that requires node copying/modification -->
  <template match="node()|@*" mode="bibleOSIS_markMainTocMilestone bibleOSIS_removeSectionDivs bibleOSIS_expelChapterTags">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  <template match="milestone[@type=concat('x-usfm-toc', $tocnumber)][generate-id() = generate-id($mainTocMilestone)]" mode="bibleOSIS_markMainTocMilestone">
    <copy><attribute name="isMainTocMilestone" select="'true'"/><for-each select="@*"><copy-of select="."/></for-each></copy>
  </template>
  <template match="div[ends-with(lower-case(@type), 'section')]" mode="bibleOSIS_removeSectionDivs">
    <apply-templates mode="bibleOSIS_removeSectionDivs"/>
  </template>
  <template match="*[parent::div[@type='book']]" mode="bibleOSIS_expelChapterTags">
    <variable name="book" select="parent::*/@osisID"/>
    <variable name="expel" select="descendant::chapter[starts-with(@sID, concat($book, '.'))]"/>
    <choose>
      <when test="not($expel)"><copy-of select="."/></when>
      <otherwise>
        <message>NOTE: Container contains a chapter milestone: <value-of select="me:printNode(.)"/></message>
        <sequence select="me:expelElements(., $expel, false())"/>
      </otherwise>
    </choose>
  </template>
  
  <!-- THE OSIS FILE IS SEPARATED INTO INDIVIDUAL XHTML FILES BY THE FOLLOWING TEMPLATES WITH ProcessFile-->
  <template match="node()"><apply-templates/></template>
  <template match="div[@type='glossary'][@subType='x-aggregate']" priority="3"/>
  
  <template match="osisText">
    <call-template name="ProcessFile"><with-param name="fileNodes" select="node()[not(
        self::header or 
        self::div[starts-with(@type, 'book')] or 
        self::div[@type=$usfmType][ancestor::osisText[last()]/@osisIDWork != $mainInputOSIS/osis[1]/osisText[1]/@osisIDWork]
    )]"/></call-template>
    <apply-templates/>
  </template>
  
  <template match="div[@type='bookGroup']">
    <call-template name="ProcessFile"><with-param name="fileNodes" select="node()[not(self::div[@type='book'])]"/></call-template>
    <apply-templates/>
  </template>
  
  <template match="div[@type='book'] | div[@type=$usfmType][ancestor::osisText[last()]/@osisIDWork != $mainInputOSIS/osis[1]/osisText[1]/@osisIDWork]">
    <choose>
      <when test="self::div[@type='book'] and $chapterFiles = 'true'">
        <variable name="book" select="@osisID"/>
        <for-each-group select="node()" group-adjacent="count(preceding::chapter[starts-with(@sID, concat($book, '.'))]) + count(descendant-or-self::chapter[starts-with(@sID, concat($book, '.'))])">
          <call-template name="ProcessFile"><with-param name="fileNodes" select="current-group()"/></call-template>
        </for-each-group>
      </when>
      <otherwise>
        <call-template name="ProcessFile"><with-param name="fileNodes" select="node()"/></call-template>
      </otherwise>
    </choose>
  </template>
  
  <template match="div[@type='glossary'][@root-name='comb' or ancestor::osisText[last()]/@osisIDWork != $mainInputOSIS/osis[1]/osisText[1]/@osisIDWork]" priority="2">
    <param name="currentTask" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    <!-- Put each keyword in a separate file to ensure that links and article tags all work properly across various eBook readers -->
    <for-each-group select="node()" group-adjacent="0.5 + count(preceding::div[starts-with(@type, 'x-keyword')]) + 0.5*count(self::div[starts-with(@type, 'x-keyword')])">
      <choose>
        <when test="not(count($combinedGlossary/*)) or ancestor::div[@root-name]">
          <call-template name="ProcessFile"><with-param name="fileNodes" select="current-group()"/></call-template>
        </when>
        <when test="$currentTask != 'write-xhtml' or self::div[starts-with(@type, 'x-keyword')] or not(current-group()[node()][normalize-space()][1])"/><!-- Don't warn unless necessary -->
        <otherwise>
          <message><text>&#xa;</text><value-of select="concat('WARNING: The combined glossary is dropping ', count(current-group()), ' node(s) containing: ')"/>
            <for-each select="current-group()//text()[normalize-space()]"><text>&#xa;</text><value-of select="me:printNode(.)"/><text>&#xa;</text></for-each>
          </message>
        </otherwise>
      </choose>
    </for-each-group>
  </template>
  
  <!-- ProcessFile may be called with any element that should initiate a new output file above. It writes the file's contents and adds it to manifest and spine -->
  <template name="ProcessFile">
    <param name="fileNodes" as="node()*"/>
    <!-- A currentTask param is used in lieu of XSLT's mode feature here. This is necessary because identical template selectors are required for multiple 
    modes (ie. a single template element should handle multiple modes), yet template content must also vary by mode (something XSLT 2.0 modes alone can't do) -->
    <param name="currentTask" tunnel="yes"/>
    
    <variable name="fileName" select="me:getFileName(.)"/>
    <variable name="fileXHTML"><apply-templates mode="xhtml" select="$fileNodes"/></variable>
    <!-- Unless the resulting xhtml file contains some text or images, the file will be dropped -->
    <variable name="keepXHTML" select="boolean($fileXHTML/descendant::text()[normalize-space()] or $fileXHTML/descendant::*[local-name()='img'])"/>
    <choose>
      <when test="$keepXHTML">
        <choose>
          <when test="$currentTask = 'get-filenames'"><value-of select="$fileName"/></when>
          <otherwise>
            <variable name="fileNotes"><call-template name="noteSections"><with-param name="nodes" select="$fileNodes"/></call-template></variable>
            <call-template name="WriteFile">
              <with-param name="fileName" select="$fileName"/>
              <with-param name="topElement" select="$fileNodes[1]/parent::*"/>
              <with-param name="fileXHTML" select="$fileXHTML"/>
              <with-param name="fileNotes" select="$fileNotes"/>
            </call-template>
          </otherwise>
        </choose>
      </when>
      <when test="$currentTask = 'get-filenames'">
        <variable name="dropping" select="$fileXHTML/descendant::node()[not(self::text()) or self::text()[normalize-space()]]"/>
        <if test="$dropping"><message>WARNING: dropping file containing: <for-each select="$dropping"><value-of select="me:printNode(.)"/>, </for-each></message></if>
      </when>
    </choose>
  </template>
  
  <!-- This template may be called from any node. It returns the output file name that contains the node -->
  <function name="me:getFileName" as="xs:string">
    <param name="node" as="node()"/>
    <variable name="root" select="if ($node/ancestor-or-self::osisText) then $node/ancestor-or-self::osisText[last()]/@osisIDWork else $node/ancestor-or-self::*[@root-name]/@root-name"/>
    <variable name="isBibleNode" select="$root = $mainInputOSIS/osis[1]/osisText[1]/@osisIDWork"/>
    <variable name="refUsfmType" select="$node/ancestor-or-self::div[@type=$usfmType][last()]"/>
    <variable name="book" select="$node/ancestor-or-self::div[@type='book'][last()]/@osisID"/>
    <choose>
      <when test="$book">
        <variable name="chapter" select="if ($chapterFiles = 'true') then 
            concat('/ch', count($node/preceding::chapter[starts-with(@sID, concat($book, '.'))]) + count($node/descendant-or-self::chapter[starts-with(@sID, concat($book, '.'))]))
            else ''"/>
        <value-of select="concat($root, '_', $book, $chapter)"/>
      </when>
      <when test="$node/ancestor-or-self::div[@type='bookGroup'][last()]">
        <value-of select="concat($root, '_bookGroup-introduction_bg', count($node/preceding::div[@type='bookGroup']) + 1)"/>
      </when>
      <when test="not($isBibleNode) and $node/ancestor-or-self::div[@type='glossary']">
        <variable name="group" select="0.5 + count($node/preceding::div[starts-with(@type, 'x-keyword')]) + 0.5*count($node/ancestor-or-self::div[starts-with(@type, 'x-keyword')][1])"/>
        <value-of select="if ($root = 'comb') then 
            concat($root, '_glossary', '/', 'k', $group) else 
            concat($root, '_glossary', '/', 'p', me:hashUsfmType($refUsfmType), '_k', $group)"/>
      </when>
      <when test="not($isBibleNode) and $refUsfmType">
        <value-of select="concat($root, '_', $refUsfmType/@type, '/', 'p', me:hashUsfmType($refUsfmType))"/>
      </when>
      <otherwise><value-of select="concat($root, '_module-introduction')"/></otherwise>
    </choose>
  </function>
  <function name="me:getGlossaryName" as="xs:string">
    <param name="glossary" as="element(div)"/>
    <value-of select="$glossary/(descendant::title[@type='main'][1] | descendant::milestone[@type=concat('x-usfm-toc', $tocnumber)][1]/@n)[1]"/>
  </function>
  <function name="me:hashUsfmType" as="xs:string">
    <param name="usfmType" as="element(div)"/>
    <variable name="title" select="me:getGlossaryName($usfmType)"/>
    <if test="$title"><value-of select="sum(string-to-codepoints(string($title)))"/></if>
    <if test="not($title)"><value-of select="count($usfmType/preceding::div[@type=$usfmType/@type]) + 1"/></if>
  </function>
  
  <!-- This template may be called with a Bible osisRef string. It returns the output file name that contains the Bible reference -->
  <function name="me:getFileNameOfRef" as="xs:string">
    <param name="osisRef" as="xs:string"/>
    <variable name="work" select="$mainInputOSIS/osis[1]/osisText[1]/@osisIDWork"/>
    <if test="contains($osisRef, ':') and not(starts-with($osisRef, concat($work, ':')))">
      <message>ERROR: Bible reference <value-of select="$osisRef"/> targets a work other than <value-of select="$work"/></message>
    </if>
    <variable name="osisRef2" select="replace($osisRef, '^[^:]*:', '')" as="xs:string"/>
    <value-of select="concat($work, '_', tokenize($osisRef2, '\.')[1], (if ($chapterFiles = 'true') then concat('/ch', tokenize($osisRef2, '\.')[2]) else ''))"/>
  </function>
  
  <!-- Write each xhtml file's contents -->
  <template name="WriteFile">
    <param name="fileName" as="xs:string"/>
    <param name="topElement" as="element()"/>
    <param name="fileXHTML" as="node()+"/>
    <param name="fileNotes" as="node()*"/>
    <variable name="isBibleNode" select="$topElement/ancestor-or-self::osisText[last]/@osisIDWork = $mainInputOSIS/osis[1]/osisText[1]/@osisIDWork"/>
    <message select="concat('writing:', $fileName)"/>
    <result-document format="xhtml" method="xml" href="xhtml/{$fileName}.xhtml">
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta name="generator" content="OSIS"/>
          <title><xsl:value-of select="$fileName"/></title>
          <meta http-equiv="Default-Style" content="text/html; charset=utf-8"/>
          <xsl:for-each select="tokenize($css, '\s*,\s*')">
            <xsl:if test="ends-with(lower-case(.), 'css')"><link href="{me:uri-to-relative($topElement, .)}" type="text/css" rel="stylesheet"/></xsl:if>
          </xsl:for-each>
        </head>
        <body>
          <xsl:attribute name="class" select="normalize-space(string-join(distinct-values(
              ('calibre', $topElement/ancestor-or-self::*[@scope][1]/@scope, for $x in tokenize($fileName, '[_/]') return $x, $topElement/@type, $topElement/@subType)), ' '))"/>
          <!-- If our main OSIS file doesn't have a main TOC milestone, add one -->
          <if test="not($mainTocMilestone) and $isBibleNode and $topElement[preceding::node()[normalize-space()][not(ancestor::header)][1][self::header]]" 
              xmlns="http://www.w3.org/1999/XSL/Transform">
            <variable name="title"><osis:title type="main"><value-of select="//osis:work[child::osis:type[@type='x-bible']][1]/title[1]"/></osis:title></variable>
            <apply-templates select="$title" mode="xhtml"/>
            <call-template name="getMainInlineTOC"/>
          </if>
          <xsl:sequence select="$fileXHTML"/>
          <xsl:sequence select="$fileNotes"/>
          <!-- If there are links to fullResourceURL then add a crossref section at the end of the first book, to show that URL -->
          <xsl:if test="$fullResourceURL and $topElement[self::div[@type='book'][@osisID = $mainInputOSIS/descendant::div[@type='book'][1]/@osisID]]">
            <div class="xsl-crossref-section">
              <hr/>          
              <div id="fullResourceURL" class="xsl-crossref">
                <xsl:if test="$epub3 = 'true'"><xsl:attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'footnote'"/></xsl:if>
                <span class="xsl-note-head xsl-crnote-symbol">+</span><xsl:value-of select="' '"/>
                <xsl:if test="starts-with($fullResourceURL, 'http')"><a href="{$fullResourceURL}"><xsl:value-of select="$fullResourceURL"/></a></xsl:if>
                <xsl:if test="not(starts-with($fullResourceURL, 'http'))"><xsl:value-of select="$fullResourceURL"/></xsl:if>
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
    <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-footnote-section">
      <hr/>
      <xsl:apply-templates mode="footnotes" select="$nodes"/>
    </div>
    <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-crossref-section">
      <hr/>
      <xsl:apply-templates mode="crossrefs" select="$nodes"/>
    </div>
  </template>
              
  <template match="node()" mode="footnotes crossrefs"><apply-templates mode="#current"/></template>
  <template match="note[not(@type) or @type != 'crossReference']" mode="footnotes">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <div xmlns="http://www.w3.org/1999/xhtml" id="{me:id($osisIDid)}" class="xsl-footnote">
      <xsl:if test="$epub3 = 'true'"><xsl:attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'footnote'"/></xsl:if>
      <a href="#textsym.{me:id($osisIDid)}">
        <xsl:call-template name="getFootnoteSymbol"><xsl:with-param name="classes" select="normalize-space(string-join((me:getClasses(.), 'xsl-note-head'), ' '))"/></xsl:call-template>
      </a>
      <xsl:value-of select="' '"/>
      <xsl:apply-templates mode="xhtml"/>
    </div>
    <text>&#xa;</text><!-- this newline is only for better HTML file formatting -->
  </template>
  <template match="note[@type='crossReference']" mode="crossrefs">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <div xmlns="http://www.w3.org/1999/xhtml" id="{me:id($osisIDid)}" class="xsl-crossref">
      <xsl:if test="$epub3 = 'true'"><xsl:attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'footnote'"/></xsl:if>
      <a href="#textsym.{me:id($osisIDid)}">
        <xsl:call-template name="getFootnoteSymbol"><xsl:with-param name="classes" select="normalize-space(string-join((me:getClasses(.), 'xsl-note-head'), ' '))"/></xsl:call-template>
      </a>
      <xsl:value-of select="' '"/>
      <xsl:apply-templates mode="xhtml"/>
    </div>
    <text>&#xa;</text><!-- this newline is only for better HTML file formatting -->
  </template>
  
  <!-- This template may be called from any note. It returns a symbol or number based on that note's type and context -->
  <template name="getFootnoteSymbol">
    <param name="classes" select="''"/>
    <variable name="inVerse" select="preceding::verse[1]/@sID = following::verse[1]/@eID or preceding::verse[1]/@sID = descendant::verse[1]/@eID or count(ancestor::title[@canonical='true'])"/>
    <choose>
      <when test="$inVerse and not(@type='crossReference')"><attribute name="class" select="string-join(($classes, 'xsl-fnote-symbol'), ' ')"/>*</when>
      <when test="$inVerse and @subType='x-parallel-passage'"><attribute name="class" select="string-join(($classes, 'xsl-crnote-symbol'), ' ')"/>⚫</when>
      <when test="$inVerse"><attribute name="class" select="string-join(($classes, 'xsl-crnote-symbol'), ' ')"/>+</when>
      <otherwise><attribute name="class" select="string-join(($classes, 'xsl-note-number'), ' ')"/>[<xsl:call-template name="getFootnoteNumber"/>]</otherwise>
    </choose>
  </template>
  
  <!-- This template may be called from any note. It returns the number of that note within its output file -->
  <template name="getFootnoteNumber">
    <choose>
      <when test="ancestor::div[@type=$usfmType]">
        <choose>
          <when test="not(descendant-or-self::seg[@type='keyword']) and count(preceding::seg[@type='keyword']) = count(ancestor::div[@type=$usfmType][1]/preceding::seg[@type='keyword'])">
            <value-of select="count(preceding::note) - count(ancestor::div[@type=$usfmType][1]/preceding::note) + 1"/>
          </when>
          <otherwise>
            <value-of select="count(preceding::note) - count(preceding::seg[@type='keyword'][1]/preceding::note) + 1"/>
          </otherwise>
        </choose>
      </when>
      <when test="ancestor::div[@type='book']">
        <value-of select="count(preceding::note) - count(ancestor::div[@type='book'][1]/preceding::note) + 1"/>
      </when>
      <when test="ancestor::div[@type='bookGroup']">
        <value-of select="count(preceding::note) - count(ancestor::div[@type='bookGroup'][1]/preceding::note) + 1"/>
      </when>
      <when test="ancestor::osisText">
        <value-of select="count(preceding::note) + 1"/>
      </when>
    </choose>    
  </template>
  
  <!-- Table of Contents
  There are two TOCs: 1) the standard eBook TOC, and 2) the inline TOC which appears inline with the text as a series of links.
  The following OSIS elements, by default, will generate both a standard TOC and an inline TOC entry:
      milestone[@type='x-usfm-tocN'] (from USFM \tocN tags, where N corresponds to this XSLT's $tocnumber param) - The TOC entry name normally comes from the "n" attribute value
      chapter[@sID] (from USFM \c tags) - The TOC entry name normally comes from a following title[@type='x-chapterLabel'] (USFM \cl or \cp) element
      seg[@type='keyword'] (from USFM \k ...\k* tags) - The TOC entry name normally comes from the child text nodes
      
  By default, TOC hierarchy is determined from OSIS hierarchy. However an explicit TOC level and/or explicit title may be specified for any entry.
  An explicit title can be specified using the "n" attribute, which may also be prepended with special bracketted INSTRUCTIONS.
  EXAMPLE: <milestone type="x-usfm-toc2" n="[level1][no_inline_toc]My Title"/>.
  
  The recognized INSTRUCTIONS which may appear at the beginning of the "n" attribute value of any TOC generating element are:
  [levelN] where N is 1, 2 or 3, to specify the TOC level.
  [no_toc] means no entry for this element should appear in any TOC (neither standard nor inline TOC)
  [no_inline_toc] means no entry for this should appear in the inline TOC (but will appear in the stardard TOC) 
  [not_parent] means this book or bookGroup TOC element is the first sibling of the following books or chapters, not the parent (parent is default).
  Any TEXT following these instructions will be used for the TOC entry name, overriding the default name -->
  <template name="getMainInlineTOC">
    <param name="combinedGlossary" tunnel="yes"/>
    <variable name="listElements">
      <sequence select="me:getTocListItems(root(.), true(), false())"/>
      <if test="count($combinedGlossary/*)"><sequence select="me:getTocListItems($combinedGlossary, true(), true())"/></if>
      <for-each select="$referencedOsisDocs"><sequence select="me:getTocListItems(., true(), count($combinedGlossary/*) != 0)"/></for-each>
    </variable>
    <if test="count($listElements/*)">
      <element name="div" namespace="http://www.w3.org/1999/xhtml">
        <attribute name="id" select="'root-toc'"/>
        <sequence select="me:getInlineTocDiv($listElements, 'ol', true())"/>
      </element>
    </if>
  </template>
  
  <function name="me:getInlineTOC" as="element(html:div)*">
    <param name="tocElement" as="element()"/>
    <variable name="listElements"><sequence select="me:getTocListItems($tocElement, false(), false())"/></variable>
    <if test="count($listElements/*)"><sequence select="me:getInlineTocDiv($listElements, if ($tocElement/ancestor::div[@type='book']) then 'ul' else 'ol', false())"/></if>
  </function>
  
  <function name="me:getInlineTocDiv" as="element(html:div)">
    <param name="listElements"/>
    <param name="listType"/>
    <param name="isMainTOC"/>
    <!-- Inline TOCs by default display as lists of inline-block links all sharing equal width, which may occupy the full width of the page. 
    The two exceptions are: Bible book lists which are limited to three columns, and the main Toc menu, which is broken into three sub-sections:
    1) introduction links 2) Bible book links, and 3) back material links, and these sections of the Main TOC each display links differently:
    Introduction: Display in two columns; if there are an odd number of intro links, the first row is a single, centered link.
    Book: Display as a single column unless there are two testament links, or one testament and more than 4 book links, or more than 5 book links (which are then displayed in two columns).
    Back: Display in two columns; if there is an odd number of Bible book links displayed as two columns, then the first back material row is a single centered link. -->
    <variable name="BookIsTwoColumns" select="count($listElements/*[@class='xsl-bookGroup-link']) = 2 or count($listElements/*[starts-with(@class, 'xsl-book')]) &#62; 5"/>
    <variable name="hasOddNumberOfIntros" select="count($listElements/*[not(starts-with(@class, 'xsl-book'))][not(preceding::*[starts-with(@class, 'xsl-book')])]) mod 2 = 1"/>
    <variable name="hasOddNumberOf2ColBooks" select="$BookIsTwoColumns and count($listElements/*[starts-with(@class, 'xsl-book')]) mod 2 = 1"/>
    <variable name="twoColumnElements" select="$listElements/*[$BookIsTwoColumns or not(starts-with(@class, 'xsl-book'))]"/>
    <variable name="oneColumnElements" select="$listElements/* except $twoColumnElements"/>
    <variable name="chars" select="if ($isMainTOC) then max(($twoColumnElements/string-length(string()), $oneColumnElements/(string-length(string())*0.5))) else max($listElements/string-length(string()))"/>
    <variable name="maxChars" select="if ($chars &#62; 32) then 32 else $chars"/>
    <element name="div" namespace="http://www.w3.org/1999/xhtml">
      <attribute name="class">xsl-inline-toc
        <if test="not($BookIsTwoColumns)"> xsl-one-book-column</if>
        <if test="$hasOddNumberOfIntros"> xsl-odd-intros</if>
        <if test="$hasOddNumberOf2ColBooks"> xsl-odd-2col-books</if>
      </attribute>
      <element name="div" namespace="http://www.w3.org/1999/xhtml"><!-- this div allows margin auto to center, which doesn't work with ul/ol -->
        <choose>
          <!-- limit main TOC width, because li width is specified as % in css -->
          <when test="$isMainTOC">
            <!-- ebible.css 2 column is: 100% = 6px + 12px + maxChars + 12px + 6px + 12px + maxChars + 12px + 6px , so: max-width of parent at 100% = 66px + 2*maxChars (but need fudge since ch, based on '0', isn't determinative)-->
            <attribute name="style" select="concat('max-width:calc(66px + ', (2.5*$maxChars), 'ch)')"/>
          </when>
          <!-- limit TOCs containing book names to three columns -->
          <when test="$listElements/*[@class = 'xsl-book-link']">
            <attribute name="style" select="concat('max-width:calc(84px + ', (4.2*$maxChars), 'ch)')"/><!-- 3.5*(calc(24px + 1.2*$maxChars)) from below -->
          </when>
        </choose>
        <element name="{$listType}" namespace="http://www.w3.org/1999/xhtml">
          <sequence select="$listElements"/>
        </element>
      </element>
    </element>
  </function>
  
  <function name="me:getTocListItems" as="element(html:li)*">
    <param name="tocNode" as="node()"/>
    <param name="isOsisRootTOC" as="xs:boolean"/>
    <param name="keepOnlyCombinedGlossary" as="xs:boolean"/>
    <variable name="isBible" select="root($tocNode)//work[@osisWork = ancestor::osisText/@osisIDWork]/type[@type='x-bible']"/>
    <if test="not($isOsisRootTOC) and not($tocNode[self::milestone[@type=concat('x-usfm-toc', $tocnumber)] or (not($isBible) and self::chapter[@sID])])">
      <message terminate="yes">ERROR: getTocListItems(): Not a TOC milestone or non-Bible chapter element: <value-of select="me:printNode($tocNode)"/></message>
    </if>
    <variable name="toplevel" select="if ($isOsisRootTOC) then 0 else me:getTocLevel($tocNode)"/>
    <if test="$toplevel &#60; 3 and not(matches($tocNode/@n, '^(\[[^\]+]\])*\[not_parent\]'))">
      <variable name="subentries" as="element()*">
        <choose>
          <when test="$tocNode/self::chapter[@sID]">
            <sequence select="($tocNode/following::seg[@type='keyword'] | $tocNode/following::milestone[@type=concat('x-usfm-toc', $tocnumber)]) except 
                $tocNode/following::chapter[@eID][@eID = $tocNode/@sID]/following::*"/>
          </when>
          <otherwise>
            <variable name="container" as="node()?" select="if ($isOsisRootTOC) then (root($tocNode)) else
                if ($tocNode/parent::div[not(preceding-sibling::*)][not(@type = ('bookGroup', 'book'))][parent::div[@type = ('bookGroup', 'book')]]) 
                then $tocNode/parent::div/parent::div 
                else $tocNode/ancestor::div[1]"/>
            <!-- select all contained toc elements, excluding: $tocNode, sub-sub-toc elements, x-aggregate div elements, keywords & glossary-toc-milestones outside the combined glossary if keepOnlyCombinedGlossary -->
            <sequence select="($container//chapter[@sID] | $container//seg[@type='keyword'] | $container//milestone[@type=concat('x-usfm-toc', $tocnumber)])
                [generate-id(.) != generate-id($tocNode)][me:getTocLevel(.) = $toplevel + 1][not(ancestor::div[@type='glossary'][@subType='x-aggregate'])]
                [not($isOsisRootTOC and $mainTocMilestone and @isMainTocMilestone = 'true')][not($isOsisRootTOC and ancestor::div[@type='glossary'][@scope=('NAVMENU','INT')])]
                [not($keepOnlyCombinedGlossary and ancestor::div[@type='glossary'][not(@root-name)])]"/>
          </otherwise>
        </choose>
      </variable>
      <if test="count($subentries)">
        <variable name="showFullGloss" select="$isBible or (count($subentries[@type='keyword']) &#60; $glossthresh) or 
            count(distinct-values($subentries[@type='keyword']/upper-case(substring(text(), 1, 1)))) = 1"/>
        <variable name="tmptitles" as="element(me:tmp)*"><!-- tmptitles is used to generate all titles before writing any of them, so that we can get the max length first -->
          <for-each select="$subentries">
            <variable name="previousKeyword" select="preceding::seg[@type='keyword'][1]/string()"/>
            <variable name="skipKeyword">
              <choose>
                <when test="matches(@n, '^(\[[^\]]*\])*\[(no_inline_toc|no_toc)\]')"><value-of select="true()"/></when>
                <when test="boolean($showFullGloss) or not(self::seg[@type='keyword']) or not($previousKeyword)"><value-of select="false()"/></when>
                <otherwise><value-of select="boolean(substring(text(), 1, 1) = substring($previousKeyword, 1, 1))"/></otherwise>
              </choose>
            </variable>
            <if test="$skipKeyword = false()">
              <me:tmp source="{generate-id(.)}">
                <choose>
                  <when test="self::chapter[@osisID]"><value-of select="tokenize(@osisID, '\.')[last()]"/></when>
                  <when test="boolean($showFullGloss)=false() and self::seg[@type='keyword']"><value-of select="upper-case(substring(text(), 1, 1))"/></when>
                  <otherwise><value-of select="me:getTocTitle(.)"/></otherwise>
                </choose>
              </me:tmp>
            </if>
          </for-each>
        </variable>
        <variable name="chars" select="max($tmptitles/string-length(string()))"/><variable name="maxChars" select="if ($chars &#62; 32) then 32 else $chars"/>
        <for-each select="root($tocNode)//node()[generate-id(.) = $tmptitles/@source]">
          <variable name="entryType" select="if (matches(./@n, '^(\[[^\]+]\])*\[not_parent\]')) then 'introduction' else ./(ancestor::div[@type=('book', 'bookGroup')][1] | ancestor::div[@type=$usfmType][1])[1]/@type" as="xs:string?"/>
          <li xmlns="http://www.w3.org/1999/xhtml">
            <xsl:attribute name="class" select="concat('xsl-', if (self::chapter) then 'chapter' else if (self::seg) then 'keyword' else if ($entryType) then $entryType else 'introduction', '-link')"/>
            <xsl:if test="not($isOsisRootTOC)"><xsl:attribute name="style" select="concat('width:calc(24px + ', (1.2*$maxChars), 'ch)')"/></xsl:if>
            <a><xsl:attribute name="href" select="me:uri-to-relative($tocNode, concat('/xhtml/', me:getFileName(.), '.xhtml#', generate-id(.)))"/>
              <xsl:value-of select="$tmptitles[@source = generate-id(current())]/string()"/>
            </a>
          </li>
        </for-each>
      </if>
    </if>
  </function>
  
  <!-- me:getTocAttributes returns attribute nodes for a TOC element -->
  <function name="me:getTocAttributes" as="attribute()+">
    <param name="tocElement" as="element()"/>
    <if test="not($tocElement[self::milestone[@type=concat('x-usfm-toc', $tocnumber)] or self::chapter[@sID] or self::seg[@type='keyword']])">
      <message terminate="yes">ERROR: getTocAttributes(): Not a TOC element: <value-of select="me:printNode($tocElement)"/></message>
    </if>
    <attribute name="id" select="generate-id($tocElement)"/>
    <attribute name="class" select="normalize-space(string-join(('xsl-toc-entry', me:getClasses($tocElement)), ' '))"/>
    <if test="not(matches($tocElement/@n, '^(\[[^\]]*\])*\[no_toc\]'))">
      <attribute name="title" select="concat('toclevel-', me:getTocLevel($tocElement))"/>
    </if>
  </function>
  
  <!-- me:getTocTitle returns the title text of tocElement -->
  <function name="me:getTocTitle" as="xs:string">
    <param name="tocElement" as="element()"/>
    <if test="not($tocElement[self::milestone[@type=concat('x-usfm-toc', $tocnumber)] or self::chapter[@sID] or self::seg[@type='keyword']])">
      <message terminate="yes">ERROR: getTocTitle(): Not a TOC element: <value-of select="me:printNode($tocElement)"/></message>
    </if>
    <variable name="tocTitleEXPLICIT" select="if (matches($tocElement/@n, '^(\[[^\]]*\])+')) then replace($tocElement/@n, '^(\[[^\]]*\])+', '') else if ($tocElement/@n) then $tocElement/@n else ''"/>
    <variable name="tocTitleOSIS">
      <choose>
        <when test="$tocElement/self::milestone[@type=concat('x-usfm-toc', $tocnumber) and @n]"><value-of select="$tocElement/@n"/></when>
        <when test="$tocElement/self::chapter[@sID]">
          <choose>
            <when test="$tocElement/following::title[@type='x-chapterLabel'][1][following::chapter[1][@eID=$tocElement/@sID]]">
              <value-of select="string($tocElement/following::title[@type='x-chapterLabel'][1][following::chapter[1][@eID=$tocElement/@sID]])"/>
            </when>
            <otherwise><value-of select="tokenize($tocElement/@sID, '\.')[last()]"/></otherwise>
          </choose>
        </when>
        <when test="$tocElement/self::seg[@type='keyword']"><value-of select="$tocElement"/></when>
        <otherwise>
          <variable name="errtitle" select="concat($tocElement/name(), ' ', count($tocElement/preceding::*[name()=$tocElement/name()]))"/>
          <value-of select="$errtitle"/>
          <message>ERROR: Could not determine TOC title of "<value-of select="$errtitle"/>"</message>
        </otherwise>
      </choose>
    </variable>
    <value-of select="if ($tocTitleEXPLICIT = '') then $tocTitleOSIS else $tocTitleEXPLICIT"/>
  </function>
  
  <!-- getTocLevel returns an integer which is the TOC hierarchy level of tocElement -->
  <function name="me:getTocLevel" as="xs:integer">
    <param name="tocElement" as="element()"/>
    <variable name="isBible" select="root($tocElement)//work[@osisWork = ancestor::osisText/@osisIDWork]/type[@type='x-bible']"/>
    <if test="not($tocElement[self::milestone[@type=concat('x-usfm-toc', $tocnumber)] or self::chapter[@sID] or self::seg[@type='keyword']])">
      <message terminate="yes">ERROR: getTocLevel(): Not a TOC element: <value-of select="me:printNode($tocElement)"/></message>
    </if>
    <variable name="toclevelEXPLICIT" select="if (matches($tocElement/@n, '^(\[[^\]]*\])*\[level(\d)\].*$')) then replace($tocElement/@n, '^(\[[^\]]*\])*\[level(\d)\].*$', '$2') else '0'"/>
    <variable name="toclevelOSIS">
      <variable name="parentTocNodes" select="if ($isBible) then me:getBibleParentTocNodes($tocElement) else me:getGlossParentTocNodes($tocElement)"/>
      <choose>
        <when test="$parentTocNodes[generate-id(.) = generate-id($tocElement)]"><value-of select="count($parentTocNodes)"/></when>
        <when test="$tocElement[self::seg[@type='keyword'] | self::chapter[@sID] | self::milestone[@type=concat('x-usfm-toc', $tocnumber)]]"><value-of select="1 + count($parentTocNodes)"/></when>
        <otherwise><value-of select="1"/></otherwise>
      </choose>
    </variable>
    <value-of select="if ($toclevelEXPLICIT = '0') then $toclevelOSIS else $toclevelEXPLICIT"/>
  </function>
  
  <!-- getBibleParentTocNodes may be called with any element -->
  <function name="me:getBibleParentTocNodes" as="element(milestone)*">
    <param name="x" as="element()"/>
    <!-- A bookGroup or book div is a TOC parent if it has a TOC milestone child (that isn't n="[not_parent]...) or a first child div, which isn't a bookGroup or book, that has one. 
    Any other div is also a TOC parent if it contains a TOC milestone child which isn't already a bookGroup/book TOC entry. -->
    <sequence select="$x/ancestor-or-self::div[@type = ('bookGroup', 'book')]/milestone[@type=concat('x-usfm-toc', $tocnumber)][not(matches(@n, '^(\[[^\]+]\])*\[not_parent\]'))][1] |
        $x/ancestor-or-self::div[@type = ('bookGroup', 'book')][not(child::milestone[@type=concat('x-usfm-toc', $tocnumber)])]/*[1][self::div][not(@type = ('bookGroup', 'book'))]/milestone[@type=concat('x-usfm-toc', $tocnumber)][not(matches(@n, '^(\[[^\]+]\])*\[not_parent\]'))][1] |
        $x/ancestor-or-self::div/milestone[@type=concat('x-usfm-toc', $tocnumber)][not(matches(@n, '^(\[[^\]+]\])*\[not_parent\]'))][1]"/>
  </function>
  
  <!-- getGlossParentTocNodes may be called from any element -->
  <function name="me:getGlossParentTocNodes" as="element()*">
    <param name="x" as="element()"/>
    <!-- A chapter is always a TOC parent, and so is any div in the usfmType if it has one or more toc milestone children OR else it has a non-div first child with one or more toc milestone children.
    The first such toc milestone descendant determines the div's TOC entry name; any following such children will be TOC sub-entries of the first. -->
    <sequence select="$x/ancestor::div/milestone[@type=concat('x-usfm-toc', $tocnumber)] | $x/ancestor::div/*[1][not(div)]/milestone[@type=concat('x-usfm-toc', $tocnumber)] | 
        $x/preceding::chapter[@sID][not(@sID = $x/preceding::chapter/@eID)]"/>
  </function>
  
  <!-- This template may be called from any element. It adds a class attribute according to tag, level, type, subType and class -->
  <template name="class"><attribute name="class" select="me:getClasses(.)"/></template>
  <function name="me:getClasses" as="xs:string">
    <param name="x" as="element()"/>
    <variable name="levelClass" select="if ($x/@level) then concat('level-', $x/@level) else ''"/>
    <variable name="osisTagClass" select="concat('osis-', $x/local-name())"/>
    <value-of select="normalize-space(string-join(($osisTagClass, $x/@type, $x/@subType, $x/@class, $levelClass), ' '))"/>
  </function>
  
  <!-- This template may be called from: p, l, item and canonical title. It writes chapter numbers if the calling element should contain an embedded chapter number -->
  <template name="WriteEmbededChapter">
    <variable name="isInVerse" select="preceding::verse[1]/@sID = following::verse[1]/@eID or preceding::verse[1]/@sID = descendant::verse[1]/@eID"/>
    <if test="$isInVerse and preceding::chapter[@sID][1][generate-id(following::*[self::p or self::l or self::item or self::title[@canonical='true']][1]) = generate-id(current())]">
      <span xmlns="http://www.w3.org/1999/xhtml" class="xsl-chapter-number"><xsl:value-of select="tokenize(preceding::chapter[@sID][1]/@osisID, '\.')[last()]"/></span>
    </if>
  </template>
  
  <!-- This template may be called from: p, l, item and canonical title. It writes verse numbers if the calling element should contain an embedded verse number -->
  <template name="WriteEmbededVerse">
    <variable name="isInVerse" select="preceding::verse[1]/@sID = following::verse[1]/@eID or preceding::verse[1]/@sID = descendant::verse[1]/@eID"/>
    <if test="$isInVerse">
      <!-- Write any verse -->
      <if test="self::*[
          preceding-sibling::*[1][self::verse[@sID]] | 
          self::l[parent::lg[generate-id(child::l[1]) = generate-id(current())][preceding-sibling::*[1][self::verse[@sID]]]] |
          self::item[parent::list[generate-id(child::item[1]) = generate-id(current())][preceding-sibling::*[1][self::verse[@sID]]]]
      ]">
        <call-template name="WriteVerseNumber"/>
      </if>
      <!-- Write any alternate verse -->
      <for-each select="
          self::*/preceding-sibling::*[1][self::hi[@subType='x-alternate']] | 
          self::l/parent::lg[generate-id(child::l[1]) = generate-id(current())]/preceding-sibling::*[1][self::hi[@subType='x-alternate']] |
          self::item/parent::list[generate-id(child::l[1]) = generate-id(current())]/preceding-sibling::*[1][self::hi[@subType='x-alternate']]">
        <apply-templates select="." mode="xhtml"><with-param name="doWrite" select="true()" tunnel="yes"/></apply-templates>
      </for-each>
    </if>
  </template>
  
  <!-- This template may be called from: p and l. -->
  <template name="WriteVerseNumber">
    <variable name="osisID" select="if (@osisID) then @osisID else preceding::*[@osisID][1]/@osisID"/>
    <variable name="first" select="tokenize($osisID, '\s+')[1]"/>
    <variable name="last" select="tokenize($osisID, '\s+')[last()]"/>
    <for-each select="tokenize($osisID, '\s+')">
      <span xmlns="http://www.w3.org/1999/xhtml"><xsl:attribute name="id" select="concat('v_', .)"/></span>
    </for-each>
    <sup xmlns="http://www.w3.org/1999/xhtml" class="xsl-verse-number">
      <xsl:value-of select="if ($first=$last) then tokenize($first, '\.')[last()] else concat(tokenize($first, '\.')[last()], '-', tokenize($last, '\.')[last()])"/>
    </sup>
  </template>
  

  <!-- THE FOLLOWING TEMPLATES CONVERT OSIS INTO XHTML MARKUP AS DESIRED -->
  <!-- By default, text is copied -->
  <template match="text()" mode="xhtml"><copy/></template>
  
  <!-- By default, attributes are dropped -->
  <template match="@*" mode="xhtml"/>
  
  <!-- By default, elements get their namespace changed from OSIS to XHTML, and a class attribute is added-->
  <template match="*" mode="xhtml">
    <element name="{local-name()}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml" select="node()|@*"/>
    </element>
  </template>
  
  <!-- Remove these elements entirely (x-chapterLabel is handled by me:getTocTitle())-->
  <template match="verse[@eID] | chapter[@eID] | index | milestone | title[@type='x-chapterLabel'] | title[@type='runningHead']" mode="xhtml"/>
  
  <!-- Remove these tags (keeping their content) -->
  <template match="name | seg | reference[ancestor::title[@type='scope']]" mode="xhtml">
    <apply-templates mode="xhtml"/>
  </template>
  
  <!-- Verses -->
  <template match="verse[@sID] | hi[@subType='x-alternate']" mode="xhtml" priority="3">
    <param name="doWrite" tunnel="yes"/>
    <!-- skip verse numbers immediately followed by p, lg, l, list, item or canonical title, since their templates will write verse numbers inside themselves using WriteEmbededVerse-->
    <if test="$doWrite or not(self::*[following-sibling::*[1][self::p or self::lg or self::l or self::list or self::item or self::title[@canonical='true']]])">
      <next-match/>
    </if>
  </template>
  <template match="verse[@sID]" mode="xhtml"><call-template name="WriteVerseNumber"/></template>
  
  <!-- Chapters -->
  <template match="chapter[@sID and @osisID]" mode="xhtml">
    <variable name="chapterLabel" select="following::title[@type='x-chapterLabel'][1][following::chapter[1][@eID=current()/@sID]]"/>
    <h1 xmlns="http://www.w3.org/1999/xhtml">
      <xsl:sequence select="me:getTocAttributes(.)"/>
      <!-- x-chapterLabel titles may contain other elements such as footnotes which need to be output -->
      <choose xmlns="http://www.w3.org/1999/XSL/Transform">
        <when test="$chapterLabel">
          <for-each select="$chapterLabel"><apply-templates mode="xhtml"/></for-each>
        </when>
        <otherwise><value-of select="me:getTocTitle(.)"/></otherwise>
      </choose>
    </h1>
    <!-- non-Bible chapters also get inline TOC (Bible trees do not have a document-node due to preprocessing) -->
    <if test="ancestor::osisText[last()]/@osisIDWork != $mainInputOSIS/osis[1]/osisText[1]/@osisIDWork">
      <h1 class="xsl-nonBibleChapterLabel" xmlns="http://www.w3.org/1999/xhtml"><xsl:value-of select="me:getTocTitle(.)"/></h1>
      <sequence select="me:getInlineTOC(.)"/>
    </if>
  </template>
  
  <!-- Glossary keywords -->
  <template match="seg[@type='keyword']" mode="xhtml" priority="2">
    <param name="combinedGlossary" tunnel="yes"/>
    <span id="{me:id(replace(replace(@osisID, '^[^:]*:', ''), '!', '_'))}" xmlns="http://www.w3.org/1999/xhtml"></span>
    <dfn xmlns="http://www.w3.org/1999/xhtml"><xsl:sequence select="me:getTocAttributes(.)"/><xsl:value-of select="me:getTocTitle(.)"/></dfn>
    <variable name="glossaryTitle" select="me:getGlossaryName($referencedOsisDocs//div[@type='glossary'][descendant::*[@osisID = current()/@osisID]][1])" as="xs:string"/>
    <if test="@osisID and count($combinedGlossary/*) != 0 and $glossaryTitle">
      <variable name="osisTitle"><osis:title level="3" subType="x-glossary-title"><value-of select="$glossaryTitle"/></osis:title></variable>
      <for-each select="$osisTitle"><apply-templates select="." mode="xhtml"/></for-each>
    </if>
  </template>
  
  <!-- Titles -->
  <template match="title" mode="xhtml">
    <variable name="tocms" select="preceding::milestone[@type=concat('x-usfm-toc', $tocnumber)][1]" as="element(milestone)?"/>
    <!-- Skip those titles which have already been output by TOC milestone. The following variables must be identical those in the TOC milestone template -->
    <variable name="title" select="$tocms/following::text()[normalize-space()][not(ancestor::title[@type='runningHead'])][not(ancestor::*[@subType='x-navmenu'])][1]/
        ancestor::title[@type='main' and not(@canonical='true')][1]" as="element(title)?"/>
    <variable name="titles" select="$title | $title/following::title[@type='main' and not(@canonical='true')][if ($title[@level]) then @level else not(@level)]
        [. &#60;&#60; $title/following::node()[normalize-space()][not(ancestor-or-self::title[@type='main' and not(@canonical='true')][if ($title[@level]) then @level else not(@level)])][1]]" as="element(title)*"/>
    <if test="not($tocms) or not($titles[generate-id() = generate-id(current())])"><call-template name="title"/></if>
  </template>
  <template name="title">
    <element name="h{if (@level) then @level else '1'}" namespace="http://www.w3.org/1999/xhtml">
      <xsl:call-template name="class"/>
      <xsl:if test="@canonical='true'"><xsl:call-template name="WriteEmbededChapter"/><xsl:call-template name="WriteEmbededVerse"/></xsl:if>
      <xsl:apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <!-- Parallel passage titles become secondary titles !-->
  <template match="title[@type='parallel']" mode="xhtml">
    <h2 xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></h2>
  </template>
  
  <!-- OSIS elements which will become spans with a special class !-->
  <template match="catchWord | foreign | hi | rdg | transChange | signed" mode="xhtml">
    <span xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></span>
  </template>
  
  <template match="cell" mode="xhtml">
    <td xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml"/></td>
  </template>
  
  <template match="caption" mode="xhtml">
    <element name="{if ($html5 = 'true') then 'figcaption' else 'div'}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/><apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <template match="div[@type='introduction']" mode="xhtml">
    <next-match/>
    <hr xmlns="http://www.w3.org/1999/xhtml"/>
  </template>
  
  <template match="figure" mode="xhtml">
    <element name="{if ($html5 = 'true') then 'figure' else 'div'}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <img xmlns="http://www.w3.org/1999/xhtml">
        <xsl:attribute name="src"><xsl:value-of select="me:uri-to-relative(., @src)"/></xsl:attribute>
        <xsl:attribute name="alt" select="@src"/>
      </img>
      <xsl:apply-templates mode="xhtml"/>
    </element>
  </template>

  <template match="head" mode="xhtml">
    <h2 xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></h2>
  </template>
  
  <template match="item" mode="xhtml">
    <li xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapter"/><xsl:call-template name="WriteEmbededVerse"/><xsl:apply-templates mode="xhtml"/></li>
  </template>
  
  <template match="lb" mode="xhtml">
    <br xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/></br>
  </template>
  
  <!-- usfm2osis.py follows the OSIS manual recommendation for selah as a line element which differs from the USFM recommendation for selah.
  According to USFM 2.4 spec, selah is: "A character style. This text is frequently right aligned, and rendered on the same line as the previous poetic text..." !-->
  <template match="l" mode="xhtml">
    <choose>
      <when test="@type = 'selah'"/>
      <when test="following-sibling::l[1][@type='selah']">
        <div xmlns="http://www.w3.org/1999/xhtml">
          <xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapter"/><xsl:call-template name="WriteEmbededVerse"/><xsl:apply-templates mode="xhtml"/>
          <i class="xsl-selah">
            <xsl:for-each select="following-sibling::l[@type='selah']
                [count(preceding-sibling::l[@type='selah'][. &#62;&#62; current()]) = count(preceding-sibling::l[. &#62;&#62; current()])]">
              <xsl:text> </xsl:text><xsl:apply-templates select="child::node()" mode="xhtml"/>
            </xsl:for-each>
          </i>
        </div>
      </when>
      <otherwise>
        <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapter"/><xsl:call-template name="WriteEmbededVerse"/><xsl:apply-templates mode="xhtml"/></div>
      </otherwise>
    </choose>
  </template>
  
  <template match="lg" mode="xhtml">
    <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></div>
  </template>
  
  <template match="list" mode="xhtml">
    <param name="currentTask" tunnel="yes"/>
    <variable name="ul" as="element(html:ul)">
      <ul xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></ul>
    </variable>
    <sequence select="me:expelElements($ul, $ul/*[contains(@class, 'osis-head')], boolean($currentTask='get-filenames'))"/><!-- OSIS allows list to contain head children, but EPUB2 validator doesn't allow <h> child tags of ul -->
  </template>
  
  <template match="list[@subType='x-navmenu'][following-sibling::*[1][self::chapter[@eID]]]" mode="xhtml">
    <if test="$chapterFiles = 'true'"><next-match/></if>
  </template>
  
  <template match="milestone[@type=concat('x-usfm-toc', $tocnumber)]" mode="xhtml" priority="2">
    <!-- The <div><small> was chosen because milestone TOC text is hidden by CSS, and non-CSS implementations should have this text de-emphasized since it is not part of the orignal book -->
    <div xmlns="http://www.w3.org/1999/xhtml"><xsl:sequence select="me:getTocAttributes(.)"/><small><i><xsl:value-of select="me:getTocTitle(.)"/></i></small></div>
    <variable name="tocms" select="."/>
    <!-- Move main titles above the inline TOC. The following variable and for-each selection must be identical to those in the title template. -->
    <variable name="title" select="$tocms/following::text()[normalize-space()][not(ancestor::title[@type='runningHead'])][not(ancestor::*[@subType='x-navmenu'])][1]/
        ancestor::title[@type='main' and not(@canonical='true')][1]" as="element(title)?"/>
    <for-each select="$title | $title/following::title[@type='main' and not(@canonical='true')][if ($title[@level]) then @level else not(@level)]
        [. &#60;&#60; $title/following::node()[normalize-space()][not(ancestor-or-self::title[@type='main' and not(@canonical='true')][if ($title[@level]) then @level else not(@level)])][1]]">
      <call-template name="title"/>
    </for-each>
    <!-- if this is the first milestone in a Bible, then include the root TOC -->
    <if test="@isMainTocMilestone = 'true'"><call-template name="getMainInlineTOC"/></if>
    <sequence select="me:getInlineTOC(.)"/>
  </template>
  
  <template match="milestone[@type='pb']" mode="xhtml" priority="2">
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></p>
  </template>
  
  <template match="note" mode="xhtml">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <sup xmlns="http://www.w3.org/1999/xhtml">
      <a href="#{me:id($osisIDid)}" id="textsym.{me:id($osisIDid)}">
        <xsl:if test="$epub3 = 'true'"><xsl:attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'noteref'"/></xsl:if>
        <xsl:call-template name="getFootnoteSymbol"><xsl:with-param name="classes" select="me:getClasses(.)"/></xsl:call-template>
      </a>
    </sup>
  </template>
  
  <template match="p" mode="xhtml">
    <param name="currentTask" tunnel="yes"/>
    <variable name="p" as="element(html:p)">
      <p xmlns="http://www.w3.org/1999/xhtml">
        <xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapter"/><xsl:call-template name="WriteEmbededVerse"/><xsl:apply-templates mode="xhtml"/>
      </p>
    </variable>
    <!-- Block elements as descendants of p do not validate, so expel those. Also expel page-breaks. -->
    <sequence select="me:expelElements($p, $p//*[matches(@class, '(^|\s)(pb|osis\-figure)(\s|$)') or matches(local-name(), '^h\d')], boolean($currentTask='get-filenames'))"/>
  </template>
  
  <template match="reference[@subType='x-other-resource']" mode="xhtml">
    <choose>
      <when test="$fullResourceURL">
        <variable name="file" select="concat('/xhtml/', me:getFileNameOfRef($mainInputOSIS/descendant::div[@type='book'][1]/@osisID), '.xhtml')"/>
        <a xmlns="http://www.w3.org/1999/xhtml" href="{me:uri-to-relative(., concat($file, '#fullResourceURL'))}"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></a>
      </when>
      <otherwise>
        <span xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></span>
      </otherwise>
    </choose>
  </template>
  
  <template match="reference" mode="xhtml">
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="bibleOSIS" tunnel="yes"/>
    <variable name="osisRef1" select="replace(@osisRef, '^[^:]*:', '')"/>
    <variable name="osisRef" select="if (count($combinedGlossary/*)) then replace($osisRef1, '\.dup\d+', '') else $osisRef1"/>
    <!-- change navmenu introduction links to getIntroFile -->
    <variable name="isIntroReference" select="self::reference[@type='x-glosslink'][ancestor::item[@subType='x-introduction-link']]"/>
    <variable name="file">
      <variable name="workid" select="if (contains(@osisRef, ':')) then tokenize(@osisRef, ':')[1] else ancestor::osisText/@osisRefWork"/>
      <variable name="refIsBible" select="$mainInputOSIS/osis[1]/osisText[1]/header[1]/work[@osisWork = $workid]/type[@type='x-bible']"/>
      <choose>
        <when test="$isIntroReference"><value-of select="me:getIntroFile($bibleOSIS)"/></when>
        <when test="$refIsBible"><value-of select="concat('/xhtml/', me:getFileNameOfRef(@osisRef), '.xhtml')"/></when>
        <otherwise><!-- references to non-bible -->
          <variable name="target" as="node()?">
            <choose>
              <when test="count($combinedGlossary/*)"><sequence select="$combinedGlossary//*[tokenize(@osisID, ' ') = $osisRef]"/></when>
              <otherwise><sequence select="($bibleOSIS | $referencedOsisDocs)/osis/osisText[@osisRefWork = $workid]//*[tokenize(@osisID, ' ') = $osisRef]"/></otherwise>
            </choose>
          </variable>
          <choose>
            <when test="count($target)=0"><message>ERROR: workID="<value-of select="$workid"/>" and target osisID not found for: <value-of select="me:printNode(.)"/></message></when>
            <when test="count($target)=1"><value-of select="concat('/xhtml/', me:getFileName($target), '.xhtml')"/></when>
            <otherwise>
              <message>ERROR: Multiple targets with same osisID (<value-of select="count($target)"/>): osisID="<value-of select="$osisRef"/>", workID="<value-of select="$workid"/>"</message>
            </otherwise>
          </choose>
        </otherwise>
      </choose>
    </variable>
    <variable name="osisRefid" select="replace($osisRef, '!', '_')"/>
    <variable name="osisRefA">
      <choose>
        <when test="$isIntroReference"/>
        <when test="starts-with(@type, 'x-gloss') or contains(@osisRef, '!')"><value-of select="me:id($osisRefid)"/></when>  <!-- refs containing "!" point to a specific note -->
        <otherwise>  <!--other refs are to Scripture, so jump to first verse of range  -->
          <variable name="osisRefStart" select="tokenize($osisRefid, '\-')[1]"/>  
          <variable name="spec" select="count(tokenize($osisRefStart, '\.'))"/>
          <value-of select="'v_'"/>
          <value-of select="if ($spec=1) then concat($osisRefStart, '.1.1') else (if ($spec=2) then concat($osisRefStart, '.1') else $osisRefStart)"/>
        </otherwise>
      </choose>
    </variable>
    <variable name="href" select="me:uri-to-relative(., concat($file, '#', $osisRefA))"/>
    <a xmlns="http://www.w3.org/1999/xhtml" href="{$href}"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></a>
  </template>
  
  <template match="row" mode="xhtml">
    <tr xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></tr>
  </template>
  
  <!-- xml:id must start with a letter or underscore, and can only contain letters, digits, underscores, hyphens, and periods. -->
  <function name="me:id" as="xs:string">
    <param name="s"/>
    <value-of select="replace(replace($s, '^([^\p{L}_])', 'x$1'), '[^\p{L}\d_\-\.]', '-')"/>
  </function>
  
  <function name="me:getIntroFile" as="xs:string">
    <param name="bibleOSIS"/>
    <value-of select="concat('/xhtml/', me:getFileName($bibleOSIS/descendant::text()[normalize-space()][not(ancestor::header)][1]), '.xhtml')"/>
  </function>
  
  <!-- Use this function if an xhtml element must not contain other elements (for EPUB2 etc. validation). 
  Any element in $expel becomes a sibling of the container $element, which is divided and copied accordingly. -->
  <function name="me:expelElements">
    <param name="element" as="element()"/>
    <param name="expel" as="element()*"/>
    <param name="quiet" as="xs:boolean"/>
    <choose>
      <when test="count($expel) = 0"><sequence select="$element"/></when>
      <otherwise>
        <variable name="pass1">
          <for-each-group select="$element" group-by="for $i in ./descendant-or-self::node() 
              return 2*count($i/preceding::node()[generate-id(.) = $expel/generate-id()]) + count($i/ancestor-or-self::node()[generate-id(.) = $expel/generate-id()])">
            <apply-templates select="current-group()" mode="weed1">
              <with-param name="expel" select="$expel" tunnel="yes"/>
            </apply-templates>
          </for-each-group>
        </variable>
        <variable name="pass2"><apply-templates select="$pass1" mode="weed2"/></variable><!-- pass2 to insures id attributes are not duplicated and removes empty generated elements -->
        <if test="not($quiet) and count($element/node())+1 != count($pass2/node())"><message>NOTE: expelling: <value-of select="me:printNode($expel)"/></message></if>
        <sequence select="$pass2"/>
      </otherwise>
    </choose>
  </function>
  <template mode="weed1" match="@*"><copy/></template>
  <template mode="weed1" match="node()">
    <param name="expel" as="element()+" tunnel="yes"/>
    <variable name="nodesInGroup" select="descendant-or-self::node()[me:expelGroupingKey(., $expel) = current-grouping-key()]" as="node()*"/>
    <variable name="expelElement" select="$nodesInGroup/ancestor-or-self::*[generate-id(.) = $expel/generate-id()][1]" as="element()?"/>
    <if test="$nodesInGroup"><!-- drop the context node if it has no descendants or self in the current group -->
      <choose>
        <when test="$expelElement and descendant::*[generate-id(.) = generate-id($expelElement)]"><apply-templates mode="weed1"/></when>
        <otherwise>
          <copy>
            <if test="child::node()[normalize-space()]"><attribute name="container"/></if><!-- used to remove empty generated containers in pass2 -->
            <if test="current-grouping-key() &#62; me:expelGroupingKey(descendant::*[generate-id(.) = $expel/generate-id()][1], $expel)">
              <attribute name="class" select="'continuation'"/>
            </if>
            <apply-templates select="node()|@*" mode="weed1"/>
          </copy>
        </otherwise>
      </choose>
    </if>
  </template>
  <function name="me:expelGroupingKey" as="xs:integer">
    <param name="node" as="node()?"/>
    <param name="expel" as="element()+"/>
    <value-of select="2*count($node/preceding::node()[generate-id(.) = $expel/generate-id()]) + count($node/ancestor-or-self::node()[generate-id(.) = $expel/generate-id()])"/>
  </function>
  <template mode="weed2" match="node()|@*"><copy><apply-templates select="node()|@*" mode="weed2"/></copy></template>
  <template mode="weed2" match="@container | *[@container and not(child::node()[normalize-space()])]"/>
  <template mode="weed2" match="@id"><if test="not(preceding::*[@id = current()][not(@container and not(child::node()[normalize-space()]))])"><copy/></if></template>
  
  <function name="me:printNode" as="text()">
    <param name="node" as="node()"/>
    <choose>
      <when test="$node[self::element()]">
        <value-of>element <value-of select="$node/name()"/><for-each select="$node/@*"><value-of select="concat(' ', name(), '=&#34;', ., '&#34;')"/></for-each></value-of>
      </when>
      <when test="$node[self::text()]"><value-of select="concat('text-node:', $node)"/></when>
      <when test="$node[self::comment()]"><value-of select="concat('comment-node:', $node)"/></when>
      <when test="$node[self::attribute()]"><value-of select="concat('attribute-node:', name($node), ' = ', $node)"/></when>
      <when test="$node[self::document-node()]"><value-of select="concat('document-node:', $node)"/></when>
      <when test="$node[self::processing-instruction()]"><value-of select="concat('processing-instruction:', $node)"/></when>
      <otherwise><value-of select="concat('other?:', $node)"/></otherwise>
    </choose>
  </function>
  
  <!-- tr:uri-to-relative-path ($base-uri, $rel-uri) this function converts a URI to a relative path using another URI directory as base reference. -->
  <function name="me:uri-to-relative-path" as="xs:string">
    <param name="base-uri-file" as="xs:string"/> <!-- the URI reference (file or directory) -->
    <param name="rel-uri-file" as="xs:string"/>  <!-- the URI to be converted to a relative path (file or directory) -->
    <variable name="base-uri" select="replace(replace($base-uri-file, '^([^/])', '/$1'), '/[^/]*$', '')"/> <!-- base now begins and ends with '/' or is just '/' -->
    <variable name="rel-uri" select="replace(replace($rel-uri-file, '^\.+', ''), '^([^/])', '/$1')"/> <!-- any '.'s at the start of rel are IGNORED, and rel now starts with '/' -->
    <variable name="tkn-base-uri" select="tokenize($base-uri, '/')" as="xs:string+"/>
    <variable name="tkn-rel-uri" select="tokenize($rel-uri, '/')" as="xs:string+"/>
    <variable name="uri-parts-max" select="max((count($tkn-base-uri), count($tkn-rel-uri)))" as="xs:integer"/>
    <!--  count equal URI parts with same index -->
    <variable name="uri-equal-parts" select="for $i in (1 to $uri-parts-max) 
      return $i[$tkn-base-uri[$i] eq $tkn-rel-uri[$i]]" as="xs:integer*"/>
    <choose>
      <!--  both URIs must share the same URI scheme -->
      <when test="$uri-equal-parts[1] eq 1">
        <!-- drop directories that have equal names but are not physically equal, e.g. their value should correspond to the index in the sequence -->
        <variable name="dir-count-common" select="max(
          for $i in $uri-equal-parts 
          return $i[index-of($uri-equal-parts, $i) eq $i]
          )" as="xs:integer"/>
        <!-- difference from common to URI parts to common URI parts -->
        <variable name="delta-base-uri" select="count($tkn-base-uri) - $dir-count-common" as="xs:integer"/>
        <variable name="delta-rel-uri" select="count($tkn-rel-uri) - $dir-count-common" as="xs:integer"/>    
        <variable name="relative-path" select="
          concat(
          (: dot or dot-dot :) if ($delta-base-uri) then string-join(for $i in (1 to $delta-base-uri) return '../', '') else './',
          (: path parts :) string-join(for $i in (($dir-count-common + 1) to count($tkn-rel-uri)) return $tkn-rel-uri[$i], '/')
          )" as="xs:string"/>
        <choose>
          <when test="starts-with($rel-uri, concat($base-uri, '#'))"><value-of select="concat('#', tokenize($rel-uri, '#')[last()])"/></when>
          <otherwise><value-of select="$relative-path"/></otherwise>
        </choose>
      </when>
      <!-- if both URIs share no equal part (e.g. for the reason of different URI scheme names) then it's not possible to create a relative path. -->
      <otherwise>
        <value-of select="$rel-uri"/>
        <message>ERROR: Indeterminate path:"<xsl:value-of select="$rel-uri"/>" is not relative to "<xsl:value-of select="$base-uri"/>"</message>
      </otherwise>
    </choose>
  </function>
  <function name="me:uri-to-relative" as="xs:string">
    <param name="base-node" as="node()"/>   <!-- node's file path is the base -->
    <param name="rel-uri" as="xs:string"/>  <!-- the URI to be converted to a relative path -->
    <value-of select="me:uri-to-relative-path(concat('/xhtml/', me:getFileName($base-node), '.xhtml'), $rel-uri)"/>
  </function>
  
</stylesheet>
