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
  
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
 
  <template match="/">
    <variable name="pass1"><apply-templates select="." mode="divs"/></variable>
    <apply-templates select="$pass1/node()"/>
  </template>
  
  <template match="div[matches(@type, '[Ss]ection')]" mode="divs"><apply-templates mode="divs"/></template>
  
  <template match="*[child::chapter[@sID]]">
    <copy><apply-templates select="@*"/>
      <for-each-group select="node()" group-adjacent="count(preceding::chapter[@sID]) + count(self::chapter[@sID])">
        <choose>
          <when test="current-grouping-key() = 0"><apply-templates select="current-group()"/></when>
          <otherwise>
            <variable name="title">
              <choose>
                <when test="current-group()[1]/following::*[1][self::title[@type='x-chapterLabel']]">
                  <value-of select="string(current-group()[1]/following::*[1][self::title[@type='x-chapterLabel']])"/>
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
            <div xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace" 
                type="chapter"><xsl:attribute name="osisID" select="$title"/>
              <xsl:apply-templates select="current-group()"/>
            </div>
          </otherwise>
        </choose>
      </for-each-group>
    </copy>
  </template>
  
  <template match="chapter"/>
  
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
      <if test="generate-id(text()[1]) = generate-id(preceding::chapter[@sID][1]/following::text()[normalize-space()][not(ancestor::title)][not(ancestor::figure)][1])">
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
  
  <template match="title/@type[. = 'x-chapterLabel']"/>

</stylesheet>
