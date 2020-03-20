<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT will do the following:
  1) Warn about any non GLO major divs being dropped from SWORD.
  2) Error if there are glossary keywords outside of a glossary.
  3) Separate all glossary keywords into their own child divs.
  4) Assign osisIDs to keywords.
  5) Find case insensitive identical keywords from glossary divs, and 
     aggregate them into a new x-aggregate div
  
  NOTE: There are three types of keyword divs generated: 
    x-keyword           = Unique keywords (case-insensitive) 
    x-keyword-duplicate = Keywords which are not unique
    x-keyword-aggregate = New keywords containing an aggregation of each
                          member of each non-unique keyword
  IMPORTANT: Only x-keyword-duplicate OR x-keyword-aggregate keywords
    should be used for any given conversion, or else material may appear
    more than once. So conversions which require unique keywords (like
    SWORD) should use x-keyword-aggregate, while conversions which
    tolerate non-unique keywords (like eBooks) should use 
    x-keyword-duplicate keywords. -->
 
  <import href="../functions/functions.xsl"/>
  
  <param name="TOC" select="oc:conf('TOC', /)"/>

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
  
    <!-- Error if keywords are outside of glossary -->
    <for-each select="//seg[@type='keyword'][not(ancestor::div[@type='glossary'])]">
      <call-template name="Error">
        <with-param name="msg">Keywords must be in a GLO (glossary) div: <value-of select="."/></with-param>
        <with-param name="exp">Either change the keyword into a regular title, or change the \id USFM tag file-type of the containing file to GLO.</with-param>
      </call-template>
    </for-each>
    
    <!-- Warn about material dropped from SWORD -->
    <for-each select="//div[@type and not(ancestor::div[@type]) and @type!='glossary']">
      <call-template name="Warn">
        <with-param name="msg">The div with type="<value-of select="@type"/>" will NOT appear in the SWORD glossary module. It contains:&#xa;BEGIN-QUOTE&#xa;<value-of select="."/>&#xa;END-QUOTE&#xa;</with-param>
        <with-param name="exp">Only "\id GLO" type USFM files will appear in the SWORD glossary module.</with-param>
      </call-template>
    </for-each>
    
    <!-- Process the OSIS file -->
    <variable name="separateKeywords"><apply-templates mode="separateKeywordMode"/></variable>
    <variable name="writeOsisIDs"><apply-templates select="$separateKeywords" mode="writeOsisIDMode"/></variable>
    <apply-templates select="$writeOsisIDs" mode="writeMode"/>
    
    <!-- Log and Report results -->
    <if test="$duplicate_keywords">
      <call-template name="Report"><with-param name="msg"><value-of select="count($duplicate_keywords)"/> instance(s) of duplicate keywords were found and aggregated:</with-param></call-template>
      <for-each select="$duplicate_keywords"><call-template name="Log"><with-param name="msg" select="string()"/></call-template></for-each>
    </if>
    <if test="not($duplicate_keywords)">
      <call-template name="Report"><with-param name="msg">0 instance(s) of duplicate keywords. Entry aggregation isn't needed (according to case insensitive keyword comparison).</with-param></call-template>
    </if>
  </template>
  
  <!-- Separate glossary contents so each entry is in its own child div -->
  <template mode="separateKeywordMode" match="div[@type='glossary']">
    <variable name="osisID" select="@osisID"/>
    <copy>
      <apply-templates select="@*"/>
      
      <variable name="firstKey" select="descendant::seg[@type='keyword'][1]/string()"/>
      
      <variable name="keywords">
        <for-each select="node()">
          <sequence select="if (element()) then oc:expelElements(., descendant::seg[@type='keyword'], false()) else ."/>
        </for-each>
      </variable>
      
      <for-each-group select="$keywords/node()" group-starting-with="seg[@type='keyword']">
        <choose>
          <when test="not(current-group()[self::seg[@type='keyword']])">
            <apply-templates select="current-group()" mode="#current"/>
          </when>
          <otherwise>
            <text>&#xa;</text>
            <osis:div>
              <attribute name="type">
                <choose>
                  <when test="$duplicate_keywords[ lower-case(string()) = 
                    lower-case(current-group()[self::seg[@type='keyword']]/string()) ]">x-keyword-duplicate</when>
                  <otherwise>x-keyword</otherwise>
                </choose>
              </attribute>
              <if test="current-group()[self::seg[@type='keyword']]/string() = $firstKey">
                <variable name="subType" as="xs:string?">
                  <choose>
                    <when test="$osisID = 'uiIntroductionTopMenu'">x-navmenu-introduction</when>
                    <when test="$osisID = 'uiDictionaryTopMenu'">x-navmenu-dictionary</when>
                  </choose>
                </variable>
                <if test="$subType"><attribute name="subType" select="$subType"/></if>
              </if>
              <apply-templates select="current-group()" mode="#current"/>
            </osis:div>
          </otherwise>
        </choose>
      </for-each-group>
    </copy>
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
        <attribute name="type" select="'glossary'"/><attribute name="subType" select="'x-aggregate'"/><attribute name="resp" select="'x-oc'"/>
        <for-each select="//seg[@type='keyword'][ends-with(@osisID,'.dup1')]">
          <element name="div" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
            <attribute name="type">x-keyword-aggregate</attribute>
            <copy><apply-templates select="@*" mode="#current"/>
              <attribute name="osisID" select="replace(@osisID, '\.dup1$', '')"/>
              <apply-templates select="node()" mode="#current"/>
            </copy>
            <variable name="subentry_keywords" 
              select="//seg[@type='keyword'][ancestor::div[@type='glossary']]
                      [lower-case(string()) = lower-case(string(current()))]"/>
            <!-- $titles look ahead allows titles to be skipped if they are all the same -->
            <variable name="titles" as="element(oc:vars)*">
              <for-each select="$subentry_keywords/ancestor::div[@type='x-keyword-duplicate']">
                <oc:vars self="{generate-id()}"
                  scopeTitle="{oc:getGlossaryScopeTitle(./ancestor::div[@type='glossary'][1])}" 
                  glossTitle="{oc:getGlossaryTitle(./ancestor::div[@type='glossary'][1])}"/>
              </for-each>
            </variable>
            <for-each select="$subentry_keywords/ancestor::div[@type='x-keyword-duplicate']">
              <copy><apply-templates select="@*" mode="#current"/>
                <attribute name="type" select="'x-aggregate-subentry'"/>
                <if test="parent::*/@scope"><attribute name="scope" select="parent::*/@scope"/></if>
                
                <variable name="glossaryScopeTitle" select="$titles[@self = generate-id(current())]/@scopeTitle"/>
                <variable name="countScopeTitles" select="count(distinct-values($titles/@scopeTitle))"/>
                
                <variable name="glossaryTitle" select="$titles[@self = generate-id(current())]/@glossTitle"/>
                <variable name="countTitles" select="count(distinct-values($titles/@glossTitle))"/>
                
                <!-- Only add disambiguation titles if there is more than one scope or glossary title represented -->
                <if test="$countScopeTitles &#62; 1 or $countTitles &#62; 1">
                  <if test="$glossaryScopeTitle">
                    <title level="3" subType="x-glossary-scope" xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"><xsl:value-of select="$glossaryScopeTitle"/></title>
                  </if>
                  <if test="$glossaryTitle">
                    <title level="3" subType="x-glossary-title" xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"><xsl:value-of select="$glossaryTitle"/></title>
                  </if>
                  <if test="not($glossaryScopeTitle) and not($glossaryTitle)">
                    <title level="3" subType="x-glossary-head" xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"><xsl:value-of select="position()"/>) </title>
                  </if>
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
