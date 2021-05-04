<?xml version="1.0" encoding="UTF-8" ?>
<!--
This file is part of "osis-converters".

Copyright 2021 John Austin (gpl.programs.info@gmail.com)
    
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
 
  <!-- Convert chapter and verse milestones to container elements. To 
  make this conversion possible, section div tags are removed, while
  p, lg and l are converted to milestone. -->
  
  <import href="../common/functions.xsl"/>
  
  <import href="../sourceVerseSystem.xsl"/>

  <template match="/"><call-template name="containers.xsl"/></template>
  
  <template mode="containers.xsl" match="/" name="containers.xsl">
    <message>NOTE: Running containers.xsl</message>
    
    <variable name="sourceVerseSystem">
      <apply-templates mode="sourceVerseSystem.xsl" select="."/>
    </variable>
    
    <!-- Remove section divs and other overlapping container tags -->
    <variable name="sections">
      <apply-templates mode="sections" select="$sourceVerseSystem"/>
    </variable>
    
    <!-- Put chapter contents into chapter containers -->
    <variable name="containers">
      <apply-templates mode="containers" select="$sections"/>
    </variable>
    
    <sequence select="$containers"/>
  </template>
  
  <!-- By default copy everything as is -->
  <template mode="#all" match="node()|@*">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
  
  <template mode="sections" match="div[contains(@type, 'ection')][ancestor::div[@type='book']]">
    <apply-templates mode="#current"/>
  </template>
  
  <template mode="sections" match="p[ancestor::div[@type='book']] | 
                                  lg[ancestor::div[@type='book']] | 
                                   l[ancestor::div[@type='book']]">
    <element name="milestone" 
        namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
      <attribute name="resp" select="concat(local-name(), '-start')"/>
      <apply-templates mode="#current" select="@*"/>
    </element>
    <apply-templates mode="#current"/>
    <element name="milestone" 
        namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
      <attribute name="resp" select="concat(local-name(), '-end')"/>
      <apply-templates mode="#current" select="@*"/>
    </element>
  </template>
  
  <template mode="containers" match="div[@type='book']">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <variable name="bookChildren">
        <for-each select="node()">
          <sequence select="oc:expelElements(., ./descendant::chapter, false())"/>
        </for-each>
      </variable>
      <for-each-group select="$bookChildren/node()" group-starting-with="chapter[@sID]">
        <choose>
          <when test="position() = 1 and name(current()) != 'chapter'">
            <apply-templates mode="#current" select="current-group()"/>
          </when>
          <otherwise>
            <element name="chapter" 
                namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
              <apply-templates mode="#current" select="current()/@*[not(name() = 'sID')]"/>
              <variable name="chapterChildren">
                <for-each select="current-group()[not(self::chapter)]">
                  <sequence select="oc:expelElements(., ./descendant::verse, false())"/>
                </for-each>
              </variable>
              <for-each-group select="$chapterChildren/node()" group-starting-with="verse[@sID]">
                <choose>
                  <when test="position() = 1 and name(current()) != 'verse'">
                    <apply-templates mode="#current" select="current-group()"/>
                  </when>
                  <otherwise>
                    <element name="verse" 
                        namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
                      <apply-templates mode="#current" select="current()/@*[not(name() = 'sID')]"/>
                      <apply-templates mode="#current" select="current-group()[not(self::verse)]"/>
                    </element>
                  </otherwise>
                </choose>
              </for-each-group>
            </element>
          </otherwise>
        </choose>
      </for-each-group>
    </copy>
  </template>
 
 </stylesheet>
