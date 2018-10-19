<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT will do the following:
  1) Check and warn about non GLO major divs in the glossary
  2) Read applicable glossary scope comments and write them to parent glossary scope
  3) Separate all glossary keywords into their own child divs
  4) Assign osisIDs to keywords
  5) Find case insensitive identical keywords from glossary divs, and aggregate them into a new x-aggregate div
  -->
 
  <import href="../functions.xsl"/>
  
  <!-- Call with DEBUG='true' to turn on debug messages -->
  <param name="DEBUG" select="'false'"/>
  
  <variable name="MOD" select="//osisText/@osisIDWork"/>
  
  <!-- Get a list of applicable keywords which are NOT unique (by a case insensitive comparison) -->
  <variable name="duplicate_keywords" select="//seg[@type='keyword']
      [ancestor::div[@type='glossary']]
      [lower-case(string()) = following::seg[@type='keyword'][ancestor::div[@type='glossary']]/lower-case(string())]
      [not(lower-case(string()) = preceding::seg[@type='keyword'][ancestor::div[@type='glossary']]/lower-case(string()))]"/>
  
  <!-- By default copy everything as is, for all modes -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <!-- Root template -->
  <template match="/">
    <for-each select="//div[@type and not(ancestor-or-self::div[@type='glossary'])]">
      <call-template name="Warn"><with-param name="msg">The div with type="<value-of select="@type"/>" will NOT appear in the SWORD glossary module, because only "\id GLO" type USFM files will appear there.</with-param></call-template>
    </for-each>
    <variable name="separateKeywords"><apply-templates mode="separateKeywordMode"/></variable>
    <variable name="writeOsisIDs"><apply-templates select="$separateKeywords" mode="writeOsisIDMode"/></variable>
    <apply-templates select="$writeOsisIDs" mode="writeMode"/>
    <if test="$duplicate_keywords">
      <call-template name="Report"><with-param name="msg"><value-of select="count($duplicate_keywords)"/> instance(s) of duplicate keywords were found and aggregated:</with-param></call-template>
      <for-each select="$duplicate_keywords"><call-template name="Log"><with-param name="msg" select="string()"/></call-template></for-each>
    </if>
    <if test="not($duplicate_keywords)">
      <call-template name="Report"><with-param name="msg">0 instance(s) of duplicate keywords. Entry aggregation isn't needed (according to case insensitive keyword comparison).</with-param></call-template>
    </if>
  </template>
  
  <!-- Separate glossary contents so each entry and the glossary intro is in its own child div -->
  <template match="div[@type='glossary']" mode="separateKeywordMode">
    <copy><apply-templates select="@*"/>
      <!-- Write applicable comments to scope -->
      <variable name="scopeComment" select="replace(string(descendant::comment()[1]), '^.*?\sscope\s*==\s*(.+?)\s*$', '$1')"/>
      <if test="$scopeComment and $scopeComment != string(descendant::comment()[1])">
        <attribute name="scope" select="$scopeComment"/>
        <if test="oc:number-of-matches(string(descendant::comment()[1]), '==') &#62; 1">
          <call-template name="Error">
            <with-param name="msg">Only a single "scope == &#60;value&#62;" can be specified for an OSIS glossary div.</with-param>
            <with-param name="exp">The \id line of an SFM file likely has multiple "scope == &#60;value&#62;" assignments. Remove all but one assignment.</with-param>
          </call-template>
        </if>
      </if>
      <!-- Separate each glossary entry into its own div. A glossary entry ends upon the following keyword, or following chapter, or at   
      the end of the keyword's first ancestor div. The following group-by must match what is used in groupCopy template's test attribute. -->
      <for-each-group select="node()" group-by="for $i in ./descendant-or-self::node()
          return count($i/following::seg[@type='keyword']) + count($i/following::chapter) - count($i/preceding::div[descendant::seg[@type='keyword']])">
        <sort select="current-grouping-key()" order="descending" data-type="number"/>
        <variable name="groupCopy"><apply-templates mode="groupCopy" select="current-group()"/></variable>
        <choose>
          <when test="$groupCopy[1][descendant-or-self::seg[@type='keyword']]">
            <variable name="isDuplicate" select="$duplicate_keywords[lower-case(string()) = lower-case($groupCopy[1]/descendant-or-self::seg[@type='keyword'][1])]"/><text>
</text>     <div xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace">
              <xsl:attribute name="type">x-keyword<xsl:if test="$isDuplicate">-duplicate</xsl:if></xsl:attribute>
              <xsl:apply-templates select="$groupCopy" mode="#current"/>
            </div>
          </when>
          <otherwise><apply-templates select="$groupCopy" mode="#current"/></otherwise>
        </choose>
      </for-each-group>
    </copy>
  </template>
  
  <!-- Copy only nodes having at least one descendant that is part of the current-group -->
  <template match="node()" mode="groupCopy" priority="2">
    <choose>
      <!-- drop any paragraph that contains this group's keyword, since the keyword will always start a new entry and p containers are very restricted in EPUB2 for example -->
      <when test="self::p[descendant::seg[@type='keyword']
          [count(following::seg[@type='keyword']) + count(following::chapter) - count(preceding::div[descendant::seg[@type='keyword']]) = current-grouping-key()]]">
        <apply-templates mode="#current"/>
      </when>
      <!-- the following test must match what was used in the group-by attribute of for-each-group -->
      <when test="descendant-or-self::node()
          [count(following::seg[@type='keyword']) + count(following::chapter) - count(preceding::div[descendant::seg[@type='keyword']]) = current-grouping-key()]">
        <copy><apply-templates select="@*"/>
          <apply-templates mode="#current"/>
        </copy>
      </when>
    </choose>
  </template>
  
  <!-- Add osisID to keywords -->
  <template match="seg[@type='keyword']" mode="writeOsisIDMode">
    <variable name="segs_sharing_keyword" select="ancestor::osisText//seg[@type='keyword'][ancestor::div[@type='glossary']][lower-case(string()) = lower-case(string(current()))]"/>
    <variable name="dup" select="if (count($segs_sharing_keyword) &#62; 1) then oc:index-of-node($segs_sharing_keyword, .) else ''"/>
    <copy>
      <choose>
        <when test="$dup">
          <!-- If there are duplicate keywords (case insensitive) then the osisID of each individual keyword is: 
          encodeOsisRef(first-keyword).dupN (where N is its integer index). And the osisID of the aggregated keyword is: 
          encodeOsisRef(first-keyword)
          This scheme has the following benefits:
          - The aggregated keyword's osisID can be obtained by simply removing the .dupN suffix from any osisID
          - The relationship: aggregated keyword = decodeOsisRef(osisID) holds, because the first occurence of the 
          keyword is used as the aggregate keyword (this is done in osisText template). This relationship is 
          important here since some SWORD implementations rely it, and SWORD uses the aggregated keywords while 
          dropping individual duplicates. This also means the relationship does NOT hold for individual duplicates, 
          but becasue of the suffix that is obvious anyway. Therefore, non-SWORD implementations should NOT rely 
          totally on the keyword = decodeOsisRef(osisID) relationship. -->
          <attribute name="osisID" select="concat(oc:encodeOsisRef(string($segs_sharing_keyword[1])), '.dup', $dup)"/>
        </when>
        <otherwise>
          <attribute name="osisID" select="oc:encodeOsisRef(string(.))"/>
        </otherwise>
      </choose>
      <apply-templates select="node()|@*" mode="#current"/>
    </copy>
  </template>
  
  <template match="osisText" mode="writeMode">
    <copy><apply-templates select="node()|@*" mode="#current"/>
    <!-- Write x-aggregate div -->
    <if test="$duplicate_keywords">
      <element name="div" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
        <attribute name="type" select="'glossary'"/><attribute name="subType" select="'x-aggregate'"/>
        <for-each select="//seg[@type='keyword'][ends-with(@osisID,'.dup1')]">
          <element name="div" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
            <attribute name="type" select="'x-keyword-aggregate'"/>
            <copy><apply-templates select="@*" mode="#current"/>
              <attribute name="osisID" select="replace(@osisID, '\.dup1$', '')"/>
              <apply-templates select="node()" mode="#current"/>
            </copy>
            <variable name="subentry_keywords" select="//seg[@type='keyword'][ancestor::div[@type='glossary']][lower-case(string()) = lower-case(string(current()))]"/>
            <for-each select="$subentry_keywords/ancestor::div[@type='x-keyword-duplicate']">
              <copy><apply-templates select="@*" mode="#current"/>
                <attribute name="type" select="'x-aggregate-subentry'"/>
                <if test="parent::*/@scope"><attribute name="scope" select="parent::*/@scope"/></if>
                <variable name="title" select="ancestor::div[@type='glossary'][1]/descendant::title[@type='main'][1]"/>
                <if test="$title">
                  <title level="3" subType="x-glossary-title" xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"><xsl:value-of select="string($title)"/></title>
                </if>
                <if test="not($title)">
                  <title level="3" subType="x-glossary-head" xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"><xsl:value-of select="position()"/>) </title>
                </if>
                <apply-templates mode="write-aggregates"/>
              </copy>
            </for-each>
          </element>
        </for-each>
      </element>
    </if>
    </copy>
  </template>
  
  <!-- Remove individual keywords when writing the aggregate div -->
  <template match="seg[@type='keyword']" mode="write-aggregates"/>
  
</stylesheet>
