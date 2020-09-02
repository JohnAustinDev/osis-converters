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
  <variable name="MAINTYPE" select="$MAINMOD/parent::*/type/@type"/>
  
  <variable name="DOCWORK" as="xs:string" select="//@osisIDWork[1]"/>
  
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
  
  <!-- Glossaries with more than this number of keywords will get an A-Z menu -->
  <param name="glossaryTocAutoThresh" select="xs:integer(number(oc:sarg('glossaryTocAutoThresh', /, '20')))"/><!-- is ARG_glossaryTocAutoThresh in config.conf -->
  
  <!-- ARG_glossaryCase for sorting, letter headings, lists and paging. Can be lower-case, as-is, or upper-case -->
  <variable name="glossaryCase" select="oc:sarg('glossaryCase', /, 'upper-case')"/>
  
  <!-- All projects have an osisID for the main introduction, and if there is a reference OSIS file
  there will also be an osisID for the top of the reference material. NOTE: If the INT feature is 
  used, the main introduction osisID will be in the dictionary module. -->
  <variable name="INT_feature" select="/descendant::*[@annotateType = 'x-feature'][@annotateRef = 'INT'][1]"/>
  <variable name="uiIntroduction" 
    select="oc:sarg('uiIntroduction', /, /osis/osisText/header/work[@osisWork = $MAINMOD]/title[1])"/>
  <variable name="uiDictionary" select="if ($DICTMOD) then 
            oc:sarg('uiDictionary', /, /osis/osisText/header/work[@osisWork = $DICTMOD]/title[1]) else ''"/>

  <variable name="REF_introduction" select="concat($MAINMOD,':BIBLE_TOP')"/>
  <!-- The following are used by sword, which requires that keywords must be decoded osisRef values. Therefore,
  there can be no other glossary keyword called $uiDictionary (nor $uiIntroduction if the INT feature is used). -->
  <variable name="REF_introductionINT" select="if ($INT_feature) then concat($DICTMOD,':',oc:encodeOsisRef($uiIntroduction)) else ''"/>
  <variable name="REF_dictionary" select="if ($DICTMOD) then concat($DICTMOD,':',oc:encodeOsisRef($uiDictionary)) else ''"/>
  
  <variable name="noDictTopMenu" select="oc:sarg('noDictTopMenu', /, 'no')"/>
  
  <key name="osisID" match="*[@osisID]" use="for $i in tokenize(@osisID, '\s+') return replace($i, '^[^:]+:', '')"/>
    
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
    <call-template name="Note"><with-param name="msg" select="concat('Reading config.conf (SCRIPT_NAME=', $SCRIPT_NAME, ', DICTMOD=', $DICTMOD, '): ARG_', $entry, ' = ', $result)"/></call-template>
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
  
  <!-- xml:id must start with a letter or underscore, and can only 
  contain ASCII letters, digits, underscores, hyphens, and periods. -->
  <function name="oc:id" as="xs:string">
    <param name="str" as="xs:string"/>
    <variable name="ascii" as="xs:string">
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
    <value-of select="if (matches($ascii, '^[A-Za-z_]')) then $ascii else concat('_', $ascii)"/>
  </function>
  
  <!-- Only output true if $glossaryEntry first letter matches that of the previous entry (case-insensitive)--> 
  <function name="oc:skipGlossaryEntry" as="xs:boolean">
    <param name="glossaryEntry" as="element(seg)"/>
    <variable name="previousKeyword" select="$glossaryEntry/preceding::seg[@type='keyword'][1]"/>
    <choose>
      <when test="not($previousKeyword)"><value-of select="false()"/></when>
      <otherwise>
        <value-of select="boolean(
            oc:keySortLetter(  $glossaryEntry/string()) = 
            oc:keySortLetter($previousKeyword/string())
        )"/>
      </otherwise>
    </choose>
  </function>
  
  <!-- Encode any UTF8 string value into a legal OSIS osisRef -->
  <function name="oc:encodeOsisRef" as="xs:string?">
    <param name="r" as="xs:string?"/>
    <choose>
      <when test="$r">
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
      </when>
    </choose>
  </function>
  
  <!-- Decode a oc:encodeOsisRef osisRef to UTF8 -->
  <function name="oc:decodeOsisRef" as="xs:string?">
    <param name="osisRef" as="xs:string?"/>
    <choose>
      <when test="$osisRef">
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
      </when>
    </choose>
  </function>
  
  <!-- Sort $KeySort order with: <sort select="oc:keySort($key)" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/> -->
  <!-- NOTE: the 'i' matching flag does not work with all Unicode characters, so a different approach must be used: oc:glossaryCase(regex-letters) -->
  <function name="oc:keySort" as="xs:string?">
    <param name="text" as="xs:string?"/>
    <if test="$KeySort and $text">
      <variable name="text2" select="oc:glossaryCase($text)"/>
      <variable name="ignoreRegex" select="oc:keySortIgnore()" as="xs:string"/>
      <variable name="text3" select="if ($ignoreRegex) 
        then replace($text2, $ignoreRegex, '') 
        else $text2"/>
      <variable name="keySortRegexes" select="oc:keySortRegexes()" as="element(oc:regex)*"/>
      <variable name="orderedRegexes" select="oc:orderLongToShort($keySortRegexes)" as="element(oc:regex)*"/>
      <variable name="keySortRegex" as="xs:string" 
        select="concat('(', string-join($orderedRegexes/oc:glossaryCaseRE(@regex), '|'), ')')"/>
      <variable name="result" as="xs:string">
        <value-of>
        <analyze-string select="$text3" regex="{$keySortRegex}">
          <matching-substring>
            <variable name="subst" select="."/>
            <for-each select="$orderedRegexes">
              <if test="matches($subst, concat('^', oc:glossaryCaseRE(@regex), '$'))">
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
      <value-of select="oc:glossaryCase($text)"/>
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
        <matching-substring><sequence select="oc:glossaryCaseRE(regex-group(1))"/></matching-substring>
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
  <function name="oc:glossaryCase" as="xs:string">
    <param name="str" as="xs:string"/>
    <choose>
      <when test="$glossaryCase = 'as-is'">
        <value-of select="$str"/>
      </when>
      <when test="$glossaryCase = 'lower-case'">
        <value-of select="lower-case($str)"/>
      </when>
      <otherwise>
        <value-of select="upper-case($str)"/>
      </otherwise>
    </choose>
  </function>
  <!-- Same as oc:glossaryCase() except leaves characters preceded by '\' 
  untouched. Since the 'i' flag does not work right on some high order 
  Unicode chars (such as ӏ) the same casing needs to be applied to the
  letters in regexes as was applied to the source string upon which 
  the search is being applied. -->
  <function name="oc:glossaryCaseRE" as="xs:string">
    <param name="regex" as="xs:string"/>
    <variable name="result" as="xs:string">
      <value-of>
        <analyze-string select="$regex" regex="{'(\\?.)'}">
          <matching-substring>
            <value-of select="if (matches(., '\\.')) then . else oc:glossaryCase(.)"/>
          </matching-substring>
        </analyze-string>
      </value-of>
    </variable>
    <value-of select="$result"/>
  </function>
  
  <!-- Find the longest KeySort match at the beginning of a string, or else the first character if $KeySort not set. -->
  <function name="oc:keySortLetter" as="xs:string">
    <param name="text" as="xs:string"/>
    <variable name="text2" select="oc:glossaryCase($text)"/>
    <choose>
      <when test="$KeySort">
        <variable name="ignoreRegex" select="oc:keySortIgnore()" as="xs:string"/>
        <variable name="text3" select="if ($ignoreRegex) 
          then replace($text2, $ignoreRegex, '') 
          else $text2"/>
        <variable name="keySortRegexes" select="oc:keySortRegexes()" as="element(oc:regex)*"/>
        <variable name="orderedRegexes" select="oc:orderLongToShort($keySortRegexes)" as="element(oc:regex)*"/>
        <value-of select="replace( $text3, 
                                   concat('^(', string-join($orderedRegexes/oc:glossaryCaseRE(@regex), '|'), ').*?$'), 
                                   '$1')"/>
      </when>
      <otherwise><value-of select="substring($text2, 1, 1)"/></otherwise>
    </choose>
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
  
  <!-- Return the title of a div element -->
  <function name="oc:getDivTitle" as="xs:string">
    <param name="div" as="element(div)"/>
    <variable name="title" as="xs:string">
      <choose>
        <when test="$div/ancestor::osis[@isCombinedGlossary = 'yes']">
          <value-of select="$uiDictionary"/>
        </when>
        <otherwise>
          <value-of select="$div/(
              descendant::title[@type='main'][1] | 
              descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]/@n |
              descendant::seg[@type='keyword'][count($div//seg[@type='keyword']) = 1]
            )[1]"/>
        </otherwise>
      </choose>
    </variable>
    <value-of select="oc:titleCase(replace($title, '^(\[[^\]]*\])+', ''))"/>
  </function>
  
  <!-- Return the sub-publication title matching @scope -->
  <function name="oc:getDivScopeTitle" as="xs:string">
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
  
  <function name="oc:docWork" as="xs:string">
    <param name="node" as="node()"/>
    <value-of select="if ($DICTMOD) then root($node)/osis[1]/osisText[1]/@osisIDWork else $MAINMOD"/>
  </function>
  
  <function name="oc:work" as="xs:string">
    <param name="osisRef" as="xs:string"/>
    <param name="defaultWork" as="xs:string"/>
    <value-of select="if (tokenize($osisRef, ':')[2]) then tokenize($osisRef, ':')[1] else $defaultWork"/>
  </function>
  
  <function name="oc:ref" as="xs:string">
    <param name="osisRef" as="xs:string"/>
    <value-of select="if (tokenize($osisRef, ':')[2]) then tokenize($osisRef, ':')[2] else $osisRef"/>
  </function>
  
  <function name="oc:key" as="node()*">
    <param name="name" as="xs:string"/>
    <param name="docs" as="document-node()+"/>
    <param name="refwork" as="xs:string"/>
    <param name="refvalue" as="xs:string"/>
    <for-each select="$docs[oc:docWork(.) = $refwork]">
      <sequence select="key($name, $refvalue)"/>
    </for-each>
  </function>
  
  <function name="oc:getPrevChapterEncRef" as="xs:string?">
    <param name="node" as="node()?"/>
    <variable name="inChapter" as="element(chapter)?"
      select="$node/(self::chapter[@eID] | following::chapter[@eID])[1]
              [@eID = $node/preceding::chapter[1]/@sID]"/>
    <variable name="osisID" select="if ($inChapter) then 
                      $inChapter/preceding::chapter[ @osisID = string-join((
                        tokenize( $inChapter/@eID, '\.' )[1], 
                        string(number(tokenize( $inChapter/@eID, '\.' )[2])-1)), '.') ][1]/@osisID 
                      else ''"/>
    <value-of select="if ($osisID) then concat('&amp;osisRef=', $osisID) else ''"/>
  </function>
  
  <function name="oc:getNextChapterEncRef" as="xs:string?">
    <param name="node" as="node()?"/>
    <variable name="inChapter" as="element(chapter)?"
      select="$node/(self::chapter[@eID] | following::chapter[@eID])[1]
              [@eID = $node/preceding::chapter[1]/@sID]"/>
    <variable name="osisID" select="if ($inChapter) then 
                      $inChapter/following::chapter[ @osisID = string-join((
                        tokenize( $inChapter/@eID, '\.' )[1], 
                        string(number(tokenize( $inChapter/@eID, '\.' )[2])+1)), '.')][1]/@osisID 
                      else ''"/>
    <value-of select="if ($osisID) then concat('&amp;osisRef=', $osisID) else ''"/>
  </function>
  
  <!-- Returns a list of links to glossary and introductory material, 
  including next/previous chapter/keyword links. Arguments are all
  encoded like a URL query is, for instance: '&osisRef=Matt.1.1&text=Matthew'.
  Also, &disabled=1 can be added to disable the generated link. NOTE: 
  Normally links to keywords in Bible modules are type x-glossary, while 
  those in Dict modules are x-glosslink, but here they are all 
  x-glosslink for CSS backward compatibility in xulsword. -->
  <function name="oc:getNavmenuLinks" as="element(list)?">
    <param name="encREF_prev"      as="xs:string?"/>
    <param name="encREF_next"      as="xs:string?"/>
    <param name="encREF_intro"     as="xs:string?"/>
    <param name="encREF_dictList"  as="xs:string*"/>
    
    <variable name="defaultTextPREV" select="
        if (boolean($encREF_prev) and not(matches($encREF_prev, '&amp;text=[^&amp;]+')))
        then '&amp;text= ← '
        else ''"/>
    <variable name="defaultTextNEXT" select="
        if (boolean($encREF_next) and not(matches($encREF_next, '&amp;text=[^&amp;]+')))
        then '&amp;text= → '
        else ''"/>
    <variable name="defaultTextINTRO" select="
        if (boolean($encREF_intro) and not(matches($encREF_intro, '&amp;text=[^&amp;]+')))
        then concat('&amp;text=', $uiIntroduction)
        else ''"/>
    
    <if test="$encREF_prev or $encREF_next or $encREF_intro or count($encREF_dictList)">
      <osis:list subType="x-navmenu" resp="x-oc">

        <if test="($encREF_prev or $encREF_next)">
          <osis:item subType="x-prevnext-link">
            <osis:p type="x-right" subType="x-introduction">
              <if test="$encREF_prev">
                <sequence select="oc:getMenuLink(concat($encREF_prev, $defaultTextPREV))"/>
              </if>
              <if test="$encREF_next">
                <sequence select="oc:getMenuLink(concat($encREF_next, $defaultTextNEXT))"/>
              </if>
            </osis:p>
          </osis:item>
        </if>
        
        <sequence select="oc:getMenuItem(
          concat($encREF_intro, $defaultTextINTRO),
          'x-introduction-link' )"/>
        
        <for-each select="$encREF_dictList">
          <sequence select="oc:getMenuItem(
            ., 
            'x-dictionary-link')"/>
        </for-each>
        
        <osis:lb/>
        <osis:lb/>
        
      </osis:list>
    </if>
  </function>
  <function name="oc:getMenuItem" as="element(item)?">
    <param name="encodedRef" as="xs:string"/>
    <param name="subType" as="xs:string"/>
    <if test="$encodedRef">
      <osis:item subType="{$subType}">
        <osis:p type="x-right" subType="x-introduction">
          <sequence select="oc:getMenuLink($encodedRef)"/>
        </osis:p>
      </osis:item>
    </if>
  </function>
  <function name="oc:getMenuLink" as="node()">
    <param name="encodedRef" as="xs:string"/>
    <variable name="text" select="replace($encodedRef, '^.*?&amp;text=([^&amp;]+).*?$', '$1')"/>
    <if test="not($text)">
      <call-template name="ErrorBug">
<with-param name="msg">getMenuLink link has no text: <value-of select="$encodedRef"/></with-param>
<with-param name="die">yes</with-param>
      </call-template>
    </if>
    <if test="not(matches($encodedRef, '&amp;disabled=1')) and 
              not(matches($encodedRef, '&amp;(osisRef|href)=[^&amp;]+'))">
      <call-template name="ErrorBug">
<with-param name="msg">getMenuLink link has no target (osisRef or href): <value-of select="$encodedRef"/></with-param>
<with-param name="die">yes</with-param>
      </call-template>
    </if>
    <choose>
      <when test="matches($encodedRef, '&amp;disabled=1')">
        <osis:seg subType="x-disabled">
          <value-of select="$text"/>
        </osis:seg>
      </when>
      <otherwise>
        <osis:reference>
          <analyze-string select="$encodedRef" regex="&amp;([A-Za-z]+)=([^&amp;]+)">
            <matching-substring>
              <if test="not(regex-group(1) = ('disabled', 'text'))">
                <attribute name="{regex-group(1)}" select="regex-group(2)"/>
              </if>
            </matching-substring>
          </analyze-string>
          <if test="matches($encodedRef, concat('&amp;osisRef=', $DICTMOD, ':'))">
            <attribute name="type">x-glosslink</attribute>
            <attribute name="subType">x-target_self</attribute>
          </if>
          <value-of select="$text"/>
        </osis:reference>
      </otherwise>
    </choose>
  </function>
  
  <!-- Returns a menu with links to each glossary of DICTMOD -->
  <function name="oc:glossaryTopMenu" as="node()+">
    <param name="osisText" as="element(osisText)"/>
    
    <osis:div type="x-keyword" subType="x-navmenu-glossaries">
      <osis:p>
        <osis:seg type="keyword" osisID="{oc:encodeOsisRef($uiDictionary)}">
          <value-of select="$uiDictionary"/>
        </osis:seg>
      </osis:p>
      
      <osis:list subType="x-menulist">
        <for-each select="$osisText/div[@type='glossary'][not(@scope = 'NAVMENU')]
                                                         [not(@annotateType = 'x-feature')]
                                                         [not(@subType = 'x-aggregate')]">
          <variable name="glossTitle" select="oc:getDivTitle(.)"/>
          <choose>
            <when test="not($glossTitle)">
              <for-each select=".//seg[@type='keyword']">
                <osis:item>
                  <osis:reference osisRef="{$DICTMOD}:{@osisID}"
                    type="x-glosslink" subType="x-target_self">
                    <value-of select="string()"/>
                  </osis:reference>
                </osis:item>
              </for-each>
              <call-template name="Warn">
<with-param name="msg">Links to <value-of select=".//seg[@type='keyword']"/> keyword(s) were placed on the navigation, menu 
because their glossary has no title.</with-param>
<with-param name="exp">If the glossary is given a title using a \toc<value-of select="$TOC"/> tag or a main title tag, then 
the glossary title will appear on the menu instead of each keyword.</with-param>
              </call-template>
            </when>
            <otherwise>
              <variable name="target" as="xs:string">
                <choose>
                  <!-- target a single keyword directly (skip the menu) -->
                  <when test="count(descendant::seg[@type='keyword']) = 1">
                    <value-of select="descendant::seg[@type='keyword']"/>
                  </when>
                  <!-- otherwise target the glossary title -->
                  <otherwise><value-of select="oc:glossMenuTitle(.)"/></otherwise>
                </choose>
              </variable>
              <osis:item>
                <osis:reference osisRef="{$DICTMOD}:{oc:encodeOsisRef($target)}"
                  type="x-glosslink" subType="x-target_self">
                  <value-of select="oc:glossMenuTitle(.)"/>
                </osis:reference>
              </osis:item>
            </otherwise>
          </choose>
        </for-each>
      </osis:list>
      <call-template name="Note">
<with-param name="msg">Added top menu keyword: <value-of select="$uiDictionary"/></with-param>
      </call-template>
    </osis:div>
  </function>
  
  <!-- Cannot have a glossary menu title which is the same as any 
  keyword, as another glossary menu, or the top menu uiDictionary -->
  <function name="oc:glossMenuTitle" as="xs:string">
    <param name="glossary" as="element(div)"/>
    <variable name="scopeTitle" select="oc:getDivScopeTitle($glossary)"/>
    <variable name="glossTitle1" select="oc:getDivTitle($glossary)"/>
    <variable name="glossTitle2" select="if ( $scopeTitle and $glossTitle1 = ($uiDictionary,
      root($glossary)//div[@type='glossary'][not(@scope = 'NAVMENU')]
      [not(@annotateType = 'x-feature')][not(@subType = 'x-aggregate')]/oc:getDivTitle(.)) )
      then concat($glossTitle1, ' (', $scopeTitle, ')') else $glossTitle1"/>
    <variable name="glossTitle" select="if ($glossTitle1) then $glossTitle2 else 'concat(
        oc:keySortLetter($glossary/descendant::reference[1]/string()), 
        '-', 
        oc:keySortLetter($glossary/descendant::reference[last()]/string()))'"/>
    <if test="not($glossTitle1)">
      <call-template name="Warn">
<with-param name="msg">Glossary does not have a title. The following will be used: '<value-of select="$glossTitle"/>'</with-param>
<with-param name="exp">You may add a title using a \toc<value-of select="$TOC"/> tag or a main title tag to the top of the glossary.</with-param>
      </call-template>
    </if>
    <value-of select="if ( (not($noDictTopMenu = 'yes') and $glossTitle = $uiDictionary) 
      or root($glossary)//seg[@type='keyword']/string() = $glossTitle )
      then concat($glossTitle, '.')
      else $glossTitle"/>
  </function>
  
  <!-- Returns new keywords which make up an auto-generated menu system
  for another glossary. If the glossary does not have a title an error 
  may be thrown. If $appendEntries is true then the glossary entries 
  themselves are also copied and returned in sorted order at the end of 
  each letter menu (in this case the glossary itself does not need to be 
  written by the caller). -->
  <function name="oc:glossaryMenu" as="node()+">
    <param name="glossary" as="element(div)"/>
    <param name="include_AtoZ_menu" as="xs:string"/>
    <param name="include_letter_menus" as="xs:string"/>
    <param name="appendEntries" as="xs:boolean"/>
    
    <if test="$include_letter_menus = 'no' and $include_AtoZ_menu = 'yes'">
      <call-template name="ErrorBug">
<with-param name="msg">When including the A to Z menu, letter menus must also be created.</with-param>
<with-param name="die">yes</with-param>      
      </call-template>
    </if>
    
    <if test="$appendEntries and $include_AtoZ_menu = 'no' and $include_letter_menus = 'no'">
      <call-template name="ErrorBug">
<with-param name="msg">All-keyword menu with appended entries is not yet implemented.</with-param>
<with-param name="die">yes</with-param>      
      </call-template>
    </if>
    
    <variable name="glossaryMenuTitle" select="oc:glossMenuTitle($glossary)"/>
    
    <variable name="glossarySorted">
      <for-each select="$glossary/descendant::div[starts-with(@type,'x-keyword')]">
        <sort select="oc:keySort(.//seg[@type='keyword'])" data-type="text" order="ascending" 
          collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/>
        <sequence select="."/>
      </for-each>
    </variable>
    
    <text>&#xa;</text>
           
    <variable name="allLetters" select="concat(
      oc:keySortLetter($glossarySorted/descendant::seg[@type='keyword'][1]), 
      '-', 
      oc:keySortLetter($glossarySorted/descendant::seg[@type='keyword'][last()]))"/>
      
    <variable name="allLettersTitle" select="concat($glossaryMenuTitle, ' (', $allLetters, ')')"/>
    
    <variable name="do_AtoZ_menu" as="xs:boolean" select="$include_AtoZ_menu = 'yes' or 
      ($include_AtoZ_menu = 'AUTO' and count($glossary//seg[@type='keyword']) &#62;= $glossaryTocAutoThresh)"/>
    
    <if test="$do_AtoZ_menu">
      <!-- Create a menu with links to each letter plus a link 
      to the all-keywords menu. --> 
      <osis:div type="x-keyword" subType="x-navmenu-all-letters">
        <osis:p subType="x-navmenu-top">
          <osis:seg type="keyword" osisID="{oc:encodeOsisRef($glossaryMenuTitle)}">
            <value-of select="$glossaryMenuTitle"/>
          </osis:seg>
        </osis:p>
        <osis:reference osisRef="{$DICTMOD}:{oc:encodeOsisRef($allLettersTitle)}" 
          type="x-glosslink" subType="x-target_self">
          <value-of select="$allLetters"/>
        </osis:reference>
        <text>&#xa;</text>
        <for-each select="$glossarySorted//seg[@type='keyword']">
          <if test="oc:skipGlossaryEntry(.) = false()">
            <variable name="letter" select="oc:keySortLetter(text())"/>
            <variable name="letterTitle" select="concat($letter, ' - ', $glossaryMenuTitle)"/>
            <osis:reference osisRef="{$DICTMOD}:{oc:encodeOsisRef($letterTitle)}" 
              type="x-glosslink" subType="x-target_self">
              <value-of select="$letter"/>
            </osis:reference>
            <text>&#xa;</text>
          </if>
        </for-each>
      </osis:div>
      <call-template name="Note">
<with-param name="msg">Added A-Z menu: <value-of select="$glossaryMenuTitle"/></with-param>
      </call-template>
    </if>
    
    <if test="count($glossary//seg[@type='keyword']) &#62; 1">
      <!-- A menu with osisID of glossaryMenuTitle must be output if the
      glossary's getDivTitle is non-empty and it has more than 1 keyword, 
      because oc:glossaryTopMenu targets it in that case. -->
      <variable name="allKeywordsTitle" select="if (not($do_AtoZ_menu)) 
        then $glossaryMenuTitle else $allLettersTitle"/>
      
      <!-- Create the all-keywords menu with a link to each keyword -->
      <text>&#xa;</text>
      <osis:div type="x-keyword" subType="x-navmenu-all-keywords">
        <osis:p>
          <if test="not($do_AtoZ_menu)">
            <attribute name="subType" select="'x-navmenu-top'"/>
          </if>
          <osis:seg type="keyword" osisID="{oc:encodeOsisRef($allKeywordsTitle)}">
            <value-of select="$allKeywordsTitle"/>
          </osis:seg>
        </osis:p>
        <osis:list subType="x-menulist">
          <for-each select="$glossarySorted//seg[@type='keyword']">
            <osis:item>
              <osis:reference osisRef="{$DICTMOD}:{@osisID}" type="x-glosslink" subType="x-target_self">
                <value-of select="text()"/>
              </osis:reference>
            </osis:item>
          </for-each>
        </osis:list>
      </osis:div>
      <call-template name="Note">
<with-param name="msg">Added all-keyword menu: <value-of select="$allKeywordsTitle"/></with-param>
      </call-template>
    </if>
  
    <if test="$do_AtoZ_menu or $include_letter_menus = 'yes'">
      <!-- Create a menu for each letter, with links to the keywords that 
      begin with that letter. -->
      <variable name="letterMenus" as="element()*">
        <for-each select="$glossarySorted//seg[@type='keyword']">
          <if test="oc:skipGlossaryEntry(.) = false()">
            <variable name="letterTitle" 
              select="concat(oc:keySortLetter(text()), ' - ', $glossaryMenuTitle)"/>
            <osis:p>
              <osis:seg type="keyword" osisID="{oc:encodeOsisRef($letterTitle)}">
                <value-of select="$letterTitle"/>
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
          <if test="not($appendEntries) or 
                    count(current-group()[self::reference]) &#62; 1">
            <osis:list subType="x-menulist">
              <for-each select="current-group()[not(position() = 1)]">
                <osis:item>
                  <sequence select="."/>
                </osis:item>
              </for-each>
            </osis:list>
          </if>
        </osis:div>
        <call-template name="Note">
<with-param name="msg">Added letter menu <value-of select="current-group()//seg[@type='keyword'][1]/string()"/></with-param>
        </call-template>
        <!-- If appendEntries is true then entries are copied and 
        appended to the end of each menu. -->
        <if test="$appendEntries">
          <variable name="keywords" as="element(div)+" 
            select="$glossarySorted/descendant::div[starts-with(@type,'x-keyword')]
                [ descendant::seg[@type='keyword']/@osisID = 
                  current-group()[not(position() = 1)][self::reference]/replace(@osisRef, '^[^:]*:' ,'') ]"/>
          <sequence select="oc:setKeywordTocInstruction($keywords, '[level3]')"/>
          <call-template name="Note">
<with-param name="msg">Included entries: <value-of select="current-group()[1]"/></with-param>
          </call-template>
        </if>
      </for-each-group>
      <text>&#xa;</text>
    </if>

  </function>
  
  <!-- Returns a copy of an element, adding TOC instruction $instr to every keyword -->
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
  
  <!-- Return an osisRef with any osisRef targets listed in refs either 
  removed (if remove is true), or solely kept. NOTE: each ref in refs 
  must include the work prefix. -->
  <function name="oc:filter_osisRef" as="xs:string">
    <param name="osisRef" as="xs:string"/>
    <param name="remove" as="xs:boolean"/>
    <param name="refs" as="xs:string*"/>
    
    <variable name="result" as="xs:string?">
      <choose>
        <!-- remove refs -->
        <when test="$remove">
          <value-of select="string-join(
              ( for $i in tokenize($osisRef, '\s+') return 
                if ($i = $refs) then '' else $i
              ), ' ')"/>
        </when>
        <!-- keep refs -->
        <otherwise>
          <value-of select="string-join(
              ( for $i in tokenize($osisRef, '\s+') return 
                if ($i != $refs) then '' else $i
              ), ' ')"/>
        </otherwise>
      </choose>
    </variable>
    
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
  
  <!-- Takes an osisID attribute value (with or without work prefixes, 
  which are ignored), and returns a list of $work prefixed osisRef values. -->
  <function name="oc:osisRef" as="xs:string+">
    <param name="osisID" as="xs:string"/>
    <param name="work" as="xs:string?"/>

    <for-each select="tokenize($osisID, '\s+')">
      <variable name="ref" select="if (contains(., ':')) then tokenize(., ':')[2] else ."/>
      <value-of select="if ($work) then concat($work, ':', .) else ."/>
    </for-each>
  </function>
  
  <!-- Takes an attribute name and returns all of those attributes within 
  $nodes having value $search (among any and all space delimited values). 
  The $search string(s) must not contain spaces. -->
  <function name="oc:attribsWith" as="attribute()*">
    <param name="attrib" as="xs:string"/>
    <param name="search" as="xs:string*"/>
    <param name="nodes" as="node()*"/>
    
    <if test="count($search)">
      <sequence select="$nodes/descendant-or-self::*
      [attribute()[local-name() = $attrib]]
      [tokenize(attribute()[local-name() = $attrib], '\s+') = $search]
      /attribute()[local-name() = $attrib]"/>
    </if>
  </function>
  
  <!-- The quick way to tell if an osisRef is to scripture -->
  <function name="oc:isScripRef" as="xs:boolean">
    <param name="osisRef" as="xs:string?"/>
    <param name="parentWork" as="xs:string"/>

    <variable name="work" select="if (tokenize($osisRef,':')[2]) 
                                  then tokenize($osisRef,':')[1] 
                                  else $parentWork"/>
    <value-of select="not($DICTMOD and $work = $DICTMOD) 
                      and not($work = $MAINMOD and $MAINTYPE ne 'x-bible') 
                      and not(contains($osisRef, '!'))"/>
  </function>
  
  <!-- Use this function if an element must not contain other elements 
  (for EPUB2 etc. validation). Any element in $expel becomes a sibling 
  of the container $element, which is divided and duplicated accordingly.
  Empty div|p|l|lg|list|item|head|li|ul|td|tr will not be copied. -->
  <function name="oc:expelElements">
    <param name="element" as="node()"/><!-- any non-element will just be returned -->
    <param name="expel" as="node()*"/> <!-- node(s) to be expelled -->
    <param name="quiet" as="xs:boolean"/>
    
    <variable name="expel2" select="$expel except $expel[ancestor::node() intersect $expel]"/>
    
    <choose>
      <when test="not($expel) or $element[not(self::element())]">
        <sequence select="$element"/>
      </when>
      <otherwise>
        <for-each-group select="$element" group-by="oc:myExpelGroups(., $expel2)">
          <sequence select="oc:copyExpel($element, current-grouping-key(), $expel2, $quiet)"/>
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
              <!-- never duplicate a container's id: only the copy containing the first text node gets it -->
              <if test="not($myFirstTextNode) or not(name() = ('id','osisID')) or 
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
    <message terminate="{$die}" select="oc:log('ERROR', $msg, 'SOLUTION', $exp)"/>
  </template>
  
  <template name="ErrorBug">
    <param name="msg"/>
    <param name="die" select="'no'"/>
    <message terminate="{$die}" select="oc:log('ERROR (UNEXPECTED)', $msg, 
      'SOLUTION', 'Please report the above unexpected ERROR to osis-converters maintainer.')"/>
  </template>
  
  <template name="Warn">
    <param name="msg"/>
    <param name="exp"/>
    <message select="oc:log('WARNING', $msg, 'CHECK', $exp)"/>
  </template>
  
  <template name="Note">
    <param name="msg"/>
    <message select="oc:log('NOTE', $msg, '', '')"/>
  </template>
  
  <template name="Debug">
    <param name="msg"/>
    <if test="$DEBUG"><message select="oc:log('DEBUG', $msg, '', '')"/></if>
  </template>
  
  <template name="Report">
    <param name="msg"/>
    <variable name="work" select="//osisText[1]/@osisIDWork"/>
    <message select="oc:log(concat( (if ($work) then concat($work, ' ') else ''), 'REPORT'), $msg, '', '')"/>
  </template>
  
  <template name="Log">
    <param name="msg"/>
    <message select="oc:log('', $msg, '', '')"/>
  </template>
  
  <function name="oc:log" as="xs:string">
    <param name="head1" as="xs:string"/>
    <param name="str1" as="xs:string"/>
    <param name="head2" as="xs:string"/>
    <param name="str2" as="xs:string"/>
    
    <value-of>
    <if test="matches($head1, '(ERROR|WARNING|REPORT|DEBUG)') and not(matches($str1, '^&#60;\-'))"><text>&#xa;</text></if>
    
    <if test="matches($str1, '\S')">
      <if test="matches($head1, '\S')"><value-of select="concat($head1, ': ')"/></if>
      <value-of select="replace($str1, '^(&#60;\-|\-&#62;)', '')"/>
    </if>
    
    <if test="matches($str2, '\S')">
      <text>&#xa;</text>
      <if test="matches($head2, '\S')"><value-of select="concat($head2, ': ')"/></if>
      <value-of select="replace($str2, '^(&#60;\-|\-&#62;)', '')"/>
    </if>
    
    <if test="matches($head1, '(ERROR)') and not(matches($str1, '^&#60;\-'))"><text>&#xa;</text></if>
    </value-of>
  </function>
  
</stylesheet>
