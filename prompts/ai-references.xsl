<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!--
    Update referenceOsisID below and run:
      saxonb-xslt -l -ext:on -xsl:/path/to/ai-references.xsl -s:/path/to/osis.xml -o:ai-references.txt
    Then add ai-references.txt and the glossary definition to the glossary_link_analysis.txt prompt, and give it to AI.
  -->
 
  <import href="../lib/bible/containers.xsl"/>

  <output method="text" encoding="UTF-8"/>
  
  <variable name="referenceOsisID" select="'TYVDICT:Виноград_32_сы_32_базар_32_о_1187_гар'"/>

  <!-- ========================================================= -->
  <!-- STEP 1: Build a temporary tree with one reference         -->
  <!-- ========================================================= -->

  <variable name="containers">
    <apply-templates mode="containers.xsl" select="/"/>
  </variable>
    
  <variable name="cleanDoc">
    <apply-templates select="$containers" mode="strip-tags"/>
  </variable>

  <!-- Default: remove tags -->
  <template match="node()" mode="strip-tags">
    <apply-templates select="node()" mode="strip-tags"/>
  </template>
  
  <!-- Remove these nodes entirely -->
  <template match="header | comment() | element()[@resp='x-oc']" mode="strip-tags" priority="1"/>

  <!-- Keep these elements entirely -->
  <template match="div
    | chapter
    | verse
    | note
    | reference[@osisRef = $referenceOsisID]"
    mode="strip-tags">
    <copy>
      <apply-templates select="@*|node()" mode="strip-tags"/>
    </copy>
  </template>

  <!-- Keep all text -->
  <template match="text()" mode="strip-tags" priority="1">
    <copy/>
  </template>

  <!-- Keep all attributes -->
  <template match="@*" mode="strip-tags">
    <copy/>
  </template>

  <!-- ========================================================= -->
  <!-- STEP 2: Run extraction on cleaned tree                    -->
  <!-- ========================================================= -->

  <template match="/">

    <for-each select="$cleanDoc//reference">

      <variable name="id" select="ancestor::*[@osisID][1]"/>

      <value-of select="$id/@osisID"/>
      
      <text>&#9;</text>

      <call-template name="emit-text">
        <with-param name="nodes" select="$id/node()[not(self::chapter | self::verse | self::note)]"/>
      </call-template>
      
      <text>&#10;</text>

    </for-each>

  </template>
  
  <!-- ========================================================= -->
  <!-- Utility: Emit line of text with marked glossary reference -->
  <!-- ========================================================= -->

  <template name="emit-text">
    <param name="nodes"/>

    <variable name="result" as="text()*">
      <for-each select="$nodes">
        <choose>

          <!-- Mark encoded glossary reference -->
          <when test="self::reference">
            <value-of select="concat('*', string-join(.//text(), ' '), '*')"/>
          </when>

          <!-- Recurse into elements -->
          <when test="self::element()">
            <text> </text>
            <call-template name="emit-text">
              <with-param name="nodes" select="node()"/>
            </call-template>
            <text> </text>
          </when>

          <!-- Plain text -->
          <when test="self::text()">
            <value-of select="."/>
          </when>

        </choose>
      </for-each>
    </variable>
    
    <value-of select="normalize-space(string-join($result, ' '))"/>
  </template>

</stylesheet>
