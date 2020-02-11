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
 xmlns:epub="http://www.idpf.org/2007/ops">
  <!--
  
  OSIS TO HTML 
  A main OSIS file and an optional dictionary OSIS file are 
  transformed into: 
  
    content.opf       - A manifest of generated and referenced files.
                        This includes html, css, font and image files.
                        
    xhtml/files.xhtml - Each book, section, chapter (if ChapterFiles is
                        'true') and keyword are written to separate
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
      
  <!-- Glossary inline TOCs with this number or more glossary entries will only appear 
       by first letter in the inline TOC (unless all entries begin with the same letter). -->
  <param name="glossthresh" select="oc:sarg('glossthresh', /, '20')"/>  

  <!-- Osis-converters config entries used by this transform -->
  <param name="DEBUG" select="oc:csys('DEBUG', /)"/>
  <param name="TOC" select="oc:conf('TOC', /)"/>
  <param name="TitleCase" select="oc:conf('TitleCase', /)"/>
  <param name="NoEpub3Markup" select="oc:conf('NoEpub3Markup', /)"/>
  <param name="FullResourceURL" select="oc:conf('FullResourceURL', /)"/><!-- '' or 'false' turns this feature off -->
  <param name="ChapterFiles" select="oc:conf('ChapterFiles', /)"/>
  <param name="CombineGlossaries" select="oc:conf('CombineGlossaries', /)"/><!-- 'AUTO', 'true' or 'false' -->
  <param name="CombinedGlossaryTitle" select="oc:conf('CombinedGlossaryTitle', /)"/>
  <param name="mainTocMaxBackChars" select="xs:integer(number(oc:sarg('mainTocMaxBackChars', /, '18')))"/><!-- is ARG_mainTocMaxBackChars in config.conf -->
  
  <variable name="isChildrensBible" select="boolean(/osis:osis/osis:osisText/osis:header/
                                            osis:work[@osisWork=/osis:osis/osis:osisText/@osisIDWork]/
                                            osis:type[@type='x-childrens-bible'])"/>
  
  <!-- The main input OSIS file must contain a work element corresponding to each 
     OSIS file referenced in the project. But osis-converters supports a single 
     dictionary OSIS file only, which contains all reference material. -->
  <variable name="referenceOSIS" select="if ($isChildrensBible) then () else //work[@osisWork != //osisText/@osisIDWork]/
                                         doc(concat(tokenize(document-uri(/), '[^/]+$')[1], @osisWork, '.xml'))"/>
  
  <!-- This must be identical to the combinedKeywords variable of navigationMenu.xsl, 
  or else navmenu prev/next could end up with broken links -->
  <variable name="combinedKeywords" select="$referenceOSIS//div[@type='glossary']//div[starts-with(@type, 'x-keyword')]
                                                [not(@type = 'x-keyword-duplicate')]
                                                [not(ancestor::div[@scope='NAVMENU'])]
                                                [not(ancestor::div[@annotateType='x-feature'][@annotateRef='INT'])]"/>

  <variable name="doCombineGlossaries" select="if ($CombineGlossaries = 'AUTO') then 
          (if ($referenceOSIS//div[@type='glossary'][@subType='x-aggregate']) then true() else false()) 
          else $CombineGlossaries = 'true' "/>
  
  <!-- All USFM file types output by CrossWire's usfm2osis.py are handled by this XSLT -->
  <variable name="usfmType" select="('front', 'introduction', 'back', 'concordance', 
      'glossary', 'index', 'gazetteer', 'x-other')" as="xs:string+"/>
  
  <!-- A main inline Table Of Contents is placed after the first TOC milestone sibling 
       following the OSIS header, or, if there isn't such a milestone, one will be created. -->
  <variable name="mainTocMilestone" select="if (not($isChildrensBible)) then 
      /descendant::milestone[@type=concat('x-usfm-toc', $TOC)][not(contains(@n, '[no_toc]'))][1]
      [. &#60;&#60; /descendant::div[starts-with(@type,'book')][1]] else
      /descendant::milestone[@type=concat('x-usfm-toc', $TOC)][not(contains(@n, '[no_toc]'))][1]"/>

  <variable name="mainInputOSIS" select="/"/>
  <variable name="mainWORK" select="$mainInputOSIS/osis[1]/osisText[1]/@osisIDWork"/>
  <variable name="dictWORK" select="$referenceOSIS[1]/osis[1]/osisText[1]/@osisIDWork"/>
  
  <!-- Don't convert Unicode SOFT HYPHEN to "&shy;" in xhtml output files. 
  Because SOFT HYPHENs are currently being stripped out by the Calibre 
  EPUB output plugin, and they break xhtml in browsers (without first  
  defining the entity). To reinstate &shy; uncomment the following line and  
  add 'use-character-maps="xhtml-entities"' to <output name="xhtml"/> below -->
  <!-- <character-map name="xhtml-entities"><output-character character="&#xad;" string="&#38;shy;"/></character-map> !-->
  
  <!-- Each MOBI footnote must be on single line, or they will not display correctly in MOBI popups! 
  Therefore indent="no" is a requirement for xhtml outputs. -->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="no" name="xhtml"/>
  
  <!-- The following default output is for the content.opf output file -->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="yes"/>

  <!-- MAIN OSIS ROOT TEMPLATE -->
  <template match="/">

    <!-- Do pre-processing for a BIG processing speedup -->
    <variable name="preprocessedOSIS">
      <variable name="markMainTocMilestone">
        <apply-templates mode="preprocess_markMainTocMilestone" select="/"/>
      </variable>
      <choose>
        <when test="$ChapterFiles = 'true' or $isChildrensBible">
          <variable name="removeSectionDivs">
            <apply-templates mode="preprocess_removeSectionDivs" select="$markMainTocMilestone"/>
          </variable>
          <apply-templates mode="preprocess_expelChapterTags" select="$removeSectionDivs"/>
        </when>
        <otherwise><sequence select="$markMainTocMilestone"/></otherwise>
      </choose>
    </variable>
    
    <!-- The combined glossary includes navmenu letter menus if available, but remove the  
    leading dashes so they will become the first item in each letter list -->
    <variable name="navmenu" as="element(div)*">
      <for-each select="$referenceOSIS//div[@subType=('x-navmenu-letter', 'x-navmenu-atoz')]">
        <apply-templates mode="removeLeadingDashes" select="."/>
      </for-each>
    </variable>
    <!-- The x-aggregate glossary is never output directly, rather it is added to the  
    combined glossary whenever it is used, and therefore x-keyword-duplicate keywords are   
    NOT included in the combined glossary. This means that links to x-keyword-duplicate 
    keywords need to be redirected to their aggregated entries by the 'reference' template. -->
    <variable name="combinedGlossary">
      <if test="$doCombineGlossaries">
        <call-template name="WriteCombinedGlossary">
          <with-param name="combinedKeywords" select="$combinedKeywords | $navmenu"/>
        </call-template>
      </if>
    </variable>
    
    <variable name="xhtmlFiles" as="xs:string*">
      <!-- processProject must be run twice: once to return file names and a second time
      to write the files. Trying to do both at once results in the following error:
      XTDE1480: Cannot switch to a final result destination while writing a temporary tree -->
      <call-template name="processProject">
        <with-param name="currentTask" select="'get-filenames'" tunnel="yes"/>
        <with-param name="preprocessedOSIS" select="$preprocessedOSIS" tunnel="yes"/>
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
        <dc:publisher>
          <xsl:value-of select="//work[@osisWork = $mainWORK]/publisher[@type='x-CopyrightHolder']/text()"/>
        </dc:publisher>
        <dc:title>
          <xsl:value-of select="//work[@osisWork = $mainWORK]/title/text()"/>
        </dc:title>
        <dc:language>
          <xsl:value-of select="//work[@osisWork = $mainWORK]/language/text()"/>
        </dc:language>
        <dc:identifier scheme="ISBN">
          <xsl:value-of select="//work[@osisWork = $mainWORK]/identifier[@type='ISBN']/text()"/>
        </dc:identifier>
        <dc:creator opf:role="aut">
          <xsl:value-of select="//work[@osisWork = $mainWORK]/publisher[@type='x-CopyrightHolder']/text()"/>
        </dc:creator>
      </metadata>
      <manifest>
        <xsl:for-each select="$xhtmlFiles">
          <item href="xhtml/{.}.xhtml" id="{me:id(.)}" media-type="application/xhtml+xml"/>
        </xsl:for-each>
        <xsl:for-each select="distinct-values((//figure/@src, $referenceOSIS//figure/@src))">
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
            <!-- In the manifest, css file paths are absolute (do not start 
            with . or /) but font files are relative (begin with .) -->
            <xsl:when test="ends-with(lower-case(.), 'css')">
              <item href="{if (starts-with(., './')) then substring(., 3) else .}" id="{me:id(.)}" media-type="text/css"/>
            </xsl:when>
            <xsl:when test="ends-with(lower-case(.), 'ttf')">
              <item href="{if (starts-with(., './')) then . else concat('./', .)}" id="{me:id(.)}" media-type="application/x-font-truetype"/>
            </xsl:when>
            <xsl:when test="ends-with(lower-case(.), 'otf')">
              <item href="{if (starts-with(., './')) then substring(., 3) else .}" id="{me:id(.)}" media-type="application/vnd.ms-opentype"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:call-template name="Error">
                <xsl:with-param name="msg">Unrecognized type of CSS file:"<xsl:value-of select="."/>"</xsl:with-param>
              </xsl:call-template>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </manifest>
      <spine toc="ncx"><xsl:for-each select="$xhtmlFiles"><itemref idref="{me:id(.)}"/></xsl:for-each></spine>
    </package>
    
    <call-template name="processProject">
      <with-param name="currentTask" select="'write-xhtml'" tunnel="yes"/>
      <with-param name="preprocessedOSIS" select="$preprocessedOSIS" tunnel="yes"></with-param>
      <with-param name="combinedGlossary" select="$combinedGlossary" tunnel="yes"></with-param>
    </call-template>
    
  </template>
  
  <!-- removeLeadingDashes from navmenu letter menu keywords -->
  <template mode="removeLeadingDashes" match="node()|@*" >
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  <template mode="removeLeadingDashes" match="seg[@type='keyword'][ancestor::div[@subType='x-navmenu-letter']]/text()">
    <value-of select="replace(., '^\s*\-\s*', '')"/>
  </template>
  
  <!-- Main process-project loop -->
  <template name="processProject">
    <param name="currentTask" tunnel="yes"/>
    <param name="preprocessedOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    
    <call-template name="Log">
      <with-param name="msg">
processProject: currentTask = <value-of select="$currentTask"/>, 
                doCombineGlossaries = <value-of select="$doCombineGlossaries"/>, 
                isChildrensBible = <value-of select="$isChildrensBible"/>
      </with-param>
    </call-template>
    
    <apply-templates mode="divideFiles" select="$preprocessedOSIS"/>
    
    <apply-templates mode="divideFiles" select="$combinedGlossary/*"/>
    
    <apply-templates mode="divideFiles" select="$referenceOSIS"/>
    
  </template>
  
  <!-- Write a single glossary that combines all other glossaries together. 
  Note: x-keyword-duplicate entries are dropped because they are included in 
  the x-aggregate glossary -->
  <template name="WriteCombinedGlossary">
    <param name="combinedKeywords" as="element(div)+"/>
    <element name="div" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
      <attribute name="type" select="'glossary'"/>
      <attribute name="root-name" select="'comb'"/>
      <attribute name="osisID" select="'DICT_TOP'"/>
      <milestone type="{concat('x-usfm-toc', $TOC)}" n="[level1]{$CombinedGlossaryTitle}" 
        xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"/>
      <title type="main" xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
        <xsl:value-of select="$CombinedGlossaryTitle"/>
      </title>
      <for-each select="$combinedKeywords">
        <sort select="oc:keySort(.//seg[@type='keyword'])" data-type="text" order="ascending" 
          collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
        <apply-templates mode="writeCombinedGlossary" select="."/>
      </for-each>
    </element>
  </template>
  <template mode="writeCombinedGlossary" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
    <if test="self::seg[not(ancestor::div[@type='glossary'][@subType='x-aggregate'])]">
      <call-template name="keywordDisambiguationHeading"/>
    </if>
  </template>
  
  <!-- When keywords are aggregated or the combined glossary is used, 
  titles indicate a keyword's source -->
  <template name="keywordDisambiguationHeading">
    <param name="noScope"/>
    <param name="noName"/>
    <if test="not($noScope)">
      <osis:title level="3" subType="x-glossary-scope">
        <value-of select="oc:getGlossaryScopeTitle(ancestor::div[@type='glossary'][1])"/>
      </osis:title>
    </if>
    <if test="not($noName)">
      <osis:title level="3" subType="x-glossary-title">
        <value-of select="oc:getGlossaryTitle(ancestor::div[@type='glossary'][1])"/>
      </osis:title>
    </if>
  </template>
  
  <!-- Bible pre-processing templates to speed up processing that 
  requires node copying/modification -->
  <template mode="preprocess_markMainTocMilestone 
                  preprocess_removeSectionDivs 
                  preprocess_expelChapterTags" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  <template mode="preprocess_markMainTocMilestone" 
      match="milestone[@type=concat('x-usfm-toc', $TOC)][. intersect $mainTocMilestone]">
    <copy>
      <attribute name="isMainTocMilestone" select="'true'"/>
      <for-each select="@*"><copy-of select="."/></for-each>
    </copy>
  </template>
  <template mode="preprocess_removeSectionDivs" match="div[ends-with(lower-case(@type), 'section')]">
    <apply-templates mode="preprocess_removeSectionDivs"/>
  </template>
  <template mode="preprocess_expelChapterTags" match="*[parent::div[@type='book']]">
    <variable name="book" select="parent::*/@osisID"/>
    <variable name="expel" select="descendant::chapter[starts-with(@sID, concat($book, '.'))]"/>
    <choose>
      <when test="not($expel)"><copy-of select="."/></when>
      <otherwise><sequence select="oc:expelElements(., $expel, false())"/></otherwise>
    </choose>
  </template>
  
  <!-- THE OSIS FILE IS SEPARATED INTO INDIVIDUAL XHTML FILES BY THE FOLLOWING TEMPLATES
  All osisText children are assumed to be div elements (others are ignored). Children's
  Bibles are contained within a single div[@type='book']. Bibles and reference material
  are contained in div[@type=$usfmType], div[@type='book'], and div[@type='bookGroup']
  and any other divs are unexpected but handled. -->
  <template mode="divideFiles" match="node()"><apply-templates mode="#current"/></template>
  <template mode="divideFiles" match="div[@type='glossary'][@subType='x-aggregate']" priority="3"/>
  
  <!-- FILE: module-introduction -->
  <template mode="divideFiles" match="osisText">
    <choose>
      <!-- If this is the top of an x-bible OSIS file, group all initial divs as the introduction -->
      <when test="oc:myWork(.) = $mainWORK and //work[@osisWork=$mainWORK]/type[@type='x-bible']">
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
      <!-- FILE (when $ChapterFiles = 'true'): Bible chapters -->
      <when test="self::div[@type='book'] and $ChapterFiles = 'true'">
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
  <template mode="divideFiles" match="div[@type='glossary'][@root-name='comb' or oc:myWork(.) != $mainWORK]">
    <param name="currentTask" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    <!-- Put each pre-keyword and keyword into separate files to ensure 
    that links and article tags all work properly across various eBook 
    readers. But if a glossary div contains only one keyword, the entire 
    contents is put into one file, which is necessary if that keyword 
    is a [no_toc] is is commonly done. -->
    <for-each-group select="node()" 
        group-adjacent="if (count(parent::*/child::div[starts-with(@type, 'x-keyword')]) = 1) then 1 else 
        0.5 + 0.5*count(self::div[starts-with(@type, 'x-keyword')]) + 
        count(preceding::div[starts-with(@type, 'x-keyword')])">
      <choose>
        <!-- Either divs are output OR the combined glossary is output. Never both -->
        <when test="not($doCombineGlossaries) or ancestor::div[@root-name]">
          <call-template name="ProcessFile">
            <with-param name="fileNodes" select="current-group()"/>
          </call-template>
        </when>
        <!-- Don't warn when unnecessary -->
        <when test="$currentTask != 'write-xhtml' or 
                    self::div[starts-with(@type, 'x-keyword')] or 
                    not(current-group()[node()][normalize-space()][1])"/>
        <otherwise>
          <call-template name="Warn">
            <with-param name="msg">
              <value-of select="concat('The combined glossary is dropping ', count(current-group()), ' node(s) containing: ')"/>
              <for-each select="current-group()//text()[normalize-space()]"><text>&#xa;</text><value-of select="oc:printNode(.)"/><text>&#xa;</text></for-each>
            </with-param>
          </call-template>
        </otherwise>
      </choose>
    </for-each-group>
  </template>
  
  <!-- ProcessFile may be called with any element that should initiate a new output
   file above. It writes the file's contents and adds it to manifest and spine -->
  <template name="ProcessFile">
    <param name="fileNodes" as="node()*"/>
    <!-- A currentTask param is used in lieu of XSLT's mode feature here. 
    This is necessary because identical template selectors are required 
    for multiple modes (ie. a single template element should handle 
    multiple modes), yet template content must also vary by mode 
    (something XSLT 2.0 modes alone can't do) -->
    <param name="currentTask" tunnel="yes"/>
    
    <variable name="fileName" select="me:getFileName(.)"/>
    <variable name="fileXHTML_0"><apply-templates mode="xhtml" select="$fileNodes"/></variable>
    <variable name="fileXHTML"><apply-templates mode="postprocess" select="$fileXHTML_0"/></variable>
    
    <!-- Unless the resulting xhtml file contains some text or images, drop it -->
    <variable name="keepXHTML" 
              select="boolean($fileXHTML/descendant::text()[normalize-space()] or 
                              $fileXHTML/descendant::*[local-name()='img'])"/>
    <if test="$keepXHTML">
      <choose>
        <when test="$currentTask = 'get-filenames'"><value-of select="$fileName"/></when>
        <otherwise>
          <variable name="fileNotes">
            <call-template name="noteSections"><with-param name="nodes" select="$fileNodes"/></call-template>
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
  <template mode="postprocess" match="node()|@*"><copy><apply-templates mode="#current" select="node()|@*"/></copy></template>
  <!-- Don't output duplicate inline-TOC tites -->
  <template mode="postprocess" match="html:h1 | html:h2 | html:h3">
    <variable name="precedingTOC" select="self::*[contains(@class, 'osis-title')]/
        preceding::text()[normalize-space()][1]/ancestor::html:div[contains(@class, 'xsl-inline-toc')][1]"/>
    <variable name="duplicateTitle" 
        select="lower-case($precedingTOC[1]/preceding::text()[normalize-space()][1][parent::html:h1]) = lower-case(text()[1])"/>
    <if test="not($duplicateTitle)"><next-match/></if>
  </template>
  
  <!-- This function may be called on any node. It returns the output 
  file that contains the node -->
  <function name="me:getFileName" as="xs:string">
    <param name="node" as="node()"/>
    
    <variable name="root" select="if ($node/ancestor-or-self::osisText) then oc:myWork($node) else 
                                  $node/ancestor-or-self::*[@root-name]/@root-name"/>
    <variable name="isMainNode" select="$root = $mainWORK"/>
    <variable name="refUsfmType" select="$node/ancestor-or-self::div[@type=$usfmType][last()]"/>
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
        <value-of select="concat($root, '_Chbl_c', $group)"/>
      </when>
      <!-- Book and chapter nodes -->
      <when test="$book">
        <variable name="group" select="count($node/descendant-or-self::chapter[starts-with(@sID, concat($book, '.'))]) + 
                                       count($node/preceding::chapter[starts-with(@sID, concat($book, '.'))])"/>
        <value-of select="concat($root, '_', $book, if ($ChapterFiles != 'true') then '' else concat('/ch', $group))"/>
      </when>
      <!-- BookGroup introduction nodes -->
      <when test="$node/ancestor::div[@type='bookGroup']">
        <variable name="group" select="0.5 + 0.5*count($node/descendant-or-self::div[@type='book']) + 
                                       count($node/preceding::div[@type='book'])"/>
        <value-of select="concat($root, '_bookGroup-introduction_', $group)"/>
      </when>
      <!-- Main module introduction nodes -->
      <when test="$isMainNode">
        <variable name="group" select="0.5 + 0.5*count($node/descendant-or-self::div[@type='bookGroup']) + 
                                       count($node/preceding::div[@type='bookGroup'])"/>
        <value-of select="concat($root, '_module-introduction', (if ($group &#60; 1) then '' else concat('_', $group)))"/>
      </when>
      <!-- Reference OSIS glossary nodes -->
      <when test="not($isMainNode) and $node/ancestor-or-self::div[@type='glossary']">
        <variable name="singleKeyword" 
            select="count($node/ancestor-or-self::div[@type='glossary'][1]/child::div[starts-with(@type, 'x-keyword')]) = 1"/>
        <variable name="group" select="if ($singleKeyword) then 1 else 
            0.5 + count($node/preceding::div[starts-with(@type, 'x-keyword')]) + 
            0.5*count($node/ancestor-or-self::div[starts-with(@type, 'x-keyword')][1])"/>
        <value-of select="if ($root = 'comb') then 
            concat($root, '_glossary', '/', 'k', $group) else 
            concat($root, '_glossary', '/', 'p', me:hashUsfmType($refUsfmType), '_k', $group)"/>
      </when>
      <!-- non-glossary refUsfmType nodes -->
      <when test="$refUsfmType">
        <value-of select="concat($root, '_', $refUsfmType/@type, '/', 'p', me:hashUsfmType($refUsfmType))"/>
      </when>
      <!-- unknown type nodes (osis-converters gives osisIDs to top level divs, so use osisID)-->
      <otherwise>
        <value-of select="concat($root, '_', $node/ancestor::div[parent::osisText]/@osisID)"/>
      </otherwise>
    </choose>
  </function>
  <function name="me:hashUsfmType" as="xs:string">
    <param name="usfmType" as="element(div)"/>
    <variable name="title" select="oc:getGlossaryTitle($usfmType)"/>
    <if test="$title"><value-of select="sum(string-to-codepoints($title))"/></if>
    <if test="not($title)"><value-of select="count($usfmType/preceding::div[@type=$usfmType/@type]) + 1"/></if>
  </function>
  
  <!-- This template may be called with a Bible osisRef string. It does
  the same thing as me:getFileName but is much faster. -->
  <function name="me:getFileNameOfRef" as="xs:string">
    <param name="osisRef" as="xs:string"/>
    <if test="contains($osisRef, ':') and not(starts-with($osisRef, concat($mainWORK, ':')))">
      <call-template name="Error">
        <with-param name="msg">
Bible reference <value-of select="$osisRef"/> targets a work other than <value-of select="$mainWORK"/>
        </with-param>
      </call-template>
    </if>
    <variable name="osisRef2" select="replace($osisRef, '^[^:]*:', '')" as="xs:string"/>
    <value-of select="concat($mainWORK, '_', 
                             tokenize($osisRef2, '\.')[1], 
                             (if ($ChapterFiles != 'true') then '' else 
                             concat('/ch', tokenize($osisRef2, '\.')[2])))"/>
  </function>
  
  <!-- Write an xhtml file -->
  <template name="WriteFile">
    <param name="fileName" as="xs:string"/>
    <param name="OSISelement" as="node()"/>
    <param name="fileXHTML" as="node()+"/>
    <param name="fileNotes" as="node()*"/>
    <param name="preprocessedOSIS" tunnel="yes"/>
    <variable name="topElement" select="$OSISelement/parent::*" as="element()"/>
    <variable name="isMainNode" select="oc:myWork($topElement) = $mainWORK"/>
    <call-template name="Log">
      <with-param name="msg" select="concat('writing:', $fileName)"/>
    </call-template>
    <result-document format="xhtml" method="xml" href="xhtml/{$fileName}.xhtml">
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta name="generator" content="OSIS"/>
          <title><xsl:value-of select="$fileName"/></title>
          <meta http-equiv="Default-Style" content="text/html; charset=utf-8"/>
          <xsl:for-each select="tokenize($css, '\s*,\s*')">
            <xsl:if test="ends-with(lower-case(.), 'css')">
              <link href="{me:uri-to-relative($topElement, .)}" type="text/css" rel="stylesheet"/>
            </xsl:if>
          </xsl:for-each>
        </head>
        <body>
          <xsl:attribute name="class" select="normalize-space(string-join(distinct-values(
              ('calibre', 
               root($OSISelement)//work[@osisWork = oc:myWork(.)]/type/@type, 
               $topElement/ancestor-or-self::*[@scope][1]/@scope, 
               for $x in tokenize($fileName, '[_/]') return $x, 
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
            <call-template name="getMainInlineTOC"/>
          </if>
          <xsl:sequence select="$fileXHTML"/>
          <xsl:sequence select="$fileNotes"/>
          <!-- If there are links to FullResourceURL then add a crossref 
          section at the end of the last book, with a link to FullResourceURL -->
          <xsl:if test="$FullResourceURL and $FullResourceURL != 'false' and 
            boolean($topElement intersect $preprocessedOSIS/descendant::div[@type='book'][last()]) and
            boolean(($preprocessedOSIS | $referenceOSIS)//reference[@subType='x-other-resource'])">
            <div class="xsl-crossref-section">
              <hr/><xsl:text>&#xa;</xsl:text>
              <div id="fullResourceURL" class="xsl-crossref">
                <xsl:if test="$NoEpub3Markup = 'false'">
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
    <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-footnote-section">
      <hr/><xsl:text>&#xa;</xsl:text>
      <xsl:apply-templates mode="footnotes" select="$nodes"/>
    </div>
    <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-crossref-section">
      <hr/><xsl:text>&#xa;</xsl:text>
      <xsl:apply-templates mode="crossrefs" select="$nodes"/>
    </div>
  </template>
              
  <template mode="footnotes crossrefs" match="node()"><apply-templates mode="#current"/></template>
  <template mode="footnotes" match="note[not(@type) or @type != 'crossReference']">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <div xmlns="http://www.w3.org/1999/xhtml" id="{me:id($osisIDid)}" class="xsl-footnote">
      <xsl:if test="$NoEpub3Markup = 'false'">
        <xsl:attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'footnote'"/>
      </xsl:if>
      <a href="#textsym.{me:id($osisIDid)}">
        <xsl:call-template name="getFootnoteSymbol">
          <xsl:with-param name="classes" 
            select="normalize-space(string-join((me:getClasses(.), 'xsl-note-head'), ' '))"/>
        </xsl:call-template>
      </a>
      <xsl:value-of select="' '"/>
      <xsl:apply-templates mode="xhtml"/>
    </div>
    <text>&#xa;</text><!-- this newline is only for better HTML file formatting -->
  </template>
  <template mode="crossrefs" match="note[@type='crossReference']">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <div xmlns="http://www.w3.org/1999/xhtml" id="{me:id($osisIDid)}" class="xsl-crossref">
      <xsl:if test="$NoEpub3Markup = 'false'">
        <xsl:attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'footnote'"/>
      </xsl:if>
      <a href="#textsym.{me:id($osisIDid)}">
        <xsl:call-template name="getFootnoteSymbol">
          <xsl:with-param name="classes" 
            select="normalize-space(string-join((me:getClasses(.), 'xsl-note-head'), ' '))"/>
        </xsl:call-template>
      </a>
      <xsl:value-of select="' '"/>
      <xsl:apply-templates mode="xhtml"/>
    </div>
    <text>&#xa;</text><!-- this newline is only for better HTML file formatting -->
  </template>
  
  <!-- This template may be called from any note. It returns a symbol or 
  number based on that note's type and context -->
  <template name="getFootnoteSymbol">
    <param name="classes" select="''"/>
    <variable name="inVerse" select="preceding::verse[1]/@sID = following::verse[1]/@eID or 
                                     preceding::verse[1]/@sID = descendant::verse[1]/@eID or 
                                     boolean(ancestor::title[@canonical='true'])"/>
    <choose>
      <when test="$inVerse and not(@type='crossReference')">
        <attribute name="class" select="string-join(($classes, 'xsl-fnote-symbol'), ' ')"/>
        <value-of select="'*'"/>
      </when>
      <when test="$inVerse and @subType='x-parallel-passage'">
        <attribute name="class" select="string-join(($classes, 'xsl-crnote-symbol'), ' ')"/>
        <value-of select="'•'"/>
      </when>
      <when test="$inVerse">
        <attribute name="class" select="string-join(($classes, 'xsl-crnote-symbol'), ' ')"/>
        <value-of select="'+'"/>
      </when>
      <otherwise>
        <attribute name="class" select="string-join(($classes, 'xsl-note-number'), ' ')"/>
        <value-of select="'['"/><xsl:call-template name="getFootnoteNumber"/><value-of select="']'"/>
      </otherwise>
    </choose>
  </template>
  
  <!-- This template may be called from any note. It returns the number 
  of that note within its output file -->
  <template name="getFootnoteNumber">
    <choose>
      <when test="ancestor::div[@type=$usfmType]">
        <choose>
          <when test="not(descendant-or-self::seg[@type='keyword']) and 
                      count(preceding::seg[@type='keyword']) = 
                      count(ancestor::div[@type=$usfmType][1]/preceding::seg[@type='keyword'])">
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
  
  <!--                  TABLE OF CONTENTS
  There are two TOCs: 1) eBook TOC marked with title="level-N" attri-
  butes, and 2) inline TOC which appears inline with the text as a 
  series of links. The following OSIS elements, by default, will 
  generate both an eBook TOC and an inline TOC entry:
  
             ELEMENT                           DESCRIPTION
  milestone[@type='x-usfm-tocN'] -From USFM \tocN tags, where N 
                                  corresponds to this XSLT's $TOC param.
                                  The TOC entry name comes from the "n" 
                                  attribute value.
  chapter[@sID]                  -From USFM \c tags. The TOC entry name 
                                  comes from a following \cl or \cp USFM 
                                  tag: title[@type='x-chapterLabel']
  seg[@type='keyword']           -From USFM \k ...\k* tags. The TOC 
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
  [no_toc]        - Means this element is NOT a TOC element.
  [not_parent]    - Used on bookGroup or book  milestone TOC elements.   
                    Means that this section should appear as the first  
                    sibling of the following book or chapter list,   
                    rather than as the parent (parent is default for  
                    book or bookGroup TOC elements).
  Any TEXT following these instructions will be used for the TOC entry 
  name (overriding the default name if there is one). -->
  <template name="getMainInlineTOC">
    <param name="combinedGlossary" tunnel="yes"/>
    <variable name="listElements">
      <sequence select="me:getTocListItems(., true(), false())"/>
      <!-- If combining glossaries, output the combined glossary first, 
      then any non-glossary material after it -->
      <if test="$doCombineGlossaries">
        <sequence select="me:getTocListItems($combinedGlossary, true(), $doCombineGlossaries)"/>
      </if>
      <!-- Ouput either non-glossary material in referenceOSIS (if 
      combiningGlossaries) or else everything in referenceOSIS -->
      <for-each select="$referenceOSIS">
        <sequence select="me:getTocListItems(., true(), $doCombineGlossaries)"/>
      </for-each>
    </variable>
    <if test="count($listElements/*)">
      <element name="div" namespace="http://www.w3.org/1999/xhtml">
        <attribute name="id" select="'root-toc'"/>
        <sequence select="me:getInlineTocDiv($listElements/*, 'ol', true())"/>
      </element>
    </if>
  </template>
  
  <function name="me:getInlineTOC" as="element(html:div)*">
    <param name="tocElement" as="element()"/>
    <variable name="listElements">
      <sequence select="me:getTocListItems($tocElement, false(), false())"/>
    </variable>
    <if test="count($listElements/*)">
      <variable name="listType" select="if ($tocElement/ancestor::div[@type='book']) then 'ul' else 'ol'"/>
      <sequence select="me:getInlineTocDiv($listElements/*, $listType, false())"/>
    </if>
  </function>
  
  <function name="me:getInlineTocDiv" as="element(html:div)">
    <param name="listElements" as="element(html:li)*"/>
    <param name="listType" as="xs:string"/>
    <param name="isTopTOC" as="xs:boolean"/>
    <!-- Inline TOCs by default display as lists of inline-block links 
    all sharing equal width, which may occupy the full width of the page. 
    The two exceptions are: Bible book lists which are limited to three 
    columns, and the main Toc menu, whose links are broken into three 
    sub-sections:
        1) INTRODUCTION links 
        2) BOOK links
        3) BACK material links
    These sections of the Main TOC each display links differently:
    INTRODUCTION: Display max two columns; if there are an odd number of 
                  intro links, the first row is a single, centered link.
    BOOK:         Display as a single column unless there are two 
                  testament links, or one testament and more than 4 book 
                  links, or more than 5 book links (which are then 
                  displayed in two columns). 
    BACK:         Display max two columns unless maxChars is greater 
                  than a mainTocMaxBackChars (which are then displayed 
                  single column); if there is an odd number of Bible 
                  book links displayed as two columns, then the first 
                  back material row is a single centered link. -->
                  
    <variable name="bookIsTwoColumns" 
              select="count($listElements[@class='xsl-bookGroup-link']) = 2 or 
                      count($listElements[starts-with(@class, 'xsl-book')]) &#62; 5"/>
                      
    <variable name="hasOddNumberOfIntros" 
              select="count($listElements
                            [not(starts-with(@class, 'xsl-book'))]
                            [not(preceding::*[starts-with(@class, 'xsl-book')])]
                      ) mod 2 = 1"/>
                      
    <variable name="hasOddNumberOf2ColBooks" 
              select="$bookIsTwoColumns and count($listElements[starts-with(@class, 'xsl-book')]) mod 2 = 1"/>
              
    <variable name="twoColumnElements" 
              select="$listElements[$bookIsTwoColumns or not(starts-with(@class, 'xsl-book'))]"/>
              
    <variable name="oneColumnElements" 
              select="$listElements except $twoColumnElements"/>
              
    <variable name="chars" 
              select="if ($isTopTOC) then 
                      max(($twoColumnElements/string-length(string()), 
                           $oneColumnElements/(string-length(string())*0.5)
                      )) else 
                      max($listElements/string-length(string()))"/>
                      
    <variable name="maxChars" 
              select="if ($chars &#62; 32) then 32 else $chars"/>
              
    <variable name="backIsOneColumn" 
              select="$maxChars &#62; $mainTocMaxBackChars"/>

    <element name="div" namespace="http://www.w3.org/1999/xhtml">
      <variable name="class">xsl-inline-toc
        <if test="not($bookIsTwoColumns)">xsl-one-book-column</if>
        <if test="$backIsOneColumn">xsl-one-back-column</if>
        <if test="$hasOddNumberOfIntros">xsl-odd-intros</if>
        <if test="$hasOddNumberOf2ColBooks">xsl-odd-2col-books</if>
      </variable>
      <attribute name="class" select="replace($class, '[\s\n]+', ' ')"/>
      <!-- this div allows margin auto to center, which doesn't work with ul/ol -->
      <element name="div" namespace="http://www.w3.org/1999/xhtml">
        <choose>
          <!-- limit main TOC width, because li width is specified as % in css -->
          <when test="$isTopTOC">
            <!-- ebible.css 2 column is: 100% = 6px + 12px + maxChars + 12px + 6px + 12px + maxChars + 12px + 6px , 
            so: max-width of parent at 100% = 66px + 2*maxChars (but need fudge since ch, based on '0', isn't determinative) -->
            <attribute name="style" select="concat('max-width:calc(66px + ', (2.5*$maxChars), 'ch)')"/>
          </when>
          <!-- limit TOCs containing book names to three columns -->
          <when test="$listElements[@class = 'xsl-book-link']">
            <!-- 3.5*(calc(24px + 1.2*$maxChars)) from below -->
            <attribute name="style" select="concat('max-width:calc(84px + ', (4.2*$maxChars), 'ch)')"/>
          </when>
        </choose>
        <for-each-group select="$listElements" group-adjacent="if (not($isTopTOC)) then @class else '1'">
          <if test="count(current-group())">
            <element name="{$listType}" namespace="http://www.w3.org/1999/xhtml"><sequence select="current-group()"/></element>
          </if>
        </for-each-group>
      </element>
    </element>
    
  </function>
  
  <function name="me:getTocListItems" as="element(html:li)*">
    <param name="tocNode" as="node()"/>
    <param name="isTopTOC" as="xs:boolean"/>
    <param name="combiningGlossaries" as="xs:boolean"/>
    <variable name="isMainNode" select="oc:myWork($tocNode) = $mainWORK"/>
    <variable name="toplevel" select="if ($isTopTOC) then 0 else me:getTocLevel($tocNode)"/>
    <if test="$toplevel &#60; 3 and not(matches($tocNode/@n, '^(\[[^\]+]\])*\[not_parent\]'))">
      <variable name="subentries" as="element()*">
        <choose>
          <!-- Children's Bibles -->
          <when test="$isChildrensBible and $isTopTOC">
            <sequence select="$tocNode/ancestor-or-self::div[@type='book'][last()]//
                milestone[@type=concat('x-usfm-toc', $TOC)]
                [contains(@n, '[level1]')][generate-id(.) != generate-id($tocNode)]"/>
          </when>
          <when test="$isChildrensBible">
            <variable name="followingTocs" select="$tocNode/following::
                milestone[@type=concat('x-usfm-toc', $TOC)]
                [contains(@n, concat('[level',($toplevel+1),']'))]"/>
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
          <otherwise>
            <!-- find the container div which this TOC element targets -->
            <variable name="container" as="node()?" select="if ($isTopTOC) then (root($tocNode)) else
                if (
                  $tocNode/parent::div[not(@type = ('bookGroup', 'book'))]
                  [parent::div[@type = ('bookGroup', 'book')]]
                  [not(preceding-sibling::*) or parent::div[@type = 'bookGroup']]
                )
                then $tocNode/parent::div/parent::div 
                else $tocNode/ancestor::div[1]"/>
            <!-- Container TOC hierarchy may be: 1,2,3,3,2,3,3,1,2,3,3 etc. so we need to 
            group by level, concatenate, and choose only the first sub-group -->
            <for-each-group group-adjacent="me:getTocLevel(.)" 
              select="( $container//chapter[@sID] | 
                        $container//seg[@type='keyword'] | 
                        $container//milestone[@type=concat('x-usfm-toc', $TOC)]
                      )[. &#62;&#62; $tocNode][me:getTocLevel(.) &#60;= $toplevel + 1]">
              <if test="position() = 1">
                <!-- select all contained toc elements, excluding: $tocNode, sub-sub-toc 
                elements, x-aggregate div elements, keywords & glossary-toc-milestones 
                outside the combined glossary if combiningGlossaries or milestone tocs 
                with [no_toc]-->
                <sequence select="current-group()
                    [not(. intersect $tocNode)]
                    [not(ancestor::div[@type='glossary'][@subType='x-aggregate'])]
                    [not($isTopTOC and $mainTocMilestone and @isMainTocMilestone = 'true')]
                    [not($isTopTOC and ancestor::div[@scope='NAVMENU'])]
                    [not($combiningGlossaries and ancestor::div[@type='glossary'][not(@root-name)])]
                    [not(self::*[contains(@n, '[no_toc]')])]"/>
              </if>
            </for-each-group>
          </otherwise>
        </choose>
      </variable>
      <if test="count($subentries)">
        <variable name="showFullGloss" select="(not($doCombineGlossaries) and $SCRIPT_NAME != 'osis2ebooks') or 
            $isMainNode or 
            (count($subentries[@type='keyword']) &#60; xs:integer(number($glossthresh))) or 
            (count(distinct-values($subentries[@type='keyword']/upper-case(oc:longestStartingMatchKS(text())))) = 1)"/>
        <!-- listElements is used to generate all list elements before 
        writing any of them, so that we can get the max length -->
        <variable name="listElements" as="element(me:li)*">
          <for-each select="$subentries">
            <variable name="previousKeyword" select="preceding::seg[@type='keyword'][1]"/>
            <variable name="skipKeyword">
              <choose>
                <when test="$previousKeyword[ancestor::div[@subType='x-navmenu-atoz']]">
                  <value-of select="false()"/>
                </when>
                <when test="boolean($showFullGloss) or 
                            not(self::seg[@type='keyword']) or 
                            not($previousKeyword)">
                  <value-of select="false()"/>
                </when>
                <otherwise><value-of select="boolean(
                    upper-case(oc:longestStartingMatchKS(text())) = 
                    upper-case(oc:longestStartingMatchKS($previousKeyword/string()))
                  )"/></otherwise>
              </choose>
            </variable>
            <if test="$skipKeyword = false()">
              <variable name="instructionClasses" 
                  select="string-join((oc:getTocInstructions(.)), ' ')" as="xs:string?"/>
              <variable name="type">
                <variable name="intros" select="me:getBookGroupIntroductions(.)"/>
                <choose>
                  <when test="self::chapter">chapter</when>
                  <when test="self::seg">keyword</when>
                  <when test="count($intros) = 1 and . intersect $intros">bookGroup</when>
                  <when test=". intersect $intros">bookSubGroup</when>
                  <when test="parent::div[@type = ('glossary', 'bookGroup', 'book')]">
                    <value-of select="parent::div/@type"/>
                  </when>
                  <otherwise>other</otherwise>
                </choose>
              </variable>
              <me:li type="{$type}"
                     class="{concat(
                        'xsl-', $type, '-link', 
                        (if ($instructionClasses) then concat(' ', $instructionClasses) else ''))}"
                     href="{me:uri-to-relative($tocNode, concat(
                        '/xhtml/', 
                        me:getFileName(.), 
                        '.xhtml#', 
                        generate-id(.)
                      ))}">
                <if test="ancestor::div[@subType='x-navmenu-atoz']">
                  <attribute name="noWidth" select="'true'"/>
                </if>
                <choose>
                  <when test="self::chapter[@osisID]">
                    <value-of select="tokenize(@osisID, '\.')[last()]"/>
                  </when>
                  <when test="ancestor::div[@subType='x-navmenu-atoz']">
                    <value-of select="replace(string(), '^\-+', '')"/>
                  </when>
                  <when test="boolean($showFullGloss)=false() and self::seg[@type='keyword']">
                    <value-of select="upper-case(oc:longestStartingMatchKS(text()))"/>
                  </when>
                  <otherwise>
                    <value-of select="oc:titleCase(me:getTocTitle(.))"/>
                  </otherwise>
                </choose>
              </me:li>
            </if>
          </for-each>
        </variable>
        <for-each select="$listElements">
          <variable name="chars" select="max($listElements
                                            [not(@noWidth='true')]
                                            [@type = current()/@type]/
                                            string-length(string()))"/>
          <variable name="maxChars" select="if ($chars &#62; 32) then 32 else $chars"/>
          <li xmlns="http://www.w3.org/1999/xhtml">
            <xsl:attribute name="class" select="@class"/>
            <xsl:if test="not($isTopTOC) and not(@noWidth='true')">
              <xsl:attribute name="style" select="concat('width:calc(24px + ', (1.2*$maxChars), 'ch)')"/>
            </xsl:if>
            <a><xsl:attribute name="href" select="@href"/>
              <xsl:value-of select="string()"/>
            </a>
          </li>
        </for-each>
      </if>
    </if>
  </function>
  
  <!-- me:getTocAttributes returns attribute nodes for a TOC element -->
  <function name="me:getTocAttributes" as="attribute()+">
    <param name="tocElement" as="element()"/>
    <variable name="isTOC" select="not(matches($tocElement/@n, '^(\[[^\]]*\])*\[no_toc\]'))"/>
    <attribute name="id" select="generate-id($tocElement)"/>
    <attribute name="class" select="normalize-space(
        string-join(( if ($isTOC) then 'xsl-toc-entry' else '', 
        me:getClasses($tocElement)
        ), ' '))"/>
    <if test="$isTOC">
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
        <!-- keyword TOCs -->
        <when test="$tocElement/self::seg[@type='keyword'][ancestor::div[@subType='x-navmenu-atoz']]">
          <value-of select="replace($tocElement, '^\-', '')"/>
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
            <with-param name="msg">
Could not determine TOC title of "<value-of select="$errtitle"/>"</with-param>
          </call-template>
        </otherwise>
      </choose>
    </variable>
    
    <value-of select="if ($tocTitleEXPLICIT) then $tocTitleEXPLICIT else $tocTitleOSIS"/>
    
  </function>
  
  <!-- getTocLevel returns an integer which is the TOC hierarchy level of tocElement -->
  <function name="me:getTocLevel" as="xs:integer">
    <param name="tocElement" as="element()"/>
    <variable name="isMainNode" select="oc:myWork($tocElement) = $mainWORK"/>
    <variable name="toclevelEXPLICIT" select="if (matches($tocElement/@n, '^(\[[^\]]*\])*\[level(\d)\].*$')) then 
                                                 replace($tocElement/@n, '^(\[[^\]]*\])*\[level(\d)\].*$', '$2') else '0'"/>
    <variable name="toclevelOSIS">
      <variable name="parentTocNodes" select="if ($isMainNode) then 
                                                  me:getBibleParentTocNodes($tocElement) else 
                                                  me:getGlossParentTocNodes($tocElement)"/>
      <value-of select="1 + count($parentTocNodes)"/>
    </variable>
    <value-of select="if ($toclevelEXPLICIT = '0') then $toclevelOSIS else $toclevelEXPLICIT"/>
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
            child::milestone[@type=concat('x-usfm-toc', $TOC)] | 
            child::*[1][not(self::div)]/child::milestone[@type=concat('x-usfm-toc', $TOC)]
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
       A BOOK-SUB-GROUP INTRODUCTION (possible when x is in a book): the first preceding 
       non-book TOC milestone in the bookGroup. -->
  <function name="me:getBookGroupIntroductions" as="element(milestone)*">
    <param name="x" as="node()"/>

    <variable name="ancestor_bookGroup" as="element(div)?" 
        select="$x/ancestor-or-self::div[@type='bookGroup'][1]"/>
    
    <variable name="TOC_milestones_in_bookGroup" as="element(milestone)*" 
        select="$ancestor_bookGroup/descendant::milestone[@type=concat('x-usfm-toc', $TOC)]"/>
    
    <variable name="nonBook_TOC_children_of_bookGroup" as="element(milestone)*" 
        select="$TOC_milestones_in_bookGroup[parent::div[not(@type='book')][parent::div[@type='bookGroup']]]"/>
        
    <variable name="myBookGroupTOC" as="element(milestone)?" 
        select="( $nonBook_TOC_children_of_bookGroup[. &#60;&#60; $x] | 
                  $nonBook_TOC_children_of_bookGroup[. intersect $x] )[last()]"/>
        
    <variable name="testament_introduction_TOC_milestone" as="element(milestone)?" 
        select="$ancestor_bookGroup/child::div[1]
        [@type != 'book']
        [ count($nonBook_TOC_children_of_bookGroup) = 1 or 
          following-sibling::div[1][@type != 'book'][. intersect $TOC_milestones_in_bookGroup/parent::div]
        ]/descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]"/>
        
    <sequence select="($testament_introduction_TOC_milestone | $myBookGroupTOC)"/>
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
      <span xmlns="http://www.w3.org/1999/xhtml" class="xsl-chapter-number">
        <xsl:value-of select="tokenize(preceding::chapter[@sID][1]/@osisID, '\.')[last()]"/>
      </span>
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
      <span xmlns="http://www.w3.org/1999/xhtml">
        <xsl:attribute name="id" select="concat('v_', .)"/>
      </span>
    </for-each>
    <!-- then verse numner(s) -->
    <sup xmlns="http://www.w3.org/1999/xhtml" class="xsl-verse-number">
      <xsl:value-of select="if ($first=$last) then tokenize($first, '\.')[last()] else 
          concat(tokenize($first, '\.')[last()], '-', tokenize($last, '\.')[last()])"/>
    </sup>
  </template>
  

  <!-- THE FOLLOWING TEMPLATES CONVERT OSIS INTO XHTML MARKUP AS DESIRED -->
  <!-- All text nodes are copied -->
  <template mode="xhtml" match="text()"><copy/></template>
  
  <!-- By default, attributes are dropped -->
  <template mode="xhtml" match="@*"/>
  
  <!-- By default, elements get their namespace changed from OSIS to XHTML, 
  with a class attribute added (and other attributes dropped) -->
  <template mode="xhtml" match="*">
    <element name="{local-name()}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml" select="node()|@*"/>
    </element>
  </template>
  
  <!-- Remove these elements entirely (x-chapterLabel is handled by me:getTocTitle())-->
  <template mode="xhtml" match="verse[@eID] | 
                                chapter[@eID] |
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
  <template mode="xhtml" match="verse[@sID] | hi[@subType='x-alternate']" priority="3">
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
    <element name="h1" namespace="http://www.w3.org/1999/xhtml">
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
    </element>
    <!-- non-Bible chapters also get inline TOC (Bible trees do not have a document-node due to preprocessing) -->
    <if test="boolean($tocAttributes/self::attribute(title)) and oc:myWork(.) != $mainWORK">
      <element name="h1" namespace="http://www.w3.org/1999/xhtml">
        <attribute name="class">xsl-nonBibleChapterLabel</attribute>
        <value-of select="$tocTitle"/>
      </element>
      <sequence select="me:getInlineTOC(.)"/>
    </if>
  </template>
  
  <!-- Glossary keywords -->
  <template mode="xhtml" match="seg[@type='keyword']" priority="2">
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="currentTask" tunnel="yes"/>
    <!-- output hyperlink target for every keyword -->
    <span id="{me:id(replace(replace(@osisID, '^[^:]*:', ''), '!', '_'))}" xmlns="http://www.w3.org/1999/xhtml"></span>
    <element name="dfn" namespace="http://www.w3.org/1999/xhtml">
      <sequence select="me:getTocAttributes(.)"/>
      <value-of select="me:getTocTitle(.)"/>
    </element>
    <if test="$currentTask = 'write-xhtml' and 
              not(ancestor::div[@resp='x-oc']) and 
              not($doCombineGlossaries) and 
              me:getTocLevel(.) = 1 and 
              count(distinct-values($referenceOSIS//div[@type='glossary']/oc:getGlossaryScopeTitle(.))) &#62; 1"> 
      <variable name="kdh" as="element(osis:title)*">
        <call-template name="keywordDisambiguationHeading"/>
      </variable>
      <apply-templates mode="xhtml" select="$kdh/node()"/>
    </if>
  </template>
  
  <!-- Titles -->
  <template mode="xhtml" match="title">
    <element name="h{if (@level) then @level else '1'}" namespace="http://www.w3.org/1999/xhtml">
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
    <element name="h2" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <!-- OSIS elements which will become spans with a special class !-->
  <template mode="xhtml" match="catchWord | 
                                foreign | 
                                hi | 
                                rdg | 
                                signed |
                                transChange">
    <element name="span" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <template mode="xhtml" match="cell">
    <element name="td" namespace="http://www.w3.org/1999/xhtml">
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <template mode="xhtml" match="caption">
    <element name="{if ($html5 = 'true') then 'figcaption' else 'div'}" 
        namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <template mode="xhtml" match="div[@type='introduction']">
    <next-match/>
    <hr xmlns="http://www.w3.org/1999/xhtml"/>
  </template>
  
  <template mode="xhtml" match="figure">
    <element name="{if ($html5 = 'true') then 'figure' else 'div'}" 
        namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <element name="img" namespace="http://www.w3.org/1999/xhtml">
        <attribute name="src" select="me:uri-to-relative(., @src)"/>
        <attribute name="alt" select="@src"/>
      </element>
      <apply-templates mode="xhtml"/>
    </element>
  </template>

  <template mode="xhtml" match="head">
    <element name="h2" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <template mode="xhtml" match="item[@subType='x-prevnext-link'][ancestor::div[starts-with(@type, 'x-keyword')]]">
    <param name="combinedGlossary" tunnel="yes"/>
    <if test="$doCombineGlossaries"><next-match/></if>
  </template>
  
  <template mode="xhtml" match="item">
    <element name="li" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <call-template name="WriteEmbededChapter"/>
      <call-template name="WriteEmbededVerse"/>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <template mode="xhtml" match="lb">
    <br xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/></br>
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
        <element name="div" namespace="http://www.w3.org/1999/xhtml">
          <call-template name="class"/>
          <call-template name="WriteEmbededChapter"/>
          <call-template name="WriteEmbededVerse"/>
          <apply-templates mode="xhtml"/>
          <element name="i" namespace="http://www.w3.org/1999/xhtml">
            <attribute name="class">xsl-selah</attribute>
            <for-each select="following-sibling::l[@type='selah']
                [ count(preceding-sibling::l[@type='selah'][. &#62;&#62; current()]) = 
                  count(preceding-sibling::l[. &#62;&#62; current()]) ]">
              <text> </text>
              <apply-templates mode="xhtml"/>
            </for-each>
          </element>
        </element>
      </when>
      <otherwise>
        <element name="div" namespace="http://www.w3.org/1999/xhtml">
          <call-template name="class"/>
          <call-template name="WriteEmbededChapter"/>
          <call-template name="WriteEmbededVerse"/>
          <apply-templates mode="xhtml"/>
        </element>
      </otherwise>
    </choose>
  </template>
  
  <template mode="xhtml" match="lg">
    <element name="div" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <template mode="xhtml" match="list">
    <param name="currentTask" tunnel="yes"/>
    <variable name="ul" as="element(html:ul)">
      <ul xmlns="http://www.w3.org/1999/xhtml">
        <xsl:call-template name="class"/>
        <xsl:apply-templates mode="xhtml"/>
      </ul>
    </variable>
    <!-- OSIS allows list to contain head children, but EPUB2 validator 
    doesn't allow <h> child tags of ul -->
    <variable name="ul2" select="oc:expelElements($ul, 
        $ul/*[contains(@class, 'osis-head')], 
        boolean($currentTask='get-filenames'))"/>
    <for-each select="$ul2">
      <if test="not(boolean(self::html:ul) and not(count(child::*)))">
        <sequence select="."/>
      </if>
    </for-each>
  </template>
  
  <template mode="xhtml" match="list[@subType='x-navmenu'][following-sibling::*[1][self::chapter[@eID]]]">
    <if test="$ChapterFiles = 'true'"><next-match/></if>
  </template>
  
  <template mode="xhtml" match="milestone[@type=concat('x-usfm-toc', $TOC)]" priority="2">
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="currentTask" tunnel="yes"/>
    <variable name="tocAttributes" select="me:getTocAttributes(.)"/>
    <if test="$tocAttributes/self::attribute(title)">
      <variable name="tocTitle" select="oc:titleCase(me:getTocTitle(.))"/>
      <variable name="inlineTOC" select="me:getInlineTOC(.)"/>
      <!-- The <div><small> was chosen because milestone TOC text is hidden by CSS, and non-CSS 
      implementations should have this text de-emphasized since it is not part of the orignal book -->
      <div xmlns="http://www.w3.org/1999/xhtml">
        <xsl:sequence select="$tocAttributes"/>
        <small><i><xsl:value-of select="$tocTitle"/></i></small>
      </div>
      <!-- if there is an inlineTOC with this milestone TOC, then write out a title -->
      <if test="@isMainTocMilestone = 'true' or count($inlineTOC/*)">
        <h1 xmlns="http://www.w3.org/1999/xhtml">
          <xsl:value-of select="$tocTitle"/>
        </h1>
      </if>
      <!-- if this is the first milestone in a Bible, then include the root TOC -->
      <if test="@isMainTocMilestone = 'true'">
        <call-template name="getMainInlineTOC"/>
      </if>
      <!-- if a glossary disambiguation title is needed, then write that out -->
      <if test="$currentTask = 'write-xhtml' and 
                not($doCombineGlossaries) and 
                me:getTocLevel(.) = 1 and 
                count(distinct-values(
                  $referenceOSIS//div[@type='glossary']/oc:getGlossaryScopeTitle(.)
                )) &#62; 1"> 
        <variable name="kdh" as="element(osis:title)*">
          <call-template name="keywordDisambiguationHeading">
            <with-param name="noName" select="'true'"/>
          </call-template>
        </variable>
        <apply-templates mode="xhtml" select="$kdh/node()"/>
      </if>
      <sequence select="$inlineTOC"/>
    </if>
  </template>
  
  <template mode="xhtml" match="milestone[@type=concat('x-usfm-toc', $TOC)][preceding-sibling::seg[@type='keyword']]" priority="3">
    <param name="currentTask" tunnel="yes"/>
    <if test="$currentTask = 'write-xhtml'">
      <call-template name="Note">
        <with-param name="msg">
Dropping redundant TOC milestone in keyword <value-of select="preceding-sibling::seg[@type='keyword'][1]"/>: <value-of select="oc:printNode(.)"/>
        </with-param>
      </call-template>
    </if>
  </template>
  
  <template mode="xhtml" match="milestone[@type='pb']" priority="2">
    <element name="p" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <template mode="xhtml" match="note">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <sup xmlns="http://www.w3.org/1999/xhtml">
      <a href="#{me:id($osisIDid)}" id="textsym.{me:id($osisIDid)}">
        <xsl:if test="$NoEpub3Markup = 'false'">
          <xsl:attribute name="epub:type" namespace="http://www.idpf.org/2007/ops" select="'noteref'"/>
        </xsl:if>
        <xsl:call-template name="getFootnoteSymbol">
          <xsl:with-param name="classes" select="me:getClasses(.)"/>
        </xsl:call-template>
      </a>
    </sup>
  </template>
  
  <template mode="xhtml" match="p">
    <param name="currentTask" tunnel="yes"/>
    <variable name="p" as="element(html:p)">
      <element name="p" namespace="http://www.w3.org/1999/xhtml">
        <call-template name="class"/>
        <call-template name="WriteEmbededChapter"/>
        <call-template name="WriteEmbededVerse"/>
        <apply-templates mode="xhtml"/>
      </element>
    </variable>
    <!-- Block elements as descendants of p do not validate, so expel those. Also expel page-breaks. -->
    <sequence select="oc:expelElements( $p, 
        $p//*[matches(@class, '(^|\s)(pb|osis\-figure)(\s|$)') or matches(local-name(), '^h\d')], 
        boolean($currentTask = 'get-filenames') )"/>
  </template>
  
  <template mode="xhtml" match="reference[@subType='x-other-resource']">
    <param name="preprocessedOSIS" tunnel="yes"/>
    <choose>
      <when test="$FullResourceURL and $FullResourceURL != 'false'">
        <variable name="file" select="concat(
            '/xhtml/', 
            me:getFileNameOfRef($preprocessedOSIS/descendant::div[@type='book'][last()]/@osisID), 
            '.xhtml')"/>
        <variable name="href" select="me:uri-to-relative(., concat($file, '#fullResourceURL'))"/>
        <element name="a" namespace="http://www.w3.org/1999/xhtml">
          <attribute name="href" select="$href"/>
          <call-template name="class"/>
          <apply-templates mode="xhtml"/>
        </element>
      </when>
      <otherwise>
        <element name="span" namespace="http://www.w3.org/1999/xhtml">
          <call-template name="class"/>
          <apply-templates mode="xhtml"/>
        </element>
      </otherwise>
    </choose>
  </template>
  
  <template mode="xhtml" match="reference">
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="preprocessedOSIS" tunnel="yes"/>
    <!-- x-glossary and x-glosslink references may have multiple targets, ignore all but the first -->
    <variable name="osisRef0" select="replace(@osisRef, '\s+.*$', '')"/>
    <variable name="osisRef1" select="replace($osisRef0, '^[^:]*:', '')"/>
    <!-- when using the combined glossary, redirect duplicates to the combined glossary -->
    <variable name="osisRef" select="if ($doCombineGlossaries) then 
                                     replace($osisRef1, '\.dup\d+', '') else 
                                     $osisRef1"/>
    <variable name="file">
      <variable name="workid" select="if (contains(@osisRef, ':')) then 
                                      tokenize(@osisRef, ':')[1] else 
                                      ancestor::osisText/@osisRefWork"/>
      <variable name="refIsBible" select="$osisRef1 != 'BIBLE_TOP' and 
          $preprocessedOSIS/osis[1]/osisText[1]/header[1]/work[@osisWork = $workid]/type[@type='x-bible']"/>
      <choose>
        <when test="$refIsBible">
          <value-of select="concat('/xhtml/', me:getFileNameOfRef(@osisRef), '.xhtml')"/>
        </when>
        <otherwise><!-- references to non-bible -->
          <variable name="target" as="node()?">
            <choose>
              <when test="$workid=$DICTMOD and $doCombineGlossaries">
                <sequence select="$combinedGlossary//*[tokenize(@osisID, ' ') = $osisRef]"/>
              </when>
              <otherwise>
                <sequence select="($preprocessedOSIS | $referenceOSIS)/osis/osisText[@osisRefWork = $workid]//
                                  *[tokenize(@osisID, ' ') = $osisRef]"/>
              </otherwise>
            </choose>
          </variable>
          <choose>
            <when test="count($target)=0">
              <call-template name="Error">
                <with-param name="msg">
workID="<value-of select="$workid"/>" and target osisID not found for: <value-of select="oc:printNode(.)"/>
                </with-param>
              </call-template>
            </when>
            <when test="count($target)=1"><value-of select="concat('/xhtml/', me:getFileName($target), '.xhtml')"/></when>
            <otherwise>
              <call-template name="Error">
                <with-param name="msg">
Multiple targets with same osisID (<value-of select="count($target)"/>): osisID="<value-of select="$osisRef"/>", workID="<value-of select="$workid"/>"
                </with-param>
              </call-template>
            </otherwise>
          </choose>
        </otherwise>
      </choose>
    </variable>
    <variable name="osisRefid" select="replace($osisRef, '!', '_')"/>
    <variable name="osisRefA">
      <choose>
        <!-- refs containing "!" point to a specific note -->
        <when test="starts-with(@type, 'x-gloss') or contains(@osisRef, '!')">
          <value-of select="me:id($osisRefid)"/>
        </when>
        <otherwise>  <!--other refs are to Scripture, so jump to first verse of range  -->
          <variable name="osisRefStart" select="tokenize($osisRefid, '\-')[1]"/>  
          <variable name="spec" select="count(tokenize($osisRefStart, '\.'))"/>
          <value-of select="'v_'"/>
          <value-of select="if ($spec=1) then 
                            concat($osisRefStart, '.1.1') else 
                            ( if ($spec=2) then 
                              concat($osisRefStart, '.1') else 
                              $osisRefStart)"/>
        </otherwise>
      </choose>
    </variable>
    <choose>
      <when test="not($file)"><apply-templates mode="xhtml"/></when>
      <otherwise>
        <variable name="href" select="me:uri-to-relative(., concat($file, '#', $osisRefA))"/>
        <element name="a" namespace="http://www.w3.org/1999/xhtml">
          <attribute name="href" select="$href"/>
          <call-template name="class"/>
          <apply-templates mode="xhtml"/>
        </element>
      </otherwise>
    </choose>
  </template>
  
  <template mode="xhtml" match="row">
    <element name="tr" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <!-- xml:id must start with a letter or underscore, and can only 
  contain letters, digits, underscores, hyphens, and periods. -->
  <function name="me:id" as="xs:string">
    <param name="s"/>
    <value-of select="replace(replace($s, oc:uniregex('^([^\p{gc=L}_])'), 'x$1'), 
                              oc:uniregex('[^\p{gc=L}\d_\-\.]'), '-')"/>
  </function>
  
  <!-- Return the relative path from a node's source file to a URL -->
  <function name="me:uri-to-relative" as="xs:string">
    <param name="base-node" as="node()"/>   <!-- this node's file path is the base -->
    <param name="rel-uri" as="xs:string"/>  <!-- the URI to be converted to a relative path from node's base -->
    <value-of select="oc:uri-to-relative-path(concat('/xhtml/', me:getFileName($base-node), '.xhtml'), $rel-uri)"/>
  </function>
  
</stylesheet>
