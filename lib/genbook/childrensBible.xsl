<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
  
  <!-- This stylesheet converts usfm2osis.py osis into osis-
  converters Children's Bible osis markup -->
 
  <import href="../common/functions.xsl"/>
  
  <!-- Use \toc1, \toc2 or \toc3 tags for creating the TOC -->
  <param name="TOC" select="oc:conf('TOC', /)"/>
  
  <variable name="chapterID_RE" select="'^X\-OTHER\.[/\d\-]+$'"/>
  <variable name="danglingTextNode_RE" select="'^\s*(\d+(\-text)?)\s*$'"/>
  
  <template mode="#all" match="node()|@*" name="identity">
    <copy><apply-templates mode="#current" select="node()|@*"/></copy>
  </template>
 
  <template match="/">
    <!-- Re-section the entire OSIS file by removing all divs, then using
    toc milestones and chapter osisIDs to re-structure with new divs-->
    <variable name="pass1"><apply-templates mode="fixChapterIDs" select="."/></variable>
    <variable name="pass2"><apply-templates mode="removeAllDivs" select="$pass1/node()"/></variable>
    <variable name="pass3"><apply-templates mode="resection" select="$pass2/node()"/></variable>
    <apply-templates mode="final" select="$pass3/node()"/>
  </template>
  
  <!-- sfm like: '\c 14/10 015' renders as: '<chapter osisID="X-OTHER.14/10" sID="X-OTHER.14/10"/> 015' 
  So normalize the chapter osisID and remove the dangling text node. -->
  <template mode="fixChapterIDs" match="chapter[matches(@osisID, $chapterID_RE)]">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <variable name="danglingTextNode" select="following-sibling::text()
        [ . &#60;&#60; current()/following::node()[not(self::text())][1] ]
        [matches(., $danglingTextNode_RE)]"/>
      <if test="$danglingTextNode">
        <attribute name="osisID" 
          select="concat('X-OTHER.', replace($danglingTextNode, $danglingTextNode_RE, '$1'))"/>
      </if>
    </copy>
  </template>
  <template mode="fixChapterIDs" match="text()[matches(., $danglingTextNode_RE)]">
    <variable name="chapter" select="preceding-sibling::chapter[1]"/>
    <variable name="danglingTextNode" select="$chapter/following-sibling::text()
        [ . &#60;&#60; $chapter/following::node()[not(self::text())][1] ]
        [matches(., $danglingTextNode_RE)]"/>
    <if test="not(. intersect $danglingTextNode)">
      <next-match/>
    </if>
  </template>
  
  <template mode="removeAllDivs" match="div"><apply-templates mode="#current"/></template>
  
  <template mode="resection" match="osisText">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <for-each select="header">
        <apply-templates mode="#current" select="."/>
      </for-each>
      <osis:div type="book" osisID="{ oc:encodeOsisRef(/osis/osisText/header/work
          [@osisWork = /osis/osisText/@osisIDWork]/title/string()) }">
        <for-each-group select="node()[not(self::header)][not(self::comment())]"
            group-adjacent="count(preceding::milestone[@type=concat('x-usfm-toc', $TOC)]) + 
                            count(self::milestone[@type=concat('x-usfm-toc', $TOC)])">
          <variable name="id" select="if (current-group()[self::*][1][@n][self::milestone[@type=concat('x-usfm-toc', $TOC)]]) 
                                      then current-group()[self::*][1]/@n else 'noName'"/>
          <choose>
            <when test="$id = 'noName' and current-group()[normalize-space()]">
              <call-template name="Error">
<with-param name="msg">Children's Bible sections that contain text must begin with a milestone TOC to supply a name.</with-param>
<with-param name="exp">The section which starts with node: '<value-of select="oc:printNode(current-group()[normalize-space()][1])"/>' should begin with USFM like: \toc2 Section Name</with-param>
              </call-template>
            </when>
            <when test="$id = 'noName' and not(current-group()[normalize-space()])">
              <apply-templates mode="#current" select="current-group()"/>
            </when>
            <otherwise>
              <osis:div type="majorSection" osisID="{oc:encodeOsisRef($id)}">
                <apply-templates mode="#current" select="current-group()"/>
              </osis:div>
            </otherwise>
          </choose>
        </for-each-group>
      </osis:div>
    </copy>
  </template>
  
  <!-- Add a main TOC milestone -->
  <template mode="final" match="div[@type='book'][not(preceding::div)]">
    <variable name="title" select="root()//work[@osisWork=$MAINMOD]/title[1]/string()"/>
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <osis:milestone type="x-usfm-toc{$TOC}" n="[level1]{$title}" osisID="BIBLE_TOP" resp="x-oc"/>
      <apply-templates mode="#current"/>
    </copy>
  </template>
  
  <!-- Specify explicit [levelN] TOC levels -->
  <template mode="final" match="milestone[@type=concat('x-usfm-toc', $TOC)]/@n">
    <attribute name="n" select="concat('[level', (count(ancestor-or-self::div[@type=('book','majorSection','chapter')])-1), ']', .)"/>
  </template>
  
  <!-- Convert chapter @osisID milestone tags into div[@type='chapter'] containers -->
  <template mode="final" match="*[child::chapter[@osisID]]">
    <copy>
      <apply-templates mode="#current" select="@*"/>
      <for-each-group select="node()" 
          group-adjacent="count(preceding-sibling::chapter[@osisID]) + 
                          count(self::chapter[@osisID])">
        <choose>
          <when test="current-grouping-key() = 0">
            <apply-templates mode="#current" select="current-group()"/>
          </when>
          <otherwise>
            <variable name="title">
              <variable name="myChapterLabel" as="element(title)?" 
                  select="current-group()[1]/following::*[1][self::title[@type='x-chapterLabel']]"/>
              <choose>
                <when test="$myChapterLabel">
                  <value-of select="$myChapterLabel"/>
                </when>
                <otherwise>
                  <value-of select="@osisID"/>
                  <call-template name="Error">
<with-param name="msg">No Chapter label for chapter osisID="<value-of select="current-group()[1]/@osisID"/>".</with-param>
<with-param name="exp">All Children's Bible chapter start milestone tags must be followed by a title of type="x-chapterLabel".</with-param>
                  </call-template>
                </otherwise>
              </choose>
            </variable>
            
            <osis:div type="chapter">
              <variable name="osisID" select="
                if (count(preceding::title[@type='x-chapterLabel'][string() = $title/string()]) = 0)
                then $title 
                else concat($title, ' (',1+count(preceding::title[@type='x-chapterLabel'][string() = $title/string()]),')')"/>
              <if test="$title != $osisID">
                <call-template name="Warn">
<with-param name="msg" select="concat('Changing title &quot;', $title, '&quot; to &quot;', $osisID, '&quot; to prevent duplicate titles.')"/>
<with-param name="exp">If this title is followed immediately by another title, they should probably be merged into a single title.</with-param>
                </call-template>
              </if>
              <attribute name="osisID" select="oc:encodeOsisRef($osisID)"/>
              <osis:milestone type="{concat('x-usfm-toc', $TOC)}" n="[level2]{$title}"/>
              <apply-templates mode="#current" select="current-group()"/>
            </osis:div>
            
          </otherwise>
        </choose>
      </for-each-group>
    </copy>
  </template>
  <template mode="final" match="chapter"/>
  
  <!-- Remove verse tags -->
  <template mode="final" match="verse"/>
  
  <!-- Add a figure element after each chapterLabel of chapters with 
  numbered @osisIDs (unless there already is a figure element) -->
  <template mode="final" match="title[@type = 'x-chapterLabel']">
    <copy>
      <apply-templates mode="#current" select="node()|@*"/>
    </copy>
    
    <variable name="chapid" select="preceding-sibling::*[1][self::chapter]/@osisID"/>
    <variable name="image" as="xs:string">
      <choose>
        <when test="matches($chapid, '^X\-OTHER\.\d+$')">
          <variable name="imgnum">
            <value-of select="replace($chapid, '^X\-OTHER\.(\d+)$', '$1')"/>
          </variable>
          <value-of select="format-number(xs:integer(number($imgnum)), '000')"/>
        </when>
        <when test="matches($chapid, '^X\-OTHER\.\d+\-text$')">
          <value-of select="replace($chapid, '^X\-OTHER\.(\d+\-text)$', '$1')"/>
        </when>
        <otherwise>
          <value-of select="''"/>
        </otherwise>
      </choose>
    </variable>
    
    <if test="$image and not(following-sibling::*[1][self::figure])">
      <osis:figure subType="x-text-image" src="./images/{$image}.jpg"></osis:figure>
    </if>
    
  </template>
  <template mode="final" match="title/@type[. = 'x-chapterLabel']"/>
  
  <!-- Add the osis-converters Children's Bible CSS classes: x-ref-cb, 
  x-text-image and x-p-first -->
  <template mode="final" match="title[@type = 'parallel'][count(@*) = 1]">
    <osis:title type="parallel" level="2" subType="x-right">
      <osis:hi type="italic">
        <attribute name="subType">x-ref-cb</attribute>
        <apply-templates mode="#current" select="node()"/>
      </osis:hi>
    </osis:title>
  </template>

  <template mode="final" match="figure[@src][@size = 'col']">
    <osis:figure subType="x-text-image">
      <apply-templates mode="#current" select="node()|@*"/>
    </osis:figure>
  </template>

  <template mode="final" match="p | lg">
    <copy>
      <if test="boolean(ancestor::div[@type='book']/div[@type='majorSection'][position()=(2,3)]
                intersect ancestor::div[@type='majorSection'])
            and
                boolean(descendant::text()[normalize-space()][1] intersect 
                preceding::chapter[@osisID][1]/following::text()
                [normalize-space()][not(ancestor::title)][not(ancestor::figure)][1])">
        <attribute name="subType">x-p-first</attribute>
      </if>
      <apply-templates mode="#current" select="node()|@*"/>
    </copy>
  </template>
  
  <!-- Make line groups indented -->
  <template mode="final" match="l[@level = '1']">
    <copy>
      <attribute name="type">x-indent</attribute>
      <apply-templates mode="#current" select="node()|@*"/>
    </copy>
  </template>
  
  <!-- Remove soft-hyphens from chapter names (osisIDs) -->
  <template mode="final" match="div[@osisID]/@osisID">
    <copy>
      <value-of select="replace(., codepoints-to-string(173), '')"/>
    </copy>
  </template>

</stylesheet>
