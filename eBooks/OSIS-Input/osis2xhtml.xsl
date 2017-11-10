<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/osis2xhtml"
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
  <param name="epub3"/>                                <!-- Output EPUB3 markup -->
  
  <!-- Output Unicode SOFT HYPHEN as "&shy;" in xhtml output files (Note: SOFT HYPHENs are currently being stripped out by the Calibre EPUB output plugin) -->
  <character-map name="xhtml-entities"><output-character character="&#xad;" string="&#38;shy;"/></character-map>
  
  <!-- Each MOBI footnote must be on single line, or they will not display correctly in MOBI popups! So indent="no" is a requirement for xhtml outputs -->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="no" name="xhtml" use-character-maps="xhtml-entities"/>
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="yes"/><!-- this default output is for the content.opf output file -->
  
  <variable name="mainInputOSIS" select="/"/>

  <!-- The main input OSIS file must contain a work element corresponding to each OSIS file referenced in the eBook, and all input OSIS files must reside in the same directory -->
  <variable name="referencedOsisDocs" select="//work[@osisWork != //osisText/@osisIDWork]/doc(concat(tokenize(document-uri(/), '[^/]+$')[1], @osisWork, '.xml'))"/>
  
  <!-- USFM file types output by usfm2osis.py are handled by this XSLT -->
  <variable name="usfmType" select="('front', 'introduction', 'back', 'concordance', 'glossary', 'index', 'gazetteer', 'x-other')" as="xs:string+"/>

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
                <item href="{.}" id="{me:id(.)}" media-type="text/css"/>
              </xsl:when>
              <xsl:when test="ends-with(lower-case(.), 'ttf')">
                <item href="./{.}" id="{me:id(.)}" media-type="application/x-font-ttf"/>
              </xsl:when>
              <xsl:when test="ends-with(lower-case(.), 'otf')">
                <item href="./{.}" id="{me:id(.)}" media-type="application/vnd.ms-opentype"/>
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
  <template match="osisText | div[@type='bookGroup'] | div[@type='book'] | div[@type=$usfmType]">
    <choose>
      <when test="self::div[@type=$usfmType]">
        <!-- Put each usfmType entry in its own file to ensure that links and article tags all work properly across various eBook readers -->
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
        <item xmlns="http://www.idpf.org/2007/opf" href="xhtml/{$filename}.xhtml" id="{me:id($filename)}" media-type="application/xhtml+xml"/>
      </when>
      <when test="$currentTask = 'write-spine'">
        <itemref xmlns="http://www.idpf.org/2007/opf" idref="{me:id($filename)}"/>
      </when>
      <otherwise>
        <call-template name="WriteFile"><with-param name="filename" select="$filename"/></call-template>
      </otherwise>
    </choose>
  </template>
  
  <!-- This template may be called from any element. It returns the output file name that contains the element -->
  <!-- If the element is part of a usfmType, and is associated with multiple files (groups) then glossaryGroupingKey must be supplied to specify which group this call pertains to -->
  <template name="getFileName">
    <param name="glossaryGroupingKey" select="'none'"/>
    <variable name="osisIDWork" select="ancestor-or-self::osisText/@osisIDWork"/>
    <choose>
      <when test="ancestor-or-self::div[@type=$usfmType]">
        <choose>
          <when test="count(preceding::seg[@type='keyword']) = count(ancestor::div[@type=$usfmType][1]/preceding::seg[@type='keyword']) and not(descendant-or-self::seg[@type='keyword'])">
            <value-of select="concat($osisIDWork, '_glossintro_', count(preceding::div[@type=$usfmType]) + 1)"/>
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
          <meta http-equiv="Default-Style" content="text/html; charset=utf-8"/>
          <xsl:for-each select="tokenize($css, '\s*,\s*')">
            <xsl:if test="ends-with(lower-case(.), 'css')"><link href="../{.}" type="text/css" rel="stylesheet"/></xsl:if>
          </xsl:for-each>
        </head>
        <body class="calibre">
          <xsl:variable name="usfmFileNum" select="if (ancestor::div[@type=$usfmType][1]) then concat('gn-', count(preceding::div[@type=$usfmType]) + 1) else ''"/>
          <xsl:attribute name="class" select="normalize-space(string-join(distinct-values(
              ('calibre', tokenize($filename, '_')[1], tokenize($filename, '_')[2], concat('n-', tokenize($filename, '_')[3]), @type, @subType, $usfmFileNum)
          ), ' '))"/>
          <choose xmlns="http://www.w3.org/1999/XSL/Transform">
            <!-- module-introduction -->
            <when test="$filename=concat($osisIDWork,'_module-introduction')">
              <variable name="keepnodes" select="node()[not(ancestor-or-self::header)][not(ancestor-or-self::div[@type='bookGroup'])][not(ancestor-or-self::div[@type=$usfmType])]"/>
              <apply-templates mode="xhtml" select="$keepnodes"/>
              <call-template name="noteSections"><with-param name="nodes" select="$keepnodes"/></call-template>
            </when>
            <!-- bookGroup-introduction -->
            <when test="starts-with($filename, concat($osisIDWork,'_bookGroup-introduction_'))">
              <variable name="keepnodes" select="node()[not(ancestor-or-self::div[@type='book'])]"/>
              <apply-templates mode="xhtml" select="$keepnodes"/>
              <call-template name="noteSections"><with-param name="nodes" select="$keepnodes"/></call-template>
            </when>
            <!-- glossintro -->
            <when test="starts-with($filename, concat($osisIDWork,'_glossintro_'))">
              <call-template name="convertGlossaryGroup"><with-param name="filter" select="'none'" tunnel="yes"/></call-template>
            </when>
            <!-- glosskey -->
            <when test="starts-with($filename, concat($osisIDWork,'_glosskey_'))">
              <element name="{if ($epub3) then 'article' else 'div'}" namespace="http://www.w3.org/1999/xhtml">
                <call-template name="convertGlossaryGroup"><with-param name="filter" select="'in-article'" tunnel="yes"/></call-template>
              </element>
              <call-template name="convertGlossaryGroup"><with-param name="filter" select="'after-article'" tunnel="yes"/></call-template>
            </when>
            <!-- book -->
            <otherwise>
              <variable name="keepnodes" select="."/>
              <apply-templates mode="xhtml" select="$keepnodes"/>
              <call-template name="noteSections"><with-param name="nodes" select="$keepnodes"/></call-template>
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
    <call-template name="noteSections"><with-param name="nodes" select="$glossaryFilter2"/></call-template>
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
      <xsl:if test="$epub3"><xsl:attribute name="type" namespace="http://www.idpf.org/2007/ops" select="'footnote'"/></xsl:if>
      <a href="#textsym.{me:id($osisIDid)}"><xsl:call-template name="getFootnoteSymbol"><xsl:with-param name="classes" select="normalize-space(string-join((me:getClasses(.), 'xsl-note-head'), ' '))"/></xsl:call-template></a>
      <xsl:value-of select="' '"/>
      <xsl:apply-templates mode="xhtml"/>
    </div>
    <text>&#xa;</text><!-- this newline is only for better HTML file formatting -->
  </template>
  <template match="note[@type='crossReference']" mode="crossrefs">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <div xmlns="http://www.w3.org/1999/xhtml" id="{me:id($osisIDid)}" class="xsl-crossref">
      <xsl:if test="$epub3"><xsl:attribute name="type" namespace="http://www.idpf.org/2007/ops" select="'footnote'"/></xsl:if>
      <a href="#textsym.{me:id($osisIDid)}"><xsl:call-template name="getFootnoteSymbol"><xsl:with-param name="classes" select="normalize-space(string-join((me:getClasses(.), 'xsl-note-head'), ' '))"/></xsl:call-template></a>
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
  Any TEXT following these instructions will be used for the TOC entry name, overriding the default name -->
  
  <!-- me:getTocAttributes returns attribute nodes for a TOC element -->
  <function name="me:getTocAttributes" as="attribute()+">
    <param name="tocElement" as="element()"/>
    <if test="not($tocElement[self::milestone[@type=concat('x-usfm-toc', $tocnumber)] or self::chapter[@sID] or self::seg[@type='keyword']])">
      <message terminate="yes">ERROR: getTocAttributes(): <value-of select="me:printTag($tocElement)"/> is not a TOC element!</message>
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
      <message terminate="yes">ERROR: getTocTitle(): <value-of select="me:printTag($tocElement)"/> is not a TOC element!</message>
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
      <message terminate="yes">ERROR: getTocLevel(): <value-of select="me:printTag($tocElement)"/> is not a TOC element!</message>
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
  
  <!-- getBibleParentTocNodes may be called from any element -->
  <function name="me:getBibleParentTocNodes" as="element()*">
    <param name="x" as="element()"/>
    <!-- A bookGroup or book div is a TOC parent if it has a TOC milestone child or a first child div, which isn't a bookGroup or book, that has one. 
    Any other div is also a TOC parent if it contains a TOC milestone child which isn't already a bookGroup/book TOC entry. -->
    <sequence select="$x/ancestor-or-self::div[@type = ('bookGroup', 'book')]/milestone[@type=concat('x-usfm-toc', $tocnumber)][1] |
        $x/ancestor-or-self::div[@type = ('bookGroup', 'book')][not(child::milestone[@type=concat('x-usfm-toc', $tocnumber)])]/*[1][self::div][not(@type = ('bookGroup', 'book'))]/milestone[@type=concat('x-usfm-toc', $tocnumber)][1] |
        $x/ancestor-or-self::div/milestone[@type=concat('x-usfm-toc', $tocnumber)][1]"/>
  </function>
  
  <!-- getGlossParentTocNodes may be called from any element -->
  <function name="me:getGlossParentTocNodes" as="element()*">
    <param name="x" as="element()"/>
    <!-- A chapter is always a TOC parent, and so is any div in the usfmType if it has one or more toc milestone children OR else it has a non-div first child with one or more toc milestone children.
    The first such toc milestone descendant determines the div's TOC entry name; any following such children will be TOC sub-entries of the first. -->
    <sequence select="$x/ancestor::div/milestone[@type=concat('x-usfm-toc', $tocnumber)] | $x/ancestor::div/*[1][not(div)]/milestone[@type=concat('x-usfm-toc', $tocnumber)] | 
        $x/preceding::chapter[@sID][not(@sID = $x/preceding::chapter/@eID)]"/>
  </function>
  
  <function name="me:getInlineMSTOC" as="element()*">
    <param name="milestoneElement" as="element()"/>
    <if test="not($milestoneElement[self::milestone[@type=concat('x-usfm-toc', $tocnumber)]])">
      <message terminate="yes">ERROR: getInlineMSTOC(): <value-of select="me:printTag($milestoneElement)"/> is not a TOC milestone element!</message>
    </if>
    <!-- if this is the first milestone in a Bible, then include the root TOC -->
    <if test="generate-id(root($milestoneElement)) = generate-id($mainInputOSIS) and not($milestoneElement/preceding::milestone[@type=concat('x-usfm-toc', $tocnumber)])">
      <sequence select="me:getInlineTOC($milestoneElement, true())"/>
      <for-each select="$referencedOsisDocs//osisText"><sequence select="me:getInlineTOC(., true())"/></for-each>
    </if>
    <sequence select="me:getInlineTOC($milestoneElement, false())"/>
  </function>
  
  <!-- me:getInlineTOC returns inline TOC nodes for a TOC element -->
  <function name="me:getInlineTOC" as="element()*">
    <param name="tocElement" as="element()"/>
    <param name="isOsisRootTOC"/>             <!-- set this only for the main (root) toc -->
    <variable name="isBible" select="root($tocElement)//work[@osisWork = ancestor::osisText/@osisIDWork]/type[@type='x-bible']"/>
    <if test="not($isOsisRootTOC) and not($tocElement[self::milestone[@type=concat('x-usfm-toc', $tocnumber)] or (not($isBible) and self::chapter[@sID])])">
      <message terminate="yes">ERROR: getInlineTOC(): <value-of select="me:printTag($tocElement)"/> is not a TOC milestone or non-Bible chapter element!</message>
    </if>
    <variable name="toplevel" select="if ($isOsisRootTOC = true()) then 0 else me:getTocLevel($tocElement)"/>
    <if test="$toplevel &#60; 3">
      <variable name="subentries" as="element()*">
        <choose>
          <when test="$tocElement/self::chapter[@sID]">
            <sequence select="($tocElement/following::seg[@type='keyword'] | $tocElement/following::milestone[@type=concat('x-usfm-toc', $tocnumber)]) except 
                $tocElement/following::chapter[@eID][@eID = $tocElement/@sID]/following::*"/>
          </when>
          <otherwise>
            <variable name="container" as="node()?" select="if ($isOsisRootTOC = true()) then (root($tocElement)) else
                if ($tocElement/parent::div[not(preceding-sibling::*)][not(@type = ('bookGroup', 'book'))][parent::div[@type = ('bookGroup', 'book')]]) 
                then $tocElement/parent::div/parent::div 
                else $tocElement/ancestor::div[1]"/>
            <sequence select="($container//chapter[@sID] | $container//seg[@type='keyword'] | $container//milestone[@type=concat('x-usfm-toc', $tocnumber)])
                [generate-id(.) != generate-id($tocElement)][me:getTocLevel(.) = $toplevel + 1]"/>
          </otherwise>
        </choose>
      </variable>
      <if test="count($subentries)">
        <variable name="showFullGloss" select="$isBible or (count($subentries[@type='keyword']) &#60; $glossthresh) or 
            count(distinct-values($subentries[@type='keyword']/upper-case(substring(text(), 1, 1)))) = 1"/>
        <element name="{if ($tocElement/ancestor::div[@type='book']) then 'ul' else 'ol'}" namespace="http://www.w3.org/1999/xhtml">
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
                    <otherwise><value-of select="me:getTocTitle(.)"/></otherwise>
                  </choose>
                </a>
              </li>
            </if>
          </for-each>
        </element>
      </if>
    </if>
  </function>
  
  <!-- This template may be called from any element. It adds a class attribute according to tag, level, type and subType -->
  <template name="class"><attribute name="class" select="me:getClasses(.)"/></template>
  <function name="me:getClasses" as="xs:string">
    <param name="x" as="element()"/>
    <variable name="levelClass" select="if ($x/@level) then concat('level-', $x/@level) else ''"/>
    <variable name="osisTagClass" select="concat('osis-', $x/local-name())"/>
    <value-of select="normalize-space(string-join(($osisTagClass, $x/@type, $x/@subType, $levelClass), ' '))"/>
  </function>
  
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
    <sup xmlns="http://www.w3.org/1999/xhtml" class="xsl-verse-number">
      <xsl:value-of select="if ($first=$last) then tokenize($first, '\.')[last()] else concat(tokenize($first, '\.')[last()], '-', tokenize($last, '\.')[last()])"/>
    </sup>
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
  
  <!-- Remove these elements entirely (x-chapterLabel is handled by me:getTocTitle())-->
  <template match="verse[@eID] | chapter[@eID] | index | milestone | title[@type='x-chapterLabel'] | title[@type='runningHead']" mode="xhtml"/>
  
  <!-- Remove these tags (keeping their content). Paragraphs tags containing certain elements are dropped so that resulting HTML will validate -->
  <template match="name | seg | reference[ancestor::title[@type='scope']] | p[descendant::seg[@type='keyword']] | p[descendant::figure]" mode="xhtml">
    <apply-templates mode="xhtml"/>
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
    <h1 xmlns="http://www.w3.org/1999/xhtml"><xsl:sequence select="me:getTocAttributes(.)"/><xsl:value-of select="me:getTocTitle(.)"/></h1>
    <!-- non-Bible chapters also get inline TOC -->
    <if test="//work[@osisWork = ancestor::osisText/@osisIDWork]/type[@type != 'x-bible']">
      <sequence select="me:getInlineTOC(., false())"/>
      <h1 class="xsl-nonBibleChapterLabel" xmlns="http://www.w3.org/1999/xhtml"><xsl:value-of select="me:getTocTitle(.)"/></h1>
    </if>
  </template>
  
  <!-- Glossary keywords -->
  <template match="seg[@type='keyword']" mode="xhtml" priority="2">
    <span id="{me:id(replace(replace(@osisID, '^[^:]*:', ''), '!', '_'))}" xmlns="http://www.w3.org/1999/xhtml"></span>
    <dfn xmlns="http://www.w3.org/1999/xhtml"><xsl:sequence select="me:getTocAttributes(.)"/><xsl:value-of select="me:getTocTitle(.)"/></dfn>
  </template>
  
  <!-- Titles -->
  <template match="title" mode="xhtml">
    <variable name="tocms" select="preceding::milestone[@type=concat('x-usfm-toc', $tocnumber)][1]" as="element(milestone)?"/>
    <!-- Skip those titles which have already been output by TOC milestone. The following variables must be identical those in the TOC milestone template -->
    <variable name="title" select="$tocms/following::text()[normalize-space()][1]/ancestor::title[@type='main' and not(@canonical='true')][1]" as="element(title)?"/>
    <variable name="titles" select="$title | $title/following::title[@type='main' and not(@canonical='true')]
        [(if (@level) then @level else '1') &#62;= (if (preceding::title[1]/@level) then preceding::title[1]/@level else '1')]
        [. &#60;&#60; $title/following::node()[normalize-space()][not(ancestor-or-self::title[@type='main' and not(@canonical='true')])][1]]" as="element(title)*"/>
    <if test="not($tocms) or not($titles[generate-id() = generate-id(current())])"><call-template name="title"/></if>
  </template>
  <template name="title">
    <element name="h{if (@level) then @level else '1'}" namespace="http://www.w3.org/1999/xhtml">
      <xsl:call-template name="class"/>
      <xsl:if test="@canonical='true'"><xsl:call-template name="WriteEmbededChapterVerse"/></xsl:if>
      <xsl:apply-templates mode="xhtml"/>
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
    <element name="{if ($epub3) then 'figcaption' else 'div'}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/><apply-templates mode="xhtml"/>
    </element>
  </template>
  
  <template match="div[@type='introduction']" mode="xhtml">
    <next-match/>
    <hr xmlns="http://www.w3.org/1999/xhtml"/>
  </template>
  
  <template match="figure" mode="xhtml">
    <element name="{if ($epub3) then 'figure' else 'div'}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <img xmlns="http://www.w3.org/1999/xhtml">
        <xsl:attribute name="src">
          <xsl:value-of select="if (starts-with(@src, './')) then concat('.', @src) else (if (starts-with(@src, '/')) then concat('..', @src) else concat('../', @src))"/>
        </xsl:attribute>
        <xsl:attribute name="alt" select="@src"/>
      </img>
      <xsl:apply-templates mode="xhtml"/>
    </element>
  </template>

  <template match="head" mode="xhtml">
    <h2 xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></h2>
  </template>
  
  <template match="item" mode="xhtml">
    <li xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></li>
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
          <xsl:call-template name="class"/>
          <xsl:call-template name="WriteEmbededChapterVerse"/>
          <xsl:apply-templates mode="xhtml"/>
          <i class="xsl-selah">
            <xsl:for-each select="following-sibling::l[@type='selah']
                [count(preceding-sibling::l[@type='selah'][. &#62;&#62; current()]) = count(preceding-sibling::l[. &#62;&#62; current()])]">
              <xsl:text> </xsl:text><xsl:apply-templates select="child::node()" mode="xhtml"/>
            </xsl:for-each>
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
    <!-- The <div><small> was chosen because milestone TOC text is hidden by CSS, and non-CSS implementations should have this text de-emphasized since it is not part of the orignal book -->
    <div xmlns="http://www.w3.org/1999/xhtml"><xsl:sequence select="me:getTocAttributes(.)"/><small><i><xsl:value-of select="me:getTocTitle(.)"/></i></small></div>
    <variable name="tocms" select="."/>
    <!-- Move main titles above the inline TOC. The following variable and for-each selection must be identical to those in the title template. -->
    <variable name="title" select="$tocms/following::text()[normalize-space()][1]/ancestor::title[@type='main' and not(@canonical='true')][1]" as="element(title)?"/>
    <for-each select="$title | $title/following::title[@type='main' and not(@canonical='true')]
        [(if (@level) then @level else '1') &#62;= (if (preceding::title[1]/@level) then preceding::title[1]/@level else '1')]
        [. &#60;&#60; $title/following::node()[normalize-space()][not(ancestor-or-self::title[@type='main' and not(@canonical='true')])][1]]">
      <call-template name="title"/>
    </for-each>
    <sequence select="me:getInlineMSTOC(.)"/>
  </template>
  
  <template match="milestone[@type='pb']" mode="xhtml" priority="2">
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml"/></p>
  </template>
  
  <template match="note" mode="xhtml">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <sup xmlns="http://www.w3.org/1999/xhtml">
      <a href="#{me:id($osisIDid)}" id="textsym.{me:id($osisIDid)}">
        <xsl:if test="$epub3"><xsl:attribute name="type" namespace="http://www.idpf.org/2007/ops" select="'noteref'"/></xsl:if>
        <xsl:call-template name="getFootnoteSymbol"><xsl:with-param name="classes" select="me:getClasses(.)"/></xsl:call-template>
      </a>
    </sup>
  </template>
  
  <template match="p" mode="xhtml">
    <p xmlns="http://www.w3.org/1999/xhtml">
      <xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapterVerse"/><xsl:apply-templates mode="xhtml"/>
    </p>
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
        <when test="starts-with(@type, 'x-gloss') or contains(@osisRef, '!')"><value-of select="me:id($osisRefid)"/></when>  <!-- refs containing "!" point to a specific note -->
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
  
  <!-- xml:id must start with a letter or underscore, and can only contain letters, digits, underscores, hyphens, and periods. -->
  <function name="me:id" as="xs:string">
    <param name="s"/>
    <value-of select="replace(replace($s, '^([^\p{L}_])', 'x$1'), '[^\w\d_\-\.]', '-')"/>
  </function>
  
  <function name="me:printTag" as="text()">
    <param name="elem" as="element()"/>
    <value-of>
      <value-of select="concat('element=', $elem/name(), ', ')"/>
      <for-each select="$elem/@*"><value-of select="concat(name(), '=', ., ', ')"/></for-each>
    </value-of>
  </function>
  
</stylesheet>
