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
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/functions.xsl"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace">
  
  <!-- If script-specific config context is desired from oc:conf(), then the calling script must pass this SCRIPT_NAME parameter -->
  <param name="SCRIPT_NAME"/>
  
  <!-- If DICT-specific config context is desired from oc:conf(), then either the OSIS file header 
  and osisText elements must be marked-up as x-glossary type, OR the calling script must pass in DICTMOD -->
  <param name="DICTMOD" select="/osis/osisText/header/work[@osisWork=/osis/osisText/@osisIDWork][child::type[@type='x-glossary']]/@osisWork"/>
  
  <!-- The following config entries require a properly marked-up OSIS header, OR 
  the calling script must pass in their values (otherwise an error is thrown for oc:conf()) -->
  <param name="DEBUG" select="oc:csys('DEBUG', /)"/>
  <param name="TOC" select="oc:conf('TOC', /)"/>
  <param name="TitleCase" select="oc:conf('TitleCase', /)"/>
  <param name="KeySort" select="oc:conf('KeySort', /)"/>
  
  <!-- Return a contextualized config entry value by reading the OSIS header (error is thrown if requested param is not there) -->
  <function name="oc:conf" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <variable name="result" select="oc:osisHeaderContext($entry, $anynode, 'no')"/>
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
  
  <!-- Return a contextualized script argument value by reading the OSIS header (the required default value is returned if param is not found) -->
  <function name="oc:sarg" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <param name="default" as="xs:string?"/>
    <variable name="result" select="oc:osisHeaderContext($entry, $anynode, 'yes')"/>
    <choose>
      <when test="$result"><value-of select="$result"/></when>
      <otherwise><value-of select="$default"/></otherwise>
    </choose>
  </function>
    
  <!-- Return a config system value by reading the OSIS header (nothing is returned if requested param is not found) -->
  <function name="oc:csys" as="xs:string?">
    <param name="entry" as="xs:string"/>
    <param name="anynode" as="node()"/>
    <value-of select="$anynode/root()/osis[1]/osisText[1]/header[1]/work[1]/description[@type=concat('x-config-system+', $entry)][1]/text()"/>
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

  <!-- Only output true if $glossaryEntry first letter matches that of the previous entry (case-insensitive)--> 
  <function name="oc:skipGlossaryEntry">
    <param name="glossaryEntry"/>
    <variable name="previousKeyword" select="$glossaryEntry/preceding::seg[@type='keyword'][1]/string()"/>
    <choose>
      <when test="not($previousKeyword)"><value-of select="false()"/></when>
      <otherwise><value-of select="boolean(upper-case(substring($glossaryEntry/text(), 1, 1)) = upper-case(substring($previousKeyword, 1, 1)))"/></otherwise>
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
            <when test="string-to-codepoints(.)[1] &#62; 1103 or matches(., '[^\p{L}\p{N}_]')">
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
  
  <!-- Sort by an arbitrary character order: <sort select="oc:keySort($key)" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/> -->
  <function name="oc:keySort" as="xs:string?">
    <param name="text" as="xs:string?"/>
    <if test="$KeySort and $text">
      <variable name="ignoreRegex" as="xs:string">
        <variable name="ignores" as="xs:string*">
          <analyze-string select="oc:encodeKS($KeySort)" regex="{'\{([^\}]*)\}'}">
            <matching-substring><sequence select="regex-group(1)"/></matching-substring>
          </analyze-string>
        </variable>
        <value-of select="if ($ignores) then oc:decodeKS(concat('(', string-join($ignores, '|'), ')')) else ''"/>
      </variable>
      <variable name="charRegexes" as="element(me:regex)*">
        <!-- split KeySort string into 3 groups: chr | [] | {} -->
        <analyze-string select="oc:encodeKS($KeySort)" regex="{'([^\[\{]|(\[[^\]]*\])|(\{[^\}]*\}))'}">
          <matching-substring>
            <if test="not(regex-group(3))"><!-- if group(3) is non empty, this is an ignore group -->
              <me:regex>
                <attribute name="regex" select="oc:decodeKS(if (regex-group(2)) then substring(., 2, string-length(.)-2) else .)"/>
                <attribute name="position" select="position()"/>
              </me:regex>
            </if>
          </matching-substring>
        </analyze-string>
      </variable>
      <!-- re-order from longest regex to shortest -->
      <variable name="long2shortCharRegexes" as="element(me:regex)*">
        <for-each select="$charRegexes">     
          <sort select="string-length(./@regex)" data-type="number" order="descending"/> 
          <copy-of select="."/>
        </for-each>
      </variable>
      <variable name="long2shortCharRegexeMono" select="concat('(', string-join($long2shortCharRegexes/@regex, '|'), ')')" as="xs:string"/>
      <variable name="textKeep" select="if ($ignoreRegex) then replace($text, $ignoreRegex, '') else $text"/>
      <variable name="result" as="xs:string">
        <value-of>
        <analyze-string select="$textKeep" regex="{$long2shortCharRegexeMono}">
          <matching-substring>
            <variable name="subst" select="."/>
            <for-each select="$long2shortCharRegexes">
              <if test="matches($subst, concat('^', @regex, '$'))">
                <value-of select="codepoints-to-string(xs:integer(number(@position) + 64))"/> <!-- 64 starts at character "A" -->
              </if>
            </for-each>
          </matching-substring>
          <non-matching-substring>
            <choose>
              <when test="matches(., '\p{L}')">
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
  
  <!-- When a glossary has a TOC entry or main title, then get that title -->
  <function name="oc:getGlossaryName" as="xs:string">
    <param name="glossary" as="element(div)?"/>
    <value-of select="oc:titleCase(replace($glossary/(descendant::title[@type='main'][1] | descendant::milestone[@type=concat('x-usfm-toc', $TOC)][1]/@n)[1], '^(\[[^\]]*\])+', ''))"/>
  </function>
  
  <!-- When a glossary has a scope which is the same as a Sub-Publication's scope, then get the localized title of that Sub-Publication -->
  <function name="oc:getGlossaryScopeName" as="xs:string">
    <param name="glossary" as="element(div)?"/>
    <value-of select="oc:getGlossaryScopeName2($glossary, $glossary/@scope)"/>
  </function>
  <function name="oc:getGlossaryScopeName2" as="xs:string">
    <param name="glossary" as="element(div)?"/>
    <param name="scope" as="xs:string?"/>
    <variable name="createFullPublication" 
      select="if ($scope) then root($glossary)//header//description[contains(@type, 'ScopeSubPublication')][text()=$scope]/@type else ''"/>
    <variable name="pubn" select="if ($createFullPublication) then substring($createFullPublication[1], string-length($createFullPublication[1]), 1) else ''"/>
    <variable name="titleFullPublications" select="if ($pubn) then root($glossary)//header//description[contains(@type, concat('TitleSubPublication', $pubn))] else ''"/>
    <value-of select="if ($titleFullPublications) then $titleFullPublications[1]/text() else ''"/>
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
  
  <function name="oc:printNode" as="text()">
    <param name="node" as="node()"/>
    <choose>
      <when test="$node[self::element()]">
        <value-of>element <value-of select="$node/name()"/><for-each select="$node/@*"><value-of select="concat(' ', name(), '=&#34;', ., '&#34;')"/></for-each></value-of>
      </when>
      <when test="$node[self::text()]"><value-of select="concat('text-node: ', $node)"/></when>
      <when test="$node[self::comment()]"><value-of select="concat('comment-node: ', $node)"/></when>
      <when test="$node[self::attribute()]"><value-of select="concat('attribute-node: ', name($node), ' = ', $node)"/></when>
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
  <variable name="envp" as="xs:string +"><value-of select="''"/></variable>
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
    <param name="exp"/>
    <param name="die" select="'no'"/>
    <message terminate="{$die}">
      <text>&#xa;</text>ERROR (UNEXPECTED): <value-of select="$msg"/><text>&#xa;</text>
      <if test="$exp">SOLUTION: <value-of select="$exp"/><text>&#xa;</text></if>
      <text>Backtrace: </text><value-of select="oc:printNode(.)"/><text>&#xa;</text>
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
    <if test="$DEBUG = 'true'"><message>DEBUG: <value-of select="$msg"/></message></if>
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
