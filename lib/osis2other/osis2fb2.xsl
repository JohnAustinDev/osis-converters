<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/osis2fb2"
 xmlns:oo="http://github.com/JohnAustinDev/osis-converters/osis2other"
 xmlns:fb2="http://www.gribuser.ru/xml/fictionbook/2.0"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:xlink="http://www.w3.org/1999/xlink"
 xmlns:xs="http://www.w3.org/2001/XMLSchema">

  <!-- TRANSFORM A BIBLE OSIS FILE, AND ITS REFERENCE FILES, INTO AN FB2 FILE
    To run this transform from the command line:
    $ saxonb-xslt -ext:on -xsl:osis2fb2.xsl -s:main.osis.xml -o:output.fb2
  -->

  <import href="../common/functions.xsl"/>

  <import href="../whitespace.xsl"/>

  <import href="./osis2other.xsl"/>

  <variable name="target" select="'fb2'"/>

  <!-- Don't convert Unicode SOFT HYPHEN to "&shy;" in html output files.
  Because SOFT HYPHENs are currently being stripped out by the Calibre
  EPUB output plugin, and they break html in browsers (without first
  defining the entity). To reinstate &shy; uncomment the following line and
  add 'use-character-maps="xhtml-entities"' to <output name="htmlfiles"/> below -->
  <!-- <character-map name="xhtml-entities"><output-character character="&#xad;" string="&#38;shy;"/></character-map> !-->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no"/>

  <!-- ROOT TEMPLATE -->
  <template match="/">
    <call-template name="oc:prepareRunTime"/>

    <call-template name="Log">
      <with-param name="msg">
      isChildrensBible = <value-of select="$isChildrensBible"/>
      isGenericBook = <value-of select="$isGenericBook"/>
      doCombineGlossaries = <value-of select="$doCombineGlossaries"/>
      includeNavMenuLinks = <value-of select="$includeNavMenuLinks"/>
      glossaryToc = <value-of select="$glossaryToc"/>
      keywordFile = <value-of select="$keywordFile"/>
      eachChapterIsFile = <value-of select="$eachChapterIsFile"/>
      </with-param>
    </call-template>

    <variable name="preprocessedMainOSIS">
      <call-template name="preprocessMain"/>
    </variable>

    <variable name="preprocessedRefOSIS">
      <call-template name="preprocessDict"/>
    </variable>

    <variable name="combinedGlossary">
      <call-template name="combinedGlossary"/>
    </variable>

    <variable name="fb2">
      <call-template name="fb2">
        <with-param name="currentTask" select="'write-output'" tunnel="yes"/>
        <with-param name="preprocessedMainOSIS" select="$preprocessedMainOSIS" tunnel="yes"></with-param>
        <with-param name="combinedGlossary" select="$combinedGlossary" tunnel="yes"></with-param>
        <with-param name="preprocessedRefOSIS" select="$preprocessedRefOSIS" tunnel="yes"/>
      </call-template>
    </variable>

    <apply-templates mode="whitespace.xsl" select="$fb2"/>

    <call-template name="oc:cleanupRunTime"/>
  </template>

  <!-- FB2 STRUCTURAL TEMPLATE -->
  <template name="fb2">
    <param name="preprocessedMainOSIS" tunnel="yes"/>
    <param name="combinedGlossary" tunnel="yes"/>
    <param name="preprocessedRefOSIS" tunnel="yes"/>

    <element name="FictionBook" namespace="http://www.gribuser.ru/xml/fictionbook/2.0">
      <namespace name="xlink">http://www.w3.org/1999/xlink</namespace>

      <fb2:stylesheet type="text/css">
        <for-each select="tokenize($css, '\s*,\s*')">
          <if test="unparsed-text-available(.)">
            <text>&#xa;</text><value-of select="unparsed-text(.)"/>
          </if>
          <if test="not(unparsed-text-available(.))">
            <call-template name="Error"><with-param name="msg" select="concat('Could not find CSS file: ', .)"/></call-template>
          </if>
        </for-each>
      </fb2:stylesheet>

      <description xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
        <title-info>
          <genre>religion</genre>
          <author>
            <first-name></first-name>
            <last-name><xsl:sequence select="oc:locConf('CopyrightHolder', 'ru', .)"/></last-name>
          </author>
          <book-title>
            <xsl:sequence select="oc:locConf('TranslationTitle', 'ru', .)"/>
          </book-title>
          <lang>
            <xsl:sequence select="replace(oc:locConf('Lang', 'ru', .), '-.*$', '')"/>
          </lang>
        </title-info>
        <document-info>
          <author>
            <first-name></first-name>
            <last-name><xsl:sequence select="oc:locConf('CopyrightHolder', 'ru', .)"/></last-name>
          </author>
          <program-used>osis-converters</program-used>
          <date><xsl:sequence select="current-date()"/></date>
          <id><xsl:sequence select="generate-id()"/></id>
          <version><xsl:sequence select="oc:locConf('Version', 'ru', .)"/></version>
        </document-info>
        <publish-info>
            <publisher>
              <xsl:sequence select="oc:locConf('CopyrightHolder', 'ru', .)"/>
            </publisher>
        </publish-info>
      </description>

      <for-each select="($preprocessedMainOSIS | $preprocessedRefOSIS)//osisText">
        <fb2:body>
          <!-- If our main OSIS file doesn't have a main TOC milestone, then add one -->
          <if test="not($mainTocMilestone)" xmlns="http://www.w3.org/1999/XSL/Transform">
            <sequence select="oc:getMainInlineTOC(root(), $combinedGlossary, $preprocessedRefOSIS)"/>
          </if>
          <apply-templates mode="tran" select="."/>
        </fb2:body>
      </for-each>

      <if test="($preprocessedMainOSIS | $preprocessedRefOSIS)//note">
        <fb2:body name="notes">
          <fb2:title><fb2:p>Footnotes</fb2:p></fb2:title>
          <for-each select="($preprocessedMainOSIS | $preprocessedRefOSIS)//note">
            <fb2:section id="{oc:id(@osisID)}">
              <fb2:title>
                <fb2:p>
                  <call-template name="getFootnoteSymbol">
                    <with-param name="classes" select="oc:getClasses(.)"/>
                  </call-template>
                </fb2:p>
              </fb2:title>
              <fb2:p><apply-templates mode="tran"/></fb2:p>
            </fb2:section>
          </for-each>
        </fb2:body>
      </if>

      <for-each select="($preprocessedMainOSIS | $preprocessedRefOSIS)//figure">
        <variable name="type" select="
          if (ends-with(lower-case(./@src), 'jpg'))
          then 'jpeg'
          else replace(lower-case(./@src), '^.*?([^\.]+)$', '$1')"/>
        <fb2:binary id="{oo:imageID(.)}" content-type="image/{$type}">
          <value-of select="oc:read-binary-resource(./@src)"/>
        </fb2:binary>
      </for-each>

    </element>
  </template>

</stylesheet>
