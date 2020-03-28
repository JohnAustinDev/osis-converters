<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:runtime="java:java.lang.Runtime"
 xmlns:uri="java:java.net.URI"
 xmlns:file="java:java.io.File"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 exclude-result-prefixes="#all">
  
  <!-- If script-specific config context is desired from oc:conf(), then the calling script must pass this SCRIPT_NAME parameter -->
  <param name="SCRIPT_NAME"/>
  
  <!-- If DICT-specific config context is desired from oc:conf(), then either the OSIS file header 
  and osisText elements must be marked-up as x-glossary type, OR the calling script must pass in DICTMOD -->
  <param name="DICTMOD" select="/osis/osisText/header/work[child::type[@type='x-glossary']]/@osisWork"/>
  <!-- The main module code (could refer to Bible or Children's Bible) -->
  <variable name="MAINMOD" select="/descendant::work[child::type[@type!='x-glossary']][1]/@osisWork"/>
  
  <param name="MAINMOD_URI"/>
  <param name="DICTMOD_URI"/>
  <variable name="MAINMOD_DOC" select="if ($MAINMOD_URI) then doc($MAINMOD_URI) else ()"/>
  <variable name="DICTMOD_DOC" select="if ($DICTMOD_URI) then doc($DICTMOD_URI) else ()"/>
  
  <!-- The following config entries require a properly marked-up OSIS header, OR 
  the calling script must pass in their values (otherwise an error is thrown for oc:conf()) -->
  <param name="DEBUG" select="oc:csys('DEBUG', /)"/>
  <param name="TOC" select="oc:conf('TOC', /)"/>
  <param name="TitleCase" select="oc:conf('TitleCase', /)"/>
  <param name="KeySort" select="oc:conf('KeySort', /)"/>
  
  <!-- All projects have an osisID for the main introduction, and if there is a reference OSIS file
  there will also be an osisID for the top of the reference material. NOTE: If the INT feature is 
  used, the main introduction osisID will be in the dictionary module. -->
  <variable name="INT_feature" select="/descendant::*[@annotateType = 'x-feature'][@annotateRef = 'INT'][1]"/>
  <variable name="uiIntroduction" 
    select="oc:sarg('uiIntroduction', /, concat('-- ', /osis/osisText/header/work[@osisWork = $MAINMOD]/title[1]))"/>
  <variable name="uiDictionary" select="if ($DICTMOD) then 
            oc:sarg('uiDictionary', /, concat('- ', /osis/osisText/header/work[@osisWork = $DICTMOD]/title[1])) else ''"/>

  <variable name="REF_introduction" select="concat($MAINMOD,':BIBLE_TOP')"/>
  <variable name="REF_introductionINT" select="concat($DICTMOD,':',oc:encodeOsisRef($uiIntroduction))"/>
  <variable name="REF_dictionary" select="if ($DICTMOD) then concat($DICTMOD,':',oc:encodeOsisRef($uiDictionary)) else ''"/>
    
  <!-- Return a contextualized config entry value by reading the OSIS header.
       An error is thrown if requested entry is not found. -->
  <function name="oc:conf" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <variable name="result" select="oc:osisHeaderContext($entry, $anynode, 'no')"/>
    <call-template name="Note"><with-param name="msg" select="concat('Reading config.conf (SCRIPT_NAME=', $SCRIPT_NAME, ', DICTMOD=', $DICTMOD, '): ', $entry, ' = ', $result)"/></call-template>
    <choose>
      <when test="$result and oc:isValidConfigValue($entry, $result)"><value-of select="$result"/></when>
      <when test="$result"><value-of select="$result"/></when>
      <otherwise>
        <call-template name="Error">
          <with-param name="msg">Config parameter was not specified in OSIS header and was not passed to functions.xsl: <value-of select="$entry"/> (SCRIPT_NAME=<value-of select="$SCRIPT_NAME"/>, isDICTMOD=<value-of select="$DICTMOD"/>)</with-param>
          <with-param name="die">yes</with-param>
        </call-template>
      </otherwise>
    </choose>
  </function>
  
  <!-- Return a contextualized optional config ARG_entry value by reading the OSIS header. 
       The required default value is returned if ARG_entry is not found) -->
  <function name="oc:sarg" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <param name="default" as="xs:string?"/>
    <variable name="result0" select="oc:osisHeaderContext($entry, $anynode, 'yes')"/>
    <variable name="result">
      <choose>
        <when test="$result0"><value-of select="$result0"/></when>
        <otherwise><value-of select="$default"/></otherwise>
      </choose>
    </variable>
    <call-template name="Note"><with-param name="msg" select="concat('Checking config.conf (SCRIPT_NAME=', $SCRIPT_NAME, ', DICTMOD=', $DICTMOD, '): ARG_', $entry, ' = ', $result)"/></call-template>
    <value-of select="$result"/>
  </function>
    
  <!-- Return a config system value by reading the OSIS header.
       Nothing is returned if the requested param is not found. -->
  <function name="oc:csys" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <variable name="result" select="$anynode/root()/osis[1]/osisText[1]/header[1]/work[1]/description[@type=concat('x-config-system+', $entry)][1]/text()"/>
    <call-template name="Note"><with-param name="msg" select="concat('(SCRIPT_NAME=', $SCRIPT_NAME, ', DICTMOD=', $DICTMOD, ') Reading system variable: ', $entry, ' = ', $result)"/></call-template>
    <value-of select="$result"/>
  </function>
  
  <!-- Return a contextualized config or argument value by reading the OSIS header -->
  <function name="oc:osisHeaderContext" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <param name="isarg" as="xs:string"/> <!-- either 'yes' this is a script argument or 'no' this is a regular config entry -->
    <variable name="entry2" select="concat((if ($isarg = 'yes') then 'ARG_' else ''), $entry)"/>
    <choose>
      <when test="$SCRIPT_NAME and boolean($anynode/root()/osis/osisText/header/work/description[@type=concat('x-config-', $SCRIPT_NAME, '+', $entry2)])">
        <value-of select="$anynode/root()/osis[1]/osisText[1]/header[1]/work[1]/description[@type=concat('x-config-', $SCRIPT_NAME, '+', $entry2)][1]/text()"/>
      </when>
      <when test="$DICTMOD and boolean($anynode/root()/osis/osisText/header/work/description[@type=concat('x-config-', $entry2)])">
        <value-of select="$anynode/root()/osis[1]/osisText[1]/header[1]/(work/description[@type=concat('x-config-', $entry2)])[last()]/text()"/>
      </when>
      <when test="$anynode/root()/osis/osisText/header/work/description[@type=concat('x-config-', $entry2)]">
        <value-of select="$anynode/root()/osis[1]/osisText[1]/header[1]/(work/description[@type=concat('x-config-', $entry2)])[1]/text()"/>
      </when>
    </choose>
  </function>
  
  <function name="oc:isValidConfigValue" as="xs:boolean">
    <param name="entry" as="xs:string"/>
    <param name="value" as="xs:string"/>
    <choose>
      <when test="matches($entry, 'Title', 'i') and matches($value, ' DEF$')">
        <value-of select="false()"/>
        <call-template name="Error">
          <with-param name="msg">XSLT found default value '<value-of select="$value"/>' for config.conf title entry <value-of select="$entry"/>.</with-param>
          <with-param name="exp">Add <value-of select="$entry"/>=[localized-title] to the config.conf file.</with-param>
        </call-template>
      </when>
      <otherwise><value-of select="true()"/></otherwise>
    </choose>
  </function>
 
  <function name="oc:number-of-matches" as="xs:integer">
    <param name="arg" as="xs:string?"/>
    <param name="pattern" as="xs:string"/>
    <sequence select="count(tokenize($arg,$pattern)) - 1"/>
  </function>
  
  <function name="oc:index-of-node" as="xs:integer*">
    <param name="nodes" as="node()*"/>
    <param name="nodeToFind" as="node()"/>
    <sequence select="for $seq in (1 to count($nodes)) return $seq[$nodes[$seq] is $nodeToFind]"/>
  </function>
  
  <function name="oc:uniregex" as="xs:string">
    <param name="regex" as="xs:string"/>
    <choose>
      <when test="oc:unicode_Category_Regex_Support('')"><value-of select="replace($regex, '\{gc=', '{')"/></when>
      <when test="oc:unicode_Category_Regex_Support('gc=')"><value-of select="$regex"/></when>
      <otherwise>
        <call-template name="ErrorBug">
          <with-param name="msg">Your Java installation does not support Unicode character properties in regular expressions! This script will be aborted!</with-param>
          <with-param name="die" select="'yes'"/>
        </call-template>
      </otherwise>
    </choose>
  </function>
  <function name="oc:unicode_Category_Regex_Support" as="xs:boolean">
    <param name="gc" as="xs:string?"/>
    <variable name="unicodeLetters" select="'ᴴЦ'"/>
    <value-of select="matches($unicodeLetters, concat('\p{', $gc, 'L}')) and not(matches($unicodeLetters, concat('[^\p{', $gc, 'L}]'))) and not(matches($unicodeLetters, concat('\P{', $gc, 'L}')))"/>
  </function>
  
  <!-- xml:id must start with a letter or underscore, and can only 
  contain ASCII letters, digits, underscores, hyphens, and periods. -->
  <function name="oc:id" as="xs:string">
    <param name="str" as="xs:string"/>
    <variable name="ascii_1" as="xs:string">
      <value-of>
        <analyze-string select="$str" regex="."> 
          <matching-substring>
            <choose>
              <when test="not(matches(., '[A-Za-z0-9_\-\.]'))">
                <value-of>_<value-of select="string-to-codepoints(.)[1]"/>_</value-of>
              </when>
              <otherwise><value-of select="."/></otherwise>
            </choose>
          </matching-substring>
        </analyze-string>
      </value-of>
    </variable>
    <!-- If it is too long, then hash the string -->
    <variable name="ascii" select="if (string-length($ascii_1) &#60;= 48) then $ascii_1 else oc:stringHash($ascii_1)"/>
    <value-of select="if (matches($ascii, '^[A-Za-z_]')) then $ascii else concat('_', $ascii)"/>
  </function>
  
  <function name="oc:stringHash" as="xs:string">
    <param name="str" as="xs:string"/>
    <value-of select="sum(for $i in 1 to string-length($str) return 53*$i + string-to-codepoints(substring($str,$i,1)))"/>
  </function>
  
  <!-- Only output true if $glossaryEntry first letter matches that of the previous entry (case-insensitive)--> 
  <function name="oc:skipGlossaryEntry" as="xs:boolean">
    <param name="glossaryEntry" as="element(seg)"/>
    <variable name="previousKeyword" select="$glossaryEntry/preceding::seg[@type='keyword'][1]"/>
    <choose>
      <when test="not($previousKeyword)"><value-of select="false()"/></when>
      <otherwise>
        <value-of select="boolean(
            upper-case(oc:keySortLetter(  $glossaryEntry/string())) = 
            upper-case(oc:keySortLetter($previousKeyword/string()))
        )"/>
      </otherwise>
    </choose>
  </function>
  
  <!-- Encode any UTF8 string value into a legal OSIS osisRef -->
  <function name="oc:encodeOsisRef">
    <param name="r"/>
    <value-of>
      <analyze-string select="$r" regex="."> 
        <matching-substring>
          <choose>
            <when test=". = ';'"> </when>
            <when test="string-to-codepoints(.)[1] &#62; 1103 or matches(., oc:uniregex('[^\p{gc=L}\p{gc=N}_]'))">
              <value-of>_<value-of select="string-to-codepoints(.)[1]"/>_</value-of>
            </when>
            <otherwise><value-of select="."/></otherwise>
          </choose>
        </matching-substring>
      </analyze-string>
    </value-of>
  </function>
  
  <!-- Decode a oc:encodeOsisRef osisRef to UTF8 -->
  <function name="oc:decodeOsisRef">
    <param name="osisRef"/>
    <value-of>
      <analyze-string select="$osisRef" regex="(_\d+_|.)">
        <matching-substring>
          <choose>
            <when test="matches(., '_\d+_')">
              <variable name="codepoint" select="xs:integer(number(replace(., '_(\d+)_', '$1')))"/>
              <value-of select="codepoints-to-string($codepoint)"/>
            </when>
            <otherwise><value-of select="."/></otherwise>
          </choose>
        </matching-substring>
      </analyze-string>
    </value-of>
  </function>
  
  <!-- Sort $KeySort order with: <sort select="oc:keySort($key)" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/> -->
  <function name="oc:keySort" as="xs:string?">
    <param name="text" as="xs:string?"/>
    <if test="$KeySort and $text">
      <variable name="ignoreRegex" select="oc:keySortIgnore()" as="xs:string"/>
      <variable name="text2" select="if ($ignoreRegex) then replace($text, $ignoreRegex, '') else $text"/>
      <variable name="keySortRegexes" select="oc:keySortRegexes()" as="element(oc:regex)*"/>
      <variable name="orderedRegexes" select="oc:orderLongToShort($keySortRegexes)" as="element(oc:regex)*"/>
      <variable name="keySortRegex" select="concat('(', string-join($orderedRegexes/@regex, '|'), ')')" as="xs:string"/>
      <variable name="result" as="xs:string">
        <value-of>
        <analyze-string select="$text2" regex="{$keySortRegex}">
          <matching-substring>
            <variable name="subst" select="."/>
            <for-each select="$orderedRegexes">
              <if test="matches($subst, concat('^', @regex, '$'))">
                <value-of select="codepoints-to-string(xs:integer(number(@position) + 64))"/> <!-- 64 starts at character "A" -->
              </if>
            </for-each>
          </matching-substring>
          <non-matching-substring>
            <choose>
              <when test="matches(., oc:uniregex('\p{gc=L}'))">
                <call-template name="Error">
                  <with-param name="msg">keySort(): Cannot sort aggregate glossary entry '<value-of select="$text"/>'; 'KeySort=<value-of select="$KeySort"/>' is missing the character <value-of select="concat('&quot;', ., '&quot;')"/>.</with-param>
                  <with-param name="exp">Add the missing character to the config.conf file's KeySort entry. Place it where it belongs in the order of characters.</with-param>
                </call-template>
              </when>
              <otherwise><value-of select="."/></otherwise>
            </choose>
          </non-matching-substring>
        </analyze-string>
        </value-of>
      </variable>
      <value-of select="$result"/>
    </if>
    <if test="not($KeySort)">
      <call-template name="Warn"><with-param name="msg">keySort(): 'KeySort' is not specified in config.conf. Glossary entries will be ordered in Unicode order.</with-param></call-template>
      <value-of select="$text"/>
    </if>
  </function>
  <function name="oc:encodeKS" as="xs:string">
    <param name="str" as="xs:string"/>
    <value-of select="replace(replace(replace(replace($str, '\\\[', '_91_'), '\\\]', '_93_'), '\\\{', '_123_'), '\\\}', '_125_')"/>
  </function>
  <function name="oc:decodeKS" as="xs:string">
    <param name="str" as="xs:string"/>
    <value-of select="replace(replace(replace(replace($str, '_91_', '['), '_93_', ']'), '_123_', '{'), '_125_', '}')"/>
  </function>
  <function name="oc:keySortIgnore" as="xs:string">
    <variable name="ignores" as="xs:string*">
      <analyze-string select="oc:encodeKS($KeySort)" regex="{'\{([^\}]*)\}'}">
        <matching-substring><sequence select="regex-group(1)"/></matching-substring>
        </analyze-string>
    </variable>
    <value-of select="if ($ignores) then oc:decodeKS(concat('(', string-join($ignores, '|'), ')')) else ''"/>
  </function>
  <function name="oc:keySortRegexes" as="element(oc:regex)*">
    <!-- split KeySort string into 3 groups: chr | [] | {} -->
    <analyze-string select="oc:encodeKS($KeySort)" regex="{'([^\[\{]|(\[[^\]]*\])|(\{[^\}]*\}))'}">
      <matching-substring>
        <if test="not(regex-group(3))"><!-- if group(3) is non empty, this is an ignore group -->
          <oc:regex>
            <attribute name="regex" select="oc:decodeKS(if (regex-group(2)) then substring(., 2, string-length(.)-2) else .)"/>
            <attribute name="position" select="position()"/>
          </oc:regex>
        </if>
      </matching-substring>
    </analyze-string>
  </function>
  <function name="oc:orderLongToShort" as="element(oc:regex)*">
    <param name="charRegexes" as="element(oc:regex)*"/>
    <for-each select="$charRegexes">     
      <sort select="string-length(./@regex)" data-type="number" order="descending"/> 
      <copy-of select="."/>
    </for-each>
  </function>
  
  <!-- Find the longest KeySort match at the beginning of a string, or else the first character if $KeySort not set. -->
  <function name="oc:keySortLetter" as="xs:string">
    <param name="text" as="xs:string"/>
    <choose>
      <when test="$KeySort">
        <variable name="ignoreRegex" select="oc:keySortIgnore()" as="xs:string"/>
        <variable name="text2" select="if ($ignoreRegex) then replace($text, $ignoreRegex, '') else $text"/>
        <variable name="keySortRegexes" select="oc:keySortRegexes()" as="element(oc:regex)*"/>
        <variable name="orderedRegexes" select="oc:orderLongToShort($keySortRegexes)" as="element(oc:regex)*"/>
        <variable name="keySortRegex" select="concat('(', string-join($orderedRegexes/@regex, '|'), ')')" as="xs:string"/>
        <value-of select="replace($text2, concat('^', $keySortRegex, '.*?$'), '$1')"/>
      </when>
      <otherwise><value-of select="substring($text, 1, 1)"/></otherwise>
    </choose>
  </function>
  
  <!-- When a glossary has a TOC entry or main title, then get that title -->
  <function name="oc:getGlossaryTitle" as="xs:string">
    <param name="glossary" as="element(div)"/>
    <value-of select="oc:titleCase(replace($glossary/(descendant::title[@type='main'][1] | descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]/@n)[1], '^(\[[^\]]*\])+', ''))"/>
  </function>
  
  <!-- When a glossary has a scope which is the same as a Sub-Publication's scope, then get the localized title of that Sub-Publication -->
  <function name="oc:getGlossaryScopeTitle" as="xs:string">
    <param name="glossary" as="element(div)?"/>
    <variable name ="pscope" select="replace($glossary/@scope, '\s', '_')"/>
    <variable name="title" select="root($glossary)//header//description[contains(@type, concat('TitleSubPublication[', $pscope, ']'))]"/>
    <value-of select="if ($title) then $title/text() else ''"/>
  </function>
  
  <function name="oc:getTocInstructions" as="xs:string*">
    <param name="tocElement" as="element()?"/>
    <variable name="result" as="xs:string*">
      <if test="$tocElement/@n">
        <analyze-string select="$tocElement/@n" regex="\[([^\]]*)\]"> 
          <matching-substring><value-of select="regex-group(1)"/></matching-substring>
        </analyze-string>
      </if>
    </variable>
    <if test="count($result[. != ''])"><value-of select="distinct-values($result)"/></if>
  </function>
  
  <function name="oc:titleCase" as="xs:string?">
    <param name="title" as="xs:string?"/>
    <choose>
      <when test="$TitleCase = '1'"><value-of select="string-join(oc:capitalize-first(tokenize($title, '\s+')), ' ')"/></when>
      <when test="$TitleCase = '2'"><value-of select="upper-case($title)"/></when>
      <otherwise><value-of select="$title"/></otherwise>
    </choose>
  </function>
  
  <function name="oc:capitalize-first" as="xs:string*">
    <param name="words" as="xs:string*"/>
    <for-each select="$words"><!-- but don't modify roman numerals! -->
      <sequence select="if (matches(., '^[IiVvLlXx]+$')) then . else concat(upper-case(substring(.,1,1)), lower-case(substring(.,2)))"/>
    </for-each>
  </function>
  
  <function name="oc:myWork" as="xs:string">
    <param name="node" as="node()"/>
    <value-of select="if ($DICTMOD) then root($node)/osis[1]/osisText[1]/@osisIDWork else $MAINMOD"/>
  </function>
  
  <function name="oc:osisRefPrevKeyword" as="xs:string?">
    <param name="node" as="node()?"/>
    <variable name="keyword" select="$node/ancestor-or-self::div[starts-with(@type,'x-keyword')][1]"/>
    <variable name="osisID" select="$keyword/preceding-sibling::div[starts-with(@type,'x-keyword')][1]/
                      descendant::seg[@type='keyword'][1]/@osisID"/>
    <value-of select="if ($osisID) then concat($DICTMOD,':',$osisID) else ''"/>
  </function>
  
  <function name="oc:osisRefNextKeyword" as="xs:string?">
    <param name="node" as="node()?"/>
    <variable name="keyword" select="$node/ancestor-or-self::div[starts-with(@type,'x-keyword')][1]"/>
    <variable name="osisID" select="$keyword/following-sibling::div[starts-with(@type,'x-keyword')][1]/
                      descendant::seg[@type='keyword'][1]/@osisID"/>
    <value-of select="if ($osisID) then concat($DICTMOD,':',$osisID) else ''"/>
  </function>
  
  <function name="oc:getPrevChapterOsisID" as="xs:string?">
    <param name="node" as="node()?"/>
    <variable name="inChapter" as="element(chapter)?"
      select="$node/(self::chapter[@eID] | following::chapter[@eID])[1]
              [@eID = $node/preceding::chapter[1]/@sID]"/>
    <value-of select="if ($inChapter) then 
                      $inChapter/preceding::chapter[ @osisID = string-join((
                        tokenize( $inChapter/@eID, '\.' )[1], 
                        string(number(tokenize( $inChapter/@eID, '\.' )[2])-1)), '.') ][1]/@osisID 
                      else ''"/>
  </function>
  
  <function name="oc:getNextChapterOsisID" as="xs:string?">
    <param name="node" as="node()?"/>
    <variable name="inChapter" as="element(chapter)?"
      select="$node/(self::chapter[@eID] | following::chapter[@eID])[1]
              [@eID = $node/preceding::chapter[1]/@sID]"/>
    <value-of select="if ($inChapter) then 
                      $inChapter/following::chapter[ @osisID = string-join((
                        tokenize( $inChapter/@eID, '\.' )[1], 
                        string(number(tokenize( $inChapter/@eID, '\.' )[2])+1)), '.')][1]/@osisID 
                      else ''"/>
  </function>
  
  <!-- Returns a list of links to glossary and introductory material, 
  including next/previous chapter/keyword links. When a REF is prefixed
  with 'href+' an osisRef attribute is NOT generated, instead, an href
  attribute is written as a literal href (this feature should only be
  used on temporary OSIS nodes, since it would not validate). NOTE: 
  Normally links to keywords in Bible modules are type x-glossary, while 
  those in Dict modules are x-glosslink, but here they are all 
  x-glosslink for CSS backward compatibility in xulsword. -->
  <function name="oc:getNavmenuLinks" as="element(list)?">
    <param name="REF_prev"  as="xs:string?"/>
    <param name="REF_next"  as="xs:string?"/>
    <param name="REF_intro" as="xs:string?"/>
    <param name="REF_dict"  as="xs:string?"/>
    <param name="title_dict" as="xs:string?"/>
    <param name="canonical" as="xs:string?"/>
    
    <if test="$REF_prev or $REF_next or $REF_intro or $REF_dict">
      <osis:list subType="x-navmenu" resp="x-oc">
        <if test="$canonical">
          <attribute name="canonical" select="$canonical"/>
        </if>

        <if test="($REF_prev or $REF_next)">
          <osis:item subType="x-prevnext-link">
            <osis:p type="x-right" subType="x-introduction">
              <if test="$REF_prev">
                <osis:reference>
                  <choose>
                    <when test="matches($REF_prev, '^href\+')">
                      <attribute name="href" select="replace($REF_prev, '^href\+', '')"/>
                    </when>
                    <otherwise>
                      <attribute name="osisRef" select="$REF_prev"/>
                    </otherwise>
                  </choose>
                  <if test="starts-with($REF_prev, concat($DICTMOD,':'))">
                    <attribute name="type">x-glosslink</attribute>
                    <attribute name="subType">x-target_self</attribute>
                  </if>
                  <text> ← </text>
                </osis:reference>
              </if>
              <if test="$REF_next">
                <osis:reference>
                  <choose>
                    <when test="matches($REF_next, '^href\+')">
                      <attribute name="href" select="replace($REF_next, '^href\+', '')"/>
                    </when>
                    <otherwise>
                      <attribute name="osisRef" select="$REF_next"/>
                    </otherwise>
                  </choose>
                  <if test="starts-with($REF_next, concat($DICTMOD,':'))">
                    <attribute name="type">x-glosslink</attribute>
                    <attribute name="subType">x-target_self</attribute>
                  </if>
                  <text> → </text>
                </osis:reference>
              </if>
            </osis:p>
          </osis:item>
        </if>
        
        <if test="$REF_intro">
          <osis:item subType="x-introduction-link">
            <osis:p type="x-right" subType="x-introduction">
              <osis:reference>
                <choose>
                  <when test="matches($REF_intro, '^href\+')">
                    <attribute name="href" select="replace($REF_intro, '^href\+', '')"/>
                  </when>
                  <otherwise>
                    <attribute name="osisRef" select="$REF_intro"/>
                  </otherwise>
                </choose>
                <if test="starts-with($REF_intro, concat($DICTMOD,':'))">
                  <attribute name="type">x-glosslink</attribute>
                  <attribute name="subType">x-target_self</attribute>
                </if>
                <value-of select="replace($uiIntroduction, '^[\-\s]+', '')"/>
              </osis:reference>
            </osis:p>
          </osis:item>
        </if>
        
        <if test="$REF_dict">
          <osis:item subType="x-dictionary-link">
            <osis:p type="x-right" subType="x-introduction">
              <osis:reference>
                <choose>
                  <when test="matches($REF_dict, '^href\+')">
                    <attribute name="href" select="replace($REF_dict, '^href\+', '')"/>
                  </when>
                  <otherwise>
                    <attribute name="osisRef" select="$REF_dict"/>
                  </otherwise>
                </choose>
                <if test="starts-with($REF_dict, concat($DICTMOD,':'))">
                  <attribute name="type">x-glosslink</attribute>
                  <attribute name="subType">x-target_self</attribute>
                </if>
                <value-of select="if ($title_dict) then $title_dict else 
                                  replace($uiDictionary, '^[\-\s]+', '')"/>
              </osis:reference>
            </osis:p>
          </osis:item>
        </if>
        
        <osis:lb/>
        <osis:lb/>
      </osis:list>
    </if>
  </function>
  
  <!-- Returns new keywords which make an auto generated menu system
  for another glossary. The containing div[@type="glossary"] must be 
  written by the caller. If $includeGlossaryKeywords is true then the  
  glossary entries themselves are also copied and returned in sorted
  order on the letter keyword menus. -->
  <function name="oc:glossaryMenu" as="node()+">
    <param name="glossary" as="element(div)"/>
    <param name="includeTopTocMenu" as="xs:boolean"/>
    <param name="includeAllEntriesMenu" as="xs:boolean"/>
    <param name="includeGlossaryKeywords" as="xs:boolean"/>
    
    <variable name="glossaryTitle" 
        select="if (oc:getGlossaryTitle($glossary)) then 
                oc:getGlossaryTitle($glossary) else 
                $uiDictionary"/>
                
    <!-- If there are glossary menus for each glossary, we need their ids to be unique -->
    <variable name="id" select="if ($glossary/ancestor::osis[@isCombinedGlossary='yes']) then '' else generate-id($glossary)"/>
    
    <variable name="sortedGlossary">
      <for-each select="$glossary/descendant::div[starts-with(@type,'x-keyword')]">
        <sort select="oc:keySort(.//seg[@type='keyword'])" data-type="text" order="ascending" 
          collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
        <sequence select="."/>
      </for-each>
    </variable>
    
    <text>&#xa;</text>
    
    <!-- Create a top keyword with links to each letter (plus a link 
    to the A-Z menu) on it -->        
    <variable name="allEntriesTitle" 
      select="concat(
              upper-case(oc:keySortLetter($sortedGlossary/descendant::seg[@type='keyword'][1])), 
              '-', 
              upper-case(oc:keySortLetter($sortedGlossary/descendant::seg[@type='keyword'][last()])))"/>
    
    <if test="$includeTopTocMenu">
      <osis:milestone type="x-usfm-toc{$TOC}" n="[level1]{$glossaryTitle}"/>
      <osis:div type="x-keyword" subType="x-navmenu-dictionary">
        <osis:p>
          <osis:seg type="keyword" osisID="{oc:encodeOsisRef($glossaryTitle)}">
            <value-of select="$glossaryTitle"/>
          </osis:seg>
        </osis:p>
        <osis:reference osisRef="{$DICTMOD}:{oc:encodeOsisRef($allEntriesTitle)}{$id}" 
          type="x-glosslink" subType="x-target_self">
          <value-of select="$allEntriesTitle"/>
        </osis:reference>
        <text>&#xa;</text>
        <for-each select="$sortedGlossary//seg[@type='keyword']">
          <if test="oc:skipGlossaryEntry(.) = false()">
            <variable name="letter" select="upper-case(oc:keySortLetter(text()))"/>
            <osis:reference osisRef="{$DICTMOD}:{oc:encodeOsisRef($letter)}{$id}" 
              type="x-glosslink" subType="x-target_self">
              <value-of select="$letter"/>
            </osis:reference>
            <text>&#xa;</text>
          </if>
        </for-each>
      </osis:div>
      <call-template name="Note">
<with-param name="msg">Added keyword: <value-of select="$glossaryTitle"/></with-param>
      </call-template>
    </if>
    
    <!-- Create A-Z keyword with links to every glossary keyword listed in it -->
    <if test="$includeTopTocMenu or $includeAllEntriesMenu">
      <text>&#xa;</text>
      <osis:div type="x-keyword" osisID="dictionaryAtoZ" subType="x-navmenu-atoz">
        <osis:p>
          <osis:seg type="keyword" osisID="{oc:encodeOsisRef($allEntriesTitle)}{$id}">
            <value-of select="$allEntriesTitle"/>
          </osis:seg>
        </osis:p>
        <osis:list subType="x-entrylist">
          <for-each select="$sortedGlossary//seg[@type='keyword']">
            <osis:item>
              <osis:reference osisRef="{$DICTMOD}:{@osisID}" type="x-glosslink" subType="x-target_self">
                <value-of select="text()"/>
              </osis:reference>
            </osis:item>
          </for-each>
        </osis:list>
      </osis:div>
      <call-template name="Note">
<with-param name="msg">Added keyword: <value-of select="$allEntriesTitle"/></with-param>
      </call-template>
    </if>
    
    <!-- Create a keyword for each letter, which either contain links to, 
    or are followed by copies of, glossary keywords that begin with that letter -->
    <variable name="letterMenus" as="element()*">
      <for-each select="$sortedGlossary//seg[@type='keyword']">
        <if test="oc:skipGlossaryEntry(.) = false()">
          <variable name="letter" select="upper-case(oc:keySortLetter(text()))"/>
          <osis:p>
            <osis:seg type="keyword" osisID="{oc:encodeOsisRef($letter)}{$id}">
              <value-of select="$letter"/>
            </osis:seg>
          </osis:p>
        </if>
        <osis:reference osisRef="{$DICTMOD}:{@osisID}" 
          type="x-glosslink" subType="x-target_self">
          <value-of select="text()"/>
        </osis:reference>
      </for-each>
    </variable>
    <for-each-group select="$letterMenus" group-starting-with="p[child::*[1][self::seg[@type='keyword']]]">
      <text>&#xa;</text>
      <osis:div type="x-keyword" subType="x-navmenu-letter">
        <sequence select="current-group()[1]"/>
        <if test="not($includeGlossaryKeywords) or 
                  count(current-group()[self::reference]) &#62; 1">
          <osis:list subType="x-entrylist">
            <for-each select="current-group()[not(position() = 1)]">
              <osis:item>
                <sequence select="."/>
              </osis:item>
            </for-each>
          </osis:list>
        </if>
      </osis:div>
      <call-template name="Note">
<with-param name="msg">Added keyword link list: <value-of select="current-group()[1]"/></with-param>
      </call-template>
      <if test="$includeGlossaryKeywords">
        <variable name="keywords" as="element(div)+" 
          select="$sortedGlossary/descendant::div[starts-with(@type,'x-keyword')]
              [ descendant::seg[@type='keyword']/@osisID = 
                current-group()[not(position() = 1)][self::reference]/replace(@osisRef, '^[^:]*:' ,'') ]"/>
        <sequence select="oc:setKeywordTocInstruction($keywords, '[level3]')"/>
        <call-template name="Note">
<with-param name="msg">Included keywords: <value-of select="current-group()[1]"/></with-param>
        </call-template>
      </if>
    </for-each-group>
    <text>&#xa;</text>

  </function>
  
  <!-- Returns a copy of an elements, adding TOC instruction $instr to every keyword -->
  <function name="oc:setKeywordTocInstruction">
    <param name="element" as="node()+"/>
    <param name="instr" as="xs:string"/>
    
    <apply-templates mode="setKeywordTocInst" select="$element">
      <with-param name="instr" select="$instr" tunnel="yes"/>
    </apply-templates>
  </function>
  <template mode="setKeywordTocInst" match="node()|@*">
    <copy><apply-templates mode="setKeywordTocInst" select="node()|@*"/></copy>
  </template>
  <template mode="setKeywordTocInst" match="seg[@type='keyword']">
    <param name="instr" tunnel="yes"/>
    <copy>
      <apply-templates mode="setKeywordTocInst" select="@*"/>
      <attribute name="n" select="concat($instr, @n)"/>
      <apply-templates mode="setKeywordTocInst" select="node()"/>
    </copy>
  </template>
  
  <!-- Return an osisRef with osisIDs listed in removedOsisIDs removed.
  NOTE: removedOsisIDs must include the work prefix. -->
  <function name="oc:trimOsisRef" as="xs:string">
    <param name="osisRef" as="xs:string"/>
    <param name="removedOsisIDs" as="xs:string"/>
  
    <variable name="result" as="xs:string?" select="string-join(
        (
          for $i in tokenize($osisRef, '\s+') return 
          if ($i = tokenize($removedOsisIDs, '\s+')) then '' else $i
        ), ' ')"/>
    <value-of select="if ($result) then normalize-space($result) else $osisRef"/>
    
    <!-- Note the result -->
    <if test="not($result)">
      <call-template name="Error">
<with-param name="msg">These reference target(s) have been removed: <value-of select="$osisRef"/></with-param>
<with-param name="exp">The targetted element(s) have been removed from this conversion. You 
may assign  multiple target osisID's to the reference, so that at least 
one target remains.</with-param>
      </call-template>
    </if>
    
  </function>
  
  <!-- Use this function if an element must not contain other elements 
  (for EPUB2 etc. validation). Any element in $expel becomes a sibling 
  of the container $element, which is divided and duplicated accordingly.
  Empty div|p|l|lg|list|item|head|li|ul|td|tr will not be copied. -->
  <function name="oc:expelElements">
    <param name="element" as="element()"/><!-- container -->
    <param name="expel" as="node()*"/> <!-- node(s) to be expelled -->
    <param name="quiet" as="xs:boolean"/>

    <if test="$expel[descendant::node()[. intersect $expel]]">
      <call-template name="ErrorBug">
<with-param name="msg">One expel element contains another: <value-of select="oc:printNode($expel[descendant::node()[. intersect $expel]][1])"/></with-param>
<with-param name="die">yes</with-param>
      </call-template>
    </if>
    
    <choose>
      <when test="not($expel)">
        <sequence select="$element"/>
      </when>
      <otherwise>
        <for-each-group select="$element" group-by="oc:myExpelGroups(., $expel)">
          <sequence select="oc:copyExpel($element, current-grouping-key(), $expel, $quiet)"/>
        </for-each-group>
      </otherwise>
    </choose>
    
  </function>
  <function name="oc:copyExpel">
    <param name="node" as="node()"/>
    <param name="currentGroupingKey" as="xs:integer"/>
    <param name="expel" as="node()+"/>
    <param name="quiet" as="xs:boolean"/>
    
    <variable name="expelMe" as="node()?" 
      select="$node/descendant-or-self::node()[. intersect $expel]
              [oc:myExpelGroups(., $expel) = $currentGroupingKey]"/>
    <choose>
      <!-- Groups with an expel element output only that element -->
      <when test="$expelMe">
        <copy-of select="$expelMe"/>
        <if test="not($quiet)">
          <call-template name="Note">
<with-param name="msg">Expelling: <value-of select="oc:printNode($expelMe)"/></with-param>
          </call-template>
        </if>
      </when>
      <!-- Container elements without text are flattened -->
      <when test="not( $node/descendant-or-self::text()[normalize-space()]
                       [oc:myExpelGroups(., $expel) = $currentGroupingKey] ) 
                  and $node/matches(local-name(), '^(div|p|l|lg|list|item|head|li|ul|td|tr)$')">
        <for-each select="$node/node()[oc:myExpelGroups(., $expel) = $currentGroupingKey]">
          <sequence select="oc:copyExpel(., $currentGroupingKey, $expel, $quiet)"/>
        </for-each>
      </when>
      <!-- Other nodes are copied according to currentGoupingKey -->
      <otherwise>
        <for-each select="$node">
          <variable name="myFirstTextNode" select="./descendant::text()[normalize-space()][1]"/>
          <variable name="myGroupTextNode" select="./descendant::text()[normalize-space()]
                                                   [oc:myExpelGroups(., $expel) = $currentGroupingKey][1]"/>
          <copy>
            <for-each select="@*">
              <!-- never duplicate an id: only the copy containing the first text node gets it -->
              <if test="not(name() = ('id','osisID')) or 
                $myGroupTextNode intersect $myFirstTextNode">
                <copy/>
              </if>
            </for-each>
            <for-each select="node()[oc:myExpelGroups(., $expel) = $currentGroupingKey]">
              <sequence select="oc:copyExpel(., $currentGroupingKey, $expel, $quiet)"/>
            </for-each>
          </copy>
        </for-each>
      </otherwise>
    </choose>
  </function>
  <function name="oc:myExpelGroups" as="xs:integer+">
    <param name="node" as="node()"/>
    <param name="expel" as="node()+"/>
    <sequence select="for $i in $node/descendant-or-self::node() return 
                        count($i[ancestor-or-self::node() intersect $expel]) + 
                      2*count($i/preceding::node()[. intersect $expel])"/>
  </function>

  <!-- oc:uriToRelativePath($base-uri, $rel-uri) this function converts a 
  URI to a relative path using another URI directory as base reference. -->
  <function name="oc:uriToRelativePath" as="xs:string">
    <param name="base-uri-file" as="xs:string"/> <!-- the URI base (file or directory) -->
    <param name="rel-uri-file" as="xs:string"/>  <!-- the URI to be converted to a relative path from that base (file or directory) -->
    
    <!-- base-uri begins and ends with '/' or is just '/' -->
    <variable name="base-uri" select="replace(replace($base-uri-file, '^([^/])', '/$1'), '/[^/]*$', '')"/>
    
    <!-- for rel-uri, any '.'s at the start of rel-uri-file are IGNORED so it begins with '/' -->
    <variable name="rel-uri" select="replace(replace($rel-uri-file, '^\.+', ''), '^([^/])', '/$1')"/>
    <variable name="tkn-base-uri" select="tokenize($base-uri, '/')" as="xs:string+"/>
    <variable name="tkn-rel-uri" select="tokenize($rel-uri, '/')" as="xs:string+"/>
    <variable name="uri-parts-max" select="max((count($tkn-base-uri), count($tkn-rel-uri)))" as="xs:integer"/>
    <!--  count equal URI parts with same index -->
    <variable name="uri-equal-parts" select="for $i in (1 to $uri-parts-max) 
      return $i[$tkn-base-uri[$i] eq $tkn-rel-uri[$i]]" as="xs:integer*"/>
    <variable name="relativePath">
      <choose>
        <!--  both URIs must share the same URI scheme -->
        <when test="$uri-equal-parts[1] eq 1">
          <!-- drop directories that have equal names but are not physically equal, 
          e.g. their value should correspond to the index in the sequence -->
          <variable name="dir-count-common" select="max(
              for $i in $uri-equal-parts 
              return $i[index-of($uri-equal-parts, $i) eq $i]
            )" as="xs:integer"/>
          <!-- difference from common to URI parts to common URI parts -->
          <variable name="delta-base-uri" select="count($tkn-base-uri) - $dir-count-common" as="xs:integer"/>
          <variable name="delta-rel-uri" select="count($tkn-rel-uri) - $dir-count-common" as="xs:integer"/>    
          <variable name="relative-path" select="
            concat(
            (: dot or dot-dot :) if ($delta-base-uri) then string-join(for $i in (1 to $delta-base-uri) return '../', '') else './',
            (: path parts :) string-join(for $i in (($dir-count-common + 1) to count($tkn-rel-uri)) return $tkn-rel-uri[$i], '/')
            )" as="xs:string"/>
          <choose>
            <when test="starts-with($rel-uri, concat($base-uri, '#'))">
              <value-of select="concat('#', tokenize($rel-uri, '#')[last()])"/>
            </when>
            <otherwise>
              <value-of select="$relative-path"/>
            </otherwise>
          </choose>
        </when>
        <!-- if both URIs share no equal part (e.g. for the reason of different URI 
        scheme names) then it's not possible to create a relative path. -->
        <otherwise>
          <value-of select="$rel-uri"/>
          <call-template name="Error">
<with-param name="msg">Indeterminate path:"<value-of select="$rel-uri"/>" is not relative to "<value-of select="$base-uri"/>"</with-param>
          </call-template>
        </otherwise>
      </choose>
    </variable>
    <sequence select="$relativePath"/>
    <!--<call-template name="Log"><with-param name="msg">base-uri-file=<value-of select="$base-uri-file"/>, rel-uri-file=<value-of select="$rel-uri-file"/>, relativePath=<value-of select="$relativePath"/>, </with-param></call-template>-->
  </function>
  
  <function name="oc:printNode" as="text()">
    <param name="node" as="node()?"/>
    <choose>
      <when test="not($node)">NULL</when>
      <when test="$node[self::element()]">
        <value-of>[<value-of select="$node/name()"/><for-each select="$node/@*"><value-of select="concat(' ', name(), '=&#34;', ., '&#34;')"/></for-each>]</value-of>
      </when>
      <when test="$node[self::text()]"><value-of select="concat('text-node = [', $node, ']')"/></when>
      <when test="$node[self::comment()]"><value-of select="concat('comment-node = [', $node, ']')"/></when>
      <when test="$node[self::attribute()]"><value-of select="concat('attribute-node: ', name($node), ' = [', $node, ']')"/></when>
      <when test="$node[self::document-node()]"><value-of select="concat('document-node: ', base-uri($node))"/></when>
      <when test="$node[self::processing-instruction()]"><value-of select="concat('processing-instruction: ', $node)"/></when>
      <otherwise><value-of select="concat('other?:', $node)"/></otherwise>
    </choose>
  </function>
  
  <!-- The following extension allows XSLT to read binary files into base64 strings. The reasons for the munge are:
  - Only Java functions are supported by saxon.
  - Java exec() immediately returns, without blocking, making another blocking method a necessity.
  - Saxon seems to limit Java exec() so it can only be run by <message>, meaning there is no usable return value of any kind,
    thus no way to monitor the process, nor return data from exec(), other than having it always write to a file.
  - XSLT's unparsed-text-available() is its only file existence check, and it only works on text files (not binaries).
  - Bash shell scripting provides all necessary functionality, but XSLT requires it to be written while the context is 
    outside of any temporary trees (hence the need to call prepareRunTime and cleanupRunTime at the proper moment). -->
  <variable name="DOCDIR" select="tokenize(document-uri(/), '[^/]+$')[1]" as="xs:string"/>
  <variable name="runtimeDir" select="file:new(uri:new($DOCDIR))"/>
  <variable name="envp" as="xs:string+"><value-of select="''"/></variable>
  <variable name="readBinaryResource" select="concat(replace($DOCDIR, '^file:', ''), 'tmp_osis2fb2.xsl.rbr.sh')" as="xs:string"/>
  <variable name="tmpResult" select="concat(replace($DOCDIR, '^file:', ''), 'tmp_osis2fb2.xsl.txt')" as="xs:string"/>
  <function name="oc:read-binary-resource">
    <param name="resource" as="xs:string"/>
    <message>JAVA: <value-of select="runtime:exec(runtime:getRuntime(), ($readBinaryResource, $resource), $envp, $runtimeDir)"/>: Read <value-of select="$resource"/></message>
    <call-template name="sleep"/>
    <if test="not(unparsed-text-available($tmpResult))"><call-template name="sleep"><with-param name="ms" select="100"/></call-template></if>
    <if test="not(unparsed-text-available($tmpResult))"><call-template name="sleep"><with-param name="ms" select="1000"/></call-template></if>
    <if test="not(unparsed-text-available($tmpResult))"><call-template name="sleep"><with-param name="ms" select="10000"/></call-template></if>
    <if test="not(unparsed-text-available($tmpResult))"><call-template name="Error"><with-param name="msg" select="'Failed writing tmpResult'"/></call-template></if>
    <variable name="result">
      <if test="unparsed-text-available($tmpResult)"><value-of select="unparsed-text($tmpResult)"/></if>
    </variable>
    <if test="starts-with($result, 'nofile')"><call-template name="Error"><with-param name="msg" select="concat('Failed to locate: ', $resource)"/></call-template></if>
    <if test="not(starts-with($result, 'nofile'))"><value-of select="$result"/></if>
  </function>
  <template name="oc:prepareRunTime">
    <result-document href="{$readBinaryResource}" method="text">#!/bin/bash
rm -r <value-of select="$tmpResult"/>
touch <value-of select="$tmpResult"/>
chmod -r <value-of select="$tmpResult"/>
if [ -s $1 ]; then
  base64 $1 > <value-of select="$tmpResult"/>
else
  echo nofile > <value-of select="$tmpResult"/>
fi
chmod +r <value-of select="$tmpResult"/>
  </result-document>
    <message>JAVA: <value-of select="runtime:exec(runtime:getRuntime(), ('chmod', '+x', $readBinaryResource), $envp, $runtimeDir)"/>: Write runtime executable</message>
  </template>
  <template name="oc:cleanupRunTime">
    <message>JAVA: <value-of select="runtime:exec(runtime:getRuntime(), ('rm', $readBinaryResource), $envp, $runtimeDir)"/>: Delete runtime executable</message>
    <message>JAVA: <value-of select="runtime:exec(runtime:getRuntime(), ('rm', '-r', $tmpResult), $envp, $runtimeDir)"/>: Delete tmpResult</message>
  </template>
  <template name="sleep" xmlns:thread="java.lang.Thread">
    <param name="ms" select="10"/>
    <if test="$ms!=10"><call-template name="Warn"><with-param name="msg" select="concat('Sleeping ', $ms, 'ms')"/></call-template></if>
    <message select="thread:sleep($ms)"/>     
  </template>
  
  <!-- The following messaging functions match those in common_opsys.pl for reporting consistency -->
  <template name="Error">
    <param name="msg"/>
    <param name="exp"/>
    <param name="die" select="'no'"/>
    <message terminate="{$die}">
      <text>&#xa;</text>ERROR: <value-of select="$msg"/><text>&#xa;</text>
      <if test="$exp">SOLUTION: <value-of select="$exp"/><text>&#xa;</text></if>
    </message>
  </template>
  <template name="ErrorBug">
    <param name="msg"/>
    <param name="die" select="'no'"/>
    <message terminate="{$die}">
      <text>&#xa;</text>ERROR (UNEXPECTED): <value-of select="$msg"/><text>&#xa;</text>
      <text>Please report the above unexpected ERROR to osis-converters maintainer.</text><text>&#xa;</text>
    </message>
  </template>
  <template name="Warn">
    <param name="msg"/>
    <param name="exp"/>
    <message>
      <text>&#xa;</text>WARNING: <value-of select="$msg"/>
      <if test="$exp"><text>&#xa;</text>CHECK: <value-of select="$exp"/></if>
    </message>
  </template>
  <template name="Note">
    <param name="msg"/>
    <message>NOTE: <value-of select="$msg"/></message>
  </template>
  <template name="Debug">
    <param name="msg"/>
    <if test="$DEBUG"><message>DEBUG: <value-of select="$msg"/></message></if>
  </template>
  <template name="Report">
    <param name="msg"/>
    <message><value-of select="//osisText[1]/@osisIDWork"/> REPORT: <value-of select="$msg"/></message>
  </template>
  <template name="Log">
    <param name="msg"/>
    <message><value-of select="$msg"/></message>
  </template>
  
</stylesheet>