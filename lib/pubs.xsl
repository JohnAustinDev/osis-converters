<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- Prepare osis-converters OSIS for use with html & ebook ePublications -->
  
  <!-- Use the source (translator's custom) verse system -->
  <import href="./sourceVerseSystem.xsl"/>
  
  <!-- Filter out any marked elements which are not intended for this conversion -->
  <import href="./conversion.xsl"/>
  
  <variable name="removedNAVMENU_ids" as="xs:string*" 
      select="($MAINMOD_DOC/descendant::*[@osisID][ancestor::div[@scope='NAVMENU']]
              /oc:osisRef(@osisID, $MAINMOD)), 
              ($DICTMOD_DOC/descendant::*[@osisID][ancestor::div[@scope='NAVMENU']]
              /oc:osisRef(@osisID, $DICTMOD))"/>
  
  <template match="/"><call-template name="pubs.xsl"/></template>
  
  <template mode="pubs.xsl" match="/" name="pubs.xsl">
    <message>NOTE: Running pubs.xsl</message>
    
    <variable name="sourcevsys"><apply-templates mode="sourceVerseSystem.xsl" select="."/></variable>
    <variable name="conversion"><apply-templates mode="conversion.xsl"        select="$sourcevsys"/></variable>
    <variable name="pubs">      <apply-templates mode="pubs"                  select="$conversion"/></variable>
    <variable name="whitespace"><apply-templates mode="whitespace.xsl"        select="$pubs"/>      </variable>
    <sequence select="$whitespace"/>

    <if test="//div[@scope='NAVMENU']">
      <call-template name="Note">
<with-param name="msg">Removed <value-of select="count(//div[@scope='NAVMENU'])"/> NAVMENU div(s).</with-param>
      </call-template>
    </if>
  </template>
  
  <!-- By default copy everything as is -->
  <template mode="pubs" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <!-- Remove all navmenu link lists, which are custom-created as needed -->
  <template mode="pubs" match="list[@subType='x-navmenu']"/>
  
  <!-- Remove all NAVMENUs, which are custom-created as needed -->
  <template mode="pubs" match="div[@scope='NAVMENU']"/>
  
  <!-- Remove any references that target the removed NAVMENUs -->
  <template mode="pubs" match="@osisRef">
    <attribute name="osisRef" 
        select="oc:filter_osisRef(., true(), ($removedNAVMENU_ids, $removedOsisIDs))"/>
  </template>
  
  <!-- Cancel a conversion mode template to handle @osisRef in this stylesheet -->
  <template mode="conversion" match="@osisRef"><copy/></template>
  
</stylesheet>
