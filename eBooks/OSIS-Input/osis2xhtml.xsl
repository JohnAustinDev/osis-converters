<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:html="http://www.w3.org/1999/xhtml"
 xmlns:epub="http://www.idpf.org/2007/ops">
 
  <!-- TRANSFORM AN OSIS FILE INTO A SET OF CALIBRE PLUGIN INPUT XHTML FILES AND CORRESPONDING CONTENT.OPF FILE
  This transform may be tested from command line (and outputs will appear in the current directory): 
  $ saxonb-xslt -ext:on -xsl:osis2xhtml.xsl -s:main_input_osis.xml -o:content.opf
  -->
 
  <!-- Input parameters which may be passed into this XSLT -->
  <param name="tocnumber" select="2"/>                 <!-- Use \toc1, \toc2 or \toc3 tags for creating the TOC -->
  <param name="css" select="'ebible.css,module.css'"/> <!-- Comma separated list of css files -->
  <param name="glossthresh" select="20"/>              <!-- Glossary inline TOCs with this number or more glossary entries will only appear by first letter in the inline TOC, unless all entries begin with the same letter.-->
  
  <!-- Output Unicode SOFT HYPHEN as "&shy;" in xhtml output files (Note: SOFT HYPHENs are currently being stripped out by the Calibre EPUB output plugin) -->
  <character-map name="xhtml-entities"><output-character character="&#xad;" string="&#38;shy;"/></character-map>
  
  <!-- Each MOBI footnote must be on single line, or they will not display correctly in MOBI popups! So indent="no" is a requirement for xhtml outputs -->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="no" name="xhtml" use-character-maps="xhtml-entities"/>
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="yes"/><!-- this default output is for the content.opf output file -->
  
  <variable name="mainInputOSIS" select="/"/>

  <!-- The main input OSIS file must contain a work element corresponding to each OSIS file referenced in the eBook, and all input OSIS files must reside in the same directory -->
  <variable name="referencedOsisDocs" select="//work[@osisWork != //osisText/@osisIDWork]/doc(concat(tokenize(document-uri(/), '[^/]+$')[1], @osisWork, '.xml'))"/>

  <!-- ROOT NODE TEMPLATE FOR ALL INPUT OSIS FILES -->
  <template match="/">
    <param name="currentTask" select="'write-xhtml'" tunnel="yes"/><!-- The tasks are: write-xhtml, write-manifest and write-spine -->
   
    <!-- Do the currentTask for this OSIS file -->
    <message><text>&#xa;</text><value-of select="concat(tokenize(document-uri(.), '/')[last()], ': ', $currentTask)"/></message>
    <apply-templates><with-param name="currentDoc" select="/" tunnel="yes"/></apply-templates>
    
    <!-- If we're doing write-xhtml on the main input OSIS file, then convert referenced documents and output content.opf as well -->
    <if test="generate-id(.) = generate-id($mainInputOSIS) and $currentTask = 'write-xhtml'">
      <variable name="osisIDWork" select="//osisText/@osisIDWork"/>
      
      <for-each select="$referencedOsisDocs"><!-- this recursively calls the current template on each referenceOsisDocs -->
        <apply-templates select="."><with-param name="currentTask" select="'write-xhtml'" tunnel="yes"/></apply-templates>
      </for-each>
      
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
          <xsl:for-each select=". | $referencedOsisDocs">
            <xsl:apply-templates select="."><xsl:with-param name="currentTask" select="'write-manifest'" tunnel="yes"/></xsl:apply-templates>
          </xsl:for-each>
          <xsl:for-each select="distinct-values((//figure/@src, $referencedOsisDocs//figure/@src))">
            <item>
              <xsl:attribute name="href" select="if (starts-with(., './')) then substring(., 3) else ."/>
              <xsl:attribute name="id" select="tokenize(., '/')[last()]"/>
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
                <item href="{.}" id="{.}" media-type="text/css"/>
              </xsl:when>
              <xsl:when test="ends-with(lower-case(.), 'ttf')">
                <item href="./{.}" id="{.}" media-type="application/x-font-ttf"/>
              </xsl:when>
              <xsl:when test="ends-with(lower-case(.), 'otf')">
                <item href="./{.}" id="{.}" media-type="application/vnd.ms-opentype"/>
              </xsl:when>
              <xsl:otherwise><xsl:message>ERROR: Unrecognized type of CSS file:"<xsl:value-of select="."/>"</xsl:message></xsl:otherwise>
            </xsl:choose>
          </xsl:for-each>
        </manifest>
        <spine toc="ncx">
          <xsl:for-each select=". | $referencedOsisDocs">
            <xsl:apply-templates select="."><xsl:with-param name="currentTask" select="'write-spine'" tunnel="yes"/></xsl:apply-templates>
          </xsl:for-each>
        </spine>
      </package>
    </if>
  </template>
  
  <!-- Pass over all nodes that don't match another template (output nothing) -->
  <template match="node()"><apply-templates/></template>
  
  <!-- Separate the OSIS file into separate xhtml files based on this template -->
  <template match="osisText | div[@type='bookGroup'] | div[@type='book'] | div[@type='glossary']">
    <choose>
      <when test="self::div[@type='glossary']">
        <!-- Put each glossary entry in its own file to ensure that links and article tags all work properly across various eBook readers -->
        <for-each-group select="node()" group-by="for $i in ./descendant-or-self::node() return count($i/following::seg[@type='keyword'])">
          <sort select="current-grouping-key()" order="descending" data-type="number"/>
          <call-template name="ProcessFile"/>
        </for-each-group>
      </when>
      <otherwise><call-template name="ProcessFile"/></otherwise>
    </choose>
    <apply-templates/>
  </template>
  
  <!-- ProcessFile may be called with any element that should initiate a new output file above. It writes the file's contents and adds it to manifest and spine -->
  <template name="ProcessFile">
    <!-- A currentTask param is used in lieu of XSLT's mode feature here. This is necessary because identical template selectors are required for multiple 
    modes (ie. a single template element should handle multiple modes), yet template content must also vary by mode (something XSLT 2.0 modes alone can't do) -->
    <param name="currentTask" tunnel="yes"/>
    <variable name="filename"><call-template name="getFileName"><with-param name="glossaryGroupingKey" select="current-grouping-key()"/></call-template></variable>
    <choose>
      <when test="$currentTask = 'write-manifest'">
        <item xmlns="http://www.idpf.org/2007/opf" href="xhtml/{$filename}.xhtml" id="id.{$filename}" media-type="application/xhtml+xml"/>
      </when>
      <when test="$currentTask = 'write-spine'">
        <itemref xmlns="http://www.idpf.org/2007/opf" idref="id.{$filename}"/>
      </when>
      <otherwise>
        <call-template name="WriteFile"><with-param name="filename" select="$filename"/></call-template>
      </otherwise>
    </choose>
  </template>
  
  <!-- This template may be called from any element. It returns the output file name that contains the element -->
  <!-- If the element is part of a glossary, and is associated with multiple files (groups) then glossaryGroupingKey must be supplied to specify which group this call pertains to -->
  <template name="getFileName">
    <param name="glossaryGroupingKey" select="'none'"/>
    <variable name="osisIDWork" select="ancestor-or-self::osisText/@osisIDWork"/>
    <choose>
      <when test="ancestor-or-self::div[@type='glossary']">
        <choose>
          <when test="count(preceding::seg[@type='keyword']) = count(ancestor::div[@type='glossary'][1]/preceding::seg[@type='keyword']) and not(descendant-or-self::seg[@type='keyword'])">
            <value-of select="concat($osisIDWork, '_glossintro_', count(preceding::div[@type='glossary']) + 1)"/>
          </when>
          <otherwise>
            <value-of select="concat($osisIDWork, '_glosskey_', 
                count(//seg[@type='keyword']) - (if ($glossaryGroupingKey castable as xs:integer) then $glossaryGroupingKey else count(following::seg[@type='keyword'])))"/>
          </otherwise>
        </choose>
      </when>
      <when test="ancestor-or-self::div[@type='book']">
        <value-of select="concat($osisIDWork, '_', ancestor-or-self::div[@type='book']/@osisID)"/>
      </when>
      <when test="ancestor-or-self::div[@type='bookGroup']">
        <value-of select="concat($osisIDWork,'_bookGroup-introduction_', count(preceding::div[@type='bookGroup']) + 1)"/>
      </when>
      <when test="ancestor-or-self::osisText">
        <value-of select="concat($osisIDWork,'_module-introduction')"/>
      </when>
    </choose>
  </template>

  <!-- Write each xhtml file's contents, selecting which input child nodes to convert (unselected nodes are dropped) -->
  <template name="WriteFile">
    <param name="filename"/>
    <message select="concat('WRITING:', $filename)"/>
    <variable name="osisIDWork" select="ancestor-or-self::osisText/@osisIDWork"/>
    <result-document format="xhtml" method="xml" href="xhtml/{$filename}.xhtml">
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta name="generator" content="OSIS"/>
          <title><xsl:value-of select="$filename"/></title>
          <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
          <xsl:for-each select="tokenize($css, '\s*,\s*')">
            <xsl:if test="ends-with(lower-case(.), 'css')"><link href="../{.}" type="text/css" rel="stylesheet"/></xsl:if>
          </xsl:for-each>
        </head>
        <body class="calibre">
          <xsl:attribute name="class" select="normalize-space(string-join(distinct-values(('calibre', tokenize($filename, '_')[2], @type, @subType)), ' '))"/>
          <choose xmlns="http://www.w3.org/1999/XSL/Transform">
            <!-- module-introduction -->
            <when test="$filename=concat($osisIDWork,'_module-introduction')">
              <apply-templates mode="xhtml" select="node()[not(ancestor-or-self::header)][not(ancestor-or-self::div[@type='bookGroup'])][not(ancestor-or-self::div[@type='glossary'])]"/>
              <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-footnote-section"><hr/>
                <xsl:apply-templates mode="footnotes" select="node()[not(ancestor-or-self::header)][not(ancestor-or-self::div[@type='bookGroup'])][not(ancestor-or-self::div[@type='glossary'])]"/>
              </div>
            </when>
            <!-- bookGroup-introduction -->
            <when test="starts-with($filename, concat($osisIDWork,'_bookGroup-introduction_'))">
              <apply-templates mode="xhtml" select="node()[not(ancestor-or-self::div[@type='book'])]"/>
              <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-footnote-section"><hr/>
                <xsl:apply-templates mode="footnotes" select="node()[not(ancestor-or-self::div[@type='book'])]"/>
              </div>
            </when>
            <!-- glossintro -->
            <when test="starts-with($filename, concat($osisIDWork,'_glossintro_'))">
              <call-template name="convertGlossaryGroup"><with-param name="filter" select="'none'" tunnel="yes"/></call-template>
            </when>
            <!-- glosskey -->
            <when test="starts-with($filename, concat($osisIDWork,'_glosskey_'))">
              <article xmlns="http://www.w3.org/1999/xhtml">
                <xsl:call-template name="convertGlossaryGroup"><xsl:with-param name="filter" select="'in-article'" tunnel="yes"/></xsl:call-template>
              </article>
              <call-template name="convertGlossaryGroup"><with-param name="filter" select="'after-article'" tunnel="yes"/></call-template>
            </when>
            <!-- book -->
            <otherwise>
              <apply-templates mode="xhtml"/>
              <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-footnote-section"><hr/>
                <xsl:apply-templates mode="footnotes"/>
              </div>
            </otherwise>
          </choose>
        </body>
      </html>
    </result-document>
  </template>
  
  <template name="convertGlossaryGroup">
    <!-- Filter the current-group, first to remove descendant nodes from other groups, then based on output context -->
    <variable name="glossaryFilter1"><apply-templates mode="glossaryFilter1" select="current-group()"/></variable>
    <variable name="glossaryFilter2"><apply-templates mode="glossaryFilter2" select="$glossaryFilter1"/></variable>
    <apply-templates mode="xhtml" select="$glossaryFilter2"/>
    <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-footnote-section"><hr/>
      <xsl:apply-templates mode="footnotes" select="$glossaryFilter2"/>
    </div>
  </template>
  <!-- Filter out any descendants which are part of a different group -->
  <template match="node()" mode="glossaryFilter1">
    <if test="descendant-or-self::node()[count(following::seg[@type='keyword']) = current-grouping-key()]">
      <copy>
        <for-each select="@*"><copy/></for-each>
        <!-- These element copies retain a reference to their source node, since the source node's context may be required later in the transform -->
        <if test="self::milestone | self::seg | self::note | self::chapter | self::reference">
          <attribute name="contextNode" select="generate-id()"/>
        </if>
        <apply-templates mode="#current"/>
      </copy>
    </if>
  </template>
  <!-- Article material does not cross any div boundary, so end article elements accordingly -->
  <template match="node()" mode="glossaryFilter2">
    <param name="filter" tunnel="yes"/>
    <variable name="keep">
      <choose>
        <when test="$filter = 'in-article'">
          <value-of     select="not(ancestor-or-self::div[1][not(descendant::seg[@type='keyword'])])"/>
        </when>
        <when test="$filter = 'after-article'">
          <value-of select="boolean(ancestor-or-self::div[1][not(descendant::seg[@type='keyword'])])"/>
        </when>
        <otherwise>true</otherwise>
      </choose>
    </variable>
    <if test="$keep = true()">
      <copy>
        <for-each select="@*"><copy/></for-each>
        <apply-templates mode="#current"/>
      </copy>
    </if>
  </template>
  <!-- Nodes having @contextNode were copied to a temporary document (variable) yet may require the source node's context, so this template takes care of that -->
  <template match="*[@contextNode]" mode="xhtml footnotes" priority="10">
    <param name="currentDoc" tunnel="yes"/>
    <for-each select="$currentDoc//node()[current()/@contextNode = generate-id(.)]">
      <apply-templates select="." mode="#current"/>
    </for-each>
  </template>
  
  <!-- Write footnotes -->
  <template match="node()" mode="footnotes"><apply-templates mode="footnotes"/></template>
  <template match="note[not(@type) or @type != 'crossReference']" mode="footnotes">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <div xmlns="http://www.w3.org/1999/xhtml" epub:type="footnote" id="{$osisIDid}" class="xsl-footnote">
      <a href="#textsym.{$osisIDid}"><xsl:call-template name="getFootnoteSymbol"><xsl:with-param name="classes"><xsl:call-template name="classValue"/> xsl-footnote-head</xsl:with-param></xsl:call-template></a>
      <xsl:value-of select="' '"/>
      <xsl:apply-templates mode="xhtml"/>
    </div>
    <text>&#xa;</text><!-- this newline is only for better HTML file formatting -->
  </template>
  
  <!-- This template may be called from any element. It adds a class attribute according to tag, level, type and subType -->
  <template name="class"><attribute name="class"><call-template name="classValue"/></attribute></template>
  <template name="classValue">
    <variable name="levelClass" select="if (@level) then concat('level-', @level) else ''"/>
    <variable name="osisTagClass" select="concat('osis-', local-name())"/>
    <value-of select="normalize-space(string-join(($osisTagClass, @type, @subType, $levelClass), ' '))"/>
  </template>
  
  <!-- This template may be called from any note. It returns a symbol for that specific note -->
  <template name="getFootnoteSymbol">
    <param name="classes"/>
    <choose>
      <when test="preceding::verse[1]/@sID = following::verse[1]/@eID or preceding::verse[1]/@sID = descendant::verse[1]/@eID or count(ancestor::title[@canonical='true'])"><attribute name="class" select="string-join(($classes, 'xsl-note-symbol'), ' ')"/>*</when> <!-- notes in verses are just '*' -->
      <otherwise><attribute name="class" select="string-join(($classes, 'xsl-note-number'), ' ')"/>[<xsl:call-template name="getFootnoteNumber"/>]</otherwise>
    </choose>
  </template>
  
  <!-- This template may be called from any note. It returns the number of that note within its output file -->
  <template name="getFootnoteNumber">
    <choose>
      <when test="ancestor::div[@type='glossary']">
        <choose>
          <when test="not(descendant-or-self::seg[@type='keyword']) and count(preceding::seg[@type='keyword']) = count(ancestor::div[@type='glossary'][1]/preceding::seg[@type='keyword'])">
            <value-of select="count(preceding::note[not(@type='crossReference')]) - count(ancestor::div[@type='glossary'][1]/preceding::note[not(@type='crossReference')]) + 1"/>
          </when>
          <otherwise>
            <value-of select="count(preceding::note[not(@type='crossReference')]) - count(preceding::seg[@type='keyword'][1]/preceding::note[not(@type='crossReference')]) + 1"/>
          </otherwise>
        </choose>
      </when>
      <when test="ancestor::div[@type='book']">
        <value-of select="count(preceding::note[not(@type='crossReference')]) - count(ancestor::div[@type='book'][1]/preceding::note[not(@type='crossReference')]) + 1"/>
      </when>
      <when test="ancestor::div[@type='bookGroup']">
        <value-of select="count(preceding::note[not(@type='crossReference')]) - count(ancestor::div[@type='bookGroup'][1]/preceding::note[not(@type='crossReference')]) + 1"/>
      </when>
      <when test="ancestor::osisText">
        <value-of select="count(preceding::note[not(@type='crossReference')]) + 1"/>
      </when>
    </choose>    
  </template>
  
  <!-- Table of Contents
  There are two TOCs: 1) the standard eBook TOC, and 2) the inline TOC which appears inline with the text as a series of links.
  The following OSIS elements, by default, will generate both a standard TOC and an inline TOC entry:
      milestone[@type='x-usfm-tocN'] (from USFM \tocN tags, where N corresponds to this XSLT's $tocnumber param) - The TOC entry name normally comes from the "n" attribute value
      chapter[@sID] (from USFM \c tags) - The TOC entry name normally comes from a following title[@type='x-chapterLabel'] (USFM \cl or \cp) element
      seg[@type='keyword'] (from USFM \k ...\k* tags) - The TOC entry name normally comes from the child text nodes
      
  By default, TOC hierarchy is determined from OSIS hierarchy. However an explicit TOC level and title may be specified for any entry.
  An explicit title can be specified using the "n" attribute, which may also be prepended with special bracketted INSTRUCTIONS.
  EXAMPLE: <milestone type="x-usfm-toc2" n="[level1][no_inline_toc]My Title"/>.
  
  The recognized INSTRUCTIONS which may appear at the beginning of the "n" attribute value of any TOC generating element are:
  [levelN] where N is 1, 2 or 3, to specify the TOC level.
  [no_toc] means no entry for this element should appear in any TOC (neither standard nor inline TOC)
  [no_inline_toc] means no entry for this should appear in the inline TOC (but will appear in the stardard TOC) 
  Any TEXT following these instructions will be used for the TOC entry name, overriding the default name -->
  
  <!-- WriteTableOfContentsEntry may be called from: milestone[x-usfm-toc], chapter[sID] or seg[keyword] -->
  <template name="WriteTableOfContentsEntry">
    <param name="element"/>
    <variable name="isBible" select="//work[@osisWork = ancestor::osisText/@osisIDWork]/type[@type='x-bible']"/>
    <element name="{if ($element) then $element else 'h1'}" namespace="http://www.w3.org/1999/xhtml">
      <attribute name="id" select="generate-id(.)"/>
      <attribute name="class" select="concat('xsl-toc-entry', (if (self::chapter) then ' x-chapterLabel' else (if (self::seg) then ' xsl-keyword' else ' xsl-milestone')))"/>
      <if test="not(matches(@n, '^(\[[^\]]*\])*\[no_toc\]'))"><attribute name="toclevel" select="oc:getTocLevel(., $isBible)"/></if>
      <call-template name="getTocTitle"/>
    </element>
  </template>
  
  <!-- getTocLevel may be called from: milestone[x-usfm-toc], chapter[sID] or seg[keyword] -->
  <function name="oc:getTocLevel">
    <param name="x"/>
    <param name="isBible"/>
    <variable name="toclevelEXPLICIT" select="if (matches($x/@n, '^(\[[^\]]*\])*\[level(\d)\].*$')) then replace($x/@n, '^(\[[^\]]*\])*\[level(\d)\].*$', '$2') else '0'"/>
    <variable name="toclevelOSIS">
      <variable name="parentTocNodes" select="if ($isBible) then oc:getBibleParentTocNodes($x) else oc:getGlossParentTocNodes($x)"/>
      <choose>
        <when test="$parentTocNodes[generate-id(.) = generate-id($x)]"><value-of select="count($parentTocNodes)"/></when>
        <when test="$x[self::seg[@type='keyword'] | self::chapter[@sID] | self::milestone[@type=concat('x-usfm-toc', $tocnumber)]]"><value-of select="1 + count($parentTocNodes)"/></when>
        <otherwise><value-of select="1"/></otherwise>
      </choose>
    </variable>
    <value-of select="if ($toclevelEXPLICIT = '0') then $toclevelOSIS else $toclevelEXPLICIT"/>
  </function>
  
  <!-- getBibleParentTocNodes may be called from any element -->
  <function name="oc:getBibleParentTocNodes">
    <param name="x"/>
    <!-- A bookGroup or book div is a TOC parent if it has a TOC milestone child or a first child div, which isn't a bookGroup or book, that has one. 
    Any other div is also a TOC parent if it contains a TOC milestone child which isn't already a bookGroup/book TOC entry. -->
    <sequence select="$x/ancestor-or-self::div[@type = ('bookGroup', 'book')]/milestone[@type=concat('x-usfm-toc', $tocnumber)][1] |
        $x/ancestor-or-self::div[@type = ('bookGroup', 'book')][not(child::milestone[@type=concat('x-usfm-toc', $tocnumber)])]/*[1][self::div][not(@type = ('bookGroup', 'book'))]/milestone[@type=concat('x-usfm-toc', $tocnumber)][1] |
        $x/ancestor-or-self::div/milestone[@type=concat('x-usfm-toc', $tocnumber)][1]"/>
  </function>
  
  <!-- getGlossParentTocNodes may be called from any element -->
  <function name="oc:getGlossParentTocNodes">
    <param name="x"/>
    <!-- A chapter is always a TOC parent, and so is any div in the glossary if it has one or more toc milestone children OR else it has a non-div first child with one or more toc milestone children.
    The first such toc milestone descendant determines the div's TOC entry name; any following such children will be TOC sub-entries of the first. -->
    <sequence select="$x/ancestor::div/milestone[@type=concat('x-usfm-toc', $tocnumber)] | $x/ancestor::div/*[1][not(div)]/milestone[@type=concat('x-usfm-toc', $tocnumber)] | 
        $x/preceding::chapter[@sID][not(@sID = $x/preceding::chapter/@eID)]"/>
  </function>
  
  <!-- getTocTitle may be called from: milestone[x-usfm-toc], chapter[sID] or seg[keyword] -->
  <template name="getTocTitle">
    <variable name="tocTitleEXPLICIT" select="if (matches(@n, '^(\[[^\]]*\])+')) then replace(@n, '^(\[[^\]]*\])+', '') else if (@n) then @n else ''"/>
    <variable name="tocTitleOSIS">
      <choose>
        <when test="self::milestone[@type=concat('x-usfm-toc', $tocnumber) and @n]"><value-of select="@n"/></when>
        <when test="self::chapter[@sID]">
          <choose>
            <when test="following-sibling::*[1][self::title[@type='x-chapterLabel']]"><value-of select="string(following-sibling::title[@type='x-chapterLabel'][1])"/></when>
            <when test="following-sibling::*[1][self::div]/title[@type='x-chapterLabel']"><value-of select="string(following-sibling::*[1][self::div]/title[@type='x-chapterLabel'][1])"/></when>
            <otherwise><value-of select="tokenize(@sID, '\.')[last()]"/></otherwise>
          </choose>
        </when>
        <when test="self::seg[@type='keyword']"><value-of select="string()"/></when>
        <otherwise><value-of select="position()"/></otherwise>
      </choose>
    </variable>
    <value-of select="if ($tocTitleEXPLICIT = '') then $tocTitleOSIS else $tocTitleEXPLICIT"/>
  </template>
  
  <!-- WriteMainRootTOC may be called from: milestone[x-usfm-toc] -->
  <template name="WriteMainRootTOC">
    <call-template name="WriteInlineTOC"><with-param name="isOsisRootTOC" select="true()"/></call-template>
    <for-each select="$referencedOsisDocs//osisText">
      <call-template name="WriteInlineTOC"><with-param name="isOsisRootTOC" select="true()"/></call-template>
    </for-each>
  </template>
  
  <!-- WriteInlineTOC may be called from: milestone[x-usfm-toc], or chapter[@sID] (for non-Bibles) -->
  <template name="WriteInlineTOC">
    <param name="isOsisRootTOC"/>
    <variable name="isBible" select="//work[@osisWork = ancestor::osisText/@osisIDWork]/type[@type='x-bible']"/>
    <variable name="toplevel" select="if ($isOsisRootTOC = true()) then 0 else oc:getTocLevel(., $isBible)"/>
    <if test="$toplevel &#60; 3">
      <variable name="subentries" as="element()*">
        <choose>
          <when test="self::chapter[@sID]">
            <sequence select="(following::seg[@type='keyword'] | following::milestone[@type=concat('x-usfm-toc', $tocnumber)]) except 
                following::chapter[@eID][@eID = current()/@sID]/following::*"/>
          </when>
          <otherwise>
            <variable name="container" as="node()" select="if ($isOsisRootTOC = true()) then (/) else
                if (parent::div[not(preceding-sibling::*)][not(@type = ('bookGroup', 'book'))][parent::div[@type = ('bookGroup', 'book')]]) 
                then parent::div/parent::div 
                else ancestor::div[1]"/>
            <sequence select="($container//chapter[@sID] | $container//seg[@type='keyword'] | $container//milestone[@type=concat('x-usfm-toc', $tocnumber)])
                [generate-id(.) != generate-id(current())][oc:getTocLevel(., $isBible) = $toplevel + 1]"/>
          </otherwise>
        </choose>
      </variable>
      <if test="count($subentries)">
        <variable name="showFullGloss" select="$isBible or (count($subentries[@type='keyword']) &#60; $glossthresh) or 
            count(distinct-values($subentries[@type='keyword']/upper-case(substring(text(), 1, 1)))) = 1"/>
        <element name="{if (ancestor::div[@type='book']) then 'ul' else 'ol'}" namespace="http://www.w3.org/1999/xhtml">
          <attribute name="class" select="'xsl-inline-toc'"/>
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
              <li xmlns="http://www.w3.org/1999/xhtml">
                <a>
                  <xsl:attribute name="href"><xsl:call-template name="getFileName"/>.xhtml#<xsl:value-of select="generate-id(.)"/></xsl:attribute>
                  <choose xmlns="http://www.w3.org/1999/XSL/Transform">
                    <when test="self::chapter[@osisID]"><value-of select="tokenize(@osisID, '\.')[last()]"/></when>
                    <when test="boolean($showFullGloss)=false() and self::seg[@type='keyword']"><value-of select="upper-case(substring(text(), 1, 1))"/></when>
                    <otherwise><call-template xmlns="http://www.w3.org/1999/XSL/Transform" name="getTocTitle"/></otherwise>
                  </choose>
                </a>
              </li>
            </if>
          </for-each>
        </element>
      </if>
    </if>
  </template>
  
  <!-- This template may be called from: p, l and canonical title. It writes verse and chapter numbers if the calling element should contain an embedded verse or chapter number -->
  <template name="WriteEmbededChapterVerse">
    <variable name="mySelf" select="."/>
    <variable name="isInVerse" select="preceding::verse[1]/@sID = following::verse[1]/@eID or preceding::verse[1]/@sID = descendant::verse[1]/@eID"/>
    <variable name="doWriteChapterNumber" select="if (not($isInVerse)) then '' else (generate-id(preceding::chapter[@sID][1]/following::*[self::p or self::l][1]) = generate-id($mySelf))"/>
    <if test="$doWriteChapterNumber">
      <span xmlns="http://www.w3.org/1999/xhtml" class="xsl-chapter-number"><xsl:value-of select="tokenize(preceding::chapter[@sID][1]/@osisID, '\.')[last()]"/></span>
    </if>
    <if test="$isInVerse and (self::*[preceding-sibling::*[1][self::verse[@sID]] | self::l[parent::lg[child::l[1] = $mySelf][preceding-sibling::*[1][self::verse[@sID]]]]])">
      <call-template name="WriteVerseNumber"/>
    </if>
  </template>
  
  <!-- This template may be called from: p and l. -->
  <template name="WriteVerseNumber">
    <variable name="osisID" select="if (@osisID) then @osisID else preceding::*[@osisID][1]/@osisID"/>
    <variable name="first" select="tokenize($osisID, '\s+')[1]"/>
    <variable name="last" select="tokenize($osisID, '\s+')[last()]"/>
    <for-each select="tokenize($osisID, '\s+')">
      <span xmlns="http://www.w3.org/1999/xhtml"><xsl:attribute name="id" select="."/></span>
    </for-each>
    <span xmlns="http://www.w3.org/1999/xhtml" class="xsl-verse-number">
      <xsl:value-of select="if ($first=$last) then tokenize($first, '\.')[last()] else concat(tokenize($first, '\.')[last()], '-', tokenize($last, '\.')[last()])"/>
    </span>
  </template>
  

  <!-- THE FOLLOWING TEMPLATES CONVERT OSIS INTO HTML MARKUP AS DESIRED -->
  <!-- By default, text is copied -->
  <template match="text()" mode="xhtml"><copy/></template>
  
  <!-- By default, attributes are dropped -->
  <template match="@*" mode="xhtml"/>
  
  <!-- By default, elements get their namespace changed from OSIS to HTML, and a class attribute is added-->
  <template match="*" mode="xhtml">
    <element name="{local-name()}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml" select="node()|@*"/>
    </element>
  </template>
  
  <!-- Remove these elements entirely (x-chapterLabel is output by WriteTableOfContentsEntry)-->
  <template match="verse[@eID] | chapter[@eID] | index | milestone | title[@type='x-chapterLabel'] | title[@type='runningHead'] | note[@type='crossReference']" mode="xhtml"/>
  
  <!-- Remove these tags (keeping their content). Paragraphs tags containing certain elements are dropped so that resulting HTML will validate -->
  <template match="name | seg | reference[ancestor::title[@type='scope']] | p[descendant::seg[@type='keyword']] | p[descendant::figure]" mode="xhtml">
    <xsl:apply-templates mode="xhtml"/>
  </template>
  
  <!-- Verses -->
  <template match="verse[@sID]" mode="xhtml">
    <!-- skip verses followed by p, lg, l or canonical title, since their templates will write verse numbers inside themselves using WriteEmbededChapterVerse-->
    <if test="not(self::verse[following-sibling::*[1][self::p or self::lg or self::l or self::title[@canonical='true']]])">
      <call-template name="WriteVerseNumber"/>
    </if>
  </template>
  
  <!-- Chapters -->
  <template match="chapter[@sID and @osisID]" mode="xhtml">
    <call-template name="WriteTableOfContentsEntry"/>
    <!-- non-Bible chapters also get inline TOC -->
    <if test="//work[@osisWork = ancestor::osisText/@osisIDWork]/type[@type != 'x-bible']"><call-template name="WriteInlineTOC"/></if>
  </template>
  
  <!-- Glossary keywords -->
  <template match="seg[@type='keyword']" mode="xhtml" priority="2">
    <span id="{replace(replace(@osisID, '^[^:]*:', ''), '!', '_')}" xmlns="http://www.w3.org/1999/xhtml"></span>
    <call-template name="WriteTableOfContentsEntry"><with-param name="element" select="'dfn'"/></call-template>
  </template>
  
  <!-- Titles -->
  <template match="title" mode="xhtml">
    <variable name="level" select="if (@level) then @level else '1'"/>
    <element name="h{$level}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <if test="@canonical='true'"><call-template name="WriteEmbededChapterVerse"/></if>
      <apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <!-- Parallel passage titles become secondary titles !-->
  <template match="title[@type='parallel']" mode="xhtml">
    <h2 xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></h2>
  </template>
  
  <template match="catchWord | foreign | hi | rdg | transChange" mode="xhtml">
    <span xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></span>
  </template>
  
  <template match="cell" mode="xhtml">
    <td xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml"/></td>
  </template>
  
  <template match="caption" mode="xhtml">
    <figcaption xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></figcaption>
  </template>
  
  <template match="figure" mode="xhtml">
    <figure xmlns="http://www.w3.org/1999/xhtml">
      <img>
        <xsl:call-template name="class"/>
        <xsl:attribute name="src">
          <xsl:value-of select="if (starts-with(@src, './')) then concat('.', @src) else (if (starts-with(@src, '/')) then concat('..', @src) else concat('../', @src))"/>
        </xsl:attribute>
      </img>
      <xsl:apply-templates mode="xhtml"/>
    </figure>
  </template>

  <template match="head" mode="xhtml">
    <h2 xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></h2>
  </template>
  
  <template match="item" mode="xhtml">
    <li xmlns="http://www.w3.org/1999/xhtml"><call-template name="class"/><xsl:apply-templates mode="xhtml"/></li>
  </template>
  
  <template match="lb" mode="xhtml">
    <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/></div>
    <apply-templates mode="xhtml"/>
  </template>
  
  <!-- usfm2osis.py follows the OSIS manual recommendation for selah as a line element which differs from the USFM recommendation for selah.
  According to USFM 2.35 spec, selah is: "A character style. This text is frequently right aligned, and rendered on the same line as the previous poetic text..." !-->
  <template match="l" mode="xhtml">
    <choose>
      <when test="@type = 'selah'"/>
      <when test="following-sibling::l[1]/@type = 'selah'">
        <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapterVerse"/><xsl:apply-templates mode="xhtml"/>
          <i class="xsl-selah">
            <xsl:text> </xsl:text>
            <xsl:value-of select="following-sibling::l[1]"/>
            <xsl:text> </xsl:text>
            <xsl:value-of select="following-sibling::l[2][@type = 'selah']"/>
          </i>
        </div>
      </when>
      <otherwise>
        <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapterVerse"/><xsl:apply-templates mode="xhtml"/></div>
      </otherwise>
    </choose>
  </template>
  
  <template match="lg" mode="xhtml">
    <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></div>
  </template>
  
  <template match="list" mode="xhtml">
    <ul xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></ul>
  </template>
  
  <template match="milestone[@type=concat('x-usfm-toc', $tocnumber)]" mode="xhtml" priority="2">
    <call-template name="WriteTableOfContentsEntry"/>
    <if test="generate-id(/) = generate-id($mainInputOSIS) and not(preceding::milestone[@type=concat('x-usfm-toc', $tocnumber)])">
      <call-template name="WriteMainRootTOC"/>
    </if>
    <call-template name="WriteInlineTOC"/>
  </template>
  
  <template match="milestone[@type='pb']" mode="xhtml" priority="2">
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></p>
  </template>
  
  <template match="note" mode="xhtml">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <a xmlns="http://www.w3.org/1999/xhtml" href="#{$osisIDid}" id="textsym.{$osisIDid}" epub:type="noteref"><xsl:call-template name="getFootnoteSymbol"><xsl:with-param name="classes"><xsl:call-template name="classValue"/></xsl:with-param></xsl:call-template></a>
  </template>
  
  <template match="p" mode="xhtml">
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapterVerse"/><xsl:apply-templates mode="xhtml"/></p>
  </template>
  
  <!-- This splits paragraphs that contain a page-break -->
  <template match="p[child::milestone[@type='pb']]" mode="xhtml">
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapterVerse"/>
      <xsl:apply-templates mode="xhtml" select="node()[following-sibling::milestone[@type='pb']]"/>
    </p>
    <xsl:apply-templates mode="xhtml" select="node()[milestone[@type='pb']]"/>
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/>
      <xsl:apply-templates mode="xhtml" select="node()[not(milestone[@type='pb'])][not(following-sibling::milestone[@type='pb'])]"/>
    </p>
  </template>
  
  <template match="reference" mode="xhtml">
    <variable name="osisRef" select="replace(@osisRef, '^[^:]*:', '')"/>
    <variable name="file">
      <variable name="workid" select="if (contains(@osisRef, ':')) then tokenize(@osisRef, ':')[1] else ancestor::osisText/@osisRefWork"/>
      <variable name="refIsBible" select="//work[@osisWork = $workid]/type[@type='x-bible']"/>
      <choose>
        <when test="$refIsBible">
          <value-of select="concat($workid, '_', tokenize($osisRef, '\.')[1])"/><!-- this faster than getFileName (but it only works for Bible refs because the file can be determined from the osisRef value directly) -->
        </when>
        <otherwise>
          <variable name="target" select="($mainInputOSIS | $referencedOsisDocs)//osisText[@osisRefWork = $workid]//*[@osisID = $osisRef]"/>
          <choose>
            <when test="count($target)=0"><message>ERROR: Target osisID not found: osisID="<value-of select="$osisRef"/>", workID="<value-of select="$workid"/>"</message></when>
            <when test="count($target)=1"><for-each select="$target"><call-template name="getFileName"/></for-each></when>
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
        <when test="starts-with(@type, 'x-gloss') or contains(@osisRef, '!')"><value-of select="$osisRefid"/></when>  <!-- refs containing "!" point to a specific note -->
        <otherwise>  <!--other refs are to Scripture, so jump to first verse of range  -->
          <variable name="osisRefStart" select="tokenize($osisRefid, '\-')[1]"/>  
          <variable name="spec" select="count(tokenize($osisRefStart, '\.'))"/>
          <value-of select="if ($spec=1) then concat($osisRefStart, '.1.1') else (if ($spec=2) then concat($osisRefStart, '.1') else $osisRefStart)"/>
        </otherwise>
      </choose>
    </variable>
    <a xmlns="http://www.w3.org/1999/xhtml" href="{concat($file, '.xhtml', '#', $osisRefA)}"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></a>
  </template>
  
  <template match="row" mode="xhtml">
    <tr xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></tr>
  </template>
  
</stylesheet>
