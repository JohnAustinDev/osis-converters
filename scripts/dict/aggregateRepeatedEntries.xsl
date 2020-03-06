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
  1) Check and warn about non GLO major divs in the glossary
  2) Check and error if there are glossary keywords outside of a glossary
  3) Separate all glossary keywords into their own child divs
  4) Assign osisIDs to keywords
  5) Find case insensitive identical keywords from glossary divs, and aggregate them into a new x-aggregate div
  -->
 
  <import href="../functions.xsl"/>
  
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
  
  <!-- Separate glossary contents so each entry and the glossary intro is in its own child div -->
  <template mode="separateKeywordMode" match="div[@type='glossary']">
    <copy><apply-templates select="@*"/>
      <!-- Separate each glossary entry into its own div. A glossary entry ends upon the following keyword, or following chapter, or at   
      the end of the keyword's first ancestor div. The following group-by must match what is used in groupCopy template's test attribute. -->
      <variable name="firstKeywordInGlossary" select="parent::*/descendant::seg[@type='keyword'][1]"/>
      <for-each-group select="node()" group-by="for $i in ./descendant-or-self::node()
          return count($i/following::seg[@type='keyword']) + count($i/following::chapter) - count($i/preceding::div[descendant::seg[@type='keyword']])">
        <sort select="current-grouping-key()" order="descending" data-type="number"/>
        <variable name="groupCopy"><apply-templates mode="groupCopy" select="current-group()"/></variable>
        <choose>
          <when test="$groupCopy[1][descendant-or-self::seg[@type='keyword']]">
            <variable name="isDuplicate" select="$duplicate_keywords[lower-case(string()) = lower-case($groupCopy[1]/descendant-or-self::seg[@type='keyword'][1])]"/><text>
</text>     <osis:div>
              <attribute name="type">x-keyword<if test="$isDuplicate">-duplicate</if></attribute>
              <!-- Mark the first keyword in uiIntroductionTopMenu or uiDictionaryTopMenu per INTMENU feature -->
              <if test="current-group() intersect $firstKeywordInGlossary">
                <variable name="subType" as="xs:string?">
                  <choose>
                    <when test="current-group()/ancestor::*[@osisID='uiIntroductionTopMenu']">x-navmenu-introduction</when>
                    <when test="current-group()/ancestor::*[@osisID='uiDictionaryTopMenu']">x-navmenu-dictionary</when>
                  </choose>
                </variable>
                <if test="$subType"><attribute name="subType" select="$subType"/></if>
              </if>
              <apply-templates select="$groupCopy" mode="#current"/>
            </osis:div>
          </when>
          <otherwise><apply-templates select="$groupCopy" mode="#current"/></otherwise>
        </choose>
      </for-each-group>
    </copy>
  </template>
  
  <!-- Copy only nodes having at least one descendant that is part of the current-group -->
  <template mode="groupCopy" match="node()" priority="2">
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
        <attribute name="type" select="'glossary'"/><attribute name="subType" select="'x-aggregate'"/><attribute name="resp" select="'x-oc'"/>
        <for-each select="//seg[@type='keyword'][ends-with(@osisID,'.dup1')]">
          <element name="div" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
            <attribute name="type" select="'x-keyword-aggregate'"/>
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
