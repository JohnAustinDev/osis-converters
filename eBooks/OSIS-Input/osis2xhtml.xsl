<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:html="http://www.w3.org/1999/xhtml"
 xmlns:epub="http://www.idpf.org/2007/ops"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace">
 
  <!-- TRANSFORM AN OSIS FILE INTO A SET OF CALIBRE PLUGIN INPUT XHTML FILES AND CORRESPONDING CONTENT.OPF FILE
  This transform may be tested from command line (and outputs will appear in the current directory): 
  $ saxonb-xslt -ext:on -xsl:osis2xhtml.xsl -s:input-osis.xml -o:content.opf tocnumber=2 epub3='true' outputfmt='epub'
  -->
 
  <!-- Input parameters which may be passed into this XSLT -->
  <param name="tocnumber" select="2"/>
  <param name="epub3" select="true"/>
  <param name="outputfmt" select="epub"/>

  <output indent="yes"/>
  <strip-space elements="*"/>
  <!-- <preserve-space elements="*"/> -->
  
  <!-- Pass over all nodes that don't match another template (output nothing) -->
  <template match="node()"><apply-templates select="node()"/></template>
  
  <!-- Separate the OSIS file into separate xhtml files (this also writes to content.opf on subsequent passes when contentopf param is set) -->
  <template match="osis:osisText | osis:div[@type='bookGroup'] | osis:div[@type='book'] | osis:div[@type='glossary']">
    <param name="contentopf" tunnel="yes"/>
    <variable name="filename">
      <choose>
        <when test="self::osis:osisText"><value-of select="concat(ancestor-or-self::osis:osisText/@osisIDWork,'_module-introduction')"/></when>
        <when test="self::osis:div[@type='bookGroup']"><value-of select="concat(ancestor-or-self::osis:osisText/@osisIDWork,'_bookGroup-introduction_', position())"/></when>
        <when test="self::osis:div[@type='book']"><value-of select="concat(ancestor-or-self::osis:osisText/@osisIDWork, '_', @osisID)"/></when>
        <when test="self::osis:div[@type='glossary']"><value-of select="concat(ancestor-or-self::osis:osisText/@osisIDWork, '_glossary_', position())"/></when>
      </choose>
    </variable>
    <choose>
      <when test="$contentopf='manifest'">
        <item xmlns="http://www.idpf.org/2007/opf" href="xhtml/{$filename}.xhtml" id="id.{$filename}" media-type="application/xhtml+xml"/>
      </when>
      <when test="$contentopf='spine'">
        <itemref xmlns="http://www.idpf.org/2007/opf" idref="id.{$filename}"/>
      </when>
      <otherwise>
        <call-template name="write-file"><with-param name="filename" select="$filename"/></call-template>
      </otherwise>
    </choose>
    <apply-templates select="node()"/>
  </template>

  <!-- Write each xhtml file's contents (choosing which child nodes to write and which to drop) -->
  <template name="write-file">
    <param name="filename"/>
    <result-document method="xml" href="xhtml/{$filename}.xhtml">
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta name="generator" content="OSIS"/>
          <title><xsl:value-of select="$filename"/></title>
          <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
          <link href="../ebible.css" type="text/css" rel="stylesheet"/>
        </head>
        <body class="calibre"><xsl:attribute name="class" select="normalize-space(string-join(distinct-values(('calibre', tokenize($filename, '_')[2], @type, @subType)), ' '))"/>
          <choose xmlns="http://www.w3.org/1999/XSL/Transform">
            <when test="$filename=concat(ancestor-or-self::osis:osisText/@osisIDWork,'_module-introduction')">
              <apply-templates mode="xhtml" select="node()[not(ancestor-or-self::osis:header)][not(ancestor-or-self::osis:div[@type='bookGroup'])][not(ancestor-or-self::osis:div[@type='glossary'])]"/>
              <hr xmlns="http://www.w3.org/1999/xhtml"/>
              <apply-templates mode="footnotes" select="node()[not(ancestor-or-self::osis:header)][not(ancestor-or-self::osis:div[@type='bookGroup'])]"/>
            </when>
            <when test="starts-with($filename, concat(ancestor-or-self::osis:osisText/@osisIDWork,'_bookGroup-introduction_'))">
              <apply-templates mode="xhtml" select="node()[not(ancestor-or-self::osis:div[@type='book'])]"/>
              <hr xmlns="http://www.w3.org/1999/xhtml"/>
              <apply-templates mode="footnotes" select="node()[not(ancestor-or-self::osis:div[@type='book'])]"/>
            </when>
            <otherwise>
              <apply-templates mode="xhtml" select="node()"/>
              <hr xmlns="http://www.w3.org/1999/xhtml"/>
              <apply-templates mode="footnotes" select="node()"/>
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
    <aside xmlns="http://www.w3.org/1999/xhtml" epub:type="footnote">
      <xsl:attribute name="id" select="replace(@osisID, '!', '_')"/>
      <p>* <xsl:apply-templates mode="xhtml" select="node()"/></p>
    </aside>
  </template>
  

  <!-- THE FOLLOWING TEMPLATES CONVERT OSIS INTO HTML MARKUP AS DESIRED -->
  
  <!-- This template adds the class attribute according to tag, level, type and subType -->
  <template name="class">
    <variable name="levelClass" select="if (@level) then concat('level-', @level) else ''"/>
    <variable name="osisTagClass" select="concat('osis-', local-name())"/>
    <attribute name="class"><value-of select="normalize-space(string-join(($osisTagClass, @type, @subType, $levelClass), ' '))"/></attribute>
  </template>
  
  <!-- This template writes verse and chapter numbers if the calling element should contain an embedded verse or chapter number -->
  <template name="WriteEmbededChapterVerse">
    <variable name="mySelf" select="."/>
    <variable name="isInVerse" select="preceding::osis:verse[1]/@sID = following::osis:verse[1]/@eID or preceding::osis:verse[1]/@sID = descendant::osis:verse[1]/@eID"/>
    <variable name="doWriteChapterNumber" select="if (not($isInVerse)) then '' else (preceding::osis:chapter[@sID][1]/following::osis:*[self::osis:p or self::osis:l][1] = .)"/>
    <if test="$doWriteChapterNumber">
      <span xmlns="http://www.w3.org/1999/xhtml" class="xsl-chapter-number"><xsl:value-of select="tokenize(preceding::osis:chapter[@sID][1]/@osisID, '\.')[last()]"/></span>
    </if>
    <if test="self::*[preceding-sibling::*[1][self::osis:verse[@sID and @osisID]] | self::osis:l[parent::osis:lg[child::osis:l[1] = $mySelf]]]"><call-template name="WriteVerseNumber"/></if>
  </template>
  
  <!-- By default, text is just copied -->
  <template match="text()" mode="xhtml"><copy/></template>
  
  <!-- By default, attributes are dropped -->
  <template match="@*" mode="xhtml"/>
  
  <!-- By default, elements just get their namespace changed from OSIS to HTML, plus a class added-->
  <template match="*" mode="xhtml">
    <element name="{local-name()}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml" select="node()|@*"/>
    </element>
  </template>
  
  <!-- Remove these elements entirely (title type x-chapterLabel are not output, because they are dynamically handled by the chapter template) -->
  <template match="osis:verse[@eID] | osis:chapter[@eID] | osis:index | osis:milestone | osis:title[@type='x-chapterLabel' or @type='runningHead'] | osis:note[@type='crossReference']" mode="xhtml"/>
  
  <!-- Remove these tags (keep their content) -->
  <template match="osis:name | osis:seg | osis:p[descendant::osis:seg[@type='keyword']]" mode="xhtml">
    <xsl:apply-templates mode="xhtml" select="node()"/>
  </template>
  
  <!-- Verses -->
  <template name="WriteVerseNumber" match="osis:verse[@sID and @osisID]" mode="xhtml">
    <choose>
      <when test="self::osis:verse[following-sibling::*[1][self::osis:p or self::osis:lg or self::osis:l]]"/> <!-- skip verses followed by p, lg or l, since their templates write verse numbers inside themselves using WriteEmbededChapterVerse-->
      <otherwise>
        <variable name="osisID" select="if (@osisID) then @osisID else preceding::*[@osisID][1]/@osisID"/>
        <variable name="first" select="tokenize($osisID, '\s+')[1]"/>
        <variable name="last" select="tokenize($osisID, '\s+')[last()]"/>
        <for-each select="tokenize($osisID, '\s+')">
          <span xmlns="http://www.w3.org/1999/xhtml"><xsl:attribute name="id" select="."/></span>
        </for-each>
        <sup xmlns="http://www.w3.org/1999/xhtml" class="xsl-verse-number">
          <xsl:value-of select="if ($first=$last) then tokenize($first, '\.')[last()] else concat(tokenize($first, '\.')[last()], '-', tokenize($last, '\.')[last()])"/>
        </sup>
      </otherwise>
    </choose>
  </template>
  
  <!-- Chapters -->
  <template match="osis:chapter[@sID and @osisID]" mode="xhtml">
    <call-template name="WriteTableOfContentsEntry"/>
    <if test="count(following-sibling::*[1][@type='x-chapterLabel'])">
      <h1 xmlns="http://www.w3.org/1999/xhtml" class="xsl-chapter-title">
        <xsl:value-of select="following-sibling::*[1]/text()"/>
      </h1>
    </if>
  </template>
  
  <!-- Glossary keywords -->
  <template match="osis:seg[@type='keyword']" mode="xhtml" priority="2">
    <call-template name="WriteTableOfContentsEntry"/>
    <variable name="osisID" select="if (contains(@osisID, ':')) then @osisID else concat(//osis:osisText[1]/@osisIDWork, ':', @osisID)"/>
    <choose>
      <!-- mobi -->
      <when test="lower-case($outputfmt)='mobi'">
        <xsl:call-template name="class"/>
        <dfn xmlns="http://www.w3.org/1999/xhtml" id="{$osisID}">
          <xsl:apply-templates mode="xhtml" select="node()"/>
        </dfn>
      </when>
      <!-- fb2 -->
      <when test="lower-case($outputfmt)='fb2'">
        <h4 xmlns="http://www.w3.org/1999/xhtml">
          <xsl:call-template name="class"/>
          <xsl:apply-templates mode="xhtml" select="node()"/>
        </h4>
      </when>
      <!-- epub -->
      <otherwise>
        <article xmlns="http://www.w3.org/1999/xhtml">
          <xsl:call-template name="class"/>
          <dfn xmlns="http://www.w3.org/1999/xhtml" id="{$osisID}">
            <xsl:apply-templates mode="xhtml" select="node()"/>
          </dfn>
        </article>
      </otherwise>
    </choose>
  </template>
  
  <!-- Table of Contents & milestone x-usfm-tocN -->
  <template name="WriteTableOfContentsEntry"  match="osis:milestone[@type=concat('x-usfm-toc', $tocnumber)]" mode="xhtml" priority="2">
    <!-- Determine TOC hierarchy from OSIS hierarchy, but if the level is explicitly specified, that value is always 
    used (and this is done by prepending "[levelN] " to the "n" attribute value of a milestone toc tag). -->
    <variable name="toclevelEXPLICIT" select="if (matches(@n, '^\[level\d\] ')) then substring(@n, 7, 1) else '0'"/>
    <variable name="toclevelOSIS">
      <variable name="isBible" select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork][child::osis:type[@type='x-bible']]"/>
      <choose>
        <when test="$isBible">
          <variable name="bookGroupLevel" select="count(ancestor::osis:div[@type='bookGroup']/*[1][self::osis:div]/osis:milestone[@type=concat('x-usfm-toc', $tocnumber)][1])"/>
          <choose>
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
    <variable name="toclevel" select="if ($toclevelEXPLICIT != '0') then $toclevelEXPLICIT else $toclevelOSIS"/>
    
    <!-- Determine TOC title according to the type of element this is -->
    <variable name="titletext">
      <choose>
        <when test="self::osis:milestone[@type=concat('x-usfm-toc', $tocnumber) and @n]"><value-of select="if ($toclevelEXPLICIT != '0') then substring(@n, 10) else @n"/></when>
        <when test="self::osis:chapter[@sID]">
          <choose>
            <when test="following-sibling::*[1][self::osis:div[@title='x-chapterLabel']]"><value-of select="string(following-sibling::osis:div[@title='x-chapterLabel'])"/></when>
            <otherwise><value-of select="tokenize(@sID, '\.')[last()]"/></otherwise>
          </choose>
        </when>
        <when test="self::osis:seg[@type='keyword']"><value-of select="string()"/></when>
        <otherwise><value-of select="position()"/></otherwise>
      </choose>
    </variable>
    
    <h1 xmlns="http://www.w3.org/1999/xhtml" class="xsl-toc-entry" toclevel="{$toclevel}"><xsl:value-of select="$titletext"/></h1>
    
  </template>
  
  <!-- Titles -->
  <template match="osis:title" mode="xhtml">
    <variable name="level" select="if (@level) then @level else '1'"/>
    <element name="h{$level}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml" select="node()"/>
    </element>
  </template>
  
  <!-- Parallel passage titles become secondary titles !-->
  <xsl:template match="osis:title[@type='parallel']">
    <h2 xmlns="http://www.w3.org/1999/xhtml" ><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></h2>
  </xsl:template>
  
  <template match="osis:catchWord" mode="xhtml">
    <i xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></i>
  </template>
  
  <template match="osis:cell" mode="xhtml">
    <td xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></td>
  </template>
  
  <template match="osis:caption" mode="xhtml">
    <figcaption xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></figcaption>
  </template>
  
  <template match="osis:figure" mode="xhtml">
    <img xmlns="http://www.w3.org/1999/xhtml">
      <xsl:call-template name="class"/>
      <xsl:attribute name="src">
        <xsl:value-of select="if (starts-with(@src, './')) then concat('.', @src) else (if (starts-with(@src, '/')) then concat('..', @src) else concat('../', @src))"/>
      </xsl:attribute>
    </img>
    <xsl:apply-templates mode="xhtml" select="node()"/>
  </template>
  
  <template match="osis:foreign" mode="xhtml">
    <span xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></span>
  </template>

  <xsl:template match="osis:head">
    <h2 xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></h2>
  </xsl:template>
  
  <template match="osis:hi[@type='bold']" mode="xhtml"><b xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></b></template>
  <template match="osis:hi[@type='emphasis']" mode="xhtml"><em xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></em></template>
  <template match="osis:hi[@type='italic']" mode="xhtml"><i xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></i></template>
  <template match="osis:hi[@type='line-through']" mode="xhtml"><s xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></s></template>
  <template match="osis:hi[@type='sub']" mode="xhtml"><sub xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></sub></template>
  <template match="osis:hi[@type='super']" mode="xhtml"><sup xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></sup></template>
  <template match="osis:hi[@type='underline']" mode="xhtml"><u xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></u></template>
  <template match="osis:hi[@type='small-caps']" mode="xhtml"><span xmlns="http://www.w3.org/1999/xhtml" style="font-variant:small-caps"><xsl:apply-templates mode="xhtml" select="node()"/></span></template>
  
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
  
  <template match="osis:milestone[@type='pb']" mode="xhtml" priority="2">
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></p>
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
  
  <template match="osis:note" mode="xhtml">
    <choose>
      <when test="lower-case($epub3)!='false'">
        <sup xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><a epub:type="noteref" href="#{replace(@osisID, '!', '_')}">*</a></sup>
      </when>
      <otherwise>
        <sup xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><a href="#{replace(@osisID, '!', '_')}" id="Ref{replace(@osisID, '!', '_')}">*</a></sup>
      </otherwise>
    </choose>
  </template>
  
  <template match="osis:rdg" mode="xhtml">
    <span xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></span>
  </template>
  
  <!-- IMPORTANT: hrefs written here are framents only and do NOT include the file! This XSLT cannot easily 
  predict what file targets will end up in. So for these links to work, the file must be added by a postprocessor. -->
  <template match="osis:reference" mode="xhtml">
    <choose>
      <when test="lower-case($outputfmt)!='fb2'">
        <choose>
          <when test="starts-with(@type, 'x-gloss')">
            <variable name="osisRef" select="if (contains(@osisRef, ':')) then @osisRef else concat(//osis:osisText[1]/@osisRefWork, ':', @osisRef)"/>
            <a xmlns="http://www.w3.org/1999/xhtml" href="#{$osisRef}"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></a>
          </when>
          <otherwise>
            <variable name="osisRefA">
              <variable name="osisRef" select="replace(@osisRef, '^[^:]*:', '')"/>
              <choose>
                <when test="contains($osisRef, '!')"><value-of select="replace($osisRef, '!', '_')"/></when>
                <otherwise>
                  <variable name="osisRefStart" select="tokenize($osisRef, '\-')[1]"/>
                  <value-of select="if (count(tokenize($osisRefStart, '\.'))=1) then concat($osisRefStart, '.1.1') else (if (count(tokenize($osisRefStart, '\.'))=2) then concat($osisRefStart, '.1') else $osisRefStart)"/>
                </otherwise>
              </choose>
            </variable>
            <a xmlns="http://www.w3.org/1999/xhtml" href="#{$osisRefA}"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></a>
          </otherwise>
        </choose>
      </when>
      <otherwise>%&amp;x-glossary-link&amp;%<xsl:apply-templates mode="xhtml" select="node()"/></otherwise>
    </choose>
  </template>
  
  <template match="osis:row" mode="xhtml">
    <tr xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></tr>
  </template>
  
  <template match="osis:transChange" mode="xhtml">
    <span xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></span>
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
          <dc:publisher><xsl:value-of select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork]/osis:publisher[not(@type)]/text()"/></dc:publisher>
          <dc:title><xsl:value-of select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork]/osis:title/text()"/></dc:title>
          <dc:language><xsl:value-of select="//osis:work[@osisWork = //osis:osisText[1]/@osisIDWork]/osis:language/text()"/></dc:language>
        </metadata>
        <manifest>
          <xsl:apply-templates select="node()">
            <xsl:with-param name="contentopf" select="'manifest'" tunnel="yes"/>
          </xsl:apply-templates>
          <xsl:apply-templates select="node()" mode="glossaries">
            <xsl:with-param name="contentopf" select="'manifest'" tunnel="yes"/>
            <xsl:with-param name="figures-already-in-manifest" select="//osis:figure/@src" tunnel="yes"/>
          </xsl:apply-templates>
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
          <xsl:choose xmlns="http://www.w3.org/1999/XSL/Transform">
            <when test="matches(lower-case(.), '(jpg|jpeg|jpe)')">image/jpeg</when>
            <when test="ends-with(lower-case(.), 'gif')">image/gif</when>
            <when test="ends-with(lower-case(.), 'png')">image/png</when>
            <otherwise>application/octet-stream</otherwise>
          </xsl:choose>
        </xsl:attribute>
      </item>
    </for-each>
  </template>
  
</stylesheet>
