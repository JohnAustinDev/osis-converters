<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/navigationMenu.xsl"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT does the following:
  1) Assemble a human readable copyright statement with distribution notes, 
     using header metadata.
  2) Insert the statement into an appropriate place in the OSIS file.
  -->
 
  <import href="./common/functions.xsl"/>
  
  <param name="fallbackLang" select="'ru'"/>
  
  <!-- Insert it before the first bookGroup, or before the first
  introduction if there is one. For Children's Bibles, insert it
  at the end of the initial majorSection. -->
  <variable name="insertBeforeMe" as="node()">
    <sequence select="if ($isChildrensBible)
      then //osisText/div[@type = 'book'][1]/div[@type = 'majorSection'][1]/node()[last()]
      else //osisText/div[@type = 'bookGroup' or (@type = 'introduction' and not(@resp = 'x-oc'))][1]"/>
  </variable>
  
  <template match="/">
    <message>NOTE: Running writeCopyrightStatement.xsl</message>
    
    <if test="//osisText/@osisIDWork != $MAINMOD">
      <call-template name="ErrorBug">
        <with-param name="msg">Module type not supported.</with-param>
        <with-param name="die">yes</with-param>
      </call-template>
    </if>
    
    <apply-templates mode="writeCopyrightStatement" select="." />
  </template>
  
  <template match="node()|@*" mode="writeCopyrightStatement">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <template match="*[. intersect $insertBeforeMe]" mode="writeCopyrightStatement">
    <variable name="DistributionLicense"
      select="oc:locConf('DistributionLicense', $fallbackLang, .)"/>
    <variable name="Copyright"
      select="oc:locConf('Copyright', $fallbackLang, .)"/>
    <variable name="DistributionNotes"
      select="oc:locConf('DistributionNotes', $fallbackLang, .)"/>
    <variable name="CopyrightHolder"
      select="oc:locConf('CopyrightHolder', $fallbackLang, .)"/>
    <variable name="CopyrightContactAddress"
      select="oc:locConf('CopyrightContactAddress', $fallbackLang, .)"/>
    <variable name="CopyrightContactEmail"
      select="oc:locConf('CopyrightContactEmail', $fallbackLang, .)"/>
      
    <if test="$DistributionLicense or $Copyright or $DistributionNotes or
      $CopyrightHolder or $CopyrightContactAddress or $CopyrightContactEmail">
      <osis:div type="x-copyright">
        <osis:lb type="x-hr"/>
        <if test="$DistributionLicense">
          <osis:title level="4" type="main" subType="x-introduction" canonical="false">
            <value-of select="$DistributionLicense"/>
          </osis:title>
        </if>
        <if test="$Copyright">
          <osis:div><value-of select="$Copyright"/></osis:div>
        </if>
        <if test="$CopyrightHolder or $CopyrightContactAddress or $CopyrightContactEmail">
          <osis:lb/>
          <if test="$CopyrightHolder">
            <osis:title level="4" type="main" subType="x-introduction" canonical="false">
              <value-of select="$CopyrightHolder"/>
            </osis:title>
          </if>
          <if test="$CopyrightContactAddress">
            <osis:title level="4" type="main" subType="x-introduction" canonical="false">
              <value-of select="$CopyrightContactAddress"/>
            </osis:title>
          </if>
          <if test="$CopyrightContactEmail">
            <osis:title level="4" type="main" subType="x-introduction" canonical="false">
              <value-of select="$CopyrightContactEmail"/>
            </osis:title>
          </if>
          <osis:lb/>
        </if>
        <if test="$DistributionNotes">
          <osis:div><value-of select="$DistributionNotes"/></osis:div>
        </if>
        <osis:lb type="x-hr"/>
      </osis:div>
    </if>
    
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
    
  </template>
  
</stylesheet>
