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
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace">
 
  <param name="DEBUG" select="'false'"/> 
 
  <!-- Copied from xsltfunctions.com -->
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
  <!-- End of functions copied from xsltfunctions.com -->

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
  
  <!-- Sort by an arbitrary character order: <sort select="oc:langSortOrder(string(), x-sword-config-LangSortOrder)" data-type="text" order="ascending" collation="http://www.w3.org/2005/xpath-functions/collation/codepoint"/> -->
  <function name="oc:langSortOrder" as="xs:string">
    <param name="text" as="xs:string"/>
    <param name="order" as="xs:string?"/>
    <if test="$order">
      <value-of>
        <for-each select="string-to-codepoints($text)">
          <choose>
            <when test="matches(codepoints-to-string(.), '[ \p{L}]')">
              <variable name="before" select="substring-before(concat('⇹ ', $order), codepoints-to-string(.))"/> <!-- ⇹ is a random never-used character required in first position -->
              <if test="not($before)">
                <call-template name="Log"><with-param name="msg" select="$text"/></call-template>
                <call-template name="Error">
                  <with-param name="msg">langSortOrder(): Cannot sort aggregate glossary entry '<value-of select="$text"/>'; 'LangSortOrder=<value-of select="$order"/>' is missing the character <value-of select="concat('&quot;', codepoints-to-string(.), '&quot; (codepoint: ', ., ')')"/>.</with-param>
                  <with-param name="exp">Add the missing character to the config.conf file's LangSortOrder entry. Place it where it belongs in the order of characters.</with-param>
                  <with-param name="die" select="'yes'"/>
                </call-template>
              </if>
              <value-of select="codepoints-to-string(string-length($before) + 64)"/> <!-- 64 starts at character "A" -->
            </when>
            <otherwise><value-of select="codepoints-to-string(.)"/></otherwise>
          </choose>
        </for-each>
      </value-of>
    </if>
    <if test="not($order)">
      <call-template name="Warn"><with-param name="msg">langSortOrder(): 'LangSortOrder' is not specified in config.conf. Glossary entries will be ordered in Unicode order. To reorder characters, specify the language's character order in config.conf with an entry like this: LangSortOrder=AaBbCcDdEe... etc.</with-param></call-template>
      <value-of select="$text"/>
    </if>
  </function>
  
  <function name="oc:getGlossaryName" as="xs:string">
    <param name="glossary" as="element(div)?"/>
    <param name="tocn" as="xs:integer"/>
    <value-of select="$glossary/(descendant::title[@type='main'][1] | descendant::milestone[@type=concat('x-usfm-toc', $tocn)][1]/@n)[1]"/>
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
