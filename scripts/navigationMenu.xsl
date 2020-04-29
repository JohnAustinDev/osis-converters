<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/navigationMenu.xsl"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT does the following:
  1) Creates a glossary menu system with links to each glossary entry in 
     a new glossary div with scope="NAVMENU".
  2) Creates an introduction menu system, if there is a glossary with 
     the INT feature.
  3) Inserts navigational links to these into every chapter, glossary 
     entry and book introduction.
  
  NOTE: If the introScope parameter is undef, then no introduction menu
  or links will be created, and if there is no glossary work listed in 
  the OSIS file, then no glossary navigation menus or links will be 
  created. But Bible chapter navigation menus will always be created.
  -->
 
  <import href="./functions/functions.xsl"/>
 
  <!-- Is this OSIS file an x-bible (not a Children's Bible or dict)? -->
  <variable name="isBible" select="/osis/osisText/header/work[@osisWork = /osis/osisText/@osisIDWork]/type[@type='x-bible']"/>
  
  <variable name="sortedGlossaryKeywords" 
      select="//div[@type='glossary']
              //div[starts-with(@type, 'x-keyword')]
              [not(@type = 'x-keyword-duplicate')]
              [not(ancestor::div[@scope='NAVMENU'])]
              [not(ancestor::div[@annotateType='x-feature'][@annotateRef='INT'])]"/>
  
  <variable name="firstTOC" select="/descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]"/>
  
  <variable name="myREF_intro" select="if ($INT_feature) then $REF_introductionINT else ''"/>
  
  <variable name="mainGlossaryID" select="oc:sarg('mainGlossaryID', /, 'false')"/>
  
  <template mode="identity" name="identity" match="node()|@*" >
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <!-- Add TOP osisIDs -->
  <template match="milestone[@type=concat('x-usfm-toc', $TOC)][. intersect $firstTOC]">
    <copy>
      <attribute name="osisID" select="if ($isBible) then 'BIBLE_TOP' else 'DICT_TOP'"/>
      <apply-templates select="node()|@*[not(name()='osisID')]"/>
    </copy>
  </template>
  
  <!-- Insert navmenu links:
  1) before the first applicable text node of each book or the first 
     chapter[@sID] of each book, whichever comes first
  2) at the end of each div[starts-with(@type, 'x-keyword')]
  3) before each Bible chapter[@eID] -->
  <template match="node()|@*">
    <variable name="prependNavMenu" select="
    ancestor::div[@type='book']/
        ( node()[descendant-or-self::text()[normalize-space()][not(ancestor::title[@type='runningHead'])]][1] | 
          descendant::chapter[@sID][1] )[1]
        [. intersect current()]"/>
    <choose>
    
      <!-- Place navmenu before chapter[eID] and anything selected by prependNavMenu -->
      <when test="($DICTMOD and $prependNavMenu) or ($isBible and boolean(self::chapter[@eID]))">
        <sequence select="oc:getNavmenuLinks(
          oc:getPrevChapterOsisID(.),
          oc:getNextChapterOsisID(.),
          $myREF_intro, 
          $REF_dictionary, '', 'false')"/>
        <copy><apply-templates mode="identity" select="node()|@*"/></copy>
        <if test="not(self::chapter) or boolean(self::chapter[matches(@eID, '\.1$')])">
          <call-template name="Note">
<with-param name="msg">Added navmenu before: <value-of select="oc:printNode(.)"/><if test="self::chapter"><value-of select="' and following chapters'"/></if></with-param>
          </call-template>
        </if>
      </when>
      
      <!-- Place prev/next navmenu at the end of each aggregate-subentry -->
      <when test="self::div[@type='x-aggregate-subentry']">
        <copy>
          <apply-templates mode="identity" select="node()|@*"/>
          <sequence select="oc:getNavmenuLinks(
            me:keywordRef('prev', .),
            me:keywordRef('next', .), 
            '', '', '', '')"/>
        </copy>
      </when>
      
      <!-- Place navmenu at the end of each keyword -->
      <when test="self::div[starts-with(@type,'x-keyword')]">
        <copy>
          <apply-templates select="node()|@*"/>
          <sequence select="oc:getNavmenuLinks(
            me:keywordRef('prev', .),
            me:keywordRef('next', .), 
            $myREF_intro, 
            $REF_dictionary, '', '')"/>
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
        
          <!-- This sortedGlossary may be used to generate the glossaryMenu -->
          <variable name="sortedGlossary" as="element(osis)">
            <osis:osis isCombinedGlossary="yes">
              <osis:osisText osisRefWork="{$DICTMOD}" osisIDWork="{$DICTMOD}">
                <osis:div type="glossary">
                  <for-each select="$sortedGlossaryKeywords">
                    <sort select="oc:keySort(.//seg[@type='keyword'])" data-type="text" order="ascending" 
                      collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
                    <copy><apply-templates mode="identity" select="node()|@*"/></copy>
                  </for-each>
                </osis:div>
              </osis:osisText>
            </osis:osis>
          </variable>
          
          <!-- Copy OSIS file contents using sortedGlossary as a tunnel variable -->
          <apply-templates select="node()|@*"/>
          
          <!-- NAVMENU is identified using the scope attribute, rather than an osisID, to facilitate the replacement  
          of uiIntroductionTopMenu by an external div, using the periph INTMENU instruction -->
          <if test="$INT_feature and not(root()//*[@osisID = 'uiIntroductionTopMenu'])">
            <osis:div type="glossary" scope="NAVMENU" resp="x-oc">
            
            <!-- Create a uiIntroductionTopMenu with links to each introductory heading on it -->
              <call-template name="Note">
<with-param name="msg">Added introduction menu: <value-of select="$uiIntroduction"/></with-param>
              </call-template>
              <variable name="introSubEntries" 
                select="//div[@type='glossary'][@annotateType = 'x-feature']
                             [@annotateRef = 'INT']
                             //seg[@type='keyword']"/>
              <text>&#xa;</text>
              <osis:div osisID="uiIntroductionTopMenu" type="x-keyword" subType="x-navmenu-introduction">
                <osis:seg  type="keyword" osisID="{tokenize($REF_introductionINT,':')[2]}">
                  <value-of select="$uiIntroduction"/>
                </osis:seg>
                <sequence select="oc:getNavmenuLinks('', '', '', $REF_dictionary, '', '')"/>
                <osis:title type="main" subType="x-introduction">
                  <value-of select="$uiIntroduction"/>
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
          
          <osis:div osisID="uiDictionaryTopMenu" type="glossary" scope="NAVMENU" resp="x-oc">
            <variable name="menuGlossary" as="element(div)?">
              <variable name="titleGloss" select="/descendant::div[@type='glossary']
                                                  [oc:getDivTitle(.) = $uiDictionary][1]"/>
              <choose>
                <when test="$mainGlossaryID != 'false'">
                  <sequence select="/descendant::div[@type='glossary'][@osisID = $mainGlossaryID]"/>
                </when>
                <when test="$titleGloss and oc:conf('CombineGlossaries', /) != 'true'">
                  <sequence select="$titleGloss"/>
                </when>
                <otherwise>
                  <sequence select="$sortedGlossary/descendant::div[@type='glossary']"/>
                </otherwise>
              </choose>
            </variable>
            <variable name="glossaryMenu"
              select="if ($menuGlossary) 
                      then oc:glossaryMenu($menuGlossary, true(), true(), false()) 
                      else ()"/>
              
            <apply-templates mode="glossmenu_navmenus" select="$glossaryMenu">
              <with-param name="customDictMenu" tunnel="yes" 
                select="/descendant::div[@osisID='uiDictionaryTopMenu.DICTMENU']"/>
            </apply-templates>
            
          </osis:div>
          <text>&#xa;</text>
          
          <call-template name="Note">
<with-param name="msg">Added NAVMENU glossary</with-param>
          </call-template>
          
        </copy>
      </otherwise>
    </choose>
  </template>
  
  <!-- Add navmenu links and customDictMenu to the output of glossaryMenu() -->
  <template mode="glossmenu_navmenus" match="node()|@*" >
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  <template mode="glossmenu_navmenus" match="p">
    <param name="customDictMenu" tunnel="yes"/>
    <next-match/>
    <sequence select="oc:getNavmenuLinks('', '', $myREF_intro, 
                      if (ancestor::div[@subType='x-navmenu-dictionary']) then '' 
                      else $REF_dictionary, '', '')"/>
    <if test="@subType = 'x-navmenu-dictionary'">
      <sequence select="$customDictMenu/node()[not(self::comment())]"/>
    </if>
  </template>
  
  <!-- Add subType='x-target_self' to any custom NAVMENU links -->
  <template mode="#all" match="reference[@type='x-glosslink'][not(@subType)][ancestor::div[@scope='NAVMENU']]">
    <copy>
      <attribute name="subType">x-target_self</attribute>
      <apply-templates select="node()|@*" mode="#current"/>
    </copy>
  </template>
  
  <!-- This menu (if it exists) is moved under x-navmenu-dictionary div -->
  <template mode="#all" match="div[@osisID = 'uiDictionaryTopMenu.DICTMENU']"/>
  
  <function name="me:keywordRef" as="xs:string?">
    <param name="do" as="xs:string"/> <!-- 'prev' or 'next' -->
    <param name="node" as="node()?"/>
    
    <variable name="subentry" 
      select="$node/ancestor-or-self::div[@type = 'x-aggregate-subentry']"/>
    <!-- Sub-entries without titles should not have their own prev/next
    links, because there their context is not apparent. In this case, 
    only the last sub-entry has pre/next links. -->
    <variable name="subentryTitle" 
      select="$subentry/preceding-sibling::*[1][self::title]"/>
    <variable name="isLastSubentry" 
      select="not($subentry/following-sibling::div[@type = 'x-aggregate-subentry'])"/>
    
    <variable name="keyword" as="element(osis:div)?">
      <choose>
        <when test="$subentry and ($subentryTitle or $isLastSubentry)">
          <sequence select="root($node)//div[@type='x-keyword-duplicate']
            [ descendant::seg[@type='keyword'][@osisID = $subentry/replace(@annotateRef, '^[^:]+:', '')] ]"/>
        </when>
        <when test="$node/ancestor-or-self::div[@subType='x-aggregate']"/>
        <otherwise>
          <sequence select="$node/ancestor-or-self::div[starts-with(@type,'x-keyword')]"/>
        </otherwise>
      </choose>
    </variable>
    
    <variable name="prevnext" as="element(osis:div)?">
      <choose>
        <when test="$do = 'prev'">
          <sequence select="$keyword/preceding-sibling::div[starts-with(@type,'x-keyword')][1]"/>
        </when>
        <when test="$do = 'next'">
          <sequence select="$keyword/following-sibling::div[starts-with(@type,'x-keyword')][1]"/>
        </when>
      </choose>
    </variable>
    
    <variable name="osisID" select="$prevnext/descendant::seg[@type='keyword']/replace(@osisID, '\.dup\d+', '')"/>
    
    <value-of select="if ($osisID) then concat($DICTMOD,':',$osisID) else ''"/>
  </function>
  
</stylesheet>
