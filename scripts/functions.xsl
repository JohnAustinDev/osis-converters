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
 
  <!-- The following params are globals which should be defined before 
  this file is imported. Globals are really nice since it's a pain to
  pass around unnecessary variables in XSLT. This is how osis-converters 
  does it:
  1) runScript() and runXSLT() will pass the current value of the 
     corresponding Perl globals.
  2) if the calling XSLT is started another way, such as osis2xhtml.xsl 
     which is called by the Calibre OSIS-input plugin, then that calling 
     XSLT should read the values from the OSIS file header.
  3) if nothing sets them, they will have the default values below -->
  
  <!-- Setting to 'true' turns on debugging messages -->
  <param name="DEBUG" select="'false'"/>
  <!-- Use \toc1, \toc2 or \toc3 tags for creating the TOC -->
  <param name="tocnumber" select="2"/>
  <!-- TOC title standardization: 0=as-is, 1=Like This, 2=LIKE THIS -->
  <param name="titleCase" select="0"/>
  <!-- String describing how to sort glossary keys -->
  <param name="keySort" select="//description[@type='x-sword-config-KeySort'][1]"/>
 
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
  
  <!-- Encode any string value into a legal OSIS osisRef -->
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
  
  <!-- Sort by an arbitrary character order: <sort select="oc:keySort($key)" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/> -->
  <function name="oc:keySort" as="xs:string?">
    <param name="text" as="xs:string?"/>
    <if test="$keySort and $text">
      <variable name="ignoreRegex" as="xs:string">
        <variable name="ignores" as="xs:string*">
          <analyze-string select="oc:encodeKS($keySort)" regex="{'\{([^\}]*)\}'}">
            <matching-substring><sequence select="regex-group(1)"/></matching-substring>
          </analyze-string>
        </variable>
        <value-of select="if ($ignores) then oc:decodeKS(concat('(', string-join($ignores, '|'), ')')) else ''"/>
      </variable>
      <variable name="charRegexes" as="element(me:regex)*">
        <!-- split KeySort string into 3 groups: chr | [] | {} -->
        <analyze-string select="oc:encodeKS($keySort)" regex="{'([^\[\{]|(\[[^\]]*\])|(\{[^\}]*\}))'}">
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
                  <with-param name="msg">keySort(): Cannot sort aggregate glossary entry '<value-of select="$text"/>'; 'KeySort=<value-of select="$keySort"/>' is missing the character <value-of select="concat('&quot;', ., '&quot;')"/>.</with-param>
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
    <if test="not($keySort)">
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
  
  <function name="oc:getGlossaryName" as="xs:string">
    <param name="glossary" as="element(div)?"/>
    <value-of select="oc:titleCase($glossary/(descendant::title[@type='main'][1] | descendant::milestone[@type=concat('x-usfm-toc', $tocnumber)][1]/@n)[1])"/>
  </function>
  
  <function name="oc:getGlossaryScopeName" as="xs:string">
    <param name="glossary" as="element(div)?"/>
    <variable name="createFullPublication" 
      select="if ($glossary/@scope) then root($glossary)//header//description[contains(@type, 'CreateFullPublication')][text()=$glossary/@scope]/@type else ''"/>
    <variable name="pubn" select="if ($createFullPublication) then substring($createFullPublication[1], string-length($createFullPublication[1]), 1) else ''"/>
    <variable name="titleFullPublications" select="if ($pubn) then root($glossary)//header//description[contains(@type, concat('TitleFullPublication', $pubn))] else ''"/>
    <value-of select="if ($titleFullPublications) then $titleFullPublications[1]/text() else oc:getGlossaryName($glossary)"/>
  </function>
  
  <function name="oc:titleCase" as="xs:string?">
    <param name="title" as="xs:string?"/>
    <choose>
      <when test="$titleCase = 1"><value-of select="string-join(oc:capitalize-first(tokenize($title, '\s+')), ' ')"/></when>
      <when test="$titleCase = 2"><value-of select="upper-case($title)"/></when>
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
      <if test="$exp">CHECK: <value-of select="$exp"/></if>
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
