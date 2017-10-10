<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT does the following:
  1) Creates an introduction menu system and puts it in a glossary with osisRef="NAVMENU"
  2) Creates a glossary menu system with links to each individual glossary entry
  3) Inserts navigational links to these into every glossary entry and book introduction
  -->
 
  <xsl:import href="./functions.xsl"/>
 
  <!-- osisRef of the glossary div which contains introductory material, if it exists -->
  <xsl:param name="osisRefIntro"/>
  
  <!-- this glossary entry will be created as the top level navigation menu if $osisRefIntro exists -->
  <xsl:param name="uiIntroduction" select="concat('-- ', //header/work[child::type[@type='x-bible']]/title[1])"/>
  
  <!-- this glossary entry will be created as the glossary navigation menu -->
  <xsl:param name="uiDictionary" select="concat('- ', //header/work[child::type[@type='x-glossary']]/title[1])"/>
  
  <xsl:variable name="MOD" select="//work[child::type[@type='x-glossary']][1]/@osisWork"/>
  
  <xsl:template match="node()|@*" mode="identity">
    <xsl:copy><xsl:apply-templates select="node()|@*" mode="identity"/></xsl:copy>
  </xsl:template>
  
  <!-- insert navmenu links:
  1) before the first text node of each book or the first chapter[@sID] of each book, whichever comes first
  2) after each glossary keyword's previous text node (except for the first keyword in each glossary div)
  3) after the last text node of each glossary div that contains keywords-->
  <xsl:template match="node()|@*">
    <xsl:variable name="prependNavMenu" select="
    ancestor::div[@type='book']/
        (child::node()[descendant-or-self::text()[normalize-space()]][1] | descendant::chapter[@sID][1])[1]
        [generate-id(.) = generate-id(current())]"/>
    <xsl:variable name="appendNavMenu" select="
    self::node()[descendant-or-self::text()[normalize-space()]]
        [ancestor::div[@type='glossary']//seg[@type='keyword']]
        [following::text()[normalize-space()][1]
            [parent::seg[@type='keyword'][generate-id(.) != generate-id((ancestor::div[@type='glossary']//seg[@type='keyword'])[1])]]
        ]
    or
    self::node()[descendant-or-self::text()[normalize-space()]]
        [ancestor::div[@type='glossary']//seg[@type='keyword']]
        [not(following::text()[normalize-space()]) or following::text()[normalize-space()][1]
            [generate-id(ancestor::div[@type='glossary'][1]) != generate-id(current()/ancestor::div[@type='glossary'][1])]
        ]
    "/>
    <xsl:choose>
      <xsl:when test="$prependNavMenu">
        <xsl:call-template name="navmenu"/>
        <xsl:copy><xsl:apply-templates select="node()|@*" mode="identity"/></xsl:copy>
      </xsl:when>
      <xsl:when test="$appendNavMenu">
        <xsl:copy><xsl:apply-templates select="node()|@*" mode="identity"/></xsl:copy>
        <xsl:call-template name="navmenu"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy><xsl:apply-templates select="node()|@*"/></xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Create glossary navigation menus and put them in a glossary div -->
  <xsl:template match="osisText">
    <xsl:copy>
      <xsl:apply-templates select="node()|@*"/>
      <xsl:if test="//work[@osisWork = current()/@osisIDWork]/type[@type='x-glossary']">
        <div type="glossary" osisRef="NAVMENU">
          
          <!-- Create a uiIntroduction main entry -->
          <xsl:if test="$osisRefIntro and //div[@type='glossary'][@osisRef=$osisRefIntro]">
            <xsl:variable name="introSubEntries" select="//div[@type='glossary'][@osisRef = $osisRefIntro]//seg[@type='keyword']"/>
            <seg type="keyword" osisID="{oc:encodeOsisRef($uiIntroduction)}"><xsl:value-of select="$uiIntroduction"/></seg>
            <xsl:call-template name="navmenu"><xsl:with-param name="skip" select="'introduction'"/></xsl:call-template>
            <title type="main" subType="x-introduction"><xsl:value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/></title>
            <lb/>
            <lb/>
            <xsl:for-each select="$introSubEntries">
              <p type="x-noindent"><reference osisRef="{$MOD}:{oc:encodeOsisRef(.)}" type="x-glosslink" subType="x-target_self"><xsl:value-of select="."/></reference>
                <lb/>
              </p>
            </xsl:for-each>
          </xsl:if>
          
           <!-- Create a uiDictionary main entry, and its sub-entries -->
          <xsl:variable name="dictEntries" select="//div[@type='glossary'][not(@osisRef)]//seg[@type='keyword']"/>
          <xsl:variable name="allEntriesTitle" select="concat('-', upper-case(substring($dictEntries[1], 1, 1)), '-', upper-case(substring($dictEntries[last()], 1, 1)))"/>
          <p>
            <seg type="keyword" osisID="{oc:encodeOsisRef($uiDictionary)}">
              <xsl:value-of select="$uiDictionary"/>
            </seg>
          </p>
          <xsl:call-template name="navmenu"><xsl:with-param name="skip" select="'dictionary'"/></xsl:call-template>
          <reference osisRef="{$MOD}:{oc:encodeOsisRef($allEntriesTitle)}" type="x-glosslink" subType="x-target_self">
            <xsl:value-of select="replace($allEntriesTitle, '^[\-\s]+', '')"/>
          </reference>
          <xsl:for-each select="$dictEntries">
            <xsl:if test="oc:skipGlossaryEntry(.) = false()">
              <reference osisRef="{$MOD}:_45_{upper-case(substring(text(), 1, 1))}" type="x-glosslink" subType="x-target_self" >
                <xsl:value-of select="upper-case(substring(text(), 1, 1))"/>
              </reference>
            </xsl:if>
          </xsl:for-each>
          
          <p>
            <seg type="keyword" osisID="{oc:encodeOsisRef($allEntriesTitle)}">
              <xsl:value-of select="$allEntriesTitle"/>
            </seg>
          </p>
          <xsl:call-template name="navmenu"/>
          <xsl:for-each select="$dictEntries">
            <reference osisRef="{$MOD}:{@osisID}" type="x-glosslink" subType="x-target_self">
              <xsl:value-of select="text()"/>
            </reference>
            <lb/>
          </xsl:for-each>
          
          <xsl:for-each select="$dictEntries">
            <xsl:if test="oc:skipGlossaryEntry(.) = false()">
              <p>
                <seg type="keyword" osisID="_45_{upper-case(substring(text(), 1, 1))}">
                  <xsl:value-of select="concat('-', upper-case(substring(text(), 1, 1)))"/>
                </seg>
              </p>
              <xsl:call-template name="navmenu"/>
            </xsl:if>
            <reference osisRef="{$MOD}:{@osisID}" type="x-glosslink" subType="x-target_self" >
              <xsl:value-of select="text()"/>
            </reference>
            <lb/>
          </xsl:for-each>
        </div>
      </xsl:if>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template name="navmenu">
    <xsl:param name="skip"/>
    <list type="x-navmenu">
      <xsl:if test="not(self::seg[@type='keyword'][@osisID = oc:encodeOsisRef($uiIntroduction)]) and not(matches($skip, 'introduction')) and $osisRefIntro">
        <item>
          <p type="x-right" subType="x-introduction">
            <reference osisRef="{$MOD}:{oc:encodeOsisRef($uiIntroduction)}" type="x-glosslink" subType="x-target_self">
              <xsl:value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/>
            </reference>
          </p>
        </item>
      </xsl:if>
      <xsl:if test="not(self::seg[@type='keyword'][@osisID = oc:encodeOsisRef($uiDictionary)]) and not(matches($skip, 'dictionary'))">
        <item>
          <p type="x-right" subType="x-introduction">
            <reference osisRef="{$MOD}:{oc:encodeOsisRef($uiDictionary)}" type="x-glosslink" subType="x-target_self">
              <xsl:value-of select="replace($uiDictionary, '^[\-\s]+', '')"/>
            </reference>
          </p>
        </item>
      </xsl:if>
      <lb/>
      <lb/>
    </list>
  </xsl:template>
  
</xsl:stylesheet>
