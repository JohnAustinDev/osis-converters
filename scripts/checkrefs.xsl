<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/checkrefs.xsl"
 exclude-result-prefixes="#all">
 
  <import href="./functions/functions.xsl"/>
  
  <param name="TMPDIR"/>
  
  <param name="versification"/>
  
  <output method="text"/>
  
  <key name="osisID" match="*[@osisID]" 
    use="for $i in tokenize(@osisID, '\s+') return replace($i, '^[^:]+:', '')"/>
  
  <variable name="VERSE_SYSTEM_DOC" select="if ($versification)
    then doc(concat($TMPDIR, '/versification/', $versification, '.xml')) else ()"/>
  
  <variable name="checkingDict" select="boolean($DICTMOD) and $DOCWORK = $DICTMOD"/>
    
  <variable name="scriptureRefs" as="element()*" select="//*[@osisRef][oc:isScripRef(@osisRef, $DOCWORK)]"/>
  
  <!-- Check all osisRefs in the OSIS file, however MAINMOD references 
  to a DICTMOD will only be checked when OSIS file is the DICTMOD,  
  because MAINMOD is assumed to be created before DICTMOD is created. -->
  <variable name="checkSelf" as="element()*" select="//*[@osisRef][not(@subType='x-external')]
    [$checkingDict or not($DICTMOD) or not(starts-with(@osisRef, $DICTMOD))]"/>
    
  <variable name="checkMain" as="element()*" select="$MAINMOD_DOC//*[@osisRef]
    [$checkingDict and starts-with(@osisRef, $DICTMOD)]"/>
  
  <!-- Just report results, no xml output -->
  <template match="/">
    <call-template name="Log">
      <with-param name="msg">
        <choose>
          <when test="$checkingDict">OSIS DICTMOD REFERENCES:</when>
          <otherwise>OSIS MAINMOD REFERENCES (EXCEPT THOSE TO DICTMOD):</otherwise>
        </choose>
      </with-param>
    </call-template>
  
    <!-- Duplicate osisIDs -->
    <variable name="all_osisIDs" as="xs:string*" select="//*[@osisID]/@osisID"/>
    <variable name="unique_osisIDs" as="xs:string*" select="distinct-values($all_osisIDs)"/>
    <if test="count($all_osisIDs) != count($unique_osisIDs)">
      <for-each-group select="$all_osisIDs" group-by=".">
        <if test="count(current-group()) &#62; 1">
          <call-template name="Error">
<with-param name="msg">osisID attribute value is not unique: <value-of select="."/></with-param>
<with-param name="exp">There are multiple elements with the same osisID, which is not allowed.</with-param>
          </call-template>
        </if>
      </for-each-group>
    </if>
    
    <!-- Bad osisRef values -->
    <for-each select="//reference[not(@osisRef) or not(normalize-space(@osisRef))]">
      <call-template name="Error">
<with-param name="msg">Reference link is missing an osisRef attribute: <value-of select="parent::*/string()"/></with-param>
<with-param name="exp">Maybe this should not be marked as a reference? 
Reference tags in OSIS require a valid target. When there isn't a valid 
target, then a different USFM tag should be used instead.</with-param>
      </call-template>
    </for-each>
    <for-each select="$scriptureRefs[contains(@osisRef, ' ')]">
      <call-template name="Error">
<with-param name="msg">A Scripture osisRef cannot have multiple targets: <value-of select="string()"/> osisRef="<value-of select="@osisRef"/>"</with-param>
<with-param name="exp">Use multiple reference elements instead.</with-param>
      </call-template>
    </for-each>
    <for-each select="$scriptureRefs[contains(@osisRef, '-')][not(matches(@osisRef, '^([^:]+:)?([^\.]+\.\d+)\.(\d+)\-(\2)\.(\d+)$'))]">
      <call-template name="Error">
<with-param name="msg">An osisRef to a range of Scripture should not exceed a chapter: <value-of select="@osisRef"/></with-param>
<with-param name="exp">Some software, like xulsword, does not support ranges that exceed a chapter.</with-param>
      </call-template>
    </for-each>
    
    <!-- Missing targets -->
    <variable name="missing" as="element()*">
      <for-each select="($MAINMOD_DOC | $DICTMOD_DOC)">
        <variable name="prefixRE" select="concat('^', //@osisIDWork[1], ':')"/>
        <sequence select="for $e in $checkSelf, $r in $e/me:osisRef_atoms(@osisRef)
            return if ( matches($r, $prefixRE) and 
                        not(key('osisID', replace($r, '^[^:]+:', '')))
                      ) then $e else ()"/>
      </for-each>
    </variable>
    <for-each select="$missing[normalize-space()]">
      <call-template name="Error">
<with-param name="msg">Reference target not found: <value-of select="string()"/> osisRef="<value-of select="@osisRef"/>"</with-param>
      </call-template>
    </for-each>
 
    <!-- Erroneous Scripture targets that are outside the verse system -->
    <for-each select="$VERSE_SYSTEM_DOC">
      <variable name="erref" select="for $e in $scriptureRefs, $r in $e/me:osisRef_atoms(@osisRef) 
        return if (not(key('osisID', replace($r, '^[^:]+:', ''))))
               then $e else ()"/>
      <for-each select="$erref">
        <call-template name="Error">
<with-param name="msg">Reference target is outside verse system: <value-of select="string()"/> osisRef="<value-of select="@osisRef"/>"</with-param>
        </call-template>
      </for-each>
    </for-each>
    
    <call-template name="Report">
<with-param name="msg">&#60;-Found "<value-of select="count(//*[@osisID])"/>" elements with osisIDs.</with-param>
    </call-template>
    
    <!-- glossary osisRefs checked -->
    <variable name="glossary_reference" select="$checkSelf[self::reference][starts-with(@type,'x-gloss')]"/>
    <if test="count($glossary_reference)">
      <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($glossary_reference)"/>" glossary osisRef attributes checked.</with-param>
      </call-template>
    </if>
    
    <!-- milestone osisRefs checked -->
    <variable name="milestone" select="$checkSelf[self::milestone]"/>
    <if test="count($milestone)">
      <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($milestone)"/>" milestone osisRef attributes checked.</with-param>
      </call-template>
    </if>
    
    <!-- note osisRefs checked -->
    <variable name="note" select="$checkSelf[self::note]"/>
    <if test="count($note)">
      <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($note)"/>" note osisRef attributes checked.</with-param>
      </call-template>
    </if>
    
    <!-- osisRefs to notes checked -->
    <variable name="note_reference" select="$checkSelf[self::reference][@type='x-note']"/>
    <if test="count($note_reference)">
      <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($note_reference)"/>" osisRefs to notes checked.</with-param>
      </call-template>
    </if>
    
    <!-- reference osisRefs checked -->
    <variable name="reference" select="$checkSelf[self::reference][not(starts-with(@type,'x-gloss'))][not(@type='x-note')]"/>
    <if test="count($reference)">
      <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($reference)"/>" reference osisRef attributes checked.</with-param>
      </call-template>
    </if>
    
    <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($checkSelf)"/>" Grand total osisRef attributes checked.</with-param>
    </call-template>
    
    <if test="$DOCWORK = $DICTMOD">
      <call-template name="Log">
<with-param name="msg">OSIS MAINMOD REFERENCES TO DICTMOD:</with-param>
      </call-template>
      
      <!-- MAIN reference to missing DICT targets -->
      <for-each select="$DICTMOD_DOC">
        <variable name="missing" select="for $e in $checkMain, $r in $e/me:osisRef_atoms(@osisRef) 
          return if (key('osisID', replace($r, '^[^:]+:', ''))) then () else $e"/>
        <for-each select="$missing[normalize-space()]">
          <call-template name="Error">
<with-param name="msg">Reference target not found: <value-of select="string()"/> osisRef="<value-of select="@osisRef"/>"</with-param>
          </call-template>
        </for-each>
      </for-each>
      
      <if test="count($checkMain)">
        <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($checkMain)"/>" main osisRef attributes to dict checked.</with-param>
        </call-template>
      </if>
    </if>
    
  </template>
  
  <!-- An osisRef value may contain multiple space separated segments, 
  including segments with ranges. This function returns separate
  prefixed osisRefs including the beginning and ending of each range. -->
  <function name="me:osisRef_atoms" as="xs:string*">
    <param name="osisRef" as="xs:string"/>
    <for-each select="tokenize($osisRef, '\s+')">
      <variable name="work" select="if (tokenize(., ':')[2]) then tokenize(., ':')[1] else $DOCWORK"/>
      <variable name="ref" select="if (tokenize(., ':')[2]) then tokenize(., ':')[2] else ."/>
      <for-each select="tokenize($ref, '-')">
        <value-of select="concat($work, ':', .)"/>
      </for-each>
    </for-each>
  </function>
  
</stylesheet>
