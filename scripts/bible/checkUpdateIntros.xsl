<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of "osis-converters".

Copyright 2017 John Austin (gpl.programs.info@gmail.com)
    
 "osis-converters" is free software: you can redistribute it and/or 
  modify it under the terms of the GNU General Public License as 
  published by the Free Software Foundation, either version 2 of 
  the License, or (at your option) any later version.

  "osis-converters" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "osis-converters".  If not, see 
  <http://www.gnu.org/licenses/>. 
-->
  
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- This XSLT will do the following:
    1) Move section titles just before chapter tags to after the chapter tags, because they are not introductory and are associated with the next chapter
    2) Report relevant intro elements which are not subType="x-introduction" and make them such. Also add canonical=false as needed
    3) Titles set to canonical=false unless already explicitly set
  -->
  
  <import href="../functions.xsl"/>
  
  <!-- Call with DEBUG='true' to turn on debug messages -->
  <param name="DEBUG" select="'false'"/>
  
  <variable name="MOD" select="//osisText/@osisIDWork"/>
  
  <variable name="moveDivs" as="element(div)*" select="descendant::div[matches(@type, 'section', 'i')]
      [(descendant::*|following::*)[self::chapter[@sID]][1] &#60;&#60; (descendant::text()|following::text())[normalize-space()][not(ancestor-or-self::title)][1]]"/>
      
  <!-- title|item|p|l|q are the introduction elements output by usfm2osis.py -->
  <variable name="introElements" as="element()*" select="//(title|item|p|l|q)[not(ancestor::header)]
      [. &#60;&#60; (ancestor::div[starts-with(@type, 'book')][1]|ancestor::osisText)[last()]/(descendant::div[starts-with(@type, 'book')]|descendant::chapter[@sID])[1]]"/>
      
  <variable name="addIntroAttrib" as="element()*" select="$introElements[not(@subType) or @subType != 'x-introduction'][not(generate-id(.) = $moveDivs/title[1]/generate-id())]"/>
      
  <variable name="removeIntroAttrib" as="element()*" select="//(title|item|p|l|q)[@subType='x-introduction'] except $introElements"/>
  
  <variable name="addCanonical" as="element()*" select="$introElements[not(@canonical)][ancestor::div[@type='book'][@canonical = 'true']]"/>

  <!-- By default copy everything as is, for all modes -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <template match="/">
    <call-template name="Log"><with-param name="msg"><text>&#xa;</text><text>&#xa;</text>Checking introductory material in <value-of select="document-uri(.)"/>.</with-param></call-template>
    
    <!-- Log moved titles -->
    <if test="$moveDivs">
      <call-template name="Note"><with-param name="msg">Section title(s) just before a chapter tag were moved after the chapter tag:</with-param></call-template>
      <for-each select="$moveDivs"><call-template name="Log"><with-param name="msg" select="concat('&#9;', (descendant::*|following::*)[self::chapter[@sID]][1]/@sID, ': ', child::title[1])"></with-param></call-template></for-each>
    </if>
    
    <!-- Check and log introduction attributes -->
    <if test="count($addIntroAttrib[@subType != 'x-introduction'])">
      <call-template name="Error"><with-param name="msg">Some introduction elements have a subType that is not x-introduction: <value-of select="distinct-values($addIntroAttrib[@subType != 'x-introduction']/local-name())"/></with-param></call-template>
    </if>
    <call-template name="Report"><with-param name="msg"><value-of select="count($addIntroAttrib)"/> instance(s) of non-introduction USFM tags used in introductions.</with-param></call-template>
    <if test="$addIntroAttrib">
      <call-template name="Note"><with-param name="msg">Some USFM tags used for introductory material were not proper introduction
tags. But these have been handled by adding subType="x-introduction" to resulting
OSIS elements, so changes to USFM source are not required.</with-param></call-template>
      <for-each select="('item', 'l', 'p', 'q', 'title')">
        <if test="count($addIntroAttrib[local-name()=current()]) != 0"><call-template name="Warn"><with-param name="msg">Added subType="x-introduction" to <value-of select="concat(count($addIntroAttrib[local-name()=current()]), ' ', .)"/> elements.</with-param></call-template></if>
      </for-each>
    </if>
    <call-template name="Report"><with-param name="msg"><value-of select="count($removeIntroAttrib)"/> instance(s) of introduction USFM tags used outside of introductions<value-of select="if ($removeIntroAttrib) then ':' else '.'"/></with-param></call-template>
    <if test="$removeIntroAttrib">
      <call-template name="Note"><with-param name="msg">These have been handled by removiong subType="x-introduction" to resulting
OSIS elements, so changes to USFM source are not required.</with-param></call-template>
      <for-each select="('item', 'l', 'p', 'q', 'title')">
        <if test="count($removeIntroAttrib[local-name()=current()]) != 0"><call-template name="Warn"><with-param name="msg">Removed subType="x-introduction" to <value-of select="concat(count($removeIntroAttrib[local-name()=current()]), ' ', .)"/> elements.</with-param></call-template></if>
      </for-each>
    </if>
    <next-match/>
  </template>

  <!-- Write (move) chapter tag before movedTitles -->
  <template match="*[$moveDivs/generate-id() = generate-id(.)]">
    <if test="not(preceding-sibling::node()[normalize-space][1][not(title[1][parent::div[matches(@type, 'section', 'i')]])])">
      <for-each select="./(descendant::*|following::*)[self::chapter[@sID]][1]"><call-template name="identity"/></for-each>
    </if>
    <call-template name="identity"/>
  </template>
  
  <!-- Remove chapter tag after moved Titles -->
  <template match="chapter[@sID][generate-id(.) = $moveDivs/(descendant::*|following::*)[self::chapter[@sID]][1]/generate-id()]"/>
  
  <!-- Add element subType and canonical attributes according to SWORD best practice -->
  <template match="*[($addIntroAttrib|$addCanonical)/generate-id() = generate-id(.)] | title[not(ancestor::header)][not(@canonical)]">
    <copy><apply-templates select="@*"/>
      <!-- titles should be canonical=false unless already explicitly set -->
      <if test="$addIntroAttrib/generate-id() = generate-id(.)"><attribute name="subType" select="'x-introduction'"/></if>
      <if test="$addCanonical/generate-id() = generate-id(.) or self::title"><attribute name="canonical" select="'false'"/></if>
      <apply-templates/>
    </copy>
  </template>
  
  <!-- Remove x-introduction attribute from moved titles -->
  <template match="title[1][parent::div[matches(@type, 'section', 'i')]][@subType = 'x-introduction']/@subType"/>
  
  <!-- Remove x-introduction attribute as needed -->
  <template match="*[$removeIntroAttrib/generate-id()= generate-id(.)]/@subType"/>
  
</stylesheet>
