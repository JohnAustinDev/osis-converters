<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
  
  <!-- This stylesheet converts osis into Children's Bible osis markup -->
 
  <import href="../../functions.xsl"/>
  
  <!-- Use \toc1, \toc2 or \toc3 tags for creating the TOC -->
  <variable name="tocnumber" select="2"/>
  
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
 
  <template match="/">
    <!-- Re-section the entire OSIS file by removing all divs, then using only toc2 cb-section markers and chapter tags -->
    <variable name="pass1"><apply-templates select="." mode="removeDivs"/></variable>
    <variable name="pass2"><apply-templates select="$pass1/node()" mode="addSections"/></variable>
    <apply-templates select="$pass2/node()"/>
  </template>
  <template match="div" mode="removeDivs"><apply-templates mode="#current"/></template>
  <template match="osisText" mode="addSections">
    <copy><apply-templates select="@*" mode="#current"/>
      <for-each select="header"><apply-templates select="." mode="#current"/></for-each>
      <div xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace" type="book" osisID="{oc:encodeOsisRef(/osis:osis/osis:osisText/osis:header/osis:work/osis:title)}">
        <xsl:for-each-group select="node()[not(local-name()='header')]"
            group-adjacent="count(preceding::milestone[@type=concat('x-usfm-toc', $tocnumber)]) + count(self::milestone[@type=concat('x-usfm-toc', $tocnumber)])">
          <xsl:variable name="id" select="if (current-group()[1][@n][self::milestone[@type=concat('x-usfm-toc', $tocnumber)]]) then current-group()[1]/@n else 'Book Introduction'"/>
          <xsl:if test="not($id = 'Book Introduction') or current-group()[normalize-space()]">
            <div type="majorSection" osisID="{oc:encodeOsisRef($id)}"><xsl:apply-templates select="current-group()" mode="#current"/></div>
          </xsl:if>
        </xsl:for-each-group>
      </div>
    </copy>
  </template>
  
  <!-- Specify explicit TOC levels -->
  <template match="milestone[@type=concat('x-usfm-toc', $tocnumber)]/@n">
    <attribute name="n" select="concat('[level', (count(ancestor-or-self::div[@type=('book','majorSection','chapter')])-1), ']', .)"/>
  </template>
  
  <!-- Convert milestone chapter tags into containers -->
  <template match="*[child::chapter[@sID]]">
    <copy><apply-templates select="@*"/>
      <for-each-group select="node()" group-adjacent="count(preceding-sibling::chapter[@sID]) + count(self::chapter[@sID])">
        <choose>
          <when test="current-grouping-key() = 0"><apply-templates select="current-group()"/></when>
          <otherwise>
            <variable name="title">
              <choose>
                <when test="current-group()[1]/following::*[1][self::title[@type='x-chapterLabel']]">
                  <value-of select="current-group()[1]/following::*[1][self::title[@type='x-chapterLabel']]"/>
                </when>
                <otherwise>
                  <value-of select="@osisID"/>
                  <call-template name="Error">
                    <with-param name="msg">No Chapter label for chapter sID="<value-of select="current-group()[1]/@osisID"/>".</with-param>
                    <with-param name="exp">All Children's Bible chapter start milestone tags must be following by a title of type="x-chapterLabel".</with-param>
                  </call-template>
                </otherwise>
              </choose>
            </variable>
            <div xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace" type="chapter">
              <xsl:attribute name="osisID" select="oc:encodeOsisRef($title)"/>
              <milestone type="{concat('x-usfm-toc', $tocnumber)}" n="[level2]{$title}"/>
              <xsl:apply-templates select="current-group()"/>
            </div>
          </otherwise>
        </choose>
      </for-each-group>
    </copy>
  </template>
  <template match="chapter"/>
  
  <!-- Add chapter images after title if there isn't one -->
  <template match="title[@type = 'x-chapterLabel']">
    <copy><apply-templates select="node()|@*"/></copy>
    <variable name="chapid" select="preceding-sibling::*[1][local-name() = 'chapter']/@osisID"/>
    <variable name="imgnum" select="if (matches($chapid, '^X\-OTHER\.\d+$')) then replace($chapid, '^X\-OTHER\.(\d+)$', '$1') else ''"/>
    <if test="$imgnum and not(following-sibling::*[1][local-name()='figure'])">
      <figure xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace" subType="x-text-image" src="./images/{format-number(xs:integer(number($imgnum)), '000')}.jpg"></figure>
    </if>
  </template>
  <template match="title/@type[. = 'x-chapterLabel']"/>
  
  <!-- Add special Children's Bible classes -->
  <template match="title[@type='parallel'][count(@*)=1]">
    <title xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace" 
        type="parallel" level="2" subType="x-right"><hi type="italic" subType="x-ref-cb"><xsl:apply-templates select="node()"/></hi></title>
  </template>

  <template match="figure[@src][@size='col']">
    <figure xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace" 
        subType="x-text-image"><xsl:apply-templates select="node()|@*"/></figure>
  </template>

  <template match="p | lg">
    <copy>
      <if test="generate-id(descendant::text()[normalize-space()][1]) = generate-id(preceding::chapter[@sID][1]/following::text()[normalize-space()][not(ancestor::title)][not(ancestor::figure)][1])">
        <attribute name="subType" select="'x-p-first'"/>
      </if>
      <apply-templates select="node()|@*"/>
    </copy>
  </template>
  
  <!-- Make line groups indented -->
  <template match="l[@level='1']">
    <copy><attribute name="type" select="'x-indent'"/><apply-templates select="node()|@*"/></copy>
  </template>
  
  <!-- Remove soft-hyphens from chapter names (osisIDs) -->
  <template match="div[@osisID]/@osisID"><copy><value-of select="replace(., codepoints-to-string(173), '')"/></copy></template>

</stylesheet>
