<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:html="http://www.w3.org/1999/xhtml"
 xmlns:epub="http://www.idpf.org/2007/ops"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace">
 
  <!-- TRANSFORM AN OSIS FILE INTO A SET OF CALIBRE PLUGIN INPUT XHTML FILES
  This transform may be tested from command line (and outputs will appear in an xhtml directory): 
  $ saxonb-xslt -ext:on -xsl:osis2xhtml.xsl -s:input-osis.xml tocnumber=2 optionalBreaks='false' epub3='true' outputfmt='epub'
  -->
 
  <!-- Input parameters which may be passed into this XSLT -->
  <param name="tocnumber" select="2"/>
  <param name="optionalBreaks" select="false"/>
  <param name="epub3" select="true"/>
  <param name="outputfmt" select="epub"/>

  <output indent="yes"/>
  <strip-space elements="*"/>
  <!-- <preserve-space elements="*"/> -->
  
  <!-- Pass over all nodes that don't match another template (output nothing) -->
  <template match="node()"><apply-templates select="node()"/></template>
  
  <!-- Separate the OSIS file into separate xhtml files -->
  <template match="osis:osisText">
    <call-template name="write-file"><with-param name="filename" select="'bible-introduction'"/></call-template>
  </template>
  
  <template match="osis:div[@type='bookGroup']">
    <call-template name="write-file"><with-param name="filename" select="concat('bookGroup-introduction_', position())"/></call-template>
  </template>
  
  <template match="osis:div[@type='book']">
    <call-template name="write-file"><with-param name="filename" select="@osisID"/></call-template>
  </template>
  
  <template match="osis:div[@type='glossary']">
    <call-template name="write-file"><with-param name="filename" select="concat('glossary_', position())"/></call-template>
  </template>
  
  <!-- Write each xhtml file's contents, choosing which child nodes to write and which to drop -->
  <template name="write-file">
    <param name="filename"/>
    <result-document method="xml" href="{$filename}.xhtml">
      <html xmlns="http://www.w3.org/1999/xhtml">
        <head>
          <meta name="generator" content="OSIS"/>
          <title><xsl:value-of select="$filename"/></title>
          <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
          <link href="ebible.css" type="text/css" rel="stylesheet"/>
        </head>
        <body class="calibre">
          <choose xmlns="http://www.w3.org/1999/XSL/Transform">
            <when test="$filename='bible-introduction'">
              <apply-templates mode="xhtml" select="node()[not(ancestor-or-self::osis:header)][not(ancestor-or-self::osis:div[@type='bookGroup'])]"/>
              <hr xmlns="http://www.w3.org/1999/xhtml"/>
              <apply-templates mode="footnotes" select="node()[not(ancestor-or-self::osis:header)][not(ancestor-or-self::osis:div[@type='bookGroup'])]"/>
            </when>
            <when test="substring($filename, 1, 9)='bookGroup'">
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
    <apply-templates select="node()"/>
  </template>
  
  <!-- Place footnotes at the bottom of the file -->
  <template match="node()" mode="footnotes"><apply-templates mode="footnotes" select="node()"/></template>
  <template match="osis:note" mode="footnotes">
    <aside xmlns="http://www.w3.org/1999/xhtml" epub:type="footnote">
      <xsl:attribute name="id" select="replace(@osisID, '!', '_')"/>
      <p>* <xsl:apply-templates mode="xhtml" select="node()"/></p>
    </aside>
  </template>
  

  <!-- THE FOLLOWING TEMPLATES CONVERT OSIS INTO HTML MARKUP AS DESIRED -->
  
  <!-- This template adds a class attribute when it's called -->
  <template name="class">
    <param name="inputclass"/>
    <variable name="class">
      <choose>
        <when test="osis:foreign">foreign</when>
        <when test="osis:head">heading</when>
        <when test="osis:l"><value-of select="string-join(('poetic-line', (if (@level) then concat('x-indent-', @level) else '')), ' ')"/></when>
      </choose>
    </variable>
    <if test="$inputclass!='' or $class!='' or @type or @subType"><attribute name="class"><value-of select="normalize-space(string-join(($class, @type, @subType, $inputclass), ' '))"/></attribute></if>
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
  
  <!-- Remove these elements entirely -->
  <template match="osis:verse[@eID] | osis:chapter[@eID] | osis:index | osis:name | osis:milestone | osis:title[@type='x-chapterLabel']" mode="xhtml"/>
  
  <!-- Remove these tags (keep their content) -->
  <template match="osis:name | osis:seg" mode="xhtml">
    <xsl:apply-templates mode="xhtml" select="node()"/>
  </template>
  
  <!-- Verses -->
  <template match="osis:verse[@sID and @osisID]" mode="xhtml">
    <variable name="first" select="tokenize(@osisID, '\s+')[1]"/>
    <variable name="last" select="tokenize(@osisID, '\s+')[last()]"/>
    <sup xmlns="http://www.w3.org/1999/xhtml">
      <xsl:value-of select="if ($first=$last) then tokenize($first, '\.')[last()] else concat(tokenize($first, '\.')[last()], '-', tokenize($last, '\.')[last()])"/>
    </sup>
  </template>
  
  <!-- Chapters -->
  <template match="osis:chapter[@sID and @osisID]" mode="xhtml">
    <variable name="chapter" select="tokenize(@osisID, '\.')[last()]"/>
    <variable name="toclevel" select="count(ancestor::*/osis:milestone[@type=concat('x-usfm-toc', $tocnumber)])+1"/>
    <variable name="title">
      <xsl:choose>
        <xsl:when test="count(following-sibling::*[1][@type='x-chapterLabel'])"><xsl:value-of select="following-sibling::*[1]/text()"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="$chapter"/></xsl:otherwise>
      </xsl:choose>
    </variable>
    <div xmlns="http://www.w3.org/1999/xhtml" class="toc-title" toclevel="{$toclevel}"><xsl:value-of select="$title"/></div>
    <h3 xmlns="http://www.w3.org/1999/xhtml" class="x-chapter-title">
      <xsl:attribute name="chapter"><xsl:value-of select="$chapter"/></xsl:attribute>
      <xsl:value-of select="$title"/>
    </h3>
  </template>
  
  <!-- Glossary keywords in TOC -->
  <template match="osis:seg[@type='keyword']" mode="xhtml" priority="2">
    <variable name="toclevel" select="count(ancestor::*/osis:milestone[@type=concat('x-usfm-toc', $tocnumber)])+1"/>
    <div xmlns="http://www.w3.org/1999/xhtml" class="toc-title" toclevel="{$toclevel}"><xsl:value-of select="./text()"/></div>
    <choose>
      <!-- mobi -->
      <when test="lower-case($outputfmt)='mobi'">
        <div xmlns="http://www.w3.org/1999/xhtml" class="glossary-entry">
          <dfn xmlns="http://www.w3.org/1999/xhtml">
            <xsl:apply-templates mode="xhtml" select="node()"/>
          </dfn>
        </div>
      </when>
      <!-- fb2 -->
      <when test="lower-case($outputfmt)='fb2'">
        <h4 xmlns="http://www.w3.org/1999/xhtml">
          <xsl:apply-templates mode="xhtml" select="node()"/>
        </h4>
      </when>
      <!-- epub -->
      <otherwise>
        <article xmlns="http://www.w3.org/1999/xhtml" class="glossary-entry">
          <dfn xmlns="http://www.w3.org/1999/xhtml">
            <xsl:apply-templates mode="xhtml" select="node()"/>
          </dfn>
        </article>
      </otherwise>
    </choose>
  </template>
  
  <!-- Table of Contents -->
  <template match="osis:milestone[@type=concat('x-usfm-toc', $tocnumber)]" mode="xhtml" priority="2">
    <variable name="toclevel" select="count(ancestor-or-self::*/osis:milestone[@type=concat('x-usfm-toc', $tocnumber)])"/>
    <div xmlns="http://www.w3.org/1999/xhtml" class="toc-title" toclevel="{$toclevel}"><xsl:value-of select="./@n"/></div>
  </template>
  
  <!-- Titles -->
  <template match="osis:title" mode="xhtml">
    <variable name="level" select="if (@level) then @level else '1'"/>
    <element name="h{$level}" namespace="http://www.w3.org/1999/xhtml">
      <call-template name="class"/>
      <apply-templates mode="xhtml" select="node()"/>
    </element>
  </template>
  
  <template match="osis:catchWord" mode="xhtml">
    <i xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></i>
  </template>
  
  <template match="osis:cell" mode="xhtml">
    <td xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></td>
  </template>
  
  <template match="osis:caption" mode="xhtml">
    <figcaption xmlns="http://www.w3.org/1999/xhtml"><xsl:apply-templates mode="xhtml" select="node()"/></figcaption>
  </template>
  
  <template match="osis:figure" mode="xhtml">
    <figure xmlns="http://www.w3.org/1999/xhtml"><img><xsl:attribute name="src"><xsl:value-of select="@src"/></xsl:attribute></img><xsl:apply-templates mode="xhtml" select="node()"/></figure>
  </template>
  
  <template match="osis:foreign" mode="xhtml">
    <span xmlns="http://www.w3.org/1999/xhtml" class="foreign"><xsl:apply-templates mode="xhtml" select="node()"/></span>
  </template>
  
  <template match="osis:head" mode="xhtml">
    <div xmlns="http://www.w3.org/1999/xhtml" class="heading"><xsl:apply-templates mode="xhtml" select="node()"/></div>
  </template>
  
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
    <if test="lower-case($optionalBreaks)!='false' or @type!='x-optional'"><br xmlns="http://www.w3.org/1999/xhtml"/></if>
    <apply-templates mode="xhtml" select="node()"/>
  </template>
  
  <template match="osis:l" mode="xhtml">
    <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></div>
  </template>
  
  <template match="osis:lg" mode="xhtml">
    <div xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></div>
  </template>
  
  <template match="osis:list" mode="xhtml">
    <ul xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></ul>
  </template>
  
  <template match="osis:milestone[@type='pb'][not(ancestor::osis:p)]" mode="xhtml" priority="2">
    <p xmlns="http://www.w3.org/1999/xhtml" class="page-break"></p>
  </template>
  
  <template match="osis:p[child::osis:milestone[@type='pb']]" mode="xhtml">
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/>
      <xsl:apply-templates mode="xhtml" select="node()[not(following-sibling::osis:milestone[@type='pb'])]"/>
    </p>
    <p xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"><xsl:with-param name="inputclass" select="'page-break'"/></xsl:call-template>
      <xsl:apply-templates mode="xhtml" select="node()[following-sibling::osis:milestone[@type='pb']]"/>
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
    <span xmlns="http://www.w3.org/1999/xhtml" class="alt-var"><xsl:apply-templates mode="xhtml" select="node()"/></span>
  </template>
  
  <template match="osis:reference" mode="xhtml">
    <choose>
      <when test="lower-case($outputfmt)!='fb2'">
        <span xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></span>
      </when>
      <otherwise>%&amp;x-glossary-link&amp;%<xsl:apply-templates mode="xhtml" select="node()"/></otherwise>
    </choose>
  </template>
  
  <template match="osis:row" mode="xhtml">
    <tr xmlns="http://www.w3.org/1999/xhtml"><xsl:call-template name="class"/><xsl:apply-templates mode="xhtml" select="node()"/></tr>
  </template>
  
  <template match="osis:transChange" mode="xhtml">
    <span xmlns="http://www.w3.org/1999/xhtml" class="transChange"><xsl:apply-templates mode="xhtml" select="node()"/></span>
  </template>

</stylesheet>
