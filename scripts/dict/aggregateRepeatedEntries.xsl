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
    x-keyword-duplicate keywords. 
    
  GLOSSARY FORMATTING
  Glossaries necessarily require simplified formatting, because all key-
  words will appear at the same TOC level, and anything before the first 
  keyword is dropped. Sometimes, the best approach is to include BAK 
  type material twice, once as a 'GLO conversion == sword' which pre-
  sents the desired keywords, and again as 'BAK' which presents all the 
  formatted material without keywords. In this way, keyed implementa-
  tions, ie SWORD, will use the GLO version, and normal serial implenta-
  tions, ie eBooks and HTML, will use the full formatted version. -->
 
  <import href="../functions/functions.xsl"/>
  
  <param name="TOC" select="oc:conf('TOC', /)"/>

  <variable name="MOD" select="//osisText/@osisIDWork"/>
  
  <!-- Get a list of applicable keywords which are NOT unique (by a case insensitive comparison) -->
  <variable name="duplicate_keywords" select="//seg[@type='keyword']
      [ancestor::div[@type='glossary']]
      [lower-case(string()) = following::seg[@type='keyword'][ancestor::div[@type='glossary']]/lower-case(string())]
      [not(lower-case(string()) = preceding::seg[@type='keyword'][ancestor::div[@type='glossary']]/lower-case(string()))]"/>
  
  <!-- By default copy everything as is, for all modes -->
  <template mode="#all" match="node()|@*" name="identity">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <!-- Root template -->
  <template match="/">
  
    <!-- Process the OSIS file -->
    <variable name="removeGlossaryDivs">
      <apply-templates mode="remove_glossary_divs"/>
    </variable>
    <variable name="separateKeywords">
      <apply-templates mode="separate_keywords" select="$removeGlossaryDivs"/>
    </variable>
    <variable name="writeOsisIDs">
      <apply-templates mode="write_osisIDs" select="$separateKeywords"/>
    </variable>
    <variable name="output">
      <apply-templates mode="writeMode" select="$writeOsisIDs"/>
    </variable>
    
    <!-- Warn about glossary material that is not in a keyword -->
    <variable name="exglossary" select="$output//div[@type='glossary'][not(@subType='x-aggregate')]
      [child::node()[not(self::comment())][not(self::div[starts-with(@type, 'x-keyword')])][normalize-space()]]"/>
    <if test="$exglossary">
      <call-template name="Warn">
<with-param name="msg">The following material will not appear in any combined glossary or SWORD module:
<for-each select="$exglossary">osisID="<value-of select="@osisID"/>"
<value-of>
          <for-each select="child::node()[not(self::comment())][not(self::div[starts-with(@type, 'x-keyword')])]">
            <if test="normalize-space(.)"><text>     </text><value-of select="."/><text>&#xa;</text></if>
          </for-each>
        </value-of><text>&#xa;</text>
        </for-each>
        </with-param>
<with-param name="exp">Everything before the first keyword, and all Level 1 
titles, are outside of any glossary entry. Level 1 headings will close 
their preceding glossary entry and all text between the heading and the 
next glossary entry will also be outside of a glossary entry. Use  
secondary titles if you wish the titles and following material to be  
included in the proceding glossary entry.</with-param>
      </call-template>
    </if>
    
    <sequence select="$output"/>
    
  
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
        <with-param name="msg">The followng <value-of select="@type"/> material will not appear in the SWORD module:&#xa;begin-quote&#xa;<value-of select="."/>&#xa;end-quote</with-param>
        <with-param name="exp">Only \id GLO USFM files will appear in the SWORD module.</with-param>
      </call-template>
    </for-each>

    <!-- Log and Report results -->
    <if test="$duplicate_keywords">
      <call-template name="Report">
<with-param name="msg"><value-of select="count($duplicate_keywords)"/> instance(s) of duplicate keywords were found and aggregated:</with-param>
      </call-template>
      <for-each select="$duplicate_keywords">
        <call-template name="Log">
<with-param name="msg" select="string()"/>
        </call-template>
      </for-each>
    </if>
    <if test="not($duplicate_keywords)">
      <call-template name="Report">
<with-param name="msg">0 instance(s) of duplicate keywords. Entry aggregation isn't needed (according to case insensitive keyword comparison).</with-param>
      </call-template>
    </if>

  </template>
  
  <!-- All divs within a glossary a first removed -->
  <template mode="remove_glossary_divs" match="div[ancestor::div[@type='glossary']]">
    <apply-templates mode="#current"/>
  </template>
  
  <!-- Then separate glossary contents so each entry is in its own child div -->
  <template mode="separate_keywords" match="div[@type='glossary']">
    <variable name="osisID" select="@osisID"/>
    <variable name="isSpecial" as="xs:boolean" 
      select="@scope = 'NAVMENU' or @annotateType = 'x-feature'"/>
    <copy>
      <apply-templates select="@*"/>
      
      <for-each select="descendant::*[count(descendant::seg[@type='keyword']) &#62; 1]">
        <call-template name="Error">
<with-param name="msg">Element contains multiple keywords: <value-of select="."/></with-param>
<with-param name="exp">Keywords are inline elements, but a single paragraph (or other element) cannot contain more than one keyword.</with-param>
<with-param name="die">yes</with-param>
        </call-template>
      </for-each>
      
      <variable name="firstKey" select="descendant::seg[@type='keyword'][1]"/>
      
      <!-- Separate glossary children into groups so that each keyword is, 
      or is inside, the first node of each group having a keyword. Title 
      elements inside a non-special glossary, having no level attribute 
      or level=1 will also start a new group, whose contents will not be 
      part of an x-keyword div. This is because in normal glossaries,
      main titles do not apply to a single keyword. -->
      <for-each-group select="node()" 
          group-adjacent="count(descendant-or-self::seg[@type='keyword']) + 
                          count(preceding::seg[@type='keyword']) +
                      0.5*count(self::title[not(@level) or @level='1'][not($isSpecial)]) +
                      0.5*count(preceding::title[not(@level) or @level='1'][not($isSpecial)])">
      
        <for-each select="current-group()/descendant::text()[normalize-space()][1]
            [. &#60;&#60; current-group()/descendant-or-self::seg[@type='keyword']]">
          <call-template name="Error">
<with-param name="msg">Glossary element '<value-of select="current-group()/descendant-or-self::seg[@type='keyword']"/>' is not the first text node in its container.</with-param>
<with-param name="exp">Place an \m or \p or other paragraph tag before this keyword.</with-param>
          </call-template>
        </for-each>
      
        <choose>
          <when test="not(current-group()[descendant-or-self::seg[@type='keyword']])">
            <apply-templates mode="#current" select="current-group()"/>
          </when>
          <otherwise>
            <text>&#xa;</text>
            <osis:div>
              <attribute name="type">
                <choose>
                  <when test="$duplicate_keywords[
                      lower-case(string()) = 
                      lower-case(current-group()/descendant-or-self::seg[@type='keyword']/string()) 
                    ]">x-keyword-duplicate</when>
                  <otherwise>x-keyword</otherwise>
                </choose>
              </attribute>
              <if test="current-group()[descendant-or-self::seg[@type='keyword']]/string() = $firstKey/string()">
                <variable name="subType" as="xs:string?">
                  <choose>
                    <when test="$osisID = 'uiIntroductionTopMenu'">x-navmenu-introduction</when>
                    <when test="$osisID = 'uiDictionaryTopMenu'">x-navmenu-dictionary</when>
                  </choose>
                </variable>
                <if test="$subType"><attribute name="subType" select="$subType"/></if>
              </if>
              <apply-templates mode="#current" select="current-group()"/>
            </osis:div>
          </otherwise>
        </choose>
      </for-each-group>
    </copy>
  </template>
  
  <!-- Finally add osisID to keywords -->
  <template mode="write_osisIDs" match="seg[@type='keyword']">
    <variable name="segs_sharing_keyword" select="ancestor::osisText//seg[@type='keyword']
    [ancestor::div[@type='glossary']]
    [lower-case(string()) = lower-case(string(current()))]"/>
    <variable name="dup" select="if (count($segs_sharing_keyword) &#62; 1) 
                                 then oc:index-of-node($segs_sharing_keyword, .) 
                                 else ''"/>
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
      <apply-templates mode="#current" select="node()|@*"/>
    </copy>
  </template>
  
  <template mode="writeMode" match="osisText">
    <copy>
      <apply-templates mode="#current" select="node()|@*"/>
      
      <!-- Write x-aggregate div -->
      <if test="$duplicate_keywords">
        <osis:div type="glossary" subType="x-aggregate" resp="x-oc">
          <for-each select="//seg[@type='keyword'][ends-with(@osisID,'.dup1')]">
            <osis:div type="x-keyword-aggregate">
              <copy>
                <apply-templates mode="#current" select="@*"/>
                <attribute name="osisID" select="replace(@osisID, '\.dup1$', '')"/>
                <apply-templates mode="#current" select="node()"/>
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
                <variable name="glossaryScopeTitle" select="$titles[@self = generate-id(current())]/@scopeTitle"/>
                <variable name="countScopeTitles" select="count(distinct-values($titles/@scopeTitle))"/>
                
                <variable name="glossaryTitle" select="$titles[@self = generate-id(current())]/@glossTitle"/>
                <variable name="countTitles" select="count(distinct-values($titles/@glossTitle))"/>
                
                <!-- Only add disambiguation titles if there is more than one scope or glossary title represented -->
                <if test="$countScopeTitles &#62; 1 or $countTitles &#62; 1">
                  <if test="$glossaryScopeTitle">
                    <osis:title level="3" subType="x-glossary-scope">
                      <value-of select="$glossaryScopeTitle"/>
                    </osis:title>
                  </if>
                  <if test="$glossaryTitle">
                    <osis:title level="3" subType="x-glossary-title">
                      <value-of select="$glossaryTitle"/>
                    </osis:title>
                  </if>
                  <if test="not($glossaryScopeTitle) and not($glossaryTitle)">
                    <osis:title level="3" subType="x-glossary-head">
                      <value-of select="concat(position(), ')')"/>
                    </osis:title>
                  </if>
                </if>
                <copy>
                  <apply-templates mode="#current" select="@*"/>
                  <attribute name="type" select="'x-aggregate-subentry'"/>
                  <if test="parent::*/@scope"><attribute name="scope" select="parent::*/@scope"/></if>
                  <apply-templates mode="write_aggregates"/>
                </copy>
              </for-each>
            </osis:div>
          </for-each>
        </osis:div>
      </if>
    
    </copy>
  </template>
  
  <template mode="write_osisIDs" match="div[@type='glossary']">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <variable name="title" select="oc:encodeOsisRef(oc:getGlossaryTitle(.))"/>
      <variable name="n" select="1 + count(
        preceding::div[@type='glossary'][oc:getGlossaryTitle(.) = oc:getGlossaryTitle(current())] )"/>
      <attribute name="osisID" 
        select="concat('glossary_', $title, if ($n &#62; 1) then concat('_', $n) else '','!con')"/>
      <apply-templates mode="#current"/>
    </copy>
  </template>
  
  <!-- Remove individual keywords when writing the aggregate div -->
  <template mode="write_aggregates" match="seg[@type='keyword']"/>
  <template mode="write_aggregates" 
    match="p[not( descendant::text()[normalize-space()][not(parent::seg[@type='keyword'])] )]"/>
  
</stylesheet>
