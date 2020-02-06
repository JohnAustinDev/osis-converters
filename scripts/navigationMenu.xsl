<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT does the following:
  1) Creates a glossary menu system with links to each glossary entry in a new glossary div with scope="NAVMENU"
  2) Creates an introduction menu system, if there is a glossary with the INT feature.
  3) Inserts navigational links to these into every chapter, glossary entry and book introduction
  NOTE: If the introScope parameter is NULL, then no introduction menus/links will be created, and if there is no glossary work listed in the
  OSIS file, then no glossary navigation menus/links will be created. But Bible chapter navigation menus will always be created.
  -->
 
  <xsl:import href="./functions.xsl"/>
 
  <!-- this glossary entry will be the top level navigation menu if $using_INT_feature -->
  <xsl:param name="uiIntroduction" select="oc:sarg('uiIntroduction', /, concat('-- ', //header/work[child::type[@type='x-bible']]/title[1]))"/>
  
  <!-- this glossary entry will be created as the glossary navigation menu -->
  <xsl:param name="uiDictionary" select="oc:sarg('uiDictionary', /, concat('- ', //header/work[child::type[@type='x-glossary']]/title[1]))"/>
  
  <xsl:param name="DICTMOD" select="/descendant::work[child::type[@type='x-glossary']][1]/@osisWork"/>
  
  <xsl:param name="BIBLEMOD" select="/descendant::work[child::type[@type='x-bible']][1]/@osisWork"/>
  
  <xsl:variable name="isBible" select="/osis/osisText/header/work[@osisWork = /osis/osisText/@osisIDWork]/type[@type='x-bible']"/>
  
  <!-- this must be identical to the combinedKeywords variable of osis2xhtml.xsl, or else navmenus could end up with broken links -->
  <xsl:variable name="combinedKeywords" select="//div[@type='glossary']//div[starts-with(@type, 'x-keyword')]
                                                [not(@type = 'x-keyword-duplicate')]
                                                [not(ancestor::div[@scope='NAVMENU'])]
                                                [not(ancestor::div[@annotateType='x-feature'][@annotateRef='INT'])]"/>
  
  <xsl:variable name="using_INT_feature" select="//*[@annotateType = 'x-feature'][@annotateRef = 'INT']"/>
  
  <xsl:variable name="firstTOC" select="/descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]"/>
  
  <xsl:template name="identity" match="node()|@*" mode="identity">
    <xsl:copy><xsl:apply-templates select="node()|@*" mode="identity"/></xsl:copy>
  </xsl:template>
  
  <!-- Add TOP osisID -->
  <xsl:template match="milestone[@type=concat('x-usfm-toc', $TOC)][generate-id() = generate-id($firstTOC)]">
    <xsl:copy>
      <xsl:attribute name="osisID" select="if ($isBible) then 'BIBLE_TOP' else 'DICT_TOP'"/>
      <xsl:apply-templates select="node()|@*[not(name()='osisID')]"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- insert navmenu links:
  1) before the first applicable text node of each book or the first chapter[@sID] of each book, whichever comes first
  2) at the end of each div[starts-with(@type, 'x-keyword')]
  3) before each Bible chapter[@eID] -->
  <xsl:template match="node()|@*">
    <xsl:variable name="prependNavMenu" select="
    ancestor::div[@type='book']/
        ( node()[descendant-or-self::text()[normalize-space()][not(ancestor::title[@type='runningHead'])]][1] | descendant::chapter[@sID][1] )[1]
        [generate-id(.) = generate-id(current())]"/>
    <xsl:choose>
      <xsl:when test="($DICTMOD and $prependNavMenu) or ($isBible and boolean(self::chapter[@eID]))">
        <xsl:call-template name="navmenu"/>
        <xsl:copy><xsl:apply-templates select="node()|@*" mode="identity"/></xsl:copy>
        <xsl:if test="not(self::chapter) or boolean(self::chapter[matches(@eID, '\.1$')])">
          <xsl:call-template name="Note"><xsl:with-param name="msg">Added navmenu before: <xsl:value-of select="oc:printNode(.)"/><xsl:if test="self::chapter"><xsl:value-of select="' and following chapters'"/></xsl:if></xsl:with-param></xsl:call-template>
        </xsl:if>
      </xsl:when>
      <xsl:when test="self::div[starts-with(@type, 'x-keyword')]">
        <xsl:copy>
          <xsl:apply-templates select="node()|@*" mode="identity"/>
          <xsl:call-template name="navmenu"/>
        </xsl:copy>
        <xsl:call-template name="Note"><xsl:with-param name="msg">Added navmenu to keyword: <xsl:value-of select="descendant::seg[@type='keyword']"/></xsl:with-param></xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy><xsl:apply-templates select="node()|@*"/></xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- NOTE: Really, links to the glossary from Bibles should be type='x-glossary' but in the navmenus 
  they are all 'x-glosslink' everywhere, so as to be backward compatible with old CSS -->
  <xsl:template name="navmenu">
    <xsl:param name="combinedGlossary" as="element(div)?" tunnel="yes"/>
    <xsl:param name="skip"/>
    <xsl:variable name="cgEntry" select="$combinedGlossary//*[@realid = generate-id(current())]"/>
    <xsl:variable name="nodeInBibleMod" select="ancestor-or-self::osisText[1]/@osisIDWork = $BIBLEMOD"/>
    <list subType="x-navmenu" resp="x-oc">
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
      <xsl:if test="not(self::seg[@type='keyword'][@osisID = oc:encodeOsisRef($uiIntroduction)]) and not(matches($skip, 'introduction'))">
        <item subType="x-introduction-link">
          <p type="x-right">
            <xsl:if test="not($nodeInBibleMod) or not(self::chapter)"><xsl:attribute name="subType" select="'x-introduction'"/></xsl:if>
            <xsl:variable name="intref" 
                select="if ($using_INT_feature) then concat($DICTMOD,':',oc:encodeOsisRef($uiIntroduction)) else concat($BIBLEMOD,':','BIBLE_TOP')"/>
            <reference osisRef="{$intref}" type="x-glosslink" subType="x-target_self">
              <xsl:value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/>
            </reference>
          </p>
        </item>
      </xsl:if>
      <xsl:if test="$DICTMOD and not(self::seg[@type='keyword'][@osisID = oc:encodeOsisRef($uiDictionary)]) and not(matches($skip, 'dictionary'))">
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
  
  <!-- Insert navigation menus -->
  <xsl:template match="osisText">
    <xsl:choose>
    
      <!-- When OSIS is a Bible, insert chapter and introduction navmenus -->
      <xsl:when test="$isBible">
        <xsl:copy><xsl:apply-templates select="node()|@*"/></xsl:copy>
      </xsl:when>
      
      <!-- Otherwise insert keyword navmenus and append the NAVMENU glossary div itself -->
      <xsl:otherwise>
        <xsl:copy>
        
          <xsl:variable name="combinedGlossary" as="element(div)">
            <div type="glossary" subType="x-combinedGlossary">
              <xsl:for-each select="$combinedKeywords"><!-- The following sort should be the same as that in osis2xhtml.xsl WriteCombinedGlossary -->
                <xsl:sort select="oc:keySort(.//seg[@type='keyword'])" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
                <xsl:copy><xsl:attribute name="realid" select="generate-id(.)"/><xsl:apply-templates/></xsl:copy>
              </xsl:for-each>
            </div>
          </xsl:variable>
          
          <!-- Copy OSIS file contents using combinedGlossary as a tunnel variable -->
          <xsl:apply-templates select="node()|@*">
            <xsl:with-param name="combinedGlossary" select="$combinedGlossary" tunnel="yes"/>
          </xsl:apply-templates>
          
          <!-- NAVMENU is identified using the scope attribute, rather than an osisID, to facilitate the replacement  
          of uiIntroductionTopMenu by an external div, with the periph INTMENU instruction -->
          <div type="glossary" scope="NAVMENU" resp="x-oc">
            
            <!-- Create a uiIntroduction top menu with links to each introductory heading on it -->
            <xsl:if test="$using_INT_feature and not(root()//*[@osisID = 'uiIntroductionTopMenu'])">
              <xsl:call-template name="Note"><xsl:with-param name="msg">Added introduction menu: <xsl:value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/></xsl:with-param></xsl:call-template>
              <xsl:variable name="introSubEntries" select="//div[@type='glossary'][@annotateType = 'x-feature'][@annotateRef = 'INT']//seg[@type='keyword']"/>
              <xsl:text>&#xa;</xsl:text>
              <div osisID="uiIntroductionTopMenu" type="x-keyword" subType="x-navmenu-introduction">
                <seg type="keyword" osisID="{oc:encodeOsisRef($uiIntroduction)}"><xsl:value-of select="$uiIntroduction"/></seg>
                <xsl:call-template name="navmenu"><xsl:with-param name="skip" select="'introduction'"/></xsl:call-template>
                <title type="main" subType="x-introduction"><xsl:value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/></title>
                <lb/>
                <lb/>
                <xsl:choose>
                  <xsl:when test="count($introSubEntries) = 1">
                    <xsl:call-template name="Note"><xsl:with-param name="msg">Added introduction menu contents: <xsl:value-of select="$introSubEntries"/></xsl:with-param></xsl:call-template>
                    <title><xsl:value-of select="$introSubEntries"/></title>
                    <xsl:for-each select="$introSubEntries/following-sibling::node()"><xsl:call-template name="identity"/></xsl:for-each>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:for-each select="$introSubEntries">
                      <xsl:call-template name="Note"><xsl:with-param name="msg">Added introduction menu link: <xsl:value-of select="."/></xsl:with-param></xsl:call-template>
                      <p type="x-noindent"><reference osisRef="{$DICTMOD}:{oc:encodeOsisRef(.)}" type="x-glosslink" subType="x-target_self"><xsl:value-of select="."/></reference>
                        <lb/>
                      </p>
                    </xsl:for-each>
                  </xsl:otherwise>
                </xsl:choose>
              </div>
            </xsl:if>
            
             <!-- Create a uiDictionary top menu with links to each letter (plus a link to the A-Z menu) on it -->
            <xsl:call-template name="Note"><xsl:with-param name="msg">Added dictionary menu: <xsl:value-of select="replace($uiDictionary, '^[\-\s]+', '')"/></xsl:with-param></xsl:call-template>
            <xsl:variable name="allEntriesTitle" select="concat('-', upper-case(oc:longestStartingMatchKS($combinedGlossary/descendant::seg[@type='keyword'][1])), '-', upper-case(oc:longestStartingMatchKS($combinedGlossary/descendant::seg[@type='keyword'][last()])))"/>
            <xsl:text>&#xa;</xsl:text>
            <div osisID="uiDictionaryTopMenu" type="x-keyword" subType="x-navmenu-dictionary">
              <p>
                <seg type="keyword" osisID="{oc:encodeOsisRef($uiDictionary)}">
                  <xsl:value-of select="$uiDictionary"/>
                </seg>
              </p>
              <xsl:call-template name="navmenu"><xsl:with-param name="skip" select="'dictionary'"/></xsl:call-template>
              <xsl:call-template name="Note"><xsl:with-param name="msg">Added dictionary sub-menu: <xsl:value-of select="replace($allEntriesTitle, '^[\-\s]+', '')"/></xsl:with-param></xsl:call-template>
              <reference osisRef="{$DICTMOD}:{oc:encodeOsisRef($allEntriesTitle)}" type="x-glosslink" subType="x-target_self">
                <xsl:value-of select="replace($allEntriesTitle, '^[\-\s]+', '')"/>
              </reference>
              <xsl:for-each select="$combinedGlossary//seg[@type='keyword']">
                <xsl:if test="oc:skipGlossaryEntry(.) = false()">
                  <xsl:call-template name="Note"><xsl:with-param name="msg">Added dictionary sub-menu: <xsl:value-of select="upper-case(oc:longestStartingMatchKS(text()))"/></xsl:with-param></xsl:call-template>
                  <reference osisRef="{$DICTMOD}:_45_{oc:encodeOsisRef(upper-case(oc:longestStartingMatchKS(text())))}" type="x-glosslink" subType="x-target_self" >
                    <xsl:value-of select="upper-case(oc:longestStartingMatchKS(text()))"/>
                  </reference>
                </xsl:if>
              </xsl:for-each>
            </div>
            
            <!-- Create a sub-menu with links to every keyword listed on it -->
            <xsl:text>&#xa;</xsl:text>
            <div osisID="dictionaryAtoZ" type="x-keyword" subType="x-navmenu-atoz">
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
            </div>
            
            <!-- Create separate sub-menus for each letter (plus A-Z) with links to keywords beginning with that letter -->
            <xsl:variable name="letterMenus" as="node()*">
              <xsl:for-each select="$combinedGlossary//seg[@type='keyword']">
                <xsl:if test="oc:skipGlossaryEntry(.) = false()">
                  <p>
                    <seg type="keyword" osisID="_45_{oc:encodeOsisRef(upper-case(oc:longestStartingMatchKS(text())))}">
                      <xsl:value-of select="concat('-', upper-case(oc:longestStartingMatchKS(text())))"/>
                    </seg>
                  </p>
                  <xsl:call-template name="navmenu"><xsl:with-param name="skip" select="'prevnext'"/></xsl:call-template>
                </xsl:if>
                <reference osisRef="{$DICTMOD}:{@osisID}" type="x-glosslink" subType="x-target_self" >
                  <xsl:value-of select="text()"/>
                </reference>
                <lb/>
              </xsl:for-each>
            </xsl:variable>
            <xsl:for-each-group select="$letterMenus" group-starting-with="p[child::*[1][self::seg[@type='keyword']]]">
              <xsl:text>&#xa;</xsl:text>
              <div type="x-keyword" subType="x-navmenu-letter"><xsl:sequence select="current-group()"/></div>
            </xsl:for-each-group>
            <xsl:text>&#xa;</xsl:text>
            
          </div>
          <xsl:text>&#xa;</xsl:text>
          
          <xsl:call-template name="Note"><xsl:with-param name="msg">Added NAVMENU glossary</xsl:with-param></xsl:call-template>
          
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Add subType='x-target_self' to any custom NAVMENU links -->
  <xsl:template match="reference[@type='x-glosslink'][not(@subType)][ancestor::div[@scope='NAVMENU']]" mode="#all">
    <xsl:copy>
      <xsl:attribute name="subType">x-target_self</xsl:attribute>
      <xsl:apply-templates select="node()|@*" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>
