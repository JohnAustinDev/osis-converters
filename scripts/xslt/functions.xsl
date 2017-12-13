<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:runtime="java:java.lang.Runtime"
 xmlns:uri="java:java.net.URI"
 xmlns:file="java:java.io.File"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace">
 
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

  <!-- Only output true if $glossaryEntry first letter matches that of the previous entry --> 
  <function name="oc:skipGlossaryEntry">
    <param name="glossaryEntry"/>
    <variable name="previousKeyword" select="$glossaryEntry/preceding::osis:seg[@type='keyword'][1]/string()"/>
    <choose>
      <when test="not($previousKeyword)"><value-of select="false()"/></when>
      <otherwise><value-of select="boolean(substring($glossaryEntry/text(), 1, 1) = substring($previousKeyword, 1, 1))"/></otherwise>
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
  
  <!-- Sort by an arbitrary character order: <sort collation="http://www.w3.org/2005/xpath-functions/collation/codepoint" select="oc:getAlphaIndex(string(), x-sword-config-LangSortOrder)" data-type="text" order="ascending"/> -->
  <function name="oc:getAlphaIndex" as="xs:string">
    <param name="text" as="xs:string"/>
    <param name="order" as="xs:string?"/>
    <if test="not($order)"><message terminate="yes">ERROR: getAlphaIndex(): Cannot sort aggregate glossary; 'LangSortOrder' must be specified in config.conf.</message></if>
    <variable name="translatedCodePoints" as="xs:integer+">
      <for-each select="string-to-codepoints($text)">
        <choose>
          <when test="matches(codepoints-to-string(.), '[ \p{L}]')">
            <variable name="before" select="substring-before(concat('⇹ ', $order), codepoints-to-string(.))"/>
            <if test="not($before)"><message select="$text"/><message terminate="yes">ERROR: getAlphaIndex(): Cannot sort aggregate glossary; 'LangSortOrder=<value-of select="$order"/>' is missing the character <value-of select="concat('&quot;', codepoints-to-string(.), '&quot; (codepoint: ', ., ')')"/>.</message></if>
            <value-of select="string-length($before) + 64"/> <!-- 64 starts at character "A" -->
          </when>
          <otherwise><value-of select="."/></otherwise>
        </choose>
      </for-each>
    </variable>
    <value-of select="codepoints-to-string($translatedCodePoints)"/>
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
    <if test="not(unparsed-text-available($tmpResult))"><message select="'ERROR: Failed writing tmpResult'"/></if>
    <variable name="result">
      <if test="unparsed-text-available($tmpResult)"><value-of select="unparsed-text($tmpResult)"/></if>
    </variable>
    <if test="starts-with($result, 'nofile')"><message select="concat('ERROR: Failed to locate: ', $resource)"/></if>
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
    <if test="$ms!=10"><message select="concat('WARNING: Sleeping ', $ms, 'ms')"/></if>
    <message select="thread:sleep($ms)"/>     
  </template>
  
  <function name="oc:printNode" as="text()">
    <param name="node" as="node()"/>
    <choose>
      <when test="$node[self::element()]">
        <value-of>element:
          <value-of select="concat('element=', $node/name(), ', ')"/>
          <for-each select="$node/@*"><value-of select="concat(name(), '=', ., ', ')"/></for-each>
        </value-of>
      </when>
      <when test="$node[self::text()]"><value-of select="concat('text-node:', $node)"/></when>
      <when test="$node[self::comment()]"><value-of select="concat('comment-node:', $node)"/></when>
      <when test="$node[self::attribute()]"><value-of select="concat('attribute-node:', name($node), ' = ', $node)"/></when>
      <when test="$node[self::document-node()]"><value-of select="concat('document-node:', $node)"/></when>
      <when test="$node[self::processing-instruction()]"><value-of select="concat('processing-instruction:', $node)"/></when>
      <otherwise><value-of select="concat('other?:', $node)"/></otherwise>
    </choose>
  </function>
  
</stylesheet>
