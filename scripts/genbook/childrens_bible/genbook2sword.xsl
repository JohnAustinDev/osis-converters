<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
  
  <!-- This stylesheet decodes osisIDs into utf8 for Children's Bible SWORD import and
       also moves pre section 1 stuff into section 1 so it will appear in the SWORD intro. -->
 
  <import href="../../functions.xsl"/>
  
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
 
  <template match="@osisID"><attribute name="osisID" select="oc:decodeOsisRef(.)"/></template>
  
  <template match="div[@type='book']/div[@type='majorSection']">
    <copy><apply-templates select="@*"/>
      <if test="not(preceding-sibling::div[@type='majorSection'])">
        <for-each select="preceding-sibling::node()"><sequence select="."/></for-each>
      </if>
      <apply-templates select="node()"/>
    </copy>
  </template>
  <template match="div[@type='book']/node()[not(self::div[@type='majorSection'])]"/>
  
</stylesheet>
