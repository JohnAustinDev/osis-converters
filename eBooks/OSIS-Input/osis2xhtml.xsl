<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:html="http://www.w3.org/1999/xhtml"
 xmlns:epub="http://www.idpf.org/2007/ops"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace">
 
  <!-- TRANSFORM AN OSIS FILE INTO A SET OF CALIBRE PLUGIN INPUT XHTML FILES AND CORRESPONDING CONTENT.OPF FILE
  This transform may be tested from command line (and outputs will appear in the current directory): 
  $ saxonb-xslt -ext:on -xsl:osis2xhtml.xsl -s:input-osis.xml -o:content.opf tocnumber=2
  -->
 
  <!-- Input parameters which may be passed into this XSLT -->
  <param name="tocnumber" select="2"/>                 <!-- Use \toc1, \toc2 or \toc3 tags for creating the TOC -->
  <param name="css" select="'ebible.css,module.css'"/> <!-- Comma separated list of css files -->
  <param name="glossthresh" select="20"/>              <!-- Glossary divs with this number or more glossary entries will only appear by first letter in the inline TOC -->
  
  <!-- Each MOBI footnote must be on single line, or they will not display correctly in MOBI popups! So indent="no" is a requirement here -->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="no"/>
  
  <!-- Pass over all nodes that don't match another template (output nothing) -->
  <template match="node()"><apply-templates select="node()"/></template>
  
  <!-- Separate the OSIS file into separate xhtml files based on this template -->
  <template match="osis:osisText | osis:div[@type='bookGroup'] | osis:div[@type='book'] | osis:div[@type='glossary']">
    <choose>
      <when test="self::osis:div[@type='glossary']"> <!-- since glossary entries are not containers, for-each-group must be used to separate each entry into separate files -->
        <for-each-group select="node()" group-adjacent="count(following::osis:seg[@type='keyword'])"><call-template name="ProcessFile"/></for-each-group>
      </when>
      <otherwise><call-template name="ProcessFile"/></otherwise>
    </choose>
    <apply-templates select="node()"/>
  </template>
  
  <!-- ProcessFile may be called with any element that should initiate a new output file above. It writes the file's contents and adds it to manifest and spine -->
  <template name="ProcessFile">
    <param name="contentopf" tunnel="yes"/> <!-- this allows writing to content.opf on subsequent passes when contentopf param is set -->
    <variable name="filename"><call-template name="getFileName"/></variable>
    <choose>
      <when test="$contentopf='manifest'">
        <item xmlns="http://www.idpf.org/2007/opf" href="xhtml/{$filename}.xhtml" id="id.{$filename}" media-type="application/xhtml+xml"/>
      </when>
      <when test="$contentopf='spine'">
        <itemref xmlns="http://www.idpf.org/2007/opf" idref="id.{$filename}"/>
      </when>
      <otherwise>
        <call-template name="WriteFile"><with-param name="filename" select="$filename"/></call-template>
      </otherwise>
    </choose>
  </template>
  
  <!-- This template may be called from any element. It returns the output file name that contains the element -->
  <template name="getFileName">
    <variable name="osisIDWork" select="ancestor-or-self::osis:osisText/@osisIDWork"/>
    <choose>
      <when test="ancestor-or-self::osis:div[@type='glossary']">
        <choose>
          <when test="not(descendant-or-self::osis:seg[@type='keyword']) and count(preceding::osis:seg[@type='keyword']) = count(ancestor::osis:div[@type='glossary'][1]/preceding::osis:seg[@type='keyword'])">
            <value-of select="concat($osisIDWork, '_glossintro_', count(preceding::osis:div[@type='glossary']) + 1)"/>
          </when>
          <otherwise>
            <value-of select="concat($osisIDWork, '_glosskey_', count(preceding::osis:seg[@type='keyword']) + 1)"/>
          </otherwise>
        </choose>
      </when>
      <when test="ancestor-or-self::osis:div[@type='book']">
        <value-of select="concat($osisIDWork, '_', ancestor-or-self::osis:div[@type='book']/@osisID)"/>
      </when>
      <when test="ancestor-or-self::osis:div[@type='bookGroup']">
        <value-of select="concat($osisIDWork,'_bookGroup-introduction_', count(preceding::osis:div[@type='bookGroup']) + 1)"/>
      </when>
      <when test="ancestor-or-self::osis:osisText">
        <value-of select="concat($osisIDWork,'_module-introduction')"/>
      </when>
    </choose>
  </template>

  <!-- Write each xhtml file's contents (choosing which child nodes to write and which to drop) -->
  <template name="WriteFile">
    <param name="filename"/>
    <message select="concat('PROCESSING:', $filename)"/>
    <result-document method="xml" href="xhtml/{$filename}.xhtml">
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
            <when test="$filename=concat(ancestor-or-self::osis:osisText/@osisIDWork,'_module-introduction')">
              <apply-templates mode="xhtml" select="node()[not(ancestor-or-self::osis:header)][not(ancestor-or-self::osis:div[@type='bookGroup'])][not(ancestor-or-self::osis:div[@type='glossary'])]"/>
              <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-footnote-section"><hr/>
                <xsl:apply-templates mode="footnotes" select="node()[not(ancestor-or-self::osis:header)][not(ancestor-or-self::osis:div[@type='bookGroup'])][not(ancestor-or-self::osis:div[@type='glossary'])]"/>
              </div>
            </when>
            <!-- bookGroup-introduction -->
            <when test="starts-with($filename, concat(ancestor-or-self::osis:osisText/@osisIDWork,'_bookGroup-introduction_'))">
              <apply-templates mode="xhtml" select="node()[not(ancestor-or-self::osis:div[@type='book'])]"/>
              <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-footnote-section"><hr/>
                <xsl:apply-templates mode="footnotes" select="node()[not(ancestor-or-self::osis:div[@type='book'])]"/>
              </div>
            </when>
            <!-- glossintro and glosskey -->
            <when test="starts-with($filename, concat(ancestor-or-self::osis:osisText/@osisIDWork,'_gloss'))">
              <article xmlns="http://www.w3.org/1999/xhtml">
                <xsl:apply-templates mode="xhtml" select="current-group()"/>
                <div class="xsl-footnote-section"><hr/>
                  <xsl:apply-templates mode="footnotes" select="current-group()"/>
                </div>
              </article>
            </when>
            <!-- book -->
            <otherwise>
              <apply-templates mode="xhtml" select="node()"/>
              <div xmlns="http://www.w3.org/1999/xhtml" class="xsl-footnote-section"><hr/>
                <xsl:apply-templates mode="footnotes" select="node()"/>
              </div>
            </otherwise>
          </choose>
        </body>
      </html>
    </result-document>
  </template>
  
  <!-- Place footnotes at the bottom of the file -->
  <template match="node()" mode="footnotes"><apply-templates mode="footnotes" select="node()"/></template>
  <template match="osis:note[@type='crossReference']" mode="footnotes"/>
  <template match="osis:note" mode="footnotes">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <div xmlns="http://www.w3.org/1999/xhtml" epub:type="footnote" id="{$osisIDid}" class="xsl-footnote">
      <a href="#textsym.{$osisIDid}"><xsl:call-template name="getFootnoteSymbol"><xsl:with-param name="classes"><xsl:call-template name="classValue"/> xsl-footnote-head</xsl:with-param></xsl:call-template></a>
      <xsl:value-of select="' '"/>
      <xsl:apply-templates mode="xhtml" select="node()"/>
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
      <when test="preceding::osis:verse[1]/@sID = following::osis:verse[1]/@eID or preceding::osis:verse[1]/@sID = descendant::osis:verse[1]/@eID or count(ancestor::osis:title[@canonical='true'])"><attribute name="class" select="string-join(($classes, 'xsl-note-symbol'), ' ')"/>*</when> <!-- notes in verses are just '*' -->
      <otherwise><attribute name="class" select="string-join(($classes, 'xsl-note-number'), ' ')"/>[<xsl:call-template name="getFootnoteNumber"/>]</otherwise>
    </choose>
  </template>
  
  <!-- This template may be called from any note. It returns the number of that note within its output file -->
  <template name="getFootnoteNumber">
    <choose>
      <when test="ancestor::osis:div[@type='glossary']">
        <choose>
          <when test="not(descendant-or-self::osis:seg[@type='keyword']) and count(preceding::osis:seg[@type='keyword']) = count(ancestor::osis:div[@type='glossary'][1]/preceding::osis:seg[@type='keyword'])">
            <value-of select="count(preceding::osis:note[not(@type='crossReference')]) - count(ancestor::osis:div[@type='glossary'][1]/preceding::osis:note[not(@type='crossReference')]) + 1"/>
          </when>
          <otherwise>
            <value-of select="count(preceding::osis:note[not(@type='crossReference')]) - count(preceding::osis:seg[@type='keyword'][1]/preceding::osis:note[not(@type='crossReference')]) + 1"/>
          </otherwise>
        </choose>
      </when>
      <when test="ancestor::osis:div[@type='book']">
        <value-of select="count(preceding::osis:note[not(@type='crossReference')]) - count(ancestor::osis:div[@type='book'][1]/preceding::osis:note[not(@type='crossReference')]) + 1"/>
      </when>
      <when test="ancestor::osis:div[@type='bookGroup']">
        <value-of select="count(preceding::osis:note[not(@type='crossReference')]) - count(ancestor::osis:div[@type='bookGroup'][1]/preceding::osis:note[not(@type='crossReference')]) + 1"/>
      </when>
      <when test="ancestor::osis:osisText">
        <value-of select="count(preceding::osis:note[not(@type='crossReference')]) + 1"/>
      </when>
    </choose>    
  </template>
  
  <!-- Table of Contents -->
  <!-- WriteTableOfContentsEntry may be called from: milestone[x-usfm-toc], chapter[sID] or seg[keyword] -->
  <template name="WriteTableOfContentsEntry">
    <param name="element"/>
    <element name="{if ($element) then $element else 'h1'}" namespace="http://www.w3.org/1999/xhtml">
      <attribute name="id" select="generate-id(.)"/>
      <attribute name="class" select="concat('xsl-toc-entry', (if (self::osis:chapter) then ' x-chapterLabel' else (if (self::osis:seg) then ' xsl-keyword' else ' xsl-milestone')))"/>
      <attribute name="toclevel"><call-template name="getTocLevel"/></attribute>
      <call-template name="getTocTitle"/>
    </element>
  </template>
  
  <!-- getTocLevel may be called from: Bible osisText, milestone[x-usfm-toc], chapter[sID] or seg[keyword] -->
  <template name="getTocLevel">
    <!-- Determine TOC hierarchy from OSIS hierarchy, but if the level is explicitly specified, that value is always 
    used (and this is done by prepending "[levelN] " to the "n" attribute value of a milestone toc tag). -->
    <variable name="toclevelEXPLICIT" select="if (matches(@n, '^\[level\d\] ')) then substring(@n, 7, 1) else '0'"/>
    <variable name="isBible" select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork][child::osis:type[@type='x-bible']]"/>
    <variable name="toclevelOSIS">
      <choose>
        <when test="$isBible">
          <variable name="bookGroupLevel" select="count(ancestor::osis:div[@type='bookGroup']/*[1][self::osis:div[not(@type='book')]]/osis:milestone[@type=concat('x-usfm-toc', $tocnumber)][1])"/>
          <choose>
            <when test="self::osis:osisText">0</when>
            <when test="self::osis:chapter[@sID]"><value-of select="2 + $bookGroupLevel"/></when>
            <when test="ancestor::osis:div[@type='book']"><value-of select="1 + $bookGroupLevel"/></when>
            <otherwise><value-of select="1"/></otherwise>
          </choose>
        </when>
        <otherwise>
          <!-- A glossary div initiates a TOC level if it has a toc milestone child OR else it has a non-div child with a toc milestone child -->
          <variable name="glossaryLevel" select="count(ancestor::osis:div[child::osis:milestone[@type=concat('x-usfm-toc', $tocnumber)] or child::*[not(osis:div)]/osis:milestone[@type=concat('x-usfm-toc', $tocnumber)]])"/>
          <choose>
            <when test="self::osis:seg[@type='keyword']"><value-of select="1 + $glossaryLevel"/></when>
            <otherwise><value-of select="$glossaryLevel"/></otherwise>
          </choose>
        </otherwise>
      </choose>
    </variable>
    <value-of select="if ($toclevelEXPLICIT != '0') then $toclevelEXPLICIT else $toclevelOSIS"/>
  </template>
  
  <!-- getTocTitle may be called from: milestone[x-usfm-toc], chapter[sID] or seg[keyword] -->
  <template name="getTocTitle">
    <variable name="toclevelEXPLICIT" select="if (matches(@n, '^\[level\d\] ')) then substring(@n, 7, 1) else '0'"/>
    <choose>
      <when test="self::osis:milestone[@type=concat('x-usfm-toc', $tocnumber) and @n]"><value-of select="if ($toclevelEXPLICIT != '0') then substring(@n, 10) else @n"/></when>
      <when test="self::osis:chapter[@sID]">
        <choose>
          <when test="following-sibling::*[1][self::osis:title[@type='x-chapterLabel']]"><value-of select="string(following-sibling::osis:title[@type='x-chapterLabel'][1])"/></when>
          <when test="following-sibling::*[1][self::osis:div]/osis:title[@type='x-chapterLabel']"><value-of select="string(following-sibling::*[1][self::osis:div]/osis:title[@type='x-chapterLabel'][1])"/></when>
          <otherwise><value-of select="tokenize(@sID, '\.')[last()]"/></otherwise>
        </choose>
      </when>
      <when test="self::osis:seg[@type='keyword']"><value-of select="string()"/></when>
      <otherwise><value-of select="position()"/></otherwise>
    </choose>
  </template>
  
  <!-- WriteInlineTOCRoot may be called from: Bible osisText or milestone[x-usfm-toc] -->
  <template name="WriteInlineTOCRoot">
    <call-template name="WriteInlineTOC"><with-param name="isRoot" select="true()"/></call-template>
    <for-each select="//osis:work[child::osis:type[@type='x-glossary']]/@osisWork">
      <for-each select="doc(concat(., '.xml'))//osis:osisText[1]">
        <call-template name="WriteInlineTOC"><with-param name="isRoot" select="true()"/></call-template>
      </for-each>
    </for-each>
  </template>
  
  <!-- WriteInlineTOC may be called from: Bible osisText or milestone[x-usfm-toc] -->
  <template name="WriteInlineTOC">
    <param name="isRoot"/>
    <variable name="toplevel">
      <choose><when test="$isRoot=true()">0</when><otherwise><call-template name="getTocLevel"/></otherwise></choose>
    </variable>
    <if test="$toplevel &#60; 3">
      <variable name="topElement" select="."/>
      <variable name="subentries" select="if ($toplevel=0) then //osis:milestone[@type=concat('x-usfm-toc', $tocnumber)] else ancestor::osis:div[@type='book' or @type='bookGroup'][1]//osis:milestone[@type=concat('x-usfm-toc', $tocnumber)] | ancestor::osis:div[@type='book'][1]//osis:chapter[@sID] | ancestor::osis:div[@type='glossary'][1]//osis:seg[@type='keyword']"/>
      <variable name="showFullGloss" select="count($subentries[@type='keyword']) &#60; $glossthresh"/>
      <if test="count($subentries)">
        <element name="{if (ancestor::osis:div[@type='book']) then 'ul' else 'ol'}" namespace="http://www.w3.org/1999/xhtml">
          <attribute name="class" select="'xsl-inline-toc'"/>
          <for-each select="$subentries">
            <variable name="sublevel"><call-template name="getTocLevel"/></variable>
            <variable name="previousKeyword" select="preceding::osis:seg[@type='keyword'][1]/string()"/>
            <variable name="skipKeyword">
              <choose>
                <when test="boolean($showFullGloss) or boolean(self::osis:seg[@type='keyword'])=false() or not($previousKeyword)"><value-of select="false()"/></when>
                <otherwise><value-of select="boolean(substring(text(), 1, 1) = substring($previousKeyword, 1, 1))"/></otherwise>
              </choose>
            </variable>
            <if test="$skipKeyword=false() and ($sublevel = $toplevel+1) and (generate-id(.) != generate-id($topElement))">
              <li xmlns="http://www.w3.org/1999/xhtml">
                <a>
                  <xsl:attribute name="href"><xsl:call-template name="getFileName"/>.xhtml#<xsl:value-of select="generate-id(.)"/></xsl:attribute>
                  <choose xmlns="http://www.w3.org/1999/XSL/Transform">
                    <when test="self::osis:chapter[@osisID]"><value-of select="tokenize(@osisID, '\.')[last()]"/></when>
                    <when test="boolean($showFullGloss)=false() and self::osis:seg[@type='keyword']"><value-of select="upper-case(substring(text(), 1, 1))"/></when>
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
    <variable name="isInVerse" select="preceding::osis:verse[1]/@sID = following::osis:verse[1]/@eID or preceding::osis:verse[1]/@sID = descendant::osis:verse[1]/@eID"/>
    <variable name="doWriteChapterNumber" select="if (not($isInVerse)) then '' else (generate-id(preceding::osis:chapter[@sID][1]/following::osis:*[self::osis:p or self::osis:l][1]) = generate-id($mySelf))"/>
    <if test="$doWriteChapterNumber">
      <span xmlns="http://www.w3.org/1999/xhtml" class="xsl-chapter-number"><xsl:value-of select="tokenize(preceding::osis:chapter[@sID][1]/@osisID, '\.')[last()]"/></span>
    </if>
    <if test="$isInVerse and (self::*[preceding-sibling::*[1][self::osis:verse[@sID]] | self::osis:l[parent::osis:lg[child::osis:l[1] = $mySelf][preceding-sibling::*[1][self::osis:verse[@sID]]]]])">
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
  <template match="osis:verse[@eID] | osis:chapter[@eID] | osis:index | osis:milestone | osis:title[@type='x-chapterLabel'] | osis:title[@type='runningHead'] | osis:note[@type='crossReference']" mode="xhtml"/>
  
  <!-- Remove these tags (keeping their content). Paragraphs tags certain elements are dropped so that resulting HTML will validate -->
  <template match="osis:name | osis:seg | osis:reference[ancestor::osis:title[@type='scope']] | osis:p[descendant::osis:seg[@type='keyword']] | osis:p[descendant::osis:figure]" mode="xhtml">
    <xsl:apply-templates mode="xhtml" select="node()"/>
  </template>
  
  <!-- Verses -->
  <template match="osis:verse[@sID]" mode="xhtml">
    <if test="not(self::osis:verse[following-sibling::*[1][self::osis:p or self::osis:lg or self::osis:l or self::osis:title[@canonical='true']]])"> <!-- skip verses followed by p, lg, l or canonical title, since their templates write verse numbers inside themselves using WriteEmbededChapterVerse-->
      <call-template name="WriteVerseNumber"/>
    </if>
  </template>
  
  <!-- Chapters -->
  <template match="osis:chapter[@sID and @osisID]" mode="xhtml">
    <call-template name="WriteTableOfContentsEntry"/>
  </template>
  
  <!-- Glossary keywords -->
  <template match="osis:seg[@type='keyword']" mode="xhtml" priority="2">
    <span id="{replace(replace(@osisID, '^[^:]*:', ''), '!', '_')}" xmlns="http://www.w3.org/1999/xhtml"></span>
    <call-template name="WriteTableOfContentsEntry"><with-param name="element" select="'dfn'"/></call-template>
  </template>
  
  <!-- Titles -->
  <template match="osis:title" mode="xhtml">
    <variable name="level" select="if (@level) then @level else '1'"/>
    <element name="h{$level}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <if test="@canonical='true'"><call-template name="WriteEmbededChapterVerse"/></if>
      <apply-templates mode="xhtml" select="node()"/>
    </element>
  </template>
  
  <!-- Parallel passage titles become secondary titles !-->
  <template match="osis:title[@type='parallel']" mode="xhtml">
    <h2 xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></h2>
  </template>
  
  <template match="osis:catchWord | osis:foreign | osis:hi | osis:rdg | osis:transChange" mode="xhtml">
    <span xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></span>
  </template>
  
  <template match="osis:cell" mode="xhtml">
    <td xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></td>
  </template>
  
  <template match="osis:caption" mode="xhtml">
    <figcaption xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></figcaption>
  </template>
  
  <template match="osis:figure" mode="xhtml">
    <figure xmlns="http://www.w3.org/1999/xhtml">
      <img>
        <xsl:call-template name="class"/>
        <xsl:attribute name="src">
          <xsl:value-of select="if (starts-with(@src, './')) then concat('.', @src) else (if (starts-with(@src, '/')) then concat('..', @src) else concat('../', @src))"/>
        </xsl:attribute>
      </img>
      <xsl:apply-templates mode="xhtml" select="node()"/>
    </figure>
  </template>

  <template match="osis:head" mode="xhtml">
    <h2 xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></h2>
  </template>
  
  <template match="osis:item" mode="xhtml">
    <li xmlns="http://www.w3.org/1999/xhtml"><call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></li>
  </template>
  
  <template match="osis:lb" mode="xhtml">
    <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/></div>
    <apply-templates mode="xhtml" select="node()"/>
  </template>
  
  <!-- usfm2osis.py follows the OSIS manual recommendation for selah as a line element which differs from the USFM recommendation for selah.
  According to USFM 2.35 spec, selah is: "A character style. This text is frequently right aligned, and rendered on the same line as the previous poetic text..." !-->
  <template match="osis:l" mode="xhtml">
    <choose>
      <when test="@type = 'selah'"/>
      <when test="following-sibling::osis:l[1]/@type = 'selah'">
        <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapterVerse"/><xsl:apply-templates mode="xhtml" select="node()"/>
          <i class="xsl-selah">
            <xsl:text> </xsl:text>
            <xsl:value-of select="following-sibling::osis:l[1]"/>
            <xsl:text> </xsl:text>
            <xsl:value-of select="following-sibling::osis:l[2][@type = 'selah']"/>
          </i>
        </div>
      </when>
      <otherwise>
        <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapterVerse"/><xsl:apply-templates mode="xhtml" select="node()"/></div>
      </otherwise>
    </choose>
  </template>
  
  <template match="osis:lg" mode="xhtml">
    <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></div>
  </template>
  
  <template match="osis:list" mode="xhtml">
    <ul xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></ul>
  </template>
  
  <template match="osis:milestone[@type=concat('x-usfm-toc', $tocnumber)]" mode="xhtml" priority="2">
    <call-template name="WriteTableOfContentsEntry"/>
    <if test="not(preceding::osis:milestone[@type=concat('x-usfm-toc', $tocnumber)])">
      <if test="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork][child::osis:type[@type='x-bible']]"><call-template name="WriteInlineTOCRoot"/></if>
    </if>
    <call-template name="WriteInlineTOC"/>
  </template>
  
  <template match="osis:milestone[@type='pb']" mode="xhtml" priority="2">
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></p>
  </template>
  
  <template match="osis:note" mode="xhtml">
    <variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
    <a xmlns="http://www.w3.org/1999/xhtml" href="#{$osisIDid}" id="textsym.{$osisIDid}" epub:type="noteref"><xsl:call-template name="getFootnoteSymbol"><xsl:with-param name="classes"><xsl:call-template name="classValue"/></xsl:with-param></xsl:call-template></a>
  </template>
  
  <template match="osis:p" mode="xhtml">
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapterVerse"/><xsl:apply-templates mode="xhtml" select="node()"/></p>
  </template>
  
  <!-- This splits paragraphs that contain a page-break -->
  <template match="osis:p[child::osis:milestone[@type='pb']]" mode="xhtml">
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:call-template name="WriteEmbededChapterVerse"/>
      <xsl:apply-templates mode="xhtml" select="node()[following-sibling::osis:milestone[@type='pb']]"/>
    </p>
    <xsl:apply-templates mode="xhtml" select="node()[osis:milestone[@type='pb']]"/>
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/>
      <xsl:apply-templates mode="xhtml" select="node()[not(osis:milestone[@type='pb'])][not(following-sibling::osis:milestone[@type='pb'])]"/>
    </p>
  </template>
  
  <template match="osis:reference" mode="xhtml">
    <variable name="osisRef" select="replace(@osisRef, '^[^:]*:', '')"/>
    <variable name="file">
      <variable name="workid" select="if (contains(@osisRef, ':')) then tokenize(@osisRef, ':')[1] else ancestor::osis:osisText/@osisRefWork"/>
      <variable name="refIsBible" select="ancestor::osis:osisText/osis:header/osis:work[@osisWork = $workid][child::osis:type[@type='x-bible']]"/>
      <choose>
        <when test="$refIsBible">
          <value-of select="concat($workid, '_', tokenize($osisRef, '\.')[1])"/>  <!-- faster than getFileName (it only works for Bible refs because the file can be determined from the osisRef value alone) -->
        </when>
        <otherwise>
          <variable name="target" select="if ($workid = ancestor::osis:osisText[1]/@osisRefWork) then ancestor::osis:osisText[1]//*[@osisID=$osisRef] else doc(concat($workid, '.xml'))//*[@osisID=$osisRef]"/>
          <choose>
            <when test="count($target)=1"><for-each select="$target"><call-template name="getFileName"/></for-each></when>
            <otherwise>
              <message>ERROR: Target osisID not found, or multiple found: workID="<value-of select="$workid"/>", elementID="<value-of select="$osisRef"/>"</message>
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
    <a xmlns="http://www.w3.org/1999/xhtml" href="{concat($file, '.xhtml', '#', $osisRefA)}"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></a>
  </template>
  
  <template match="osis:row" mode="xhtml">
    <tr xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></tr>
  </template>
  
  
  <!-- THE FOLLOWING TEMPLATES PROCESS REFERENCED GLOSSARY MODULES -->
  <template match="node()|@*" mode="glossaries">
    <apply-templates select="node()" mode="glossaries"/>
  </template>
  
  <template match="osis:work[child::osis:type[@type='x-glossary']]" mode="glossaries">
    <apply-templates select="doc(concat(@osisWork, '.xml'))"/>
  </template>
    
    
  <!-- THE FOLLOWING TEMPLATE FOR THE ROOT NODE CONTROLS OVERALL CONVERSION FLOW -->
  <template match="/">
    <param name="contentopf" tunnel="yes"/>
    <variable name="isBible" select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork][child::osis:type[@type='x-bible']]"/>
    
    <apply-templates select="node()"/>
    
    <if test="not($isBible) and $contentopf='manifest'">
      <xsl:call-template name="figure-manifest"/>
    </if>
    
    <if test="$isBible">
      <apply-templates select="node()" mode="glossaries"/>
      <package xmlns="http://www.idpf.org/2007/opf" unique-identifier="uuid_id" version="2.0">
        <metadata 
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
            xmlns:opf="http://www.idpf.org/2007/opf" 
            xmlns:dcterms="http://purl.org/dc/terms/" 
            xmlns:calibre="http://calibre.kovidgoyal.net/2009/metadata" 
            xmlns:dc="http://purl.org/dc/elements/1.1/">
          <dc:publisher><xsl:value-of select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork]/osis:publisher[@type='x-CopyrightHolder']/text()"/></dc:publisher>
          <dc:title><xsl:value-of select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork]/osis:title/text()"/></dc:title>
          <dc:language><xsl:value-of select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork]/osis:language/text()"/></dc:language>
          <dc:identifier scheme="ISBN"><xsl:value-of select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork]/osis:identifier[@type='ISBN']/text()"/></dc:identifier>
          <dc:creator opf:role="aut"><xsl:value-of select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork]/osis:publisher[@type='x-CopyrightHolder']/text()"/></dc:creator>
        </metadata>
        <manifest>
          <xsl:apply-templates select="node()">
            <xsl:with-param name="contentopf" select="'manifest'" tunnel="yes"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="node()" mode="glossaries">
            <xsl:with-param name="contentopf" select="'manifest'" tunnel="yes"/>
            <xsl:with-param name="figures-already-in-manifest" select="//osis:figure/@src" tunnel="yes"/>
          </xsl:apply-templates>
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
          <xsl:apply-templates select="node()">
            <xsl:with-param name="contentopf" select="'spine'" tunnel="yes"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="node()" mode="glossaries">
            <xsl:with-param name="contentopf" select="'spine'" tunnel="yes"/>
          </xsl:apply-templates>
        </spine>
      </package>
    </if>
  </template>
  
  <template name="figure-manifest">
    <param name="figures-already-in-manifest" select="()" tunnel="yes"/>
    <for-each select="distinct-values((distinct-values(//osis:figure/@src), distinct-values($figures-already-in-manifest)))">
      <item xmlns="http://www.idpf.org/2007/opf">
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
    </for-each>
  </template>
  
</stylesheet>
