<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:tei="http://www.crosswire.org/2013/TEIOSIS/namespace"
 exclude-result-prefixes="#all">
 
  <!-- This script checks osisRef and src attribtue targets of SWORD 
  OSIS and TEI source files. Any MAINMOD links to DICTMOD will only be 
  checked when DICTMOD is checked (so MAINMOD must be created before 
  DICTMOD). If an osisRef targets a DICTMOD entry which does not exist, 
  an error is generated. When DICTMOD is checked, all keywords will be 
  checked for uniqueness, which is a requirement of SWORD. -->
 
  <import href="./common/functions.xsl"/>
  
  <output method="text"/><!-- this xsl only checks references and outputs nothing -->
 
  <param name="moduleFiles"/><!-- '|' separated list of referenceable module file relative paths -->
  
  <param name="MAINMOD"/><!-- MAINMOD must be a param because TEI header doesn't have it! -->
  
  <variable name="MAINTYPE" select="$MAINMOD_DOC//work[@osisWork=//@osisIDWork]/type/@type"/>
 
  <variable name="DOCWORK" select="if (//@osisRefWork) 
                                   then //@osisRefWork[1] 
                                   else $DICTMOD"/>
  <variable name="keywords" select="//tei:entryFree/@n"/>
  
  <variable name="duplicate_keywords" select="//tei:entryFree/@n
                                              [. = following::tei:entryFree/@n]
                                              [not(. = preceding::tei:entryFree/@n)]"/>
                                                              
  <template match="/"><call-template name="checkrefsSWORD.xsl"/></template>
  
  <template mode="checkrefsSWORD.xsl" match="/" name="checkrefsSWORD.xsl">
    <message>NOTE: Running checkrefsSWORD.xsl on <value-of select="document-uri(.)"/></message>
    
    <!-- Check for duplicate keywords, which are not allowed by SWORD -->
    <for-each select="$duplicate_keywords">
      <call-template name="Error">
<with-param name="msg">Duplicate keyword: <value-of select="."/></with-param>
      </call-template>
    </for-each>
    <if test="$keywords">
      <call-template name="Report">
<with-param name="msg">There are <value-of select="count($duplicate_keywords)"/> instances of duplicate keywords in <value-of select="$DICTMOD"/> TEI file.</with-param>
      </call-template>
    </if>
    
    <!-- Check for empty osisRef attributes -->
    <for-each select="(//@osisRef | $MAINMOD_DOC//@osisRef)[not(normalize-space())]">
      <call-template name="Error">
<with-param name="msg">Empty osisRef in <value-of select="if (./ancestor::osisText/@osisIDWork) then $MAINMOD else $DICTMOD"/>: <value-of select="oc:printNode(./parent::*)"/></with-param>
      </call-template>
    </for-each>
    
    <!-- Check osisRef targets (but scripture ref targets are not  
    checked because SWORD supports scripture references which do not
    exist in the referenced work)-->
    <variable name="osisRefs" as="xs:string*"
      select="(//@osisRef | $MAINMOD_DOC//@osisRef)
              [boolean($keywords)][starts-with(., concat($DICTMOD, ':'))]"/>
    
    <variable name="missing2DICT" as="xs:string*" 
        select="for $e in $osisRefs, $r in oc:osisRef_atoms($e)
          return if (not(starts-with($r, concat($DICTMOD, ':')))) then ()
                 else if (not($keywords)) then ()
                 else if (oc:decodeOsisRef(oc:ref($r)) = $keywords) then ()
                 else $r"/>
    <for-each select="$missing2DICT[normalize-space()]">
      <call-template name="Error">
<with-param name="msg">Missing target entryFree[@n="<value-of select="oc:decodeOsisRef(oc:ref(.))"/>"]</with-param>
      </call-template>
    </for-each>
    
    <!-- Check src attributes against module files -->
    <for-each select="//@src[not(. = tokenize($moduleFiles, '\|'))]">
      <call-template name="Error">
<with-param name="msg">Reference to missing module file: "<value-of select="."/>"</with-param>
      </call-template>
    </for-each>
    
  </template>
  
</stylesheet>
