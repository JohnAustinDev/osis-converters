<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT does the following:
  1) Creates a glossary menu system with links to each glossary entry in a new glossary div with scope="NAVMENU"
  2) Creates an introduction menu system, if there is a glossary with the INT feature.
  3) Inserts navigational links to these into every chapter, glossary entry and book introduction
  NOTE: If the introScope parameter is NULL, then no introduction menus/links will be created, and if there is no glossary work listed in the
  OSIS file, then no glossary navigation menus/links will be created. But Bible chapter navigation menus will always be created.
  -->
 
  <import href="./functions.xsl"/>
 
  <!-- this glossary entry will be the top level navigation menu if $using_INT_feature -->
  <param name="uiIntroduction" select="oc:sarg('uiIntroduction', /, concat('-- ', //header/work[child::type[@type='x-bible']]/title[1]))"/>
  
  <!-- this glossary entry will be created as the glossary navigation menu -->
  <param name="uiDictionary" select="oc:sarg('uiDictionary', /, concat('- ', //header/work[child::type[@type='x-glossary']]/title[1]))"/>
  
  <param name="DICTMOD" select="/descendant::work[child::type[@type='x-glossary']][1]/@osisWork"/>
  
  <param name="BIBLEMOD" select="/descendant::work[child::type[@type='x-bible']][1]/@osisWork"/>
  
  <variable name="isBible" select="/osis/osisText/header/work[@osisWork = /osis/osisText/@osisIDWork]/type[@type='x-bible']"/>
  
  <variable name="combinedKeywords" select="//div[@type='glossary']//div[starts-with(@type, 'x-keyword')]
                                                [not(@type = 'x-keyword-duplicate')]
                                                [not(ancestor::div[@scope='NAVMENU'])]
                                                [not(ancestor::div[@annotateType='x-feature'][@annotateRef='INT'])]"/>
  
  <variable name="using_INT_feature" select="//*[@annotateType = 'x-feature'][@annotateRef = 'INT']"/>
  
  <variable name="firstTOC" select="/descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]"/>
  
  <template mode="identity" name="identity" match="node()|@*" >
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <!-- Add TOP osisID -->
  <template match="milestone[@type=concat('x-usfm-toc', $TOC)][generate-id() = generate-id($firstTOC)]">
    <copy>
      <attribute name="osisID" select="if ($isBible) then 'BIBLE_TOP' else 'DICT_TOP'"/>
      <apply-templates select="node()|@*[not(name()='osisID')]"/>
    </copy>
  </template>
  
  <!-- Insert navmenu links:
  1) before the first applicable text node of each book or the first chapter[@sID] of each book, whichever comes first
  2) at the end of each div[starts-with(@type, 'x-keyword')]
  3) before each Bible chapter[@eID] -->
  <template match="node()|@*">
    <param name="navmenuGlossary" tunnel="yes"/>
    <variable name="prependNavMenu" select="
    ancestor::div[@type='book']/
        ( node()[descendant-or-self::text()[normalize-space()][not(ancestor::title[@type='runningHead'])]][1] | 
          descendant::chapter[@sID][1] )[1]
        [. intersect current()]"/>
    <choose>
      <when test="($DICTMOD and $prependNavMenu) or ($isBible and boolean(self::chapter[@eID]))">
        <sequence select="oc:getNavmenuLinks(., /, '')"/>
        <copy><apply-templates mode="identity" select="node()|@*"/></copy>
        <if test="not(self::chapter) or boolean(self::chapter[matches(@eID, '\.1$')])">
          <call-template name="Note">
<with-param name="msg">Added navmenu before: <value-of select="oc:printNode(.)"/><if test="self::chapter"><value-of select="' and following chapters'"/></if></with-param>
          </call-template>
        </if>
      </when>
      <when test="self::div[starts-with(@type, 'x-keyword')]">
        <copy>
          <apply-templates mode="identity" select="node()|@*"/>
          <variable as="element(div)?" name="navmenuGlossaryNode" 
              select="$navmenuGlossary/descendant::div
                      [descendant::seg[@type='keyword'][@osisID = current()//seg[@type='keyword'][1]/@osisID]][1]"/>
          <variable as="element(div)" name="context" 
              select="if ($navmenuGlossaryNode) then $navmenuGlossaryNode else ."/>
          <sequence select="oc:getNavmenuLinks($context, /, if ($context intersect .) then 'prevnext' else '')"/>
        </copy>
        <call-template name="Note">
<with-param name="msg">Added navmenu to keyword: <value-of select="descendant::seg[@type='keyword']"/></with-param>
        </call-template>
      </when>
      <otherwise>
        <copy><apply-templates select="node()|@*"/></copy>
      </otherwise>
    </choose>
  </template>
  
  <!-- Insert navigation menus -->
  <template match="osisText">
    <choose>
    
      <!-- When OSIS is a Bible, insert chapter and introduction navmenus -->
      <when test="$isBible">
        <copy><apply-templates select="node()|@*"/></copy>
      </when>
      
      <!-- Otherwise insert introduction and keyword navmenus within a NAVMENU glossary div -->
      <otherwise>
        <copy>
        
          <!-- This navmenuGlossary is used to generate prev/next links between
          the glossary entries in the OSIS file (using aggregated entries) -->
          <variable name="navmenuGlossary" as="element(div)">
            <osis:div type="glossary">
              <for-each select="$combinedKeywords">
                <sort select="oc:keySort(.//seg[@type='keyword'])" data-type="text" order="ascending" 
                  collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
                <copy><apply-templates mode="identity" select="node()|@*"/></copy>
              </for-each>
            </osis:div>
          </variable>
          
          <!-- Copy OSIS file contents using navmenuGlossary as a tunnel variable -->
          <apply-templates select="node()|@*">
            <with-param name="navmenuGlossary" select="$navmenuGlossary" tunnel="yes"/>
          </apply-templates>
          
          <!-- NAVMENU is identified using the scope attribute, rather than an osisID, to facilitate the replacement  
          of uiIntroductionTopMenu by an external div, with the periph INTMENU instruction -->
          <if test="$using_INT_feature and not(root()//*[@osisID = 'uiIntroductionTopMenu'])">
            <osis:div type="glossary" scope="NAVMENU" resp="x-oc">
            
            <!-- Create a uiIntroduction top menu with links to each introductory heading on it -->
              <call-template name="Note">
<with-param name="msg">Added introduction menu: <value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/></with-param>
              </call-template>
              <variable name="introSubEntries" 
                select="//div[@type='glossary'][@annotateType = 'x-feature']
                             [@annotateRef = 'INT']
                             //seg[@type='keyword']"/>
              <text>&#xa;</text>
              <osis:div osisID="uiIntroductionTopMenu" type="x-keyword" subType="x-navmenu-introduction">
                <osis:seg  type="keyword" osisID="{oc:encodeOsisRef($uiIntroduction)}">
                  <value-of select="$uiIntroduction"/>
                </osis:seg>
                <sequence select="oc:getNavmenuLinks(., /, 'introduction')"/>
                <osis:title type="main" subType="x-introduction">
                  <value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/>
                </osis:title>
                <osis:lb/>
                <osis:lb/>
                <choose>
                  <when test="count($introSubEntries) = 1">
                    <call-template name="Note">
<with-param name="msg">Added introduction menu contents: <value-of select="$introSubEntries"/></with-param>
                    </call-template>
                    <osis:title>
                      <value-of select="$introSubEntries"/>
                    </osis:title>
                    <for-each select="$introSubEntries/following-sibling::node()">
                      <call-template name="identity"/>
                    </for-each>
                  </when>
                  <otherwise>
                    <for-each select="$introSubEntries">
                      <call-template name="Note">
<with-param name="msg">Added introduction menu link: <value-of select="."/></with-param>
                      </call-template>
                      <osis:p type="x-noindent">
                        <osis:reference osisRef="{$DICTMOD}:{oc:encodeOsisRef(.)}" 
                            type="x-glosslink" subType="x-target_self">
                          <value-of select="."/>
                        </osis:reference>
                        <osis:lb/>
                      </osis:p>
                    </for-each>
                  </otherwise>
                </choose>
              </osis:div>
            </osis:div>
          </if>
          
          <sequence select="oc:getGlossaryMenu($navmenuGlossary, root(), 'uiDictionaryTopMenu', false())"/>

          <text>&#xa;</text>
          
          <call-template name="Note">
<with-param name="msg">Added NAVMENU glossary</with-param>
          </call-template>
          
        </copy>
      </otherwise>
    </choose>
  </template>
  
  <!-- Add subType='x-target_self' to any custom NAVMENU links -->
  <template mode="#all" match="reference[@type='x-glosslink'][not(@subType)][ancestor::div[@scope='NAVMENU']]">
    <copy>
      <attribute name="subType">x-target_self</attribute>
      <apply-templates select="node()|@*" mode="#current"/>
    </copy>
  </template>
  
</stylesheet>
