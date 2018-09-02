<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT does the following:
  1) Creates a glossary menu system with links to each glossary entry in the combined glossary and puts it in a glossary with scope="NAVMENU"
  2) Creates an introduction menu system, if introScope is given
  3) Inserts navigational links to these into every chapter, glossary entry and book introduction
  -->
 
  <xsl:import href="./functions.xsl"/>
 
  <!-- scope of the glossary div which contains introductory material, if it exists -->
  <xsl:param name="introScope"/>
  
  <!-- this glossary entry will be created as the top level navigation menu if $introScope exists -->
  <xsl:param name="uiIntroduction" select="concat('-- ', //header/work[child::type[@type='x-bible']]/title[1])"/>
  
  <!-- this glossary entry will be created as the glossary navigation menu -->
  <xsl:param name="uiDictionary" select="concat('- ', //header/work[child::type[@type='x-glossary']]/title[1])"/>
  
  <xsl:param name="DICTMOD" select="/descendant::work[child::type[@type='x-glossary']][1]/@osisWork"/>
  
  <xsl:param name="BIBLEMOD" select="/descendant::work[child::type[@type='x-bible']][1]/@osisWork"/>
  
  <xsl:variable name="dictEntries" select="//div[starts-with(@type, 'x-keyword')][not(@type = 'x-keyword-duplicate')]"/>
  
  <xsl:template match="node()|@*" mode="identity">
    <xsl:copy><xsl:apply-templates select="node()|@*" mode="identity"/></xsl:copy>
  </xsl:template>
  
  <!-- insert navmenu links:
  1) before the first applicable text node of each book or the first chapter[@sID] of each book, whichever comes first
  2) at the end of each div[starts-with(@type, 'x-keyword')]
  3) before each chapter[@eID] -->
  <xsl:template match="node()|@*">
    <xsl:variable name="prependNavMenu" select="
    ancestor::div[@type='book']/
        (node()[descendant-or-self::text()[normalize-space()][not(ancestor::title[@type='runningHead'])]][1] | descendant::chapter[@sID][1])[1]
        [generate-id(.) = generate-id(current())]"/>
    <xsl:choose>
      <xsl:when test="$prependNavMenu or self::chapter[@eID]">
        <xsl:call-template name="navmenu"/>
        <xsl:copy><xsl:apply-templates select="node()|@*" mode="identity"/></xsl:copy>
        <xsl:if test="not(self::chapter) or boolean(self::chapter[matches(@eID, '\.1$')])">
          <xsl:message>NOTE: Added navmenu before: <xsl:value-of select="oc:printNode(.)"/><xsl:if test="self::chapter"><xsl:value-of select="' and following chapters'"/></xsl:if></xsl:message>
        </xsl:if>
      </xsl:when>
      <xsl:when test="generate-id(.) = $dictEntries/generate-id()">
        <xsl:copy><xsl:apply-templates select="node()|@*" mode="identity"/><xsl:call-template name="navmenu"/></xsl:copy>
        <xsl:message>NOTE: Added navmenu to keyword: <xsl:value-of select="descendant::seg[@type='keyword']"/></xsl:message>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy><xsl:apply-templates select="node()|@*"/></xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="navmenu">
    <xsl:param name="combinedGlossary" as="element(div)?" tunnel="yes"/>
    <xsl:param name="skip"/>
    <xsl:variable name="cgEntry" select="$combinedGlossary//*[@realid = generate-id(current())]"/>
    <xsl:variable name="nodeInBibleMod" select="ancestor-or-self::osisText[1]/@osisIDWork = $BIBLEMOD"/>
    <list subType="x-navmenu">
      <xsl:if test="$nodeInBibleMod"><xsl:attribute name="canonical" select="'false'"/></xsl:if>
      <xsl:variable name="prev" select="
          if ($cgEntry) then $cgEntry/preceding-sibling::*[1]/descendant::seg[@type='keyword'][1] 
          else if (self::chapter[@eID]) then //chapter[@osisID = string-join((tokenize(current()/@eID, '\.')[1], string(number(tokenize(current()/@eID, '\.')[2])-1)), '.')][1] else false()"/>
      <xsl:variable name="next" select="
          if ($cgEntry) then $cgEntry/following-sibling::*[1]/descendant::seg[@type='keyword'][1] 
          else if (self::chapter[@eID]) then //chapter[@osisID = string-join((tokenize(current()/@eID, '\.')[1], string(number(tokenize(current()/@eID, '\.')[2])+1)), '.')][1] else false()"/>
      <xsl:if test="ancestor-or-self::div[@type=('glossary', 'book')] and not(matches($skip, 'prevnext')) and ($prev or $next)">
        <item subType="x-prevnext-link">
          <p type="x-right">
            <xsl:if test="not($nodeInBibleMod) or not(self::chapter)"><xsl:attribute name="subType" select="'x-introduction'"/></xsl:if>
            <xsl:if test="$prev">
              <xsl:choose>
                <xsl:when test="$nodeInBibleMod and self::chapter">
                  <reference osisRef="{concat(ancestor::osisText[last()]/@osisIDWork, ':', $prev/@osisID)}"> ← </reference>
                </xsl:when>
                <xsl:otherwise>
                  <reference osisRef="{concat($DICTMOD, ':', $prev/@osisID)}" type="x-glosslink" subType="x-target_self"> ← </reference>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:if>
            <xsl:if test="$next">
              <xsl:choose>
                <xsl:when test="$nodeInBibleMod and self::chapter">
                  <reference osisRef="{concat(ancestor::osisText[last()]/@osisIDWork, ':', $next/@osisID)}"> → </reference>
                </xsl:when>
                <xsl:otherwise>
                  <reference osisRef="{concat($DICTMOD, ':', $next/@osisID)}" type="x-glosslink" subType="x-target_self"> → </reference>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:if>
          </p>
        </item>
      </xsl:if>
      <xsl:if test="not(self::seg[@type='keyword'][@osisID = oc:encodeOsisRef($uiIntroduction)]) and not(matches($skip, 'introduction')) and $introScope">
        <item subType="x-introduction-link">
          <p type="x-right">
            <xsl:if test="not($nodeInBibleMod) or not(self::chapter)"><xsl:attribute name="subType" select="'x-introduction'"/></xsl:if>
            <reference osisRef="{$DICTMOD}:{oc:encodeOsisRef($uiIntroduction)}" type="x-glosslink" subType="x-target_self">
              <xsl:value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/>
            </reference>
          </p>
        </item>
      </xsl:if>
      <xsl:if test="not(self::seg[@type='keyword'][@osisID = oc:encodeOsisRef($uiDictionary)]) and not(matches($skip, 'dictionary'))">
        <item subType="x-dictionary-link">
          <p type="x-right" subType="x-introduction">
            <reference osisRef="{$DICTMOD}:{oc:encodeOsisRef($uiDictionary)}" type="x-glosslink" subType="x-target_self">
              <xsl:value-of select="replace($uiDictionary, '^[\-\s]+', '')"/>
            </reference>
          </p>
        </item>
      </xsl:if>
      <lb/>
      <lb/>
    </list>
  </xsl:template>
  
  <!-- Create glossary navigation menus and put them in a glossary div -->
  <xsl:template match="osisText">
    <xsl:variable name="combinedGlossary" as="element(div)">
      <div type="glossary" subType="x-combinedGlossary">
        <xsl:if test="$dictEntries and not(//description[@type='x-sword-config-LangSortOrder'])">
          <xsl:message terminate="yes">ERROR: Cannot sort glossary entries: 'LangSortOrder' must be specified in config.conf.</xsl:message>
        </xsl:if>
        <xsl:for-each select="$dictEntries">
          <xsl:sort select="oc:langSortOrder(.//seg[@type='keyword'], //description[@type='x-sword-config-LangSortOrder'][1])" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
          <xsl:copy><xsl:attribute name="realid" select="generate-id(.)"/><xsl:apply-templates/></xsl:copy>
        </xsl:for-each>
      </div>
    </xsl:variable>
      
    <xsl:copy>
      <xsl:apply-templates select="node()|@*">
        <xsl:with-param name="combinedGlossary" select="$combinedGlossary" tunnel="yes"/>
      </xsl:apply-templates>
      
      <xsl:if test="//work[@osisWork = current()/@osisIDWork]/type[@type='x-glossary']">
        <xsl:message>NOTE: Added NAVMENU glossary</xsl:message>
        <div type="glossary" scope="NAVMENU">
          
          <!-- Create a uiIntroduction main entry -->
          <xsl:if test="$introScope and //div[@type='glossary'][@scope=$introScope]">
            <xsl:message>NOTE: Added introduction menu: <xsl:value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/></xsl:message>
            <xsl:variable name="introSubEntries" select="//div[@type='glossary'][@scope = $introScope]//seg[@type='keyword']"/>
            <seg type="keyword" osisID="{oc:encodeOsisRef($uiIntroduction)}"><xsl:value-of select="$uiIntroduction"/></seg>
            <xsl:call-template name="navmenu"><xsl:with-param name="skip" select="'introduction'"/></xsl:call-template>
            <title type="main" subType="x-introduction"><xsl:value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/></title>
            <lb/>
            <lb/>
            <xsl:for-each select="$introSubEntries">
              <xsl:message>NOTE: Added introduction sub-menu: <xsl:value-of select="."/></xsl:message>
              <p type="x-noindent"><reference osisRef="{$DICTMOD}:{oc:encodeOsisRef(.)}" type="x-glosslink" subType="x-target_self"><xsl:value-of select="."/></reference>
                <lb/>
              </p>
            </xsl:for-each>
          </xsl:if>
          
           <!-- Create a uiDictionary main entry, and its sub-entries -->
          <xsl:message>NOTE: Added dictionary menu: <xsl:value-of select="replace($uiDictionary, '^[\-\s]+', '')"/></xsl:message>
          <xsl:variable name="allEntriesTitle" select="concat('-', upper-case(substring($combinedGlossary/descendant::seg[@type='keyword'][1], 1, 1)), '-', upper-case(substring($combinedGlossary/descendant::seg[@type='keyword'][last()], 1, 1)))"/>
          <p>
            <seg type="keyword" osisID="{oc:encodeOsisRef($uiDictionary)}">
              <xsl:value-of select="$uiDictionary"/>
            </seg>
          </p>
          <xsl:call-template name="navmenu"><xsl:with-param name="skip" select="'dictionary'"/></xsl:call-template>
          <xsl:message>NOTE: Added dictionary sub-menu: <xsl:value-of select="replace($allEntriesTitle, '^[\-\s]+', '')"/></xsl:message>
          <reference osisRef="{$DICTMOD}:{oc:encodeOsisRef($allEntriesTitle)}" type="x-glosslink" subType="x-target_self">
            <xsl:value-of select="replace($allEntriesTitle, '^[\-\s]+', '')"/>
          </reference>
          <xsl:for-each select="$combinedGlossary//seg[@type='keyword']">
            <xsl:if test="oc:skipGlossaryEntry(.) = false()">
              <xsl:message>NOTE: Added dictionary sub-menu: <xsl:value-of select="upper-case(substring(text(), 1, 1))"/></xsl:message>
              <reference osisRef="{$DICTMOD}:_45_{oc:encodeOsisRef(upper-case(substring(text(), 1, 1)))}" type="x-glosslink" subType="x-target_self" >
                <xsl:value-of select="upper-case(substring(text(), 1, 1))"/>
              </reference>
            </xsl:if>
          </xsl:for-each>
          
          <p>
            <seg type="keyword" osisID="{oc:encodeOsisRef($allEntriesTitle)}">
              <xsl:value-of select="$allEntriesTitle"/>
            </seg>
          </p>
          <xsl:call-template name="navmenu"><xsl:with-param name="skip" select="'prevnext'"/></xsl:call-template>
          <xsl:for-each select="$combinedGlossary//seg[@type='keyword']">
            <reference osisRef="{$DICTMOD}:{@osisID}" type="x-glosslink" subType="x-target_self">
              <xsl:value-of select="text()"/>
            </reference>
            <lb/>
          </xsl:for-each>
          
          <xsl:for-each select="$combinedGlossary//seg[@type='keyword']">
            <xsl:if test="oc:skipGlossaryEntry(.) = false()">
              <p>
                <seg type="keyword" osisID="_45_{oc:encodeOsisRef(upper-case(substring(text(), 1, 1)))}">
                  <xsl:value-of select="concat('-', upper-case(substring(text(), 1, 1)))"/>
                </seg>
              </p>
              <xsl:call-template name="navmenu"><xsl:with-param name="skip" select="'prevnext'"/></xsl:call-template>
            </xsl:if>
            <reference osisRef="{$DICTMOD}:{@osisID}" type="x-glosslink" subType="x-target_self" >
              <xsl:value-of select="text()"/>
            </reference>
            <lb/>
          </xsl:for-each>
        </div>
      </xsl:if>
    </xsl:copy>
  </xsl:template>
  
  <!-- Add a special subType to Bible introductions if the glossary also includes the introduction -->
  <xsl:template match="div[@type='introduction'][not(ancestor::div[@type=('book','bookGroup')])][not(@subType)]">
    <xsl:copy>
      <xsl:if test="$introScope">
        <xsl:message>NOTE: Added subType="x-glossary-duplicate" to div beginning with: "<xsl:value-of select="substring(string-join(.//text()[normalize-space()], ' '), 1, 128)"/>... "</xsl:message>
        <xsl:attribute name="subType" select="'x-glossary-duplicate'"/>
      </xsl:if>
      <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>
