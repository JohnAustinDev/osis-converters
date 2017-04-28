<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:html="http://www.w3.org/1999/xhtml"
 xmlns:epub="http://www.idpf.org/2007/ops"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace">
 
 <!-- Run like this: 
 
 $ saxonb-xslt -ext:on -xsl:osis2xthml.xsl -s:osis.xml
 
 Outputs will appear in an xhtml directory
 
 -->
 
 <!-- TRANSFORM AN OSIS FILE INTO A SET OF CALIBRE PLUGIN INPUT XHTML FILES -->
  
  <!-- Separate any Bible introduction, testament introductions and Bible books into separate xhtml files -->
  <template match="/|node()">
    <choose>
      <when test="self::osis:osisText">
        <call-template name="write-file"><with-param name="filename" select="'bible-introduction'"/></call-template>
      </when>
      <when test="self::osis:div[@type='bookGroup']">
        <call-template name="write-file"><with-param name="filename" select="concat('bookGroup-introduction_', position())"/></call-template>
      </when>
      <when test="self::osis:div[@type='book']">
        <call-template name="write-file"><with-param name="filename" select="@osisID"/></call-template>
      </when>
      <otherwise>
        <apply-templates select="node()"/>
      </otherwise>
    </choose>
  </template>
  
  <!-- Write each xhtml file -->
  <template name="write-file">
    <param name="filename"/>
    <result-document method="xml" href="xhtml/{$filename}.xhtml">
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
            </when>
            <when test="substring($filename, 1, 9)='bookGroup'">
              <apply-templates mode="xhtml" select="node()[not(ancestor-or-self::osis:div[@type='book'])]"/>
            </when>
            <otherwise><apply-templates mode="xhtml" select="*"/></otherwise>
          </choose>
        </body>
      </html>
    </result-document>
    <apply-templates select="node()"/>
  </template>
  
  
  <!-- THE FOLLOWING CONVERTINGS OSIS INTO THE HTML MARKUP THAT IS DESIRED -->
  
  <!-- Text and attributes are just copied by default -->
  <template match="text()|@*" mode="xhtml"><copy/></template>
  
  <!-- Remove chapter and verse tags -->
  <template match="osis:verse | osis:chapter" mode="xhtml"/>
  
  <!-- By default, elements just get their namespace changed from OSIS to HTML-->
  <template match="*" mode="xhtml">
    <element name="{local-name()}" namespace="http://www.w3.org/1999/xhtml">
      <apply-templates mode="xhtml" select="node()|@*"/>
    </element>
  </template>
  
  <!-- Convert OSIS titles to HTML heading tags -->
  <template match="osis:title" mode="xhtml">
    <variable name="level"><value-of select="if (@level) then @level else '1'"/></variable>
    <element name="h{$level}" namespace="http://www.w3.org/1999/xhtml">
      <if test="./@subType"><attribute name="class"><value-of select="./@subType"/></attribute></if>
      <apply-templates mode="xhtml" select="node()"/>
    </element>
  </template>

</stylesheet>
