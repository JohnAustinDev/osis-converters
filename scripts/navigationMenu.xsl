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
  1) Creates an introduction menu system when the INT feature is being 
     used, having scope="NAVMENU".
  2) Creates a reference material menu system for DICTMOD with links to 
     each glossary and its keywords, having scope="NAVMENU".
  3) Inserts navigational links into every chapter, glossary entry and 
     book introduction. These 'navmenu's have links to prev/next chapter
     or keyword, and links to the above NAVMENUs.
     
     NOTE: This navigation menu system is currently used by SWORD.
     As such it is designed to meet the following criteria:
     - Optimized for random-access Bibles, such as a website or Bible 
       study program. So rather than having a central table of contents, 
       there are many smaller table of contents, one for every 
       introduction, chapter, or keyword.
     - Navmenu links must only target keywords contained in the glossary 
       divs of DICTMOD.
     - Every keyword must be unique (this is handled using aggregated
       keywords when necessary).
  -->
 
  <import href="./common/functions.xsl"/>
 
  <!-- Is this OSIS file an x-bible (not a Children's Bible or dict)? -->
  <variable name="isBible" select="/osis/osisText/header/work[@osisWork = /osis/osisText/@osisIDWork]/type[@type='x-bible']"/>
  
  <variable name="combinedGlossaryKeywords" 
      select="//div[@type='glossary']
              //div[starts-with(@type, 'x-keyword')]
              [not(@type = 'x-keyword-duplicate')]
              [not(ancestor::div[@scope='NAVMENU'])]
              [not(ancestor::div[@annotateType='x-feature'][@annotateRef='INT'])]"/>
  
  <variable name="firstTOC" select="/descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]"/>
  
  <variable name="myREF_intro" select="if ($INT_feature) then $REF_introductionINT else ''"/>
  
  <variable name="mainGlossaryID" select="oc:sarg('mainGlossaryID', /, 'false')"/>
  
  <variable name="noDictTopMenu" select="oc:sarg('noDictTopMenu', /, 'no')"/>
  
  <variable name="doCombineGlossaries" select="oc:conf('CombineGlossaries', /) = 'true'"/>
  
  <variable name="glossaryNavmenuLinks" select="/osis[$DICTMOD]/osisText/header/work/description
      [matches(@type, '^x\-config\-GlossaryNavmenuLink\[[1-9]\]')]/string()"/>
  <variable name="dictLinks" as="xs:string*" select="if (not($DICTMOD)) then ()
      else if (count($glossaryNavmenuLinks)) then $glossaryNavmenuLinks 
      else oc:decodeOsisRef(tokenize($REF_dictionary, ':')[2])"/>
  <variable name="dictLinksEnc" as="xs:string*" select="for $t in $dictLinks return me:glossaryNavmenuLink($t)"/>
  <variable name="docroot" select="/"/>
  
  <variable name="customize" as="element(div)*" select="/osis/osisText/div[starts-with(@osisID, 'NAVMENU.')]"/>
  
  <template mode="identity introMenu" name="identity" match="node()|@*" >
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
          oc:getPrevChapterEncRef(.),
          oc:getNextChapterEncRef(.),
          if (not($myREF_intro)) then '' else concat('&amp;osisRef=', $myREF_intro), 
          $dictLinksEnc)"/>
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
            me:keywordEncREF('prev', .),
            me:keywordEncREF('next', .), 
            '', ())"/>
        </copy>
      </when>
      
      <!-- Place navmenu at the end of each keyword -->
      <when test="self::div[starts-with(@type,'x-keyword')]">
        <variable name="skipPrevNext" select="@subType = 
          ('x-navmenu-glossaries', 'x-navmenu-all-letters', 'x-navmenu-all-keywords')"/>
        <copy>
          <apply-templates select="node()|@*"/>
          <sequence select="oc:getNavmenuLinks(
            if ($skipPrevNext)       then '' else me:applyMenuContext(., me:keywordEncREF('prev', .)),
            if ($skipPrevNext)       then '' else me:applyMenuContext(., me:keywordEncREF('next', .)), 
            if (not($myREF_intro))   then '' else me:applyMenuContext(., concat('&amp;osisRef=', $myREF_intro)), 
            for $t in $dictLinksEnc return me:applyMenuContext(., $t) )"/>
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
  
  <template match="osisText">
    <choose>
    
      <!-- When OSIS is a Bible, insert chapter and introduction navmenus -->
      <when test="$isBible">
        <copy><apply-templates select="node()|@*"/></copy>
      </when>
      
      <!-- Otherwise create introduction and DICTMOD NAVMENUs -->
      <otherwise>
        <copy>
          
          <!-- Copy OSIS file contents -->
          <apply-templates select="node()|@*"/>
          
          <!-- CombinedGlossary may be used to generate DICTMOD NAVMENUs -->
          <variable name="combinedGlossary" as="element(osis)">
            <osis:osis isCombinedGlossary="yes">
              <osis:osisText osisRefWork="{$DICTMOD}" osisIDWork="{$DICTMOD}">
                <osis:div type="glossary">
                  <osis:title type="main"><value-of select="$uiDictionary"/></osis:title>
                  <for-each select="$combinedGlossaryKeywords">
                    <sort select="oc:keySort(.//seg[@type='keyword'])" data-type="text" order="ascending" 
                      collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
                    <copy><apply-templates mode="identity" select="node()|@*"/></copy>
                  </for-each>
                </osis:div>
              </osis:osisText>
            </osis:osis>
          </variable>
          
          <variable name="navmenus" as="element(div)+">
            <!-- Create a menu with links to each introductory heading on it -->
            <variable name="INT" select="//div[@type='glossary']
              [@annotateType = 'x-feature'][@annotateRef = 'INT']"/>
            <if test="$INT">
              <osis:div type="glossary" scope="NAVMENU" resp="x-oc">
                <text>&#xa;</text>
                <osis:div type="x-keyword" subType="x-navmenu-introduction">
                  <osis:p subType="x-navmenu-top">
                    <osis:seg  type="keyword" osisID="{tokenize($REF_introductionINT,':')[2]}">
                      <value-of select="$uiIntroduction"/>
                    </osis:seg>
                  </osis:p>
                  <osis:title type="main" subType="x-introduction">
                    <value-of select="$uiIntroduction"/>
                  </osis:title>
                  <osis:lb/>
                  <osis:lb/>
                  <choose>
                    <when test="count($INT//seg[@type='keyword']) &#60;= 1">
                      <apply-templates mode="introMenu" select="$INT/node()"/>
                      <call-template name="Note">
<with-param name="msg">Added intro content to <value-of select="$uiIntroduction"/></with-param>
                      </call-template>
                    </when>
                    <otherwise>
                      <osis:list subType="x-menulist">
                        <for-each select="$INT//seg[@type='keyword']">
                          <osis:item>
                            <osis:reference osisRef="{$DICTMOD}:{oc:encodeOsisRef(.)}" 
                                type="x-glosslink" subType="x-target_self">
                              <value-of select="."/>
                            </osis:reference>
                          </osis:item>
                          <call-template name="Note">
<with-param name="msg">Added intro link <value-of select="$uiIntroduction"/>: <value-of select="."/></with-param>
                          </call-template>
                        </for-each>
                      </osis:list>
                    </otherwise>
                  </choose>
                </osis:div>
                <call-template name="Note">
<with-param name="msg">Finished introduction NAVMENU '<value-of select="$uiIntroduction"/>'</with-param>
                </call-template>
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
            less than ARG_glossaryTocAutoThresh keywords in the designated glossary, it   
            will still not have an A-Z menu or letter submenus, but only a keyword menu.  
            If config.conf ARG_noDictTopMenu is 'yes' the DICT top menu will not be 
            generated. -->
            <osis:div type="glossary" scope="NAVMENU" resp="x-oc">
              <variable name="osisText" select="if ($doCombineGlossaries) 
                                                then $combinedGlossary/osisText 
                                                else ."/>
              <variable name="atoz" as="element(div)?">
                <variable name="glossaries" as="element(div)*" select="$osisText/descendant::div[@type='glossary']
                  [not(@scope = 'NAVMENU')][not(@annotateType = 'x-feature')][not(@subType = 'x-aggregate')]"/>
                <variable name="maxkw" select="max($glossaries/count(descendant::seg[@type='keyword']))"/>
                <choose>
                  <when test="$doCombineGlossaries">
                    <sequence select="$combinedGlossary/descendant::div[@type='glossary']"/>
                  </when>
                  <when test="$mainGlossaryID != 'false'">
                    <sequence select="/descendant::div[@type='glossary'][@osisID = $mainGlossaryID]"/>
                  </when>
                  <when test="$maxkw &#62; $glossaryTocAutoThresh">
                    <sequence select="$glossaries[count(descendant::seg[@type='keyword']) = $maxkw]"/>
                  </when>
                </choose>
              </variable>
              
              <if test="not($noDictTopMenu = 'yes')">
                <variable name="glossaryTopMenu" select="oc:glossaryTopMenu($osisText)"/>
                <if test="count($glossaryTopMenu//reference) &#60;= 4 
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
    <otherwise>
      <value-of select="concat('&amp;osisRef=', @osisRef, '&amp;text=', string())"/>
    </otherwise>
  </choose>
</variable>
<value-of select="concat('GlossaryNavmenuLink[', position(), ']=', $val, '&#xa;')"/>
</for-each>
</with-param>
                  </call-template>
                </if>
                <sequence select="$glossaryTopMenu"/>
              </if>
              
              <for-each select="$osisText/div[@type='glossary'][oc:getDivTitle(.)]
                  [not(@scope = 'NAVMENU')][not(@annotateType = 'x-feature')][not(@subType = 'x-aggregate')]">
                <if test="not($noDictTopMenu = 'yes') or boolean(. intersect $atoz)">
                  <sequence select="oc:glossaryMenu(., 'AUTO', 'AUTO', false())"/>
                </if>
              </for-each>
              <call-template name="Note">
<with-param name="msg">Finished glossary NAVMENU '<value-of select="$uiDictionary"/>'</with-param>
              </call-template>              
            </osis:div>
          </variable>
          
          <variable name="navmenus1">
            <!-- replace or modify using the NAVMENU feature -->
            <apply-templates mode="navmenus" select="$navmenus"/>
          </variable>
          <!-- append navmenu links -->
          <apply-templates select="$navmenus1"/>
        
        </copy>
      </otherwise>
    </choose>
  </template>
  
  <template mode="introMenu" match="seg[@type='keyword']">
    <osis:title>
      <sequence select="node()"/>
    </osis:title>
  </template>
  <template mode="introMenu" match="div[starts-with(@type,'x-keyword')]/@type"/>
  <template mode="introMenu" match="comment() | title[@type='runningHead'] | milestone" priority="1"/>
  
  <!-- Replace or modify NAVMENUs using the NAVMENU feature:
  NAVMENU.osisID.replace -> replaces the keyword div of the keyword having the osisID.
  NAVMENU.osisID.top -> inserts nodes at the top of the keyword div having the osisID. -->
  <template mode="navmenus" match="node()|@*" >
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  <template mode="navmenus" match="comment()" priority="1"/>
  <template mode="navmenus" match="@type[parent::div intersect $customize]"/>
  <template mode="navmenus" match="div[starts-with(@type, 'x-keyword')]
    [descendant::seg[@type='keyword'][1][@osisID = $customize/replace(@osisID, '^NAVMENU\.(.*)\.replace$', '$1')]]">
    <variable name="osisID" select="descendant::seg[@type='keyword'][1]/@osisID"/>
    <apply-templates mode="#current" 
      select="$customize[@osisID = concat('NAVMENU.', $osisID, '.replace')]">
      <with-param name="src" select="." tunnel="yes"/>
    </apply-templates>
    <call-template name="Note">
<with-param name="msg">Customizing NAVMENU '<value-of select="$osisID"/>' (replacement)</with-param>
    </call-template>
  </template>
  <template mode="navmenus" match="div[starts-with(@type, 'x-keyword')]
    [ancestor::div[@osisID = $customize/@osisID]]" priority="1">
    <param name="src" tunnel="yes"/>
    <copy>
      <if test="$src and ( ancestor::div[@type='glossary']
        /descendant::div[starts-with(@type, 'x-keyword')][1] intersect . )">
        <sequence select="$src/attribute()"/>
      </if>
      <apply-templates mode="#current" select="@*|node()"/>
    </copy>
  </template>
  <template mode="navmenus" match="p">
    <next-match/>
    <variable name="mykw" 
      select="ancestor::div[starts-with(@type, 'x-keyword')]/descendant::seg[@type='keyword'][1]"/>
    <variable name="ins" select="$customize[@osisID = concat('NAVMENU.', $mykw/@osisID, '.top')]"/>
    <if test="@subType = 'x-navmenu-top' and $ins">
      <apply-templates mode="#current" select="$ins"/>
      <call-template name="Note">
<with-param name="msg">Customizing NAVMENU '<value-of select="string($mykw)"/>' (insertion)</with-param>
      </call-template>
    </if>
  </template>
            
  <!-- Adds subType='x-target_self' to any custom NAVMENU links -->
  <template mode="#all" match="reference[@type='x-glosslink'][not(@subType)][ancestor::div[@scope='NAVMENU']]">
    <copy>
      <attribute name="subType">x-target_self</attribute>
      <apply-templates select="node()|@*" mode="#current"/>
    </copy>
  </template>
  
  <!-- These menus (when they exist) are moved to the navmenu -->
  <template match="div[. intersect $customize]">
    <call-template name="Note">
<with-param name="msg">Found custom NAVMENU osisID="<value-of select="@osisID"/>"</with-param>
    </call-template>
  </template>
  
  <!-- Return the query encoded osisRef of the next or previous keyword.
  When node is in an aggregated entry, the source glossary is used for 
  the prev/next context, rather than the aggregated glossary. -->
  <function name="me:keywordEncREF" as="xs:string?">
    <param name="do" as="xs:string"/> <!-- 'prev' or 'next' -->
    <param name="node" as="node()?"/>
    
    <variable name="subentry" 
      select="$node/ancestor-or-self::div[@type = 'x-aggregate-subentry']"/>
    <!-- Sub-entries without titles should not have their own prev/next
    links, because their context is not apparent. In this case, only the 
    last sub-entry has prev/next links. -->
    <variable name="subentryTitle" 
      select="$subentry/preceding-sibling::*[1][self::title]"/>
    <variable name="isLastSubentry" 
      select="not($subentry/following-sibling::div[@type = 'x-aggregate-subentry'])"/>
    
    <variable name="keyword" as="element(osis:div)?">
      <choose>
        <when test="$subentry and ($subentryTitle or $isLastSubentry)">
          <sequence select="root($node)//div[@type='x-keyword-duplicate']
            [ descendant::seg[@type='keyword'][@osisID = $subentry/replace(@osisID, '!(dup\d+)$', '.$1')] ]"/>
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
    
    <value-of select="if ($osisID) then concat('&amp;osisRef=', $DICTMOD, ':', $osisID) else ''"/>
  </function>
  
  <!-- Hide or disable links according to the menu on which they appear -->
  <function name="me:applyMenuContext" as="xs:string?">
    <param name="kwdiv" as="element(div)"/>
    <param name="osisRefEnc" as="xs:string"/>
    <variable name="osisRef" select="replace($osisRefEnc, '^.*?&amp;osisRef=([^&amp;]+).*?$' , '$1')"/>
    <variable name="osisID" select="$kwdiv//seg[@type='keyword'][1]/@osisID"/>
    <!-- If osisRef is to the current menu, the append &disabled=1 -->
    <variable name="osisRefEnc2" select="
      if (tokenize($osisRef, ':')[2] = $osisID)
      then concat($osisRefEnc, '&amp;disabled=1') 
      else $osisRefEnc"/>
    <!-- If a link to osisRef is already listed on the current menu, then return ''
    <variable name="osisRefEnc3" select="
      if (tokenize($osisRef, ':')[2] = $kwdiv//reference/tokenize(@osisRef, ':')[2])
      then '' 
      else $osisRefEnc2"/> -->
    <value-of select="$osisRefEnc2"/>
  </function>
  
  <!-- Check and convert config.conf glossaryNavmenuLink[n] values into
  finished URL query incoded link strings -->
  <function name="me:glossaryNavmenuLink" as="xs:string">
    <param name="navmenuLink" as="xs:string"/>
    <variable name="nml1" select="if (matches($navmenuLink, '&amp;[^=]+=')) 
        then $navmenuLink 
        else concat('&amp;osisRef=', $DICTMOD, ':', oc:encodeOsisRef($navmenuLink), '&amp;text=', $navmenuLink)"/>
    <if test="not(matches($nml1, '&amp;osisRef=[^&amp;]+'))">
      <call-template name="Error">
<with-param name="msg">glossaryNavmenuLink has no osisRef: glossaryNavmenuLink[n]=<value-of select="$navmenuLink"/></with-param>
<with-param name="exp">A glossaryNavmenuLink value in config.conf must not include attributes unless attribute &amp;osisRef=MOD:target is also included.</with-param>
<with-param name="die">yes</with-param>
      </call-template>
    </if>
    <variable name="nml2" select="if (matches($nml1, '&amp;text=[^&amp;]+')) then $nml1 
        else concat($nml1, '&amp;text=', oc:decodeOsisRef(replace($nml1, '^.*?&amp;osisRef=[^:&amp;]+:([^&amp;]+).*?$', '$1')))"/>
        
    <value-of select="me:bestRefEnc($nml2)"/>
  </function>
  
  <!-- If a target DICTMOD menu has only one keyword, skip the menu and
  target that keyword directly. -->
  <function name="me:bestRefEnc" as="xs:string">
    <param name="encLink" as="xs:string"/>
    <variable name="osisRef" select="replace($encLink, '^.*?&amp;osisRef=([^&amp;]+).*?$', '$1')"/>
    <variable name="reftext" select="oc:decodeOsisRef(tokenize($osisRef, ':')[2])"/>
    <variable name="osisRefNew" select="if (count($docroot//div[@type='glossary']
            [oc:getDivTitle(.) = $reftext]/descendant::seg[@type='keyword']) = 1)
        then concat($DICTMOD, ':', oc:encodeOsisRef($docroot//div[@type='glossary']
            [oc:getDivTitle(.) = $reftext]/descendant::seg[@type='keyword']/string()))
        else $osisRef"/>
    <value-of select="replace($encLink, '&amp;osisRef=[^&amp;]+', concat('&amp;osisRef=', $osisRefNew))"/>
  </function>
  
</stylesheet>
