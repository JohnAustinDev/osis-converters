<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:fb="http://www.gribuser.ru/xml/fictionbook/2.0"
 xmlns:xlink="http://www.w3.org/1999/xlink"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">

  <!-- TRANSFORM A BIBLE OSIS FILE, AND ITS REFERENCE FILES, INTO AN FB2 FILE
    To run this transform from the command line:
    $ saxonb-xslt -ext:on -xsl:osis2fb2.xsl -s:main.osis.xml -o:output.fb2
  -->

  <import href="./common/functions.xsl"/>

  <!-- A comma separated list of css and css-referenced files (such as fonts) -->
  <param name="css" select="oc:sarg('css', /, 'ebible.css,module.css')"/>

  <!-- Settings used to control the transform -->
  <param name="CombineGlossaries" select="oc:conf('CombineGlossaries', /)"/> <!-- CombineGlossaries: 'AUTO', 'true' or 'false' -->

  <!-- Osis-converters config entries used by this transform -->
  <param name="DEBUG" select="oc:csys('DEBUG', /)"/>

  <param name="TOC" select="oc:conf('TOC', /)"/>

  <param name="TitleCase" select="oc:conf('TitleCase', /)"/>

  <param name="TitleTOC" select="oc:conf('TitleTOC', /)"/>

  <param name="FullResourceURL" select="oc:conf('FullResourceURL', /)"/><!-- '' or 'false' turns this feature off -->

  <!-- The main input OSIS file must contain a work element corresponding to each
     OSIS file referenced in the project. But osis-converters supports a single
     dictionary OSIS file only, which contains all reference material. -->
  <variable name="referenceOSIS" as="document-node()?"
      select="if ($isChildrensBible or $isGenericBook)
              then ()
              else /osis/osisText/header/work[@osisWork != /osis/osisText/@osisIDWork]/
                doc(concat(tokenize(document-uri(/), '[^/]+$')[1], @osisWork, '.xml'))"/>

  <variable name="doCombineGlossaries" select="if ($CombineGlossaries = 'AUTO')
      then false() else $CombineGlossaries = 'true' "/>

  <variable name="CombGlossaryTitle" select="//work[boolean($DICTMOD) and @osisWork = $DICTMOD]/title[1]"/>

  <!-- A main inline Table Of Contents is placed after the first TOC milestone sibling
       following the OSIS header, or, if there isn't such a milestone, one will be created. -->
  <variable name="mainTocMilestone" select="
      if (not($isChildrensBible) and not($isGenericBook))
      then /descendant::milestone[@type=concat('x-usfm-toc', $TOC)]
          [not(me:getTocClasses(.) = ('no_toc'))][1]
          [. &#60;&#60; /descendant::div[starts-with(@type,'book')][1]]
      else /descendant::milestone[@type=concat('x-usfm-toc', $TOC)]
          [not(me:getTocClasses(.) = ('no_toc'))][1]"/>

  <variable name="REF_BibleTop" select="concat($MAINMOD,':BIBLE_TOP')"/>
  <variable name="REF_DictTop" select="if ($DICTMOD) then concat($DICTMOD,':DICT_TOP') else ''"/>

  <variable name="mainInputOSIS" select="/"/>

  <!-- Don't convert Unicode SOFT HYPHEN to "&shy;" in html output files.
  Because SOFT HYPHENs are currently being stripped out by the Calibre
  EPUB output plugin, and they break html in browsers (without first
  defining the entity). To reinstate &shy; uncomment the following line and
  add 'use-character-maps="xhtml-entities"' to <output name="htmlfiles"/> below -->
  <!-- <character-map name="xhtml-entities"><output-character character="&#xad;" string="&#38;shy;"/></character-map> !-->
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no"/>

  <!-- ROOT NODE TEMPLATE FOR MAIN INPUT OSIS FILE -->
  <template match="/">
    <call-template name="oc:prepareRunTime"/>

    <FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">

      <stylesheet type="text/css">
        <for-each select="tokenize($css, '\s*,\s*')" xmlns="http://www.w3.org/1999/XSL/Transform">
          <if test="unparsed-text-available(.)">
            <text>&#xa;</text><value-of select="unparsed-text(.)"/>
          </if>
          <if test="not(unparsed-text-available(.))">
            <call-template name="Error"><with-param name="msg" select="concat('Could not find CSS file: ', .)"/></call-template>
          </if>
        </for-each>
      </stylesheet>

      <description>
        <xsl:apply-templates select="//header"/>
      </description>

      <body>
        <xsl:call-template name="WriteRootTOC"/>
      </body>

      <xsl:for-each select="$allOsisFiles//osisText/*[not(self::header)]">
        <body>
          <xsl:apply-templates select="."/>
        </body>
      </xsl:for-each>

      <xsl:if test="$allOsisFiles//note">
        <body name="notes">
          <xsl:for-each select="$allOsisFiles//note">
            <xsl:variable name="osisIDid" select="replace(replace(@osisID, '^[^:]*:', ''), '!', '_')"/>
            <section id="n_{./ancestor::osisText[1]/@osisIDWork[1]}_{$osisIDid}"><p><a href="s_{./ancestor::osisText[1]/@osisIDWork[1]}_{$osisIDid}"><xsl:call-template name="getFootnoteSymbol"/></a><xsl:text> </xsl:text><xsl:apply-templates/></p></section>
          </xsl:for-each>
        </body>
      </xsl:if>

      <xsl:for-each select="distinct-values(($allOsisFiles//figure/@src))">
        <binary id="fig_{replace(replace(., '^.*?([^/]+)$', '$1'), '[\.\s]', '_')}"
                content-type="image/{if (ends-with(lower-case(.), 'jpg')) then 'jpeg' else replace(lower-case(.), '^.*?([^\.]+)$', '$1')}">
          <xsl:value-of select="oc:read-binary-resource(.)"/>
        </binary>
      </xsl:for-each>
    </FictionBook>
    <call-template name="oc:cleanupRunTime"/>
  </template>

  <!-- This template is called after writing the first body element -->
  <template name="WriteRootTOC">
  </template>

  <!-- This template may be called from any note. It returns a symbol or number based on that note's type and OSIS context -->
  <template name="getFootnoteSymbol">
    <param name="classes"/>
    <variable name="inVerse" select="preceding::verse[1]/@sID = following::verse[1]/@eID or preceding::verse[1]/@sID = descendant::verse[1]/@eID or count(ancestor::title[@canonical='true'])"/>
    <choose>
      <when test="$inVerse and not(@type='crossReference')">*</when>
      <when test="$inVerse and @subType='x-parallel-passage'">•</when>
      <when test="$inVerse">+</when>
      <otherwise>[<xsl:call-template name="getFootnoteNumber"/>]</otherwise>
    </choose>
  </template>

  <!-- This template may be called from any note. It returns the number of that note within its output file -->
  <template name="getFootnoteNumber">
    <choose>
      <when test="ancestor::div[@type='glossary']">
        <choose>
          <when test="not(descendant-or-self::seg[@type='keyword']) and count(preceding::seg[@type='keyword']) = count(ancestor::div[@type='glossary'][1]/preceding::seg[@type='keyword'])">
            <value-of select="count(preceding::note) - count(ancestor::div[@type='glossary'][1]/preceding::note) + 1"/>
          </when>
          <otherwise>
            <value-of select="count(preceding::note) - count(preceding::seg[@type='keyword'][1]/preceding::note) + 1"/>
          </otherwise>
        </choose>
      </when>
      <when test="ancestor::div[@type='book']">
        <value-of select="count(preceding::note) - count(ancestor::div[@type='book'][1]/preceding::note) + 1"/>
      </when>
      <when test="ancestor::div[@type='bookGroup']">
        <value-of select="count(preceding::note) - count(ancestor::div[@type='bookGroup'][1]/preceding::note) + 1"/>
      </when>
      <when test="ancestor::osisText">
        <value-of select="count(preceding::note) + 1"/>
      </when>
    </choose>
  </template>

</stylesheet>
