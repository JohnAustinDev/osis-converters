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
  
  <variable name="noDictTopMenu" select="oc:sarg('noDictTopMenu', /, 'false')"/>
  
  <variable name="doCombineGlossaries" select="oc:conf('CombineGlossaries', /) = 'true'"/>
  
  <variable name="glossaryNavmenuLinks" select="/osis[$DICTMOD]/osisText/header/work/description
      [matches(@type, '^x\-config\-GlossaryNavmenuLink\[[1-9]\]')]/string()"/>
  <variable name="dictlinks" as="xs:string*" select="if (not($DICTMOD)) then ()
      else if (count($glossaryNavmenuLinks)) then $glossaryNavmenuLinks 
      else oc:decodeOsisRef(tokenize($REF_dictionary, ':')[2])"/>
  <variable name="docroot" select="/"/>
  
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
          me:bestRef($dictlinks))"/>
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
            '', ())"/>
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
            me:bestRef($dictlinks))"/>
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
      
      <!-- Otherwise insert introduction and DICTMOD navmenus within NAVMENU glossary divs -->
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
          
          <!-- Copy OSIS file contents -->
          <apply-templates select="node()|@*"/>
          
          <!-- uiIntroductionTopMenu is a NAVMENU glossary used by the INT feature. It is  
          identified using the scope attribute to facilitate the replacement of 
          uiIntroductionTopMenu using the INTMENU feature -->
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
                <sequence select="oc:getNavmenuLinks('', '', '', me:bestRef($dictlinks))"/>
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
          
          <!-- There are two options for generating the DICTMOD menu system. When 
          config.conf CombineGlossaries=true then oc:glossaryMenu will be run on
          a single combined glossary so there will be up to two levels of menus: 
          the A-Z menu, and the letter menus. But when CombineGlossaries=false|AUTO 
          then oc:glossaryMenu will be run on each glossary div, and there will be
          up to three levels of menus: a glossary menu, then either keyword menus, 
          or, for one particular designated glossary, possibly an A-Z and letter 
          sub-menus will be generated. The A-Z glossary is chosen one of three ways: 
          if CombineGlossaries=true it will be the combined glossary, if config.conf 
          ARG_mainGlossaryID is set, it will be the glossary with that osisID, 
          otherwise the glossary with the most keywords will be used. If there are  
          less than ARG_glossThresh keywords in the designated glossary, it will  
          still not have an A-Z menu or letter submenus, but only a keyword menu. If 
          config.conf ARG_noDictTopMenu is 'true' the DICT top menu will not be 
          generated. -->
          <osis:div type="glossary" scope="NAVMENU" resp="x-oc">

            <variable name="atoz" as="element(div)?">
              <variable name="glossaries" as="element(div)*" select="/descendant::div[@type='glossary']
                [not(@scope = 'NAVMENU')][not(@annotateType = 'x-feature')][not(subType = 'x-aggregate')]"/>
              <variable name="maxkw" select="max($glossaries/count(descendant::seg[@type='keyword']))"/>
              <choose>
                <when test="$doCombineGlossaries">
                  <sequence select="$sortedGlossary/descendant::div[@type='glossary']"/>
                </when>
                <when test="$mainGlossaryID != 'false'">
                  <sequence select="/descendant::div[@type='glossary'][@osisID = $mainGlossaryID]"/>
                </when>
                <when test="$maxkw &#62; $glossThresh">
                  <sequence select="$glossaries[count(descendant::seg[@type='keyword']) = $maxkw]"/>
                </when>
              </choose>
            </variable>
            
            <variable name="glossNavMenus">
              <choose>
                <when test="$doCombineGlossaries">
                  <sequence select="oc:glossaryMenu($atoz, true(), true(), true(), false())"/>
                </when>
                <otherwise>
                  <if test="not($noDictTopMenu = 'true')">
                    <variable name="glossaryTopMenu" select="oc:glossaryTopMenu(.)"/>
                    <if test="count($glossaryTopMenu//reference) &#60;= 5 
                              and count($glossaryNavmenuLinks) = 0">
                      <call-template name="Warn">
<with-param name="msg">There are only <value-of select="count($glossaryTopMenu//reference)"/> links on the top <value-of select="$DICTMOD"/> navigation menu, 
and you are not specifying GlossaryNavmenuLink[n] in config.conf.</with-param>
<with-param name="exp">You can improve SWORD module navigation by making these links 
into navmenu links and avoiding an extra menu by specifying the 
following in config.conf:
<for-each select="$glossaryTopMenu//reference">
<variable name="val" as="xs:string">
<choose>
  <when test="oc:decodeOsisRef(tokenize(@osisRef, ':')[2]) = string()">
    <value-of select="string()"/>
  </when>
  <otherwise><value-of select="concat('&amp;osisRef=', @osisRef, '&amp;text=', string())"/></otherwise>
</choose>
</variable>
<value-of select="concat('GlossaryNavmenuLink[', position(), ']=', $val, '&#xa;')"/>
</for-each>
</with-param>
                      </call-template>
                    </if>
                    <sequence select="$glossaryTopMenu"/>
                  </if>
                  <for-each select="div[@type='glossary'][not(@scope = 'NAVMENU')]
                                                         [not(@annotateType = 'x-feature')]
                                                         [not(subType = 'x-aggregate')]">
                    <sequence select="oc:glossaryMenu(., 
                      boolean(position() = 1 and $noDictTopMenu = 'true'), 
                      boolean(. intersect $atoz), 
                      boolean(. intersect $atoz),
                      false())"/>
                  </for-each>
                </otherwise>
              </choose>
            </variable>

            <apply-templates mode="glossNavMenus" select="$glossNavMenus">
              <with-param name="dictdoc" tunnel="yes" select="/"/>
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
  
  <!-- Replace or modify DICT NAVMENU menus using the DICTMENU feature:
  DICTMENU.osisID -> replaces the entire x-keyword div's contents.
  DICTMENU.osisID.top -> inserts nodes after the menu keyword. -->
  <template mode="glossNavMenus" match="node()|@*" >
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  <template mode="glossNavMenus" match="div[starts-with(@type, 'x-keyword')]">
    <param name="dictdoc" tunnel="yes"/>
    <copy>
      <copy-of select="@*"/>
      <if test="descendant::seg[@type='keyword'][string() = $uiDictionary]">
        <attribute name="osisID" select="'uiDictionaryTopMenu'"/> 
      </if>
      <variable name="myid" select="descendant::seg[@type = 'keyword'][1]/@osisID"/>
      <choose>
        <when test="$dictdoc//*[@osisID = concat('DICTMENU.', $myid)]">
          <sequence select="$dictdoc//*[@osisID = concat('DICTMENU.', $myid)]/node()[not(self::comment())]"/>
        </when>
        <otherwise>
          <apply-templates mode="#current"/>
        </otherwise>
      </choose>
    </copy>
  </template>
  <template mode="glossNavMenus" match="p">
    <param name="dictdoc" tunnel="yes"/>
    <next-match/>
    <variable name="mykw" select="ancestor::div[starts-with(@type, 'x-keyword')]
                                  /descendant::seg[@type='keyword'][1]"/>
    <variable name="mylinks" as="xs:string*" select="(for $i in $dictlinks return 
        if (oc:encodeOsisRef($i) = $mykw/@osisID) then '' else $i)"/>
    <sequence select="oc:getNavmenuLinks('', '', $myREF_intro, me:bestRef($mylinks))"/>
    <if test="@subType = 'x-navmenu-top'">
      <variable name="refs" select="$dictdoc//*[@osisID = concat('DICTMENU.', $mykw/@osisID, '.top')]"/>
      <sequence select="$refs/node()[not(self::comment())]"/>
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
  <template mode="#all" match="div[starts-with(@osisID, 'DICTMENU.')]"/>
  
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
  
  <!-- If a target menu has only one keyword, target that keyword directly. -->
  <function name="me:bestRef" as="xs:string*">
    <param name="links" as="xs:string*"/>
    <sequence select="for $i in $links return
        if (not(matches($i, '\S'))) then ''
        else if (contains($i, '&amp;osisRef=')) then $i
        else if (count($docroot//div[@type='glossary']
            [oc:getDivTitle(.) = $i]/descendant::seg[@type='keyword']) = 1) 
        then concat('&amp;osisRef=', $DICTMOD, ':', oc:encodeOsisRef(
            $docroot//div[@type='glossary'][oc:getDivTitle(.) = $i]
            /descendant::seg[@type='keyword']/string()), '&amp;text=', $i) 
        else concat('&amp;osisRef=', $DICTMOD, ':', oc:encodeOsisRef($i), '&amp;text=', $i)"/>
  </function>
  
</stylesheet>
