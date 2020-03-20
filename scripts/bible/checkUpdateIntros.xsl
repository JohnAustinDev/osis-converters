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
    1) Report relevant intro elements which are not subType="x-introduction" and make them such. Also add canonical=false as needed
    2) Report relevant body elements which are subType="x-introduction" and remove the subType attribute from them.
    3) Titles are set to canonical=false unless already explicitly set
  -->
  
  <import href="../functions/functions.xsl"/>
  
  <variable name="MOD" select="//osisText/@osisIDWork"/>
      
  <!-- All introduction elements output by usfm2osis.py (title|item|p|l|q) which are located in an introductory position -->
  <variable name="introElements" as="element()*" select="
    //(title|item|p|l|q)
    [not(ancestor::header)]
    [not(ancestor::div[@scope='NAVMENU'])]
    [not(ancestor::*[@subType='x-navmenu'])]
    [not(. &#62;&#62; ./ancestor::div[@type='book'][1]/descendant::chapter[@sID][1])]"/>
  
  <!-- All introduction elements which need to have subType="x-introduction" added to them -->
  <variable name="addIntroAttrib" as="element()*" select="
    $introElements
    [not(@subType) or @subType != 'x-introduction']"/>
      
  <!-- All elements which are not introduction elements and need to have subType="x-introduction" removed -->
  <variable name="removeIntroAttrib" as="element()*" select="
    //(title|item|p|l|q)
    [not(ancestor::header)]
    [not(ancestor::div[@scope='NAVMENU'])]
    [not(ancestor::*[@subType='x-navmenu'])]
    [@subType='x-introduction'] 
    except $introElements"/>
  
  <!-- All introduction elements within canonical divs which need to be marked as non-canonical -->
  <variable name="addCanonicalFalse" as="element()*" select="
    $introElements
    [not(@canonical)]
    [ancestor::div[@type='book'][@canonical = 'true']]"/>

  <!-- By default copy everything as is, for all modes -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <!-- Report everything that is to be done -->
  <template match="/">
    <call-template name="Log"><with-param name="msg"><text>&#xa;</text><text>&#xa;</text>Checking introductory material in <value-of select="document-uri(.)"/>.</with-param></call-template>
    
    <!-- Check and log introduction attributes -->
    <if test="count($addIntroAttrib[@subType != 'x-introduction'])">
      <call-template name="Warn"><with-param name="msg">Some introduction elements have a subType that is not x-introduction: <for-each select="$addIntroAttrib[@subType != 'x-introduction']"><text>&#xa;</text><value-of select="oc:printNode(.)"/></for-each></with-param></call-template>
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
  
  <!-- Add element subType and canonical attributes according to SWORD best practice -->
  <template match="*[($addIntroAttrib|$addCanonicalFalse)/generate-id() = generate-id(.)] | title[not(ancestor::header)][not(@canonical)]">
    <copy><apply-templates select="@*"/>
      <!-- titles should be canonical=false unless already explicitly set -->
      <if test="$addIntroAttrib/generate-id() = generate-id(.)"><attribute name="subType" select="'x-introduction'"/></if>
      <if test="$addCanonicalFalse/generate-id() = generate-id(.) or self::title"><attribute name="canonical" select="'false'"/></if>
      <apply-templates/>
    </copy>
  </template>
  
  <!-- Remove x-introduction attribute as needed -->
  <template match="*[$removeIntroAttrib/generate-id()= generate-id(.)]/@subType"/>
  
</stylesheet>
