<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:fb="http://www.gribuser.ru/xml/fictionbook/2.0"
 xmlns:xlink="http://www.w3.org/1999/xlink"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <xsl:import href="../functions.xsl"/>
 
  <!-- TRANSFORM A BIBLE OSIS FILE, AND ITS REFERENCE FILES, INTO AN FB2 FILE
  To run this transform from the command line: 
  $ saxonb-xslt -ext:on -xsl:osis2fb2.xsl -s:main.osis.xml -o:output.fb2
  -->
  
  <!-- Input parameters which may be passed into this XSLT -->
  <param name="tocnumber" select="2"/>                 <!-- Use \toc1, \toc2 or \toc3 tags for creating the TOC -->
  <param name="css" select="'ebible.css,module.css'"/> <!-- Comma separated list of css files -->
  <param name="glossthresh" select="20"/>
  
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="yes"/>
  
  <variable name="mainInputOSIS" select="/"/>

  <!-- The main input OSIS file must contain a work element corresponding to each OSIS file referenced in the eBook, and all input OSIS files must reside in the same directory -->
  <variable name="referencedOsisDocs" select="(/) | //work[@osisWork != //osisText/@osisIDWork]/doc(concat($DOCDIR, @osisWork, '.xml'))"/>
  <variable name="allOsisFiles" select="$mainInputOSIS | $referencedOsisDocs"/>

  <!-- ROOT NODE TEMPLATE FOR MAIN INPUT OSIS FILE -->
  <template match="/">
    <call-template name="oc:prepareRunTime"/>
    
    <FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
      
      <stylesheet type="text/css">
        <for-each select="tokenize($css, '\s*,\s*')" xmlns="http://www.w3.org/1999/XSL/Transform">
          <if test="unparsed-text-available(.)">
            <text>&#xa;</text><value-of select="unparsed-text(.)"/>
          </if>
          <if test="not(unparsed-text-available(.))">
            <call-template name="Error"><with-param name="msg" select="concat('Could not find CSS file: ', .)"/></call-template>
          </if>
        </for-each>
      </stylesheet>
      
      <description>
        <xsl:apply-templates select="//header"/>
      </description>
      
      <body>
        <xsl:call-template name="WriteRootTOC"/>
      </body>
      
      <xsl:for-each select="$allOsisFiles//osisText/*[not(self::header)]">
        <body>
          <xsl:apply-templates select="."/>
        </body>
      </xsl:for-each>
      
      <xsl:if test="$allOsisFiles//note">
        <body name="notes">
          <xsl:for-each select="$allOsisFiles//note">
            <xsl:variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
            <section id="n_{./ancestor::osisText[1]/@osisIDWork[1]}_{$osisIDid}"><p><a href="s_{./ancestor::osisText[1]/@osisIDWork[1]}_{$osisIDid}"><xsl:call-template name="getFootnoteSymbol"/></a><xsl:text> </xsl:text><xsl:apply-templates/></p></section>
          </xsl:for-each>
        </body>
      </xsl:if>
      
      <xsl:for-each select="distinct-values(($allOsisFiles//figure/@src))">
        <binary id="fig_{replace(replace(., '^.*?([^/]+)$', '$1'), '[\.\s]', '_')}" 
                content-type="image/{if (ends-with(lower-case(.), 'jpg')) then 'jpeg' else replace(lower-case(.), '^.*?([^\.]+)$', '$1')}">
          <xsl:value-of select="oc:read-binary-resource(.)"/>
        </binary>
      </xsl:for-each>
    </FictionBook>
    <call-template name="oc:cleanupRunTime"/>
  </template>
  
  <!-- This template is called after writing the first body element -->
  <template name="WriteRootTOC">
  </template>
  
  <!-- This template may be called from any note. It returns a symbol or number based on that note's type and OSIS context -->
  <template name="getFootnoteSymbol">
    <param name="classes"/>
    <variable name="inVerse" select="preceding::verse[1]/@sID = following::verse[1]/@eID or preceding::verse[1]/@sID = descendant::verse[1]/@eID or count(ancestor::title[@canonical='true'])"/>
    <choose>
      <when test="$inVerse and not(@type='crossReference')">*</when>
      <when test="$inVerse and @subType='x-parallel-passage'">•</when>
      <when test="$inVerse">+</when>
      <otherwise>[<xsl:call-template name="getFootnoteNumber"/>]</otherwise>
    </choose>
  </template>
  
  <!-- This template may be called from any note. It returns the number of that note within its output file -->
  <template name="getFootnoteNumber">
    <choose>
      <when test="ancestor::div[@type='glossary']">
        <choose>
          <when test="not(descendant-or-self::seg[@type='keyword']) and count(preceding::seg[@type='keyword']) = count(ancestor::div[@type='glossary'][1]/preceding::seg[@type='keyword'])">
            <value-of select="count(preceding::note) - count(ancestor::div[@type='glossary'][1]/preceding::note) + 1"/>
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
  
</stylesheet>
