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
  at the end of the initial majorSection. For others at the end
  of the first chapter. -->
  <variable name="insertBefore" as="node()?">
    <sequence select="
      if (not($isChildrensBible) and not($isGenericBook))
      then //osisText/div[@type = 'bookGroup' or (@type = 'introduction' and not(@resp = 'x-oc'))][1]
      else ()"/>
  </variable>

  <variable name="appendChild" as="node()?">
    <sequence select="
      if ($isChildrensBible)
      then //osisText/div[@type = 'book'][1]/div[@type = 'majorSection'][1]
      else (if ($isGenericBook)
      then //osisText/descendant::div[@type = 'book'][1]
      else ())"/>
  </variable>

  <template match="/">
    <call-template name="Log">
      <with-param name="msg">NOTE: Running writeCopyrightStatement.xsl (insertBefore=<value-of select="count($insertBefore)"/>, appendChild=<value-of select="count($appendChild)"/>)</with-param>
    </call-template>

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

  <template match="*[. intersect $insertBefore]" mode="writeCopyrightStatement">
    <call-template name="copyright"/>
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>

  <template match="*[. intersect $appendChild]" mode="writeCopyrightStatement">
    <copy>
      <apply-templates mode="#current" select="node()|@*"/>
      <call-template name="copyright"/>
    </copy>
  </template>

  <template name="copyright">
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
    <variable name="doInsert" select="$DistributionLicense or $Copyright or $DistributionNotes or
      $CopyrightHolder or $CopyrightContactAddress or $CopyrightContactEmail"/>

    <call-template name="Log">
      <with-param name="msg">Inserting copyright: (<value-of select="$doInsert"/>)</with-param>
    </call-template>

    <if test="$doInsert">
      <osis:div type="x-copyright">
        <osis:lb type="x-hr"/>
        <if test="$DistributionLicense">
          <osis:title level="4" type="main" subType="x-introduction" canonical="false">
            <value-of select="$DistributionLicense"/>
          </osis:title>
        </if>
        <if test="$Copyright">
          <osis:p><value-of select="$Copyright"/></osis:p>
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
          <osis:p><value-of select="$DistributionNotes"/></osis:p>
        </if>
        <osis:lb type="x-hr"/>
      </osis:div>
    </if>
  </template>

</stylesheet>
