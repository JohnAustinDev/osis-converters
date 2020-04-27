<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:tei="http://www.crosswire.org/2013/TEIOSIS/namespace"
 exclude-result-prefixes="#all">
 
  <!-- This script checks all osisRef attribtues in the TEI DICT mod and  
  its MAIN OSIS file. If an osisRef targets a DICT entry which does not 
  exist, then an error is generated. It also checks that DICT entries
  are unique, which is a requirement for SWORD. -->
 
  <import href="../../functions/functions.xsl"/>
 
  <param name="mainmod"/>
  <param name="mainmodURI"/>
 
  <variable name="keywords" select="//tei:entryFree/@n"/>
  <variable name="mainmodDOC" select="doc($mainmodURI)"/>
  <variable name="duplicate_keywords" select="//tei:entryFree/@n
                                              [. = following::tei:entryFree/@n]
                                              [not(. = preceding::tei:entryFree/@n)]"/>
 
  <template match="node()|@*" name="identity" mode="identity">
    <copy><apply-templates select="node()|@*" mode="identity"/></copy>
  </template>
  
  <template match="document-node()" priority="2" mode="#all">
    <call-template name="Log">
<with-param name="msg">Checking glossary osisRef targets in <value-of select="document-uri(.)"/></with-param>    
    </call-template>
    <next-match/>
  </template>
  
  <template match="/">
    <!-- error if any duplicates, which are not allowed by SWORD -->
    <for-each select="$duplicate_keywords">
      <call-template name="Error">
<with-param name="msg">Duplicate keyword: <value-of select="."/></with-param>
      </call-template>
    </for-each>
    <call-template name="Report">
<with-param name="msg">There are <value-of select="count($duplicate_keywords)"/> instances of duplicate keywords in <value-of select="$DICTMOD"/> TEI file.</with-param>
    </call-template>
    
    <!-- copy DICT xml while checking osisRefs -->
    <copy><apply-templates select="node()" mode="identity"/></copy>
    
    <!-- read MAIN xml while checking osisRefs -->
    <apply-templates select="$mainmodDOC" mode="no_output"/>
  </template>
  
  <template match="node()|@*" name="no_output" mode="no_output">
    <apply-templates select="node()|@*" mode="no_output"/>
  </template>
  
  <!-- this template checks every osisRef in both MAIN and DICT documents -->
  <template match="@osisRef" mode="#all">
    <variable name="docwork" select="if (ancestor::osisText/@osisRefWork) 
                                     then ancestor::osisText/string(@osisRefWork) 
                                     else $DICTMOD"/>
    <variable name="work" select="if (tokenize(., ':')[2]) 
                                  then tokenize(., ':')[1] 
                                  else $docwork"/>
    <variable name="ref" select="if (tokenize(., ':')[2]) 
                                 then tokenize(., ':')[2] 
                                 else ."/>
    <choose>
      <when test="$work = $DICTMOD">
        <if test="not(oc:decodeOsisRef($ref) = $keywords)">
          <call-template name="Error">
<with-param name="msg"><value-of select="$docwork"/> reference target missing: <value-of select="parent::*/string()"/> osisRef="<value-of select="."/>"</with-param>
          </call-template>
        </if>
      </when>
      <!-- This check wont' be run if there is no DICT -->
      <when test="$work = $mainmod">
        <if test="matches($ref, '[^A-Za-z0-9\-\.]') and not($ref = $mainmodDOC//*/@osisID)">
          <call-template name="Error">
<with-param name="msg"><value-of select="$docwork"/> bad reference target: osisRef="<value-of select="."/>"</with-param>
          </call-template>
        </if>
      </when>
    </choose> 
    
    <next-match/>
  </template>
  
</stylesheet>
