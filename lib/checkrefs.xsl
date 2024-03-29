<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:me="http://github.com/JohnAustinDev/osis-converters/lib/checkrefs.xsl"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 xmlns:sx="http://saxon.sf.net/"
 xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
 exclude-result-prefixes="#all">
 
  <import href="./common/functions.xsl"/>
  
  <param name="TMPDIR"/>
  
  <param name="versification"/>
  
  <output method="text"/>
  
  <variable name="VERSE_SYSTEM_DOC" select="if ($versification)
    then doc(concat($TMPDIR, '/versification/', $versification, '.xml')) else ()"/>
  
  <variable name="checkingDict" select="boolean($DICTMOD) and $DOCWORK = $DICTMOD"/>
    
  <variable name="scriptureRefs" as="element()*" select="//*[@osisRef][oc:isScripRef(@osisRef, $DOCWORK)]"/>
  
  <!-- Check all osisRefs in the OSIS file, however MAINMOD references 
  to a DICTMOD will only be checked at the time DICTMOD is checked,  
  meaning MAINMOD must be created before DICTMOD. -->
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
  
    <!-- Check for duplicate osisIDs -->
    <for-each select="//*[@osisID][(for $i in tokenize(@osisID, '\s+') return count(key('osisID', $i))) != 1]">
      <call-template name="Error">
<with-param name="msg">osisID is not unique: <value-of select="@osisID"/></with-param>
<with-param name="exp">There are multiple elements with the same osisID, which is not allowed.</with-param>
      </call-template>
    </for-each>
    
    <!-- Check for bad osisRef values -->
    <for-each select="//reference[not(@osisRef) or not(normalize-space(@osisRef))]">
      <call-template name="Error">
<with-param name="msg">Reference link on line <value-of select="sx:line-number(.)"/> is missing an osisRef attribute: <value-of select="parent::*/string()"/></with-param>
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

    <!-- Check for osisRef target existence -->
    <variable name="missing" as="xs:string*">
      <for-each select="($MAINMOD_DOC | $DICTMOD_DOC)">
        <variable name="prefixRE" select="concat('^', //@osisIDWork[1], ':')"/>
        <!-- Ignore !PART endings of osisRefs even though that osisID does not exist -->
        <sequence select="for $e in $checkSelf, $r in $e/oc:osisRef_atoms(@osisRef)
            return if ( matches($r, $prefixRE) and 
                        not(key('osisID', replace(oc:ref($r), '!PART$', '')))
                      ) then $r else ()"/>
      </for-each>
    </variable>
    <for-each select="$missing[normalize-space()]">
      <call-template name="Error">
<with-param name="msg"><value-of select="$DOCWORK"/> reference to missing osisRef segment "<value-of select="."/>"</with-param>
      </call-template>
    </for-each>
    
    <!-- Check for aggregated glossary entries that are being referenced -->
    <sequence select="me:doAggregateCheck($MAINMOD_DOC)"/>
    <sequence select="me:doAggregateCheck($DICTMOD_DOC)"/>
    
    <!-- Check for Scripture targets that are outside the verse system -->
    <for-each select="$VERSE_SYSTEM_DOC">
      <variable name="erref" select="for $e in $scriptureRefs, $r in $e/oc:osisRef_atoms(@osisRef) 
        return if (not(key('osisID', replace($r, '^[^:]+:', ''))))
               then $e else ()"/>
      <for-each select="$erref">
        <call-template name="Error">
<with-param name="msg">Reference target is outside verse system: <value-of select="string()"/> osisRef="<value-of select="@osisRef"/>"</with-param>
        </call-template>
      </for-each>
    </for-each>
    
    <!-- Report number of elements with osisIDs-->
    <call-template name="Report">
<with-param name="msg">&#60;-Found "<value-of select="count(//*[@osisID])"/>" elements with osisIDs.</with-param>
    </call-template>
    
    <!-- Report number of glossary osisRefs -->
    <variable name="glossary_reference" select="$checkSelf[self::reference][starts-with(@type,'x-gloss')]"/>
    <if test="count($glossary_reference)">
      <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($glossary_reference)"/>" glossary osisRef attributes checked.</with-param>
      </call-template>
    </if>
    
    <!-- Report number of milestone osisRefs -->
    <variable name="milestone" select="$checkSelf[self::milestone]"/>
    <if test="count($milestone)">
      <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($milestone)"/>" milestone osisRef attributes checked.</with-param>
      </call-template>
    </if>
    
    <!-- Report number of note osisRefs -->
    <variable name="note" select="$checkSelf[self::note]"/>
    <if test="count($note)">
      <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($note)"/>" note osisRef attributes checked.</with-param>
      </call-template>
    </if>
    
    <!-- Report number of osisRefs to notes -->
    <variable name="note_reference" select="$checkSelf[self::reference][@type='x-note']"/>
    <if test="count($note_reference)">
      <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($note_reference)"/>" osisRefs to notes checked.</with-param>
      </call-template>
    </if>
    
    <!-- Report number of reference osisRefs -->
    <variable name="reference" select="$checkSelf[self::reference][not(starts-with(@type,'x-gloss'))][not(@type='x-note')]"/>
    <if test="count($reference)">
      <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($reference)"/>" reference osisRef attributes checked.</with-param>
      </call-template>
    </if>
    
    <!-- Report total number of osisRefs -->
    <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($checkSelf)"/>" Grand total osisRef attributes checked.</with-param>
    </call-template>
    
    <!-- Check MAIN references to DICT targets -->
    <if test="$DOCWORK = $DICTMOD">
      <call-template name="Log">
<with-param name="msg">OSIS MAINMOD REFERENCES TO DICTMOD:</with-param>
      </call-template>
      <for-each select="$DICTMOD_DOC">
        <!-- Ignore !PART endings of osisRefs even though that osisID does not exist -->
        <variable name="missing" select="for $e in $checkMain, $r in $e/oc:osisRef_atoms(@osisRef) 
          return if (key('osisID', replace(replace($r, '^[^:]+:', ''), '!PART$', ''))) then () else $r" as="xs:string*"/>
        <for-each select="$missing[normalize-space()]">
          <call-template name="Error">
<with-param name="msg"><value-of select="$MAINMOD"/> reference to missing DICTMOD osisRef segment "<value-of select="."/>"</with-param>
          </call-template>
        </for-each>
      </for-each>
      
      <!-- Report number of MAIN references to DICT -->
      <if test="count($checkMain)">
        <call-template name="Report">
<with-param name="msg">&#60;-"<value-of select="count($checkMain)"/>" main osisRef attributes to dict checked.</with-param>
        </call-template>
      </if>
    </if>
    
  </template>
  
  <function name="me:doAggregateCheck">
    <param name="doc" as="document-node()?"/>
    <choose>
      <when test="not($doc)"><sequence select="()"/></when>
      <otherwise>
      <variable name="aggcheck" select="$doc//@osisRef
          [not(ancestor::*[@resp='x-oc'])]" as="xs:string*"/>
        <variable name="aggcheckFail" as="xs:string*">
          <for-each select="$DICTMOD_DOC">
            <sequence select="for $e in $aggcheck, $r in oc:osisRef_atoms($e)
                  return if ( (key('osisID', oc:ref($r))/ancestor::div
                              [@type='glossary'][@subType='x-aggregate'] )
                            ) then $r else ()"/>
          </for-each>
        </variable>
        <for-each select="distinct-values($aggcheckFail)">
          <call-template name="Error">
<with-param name="msg">Found reference(s) in <value-of select="$doc//@osisIDWork[1]"/> to aggregated glossary entry: <value-of select="concat($DICTMOD_DOC//@osisIDWork[1], ':', oc:ref(.))"/></with-param>
<with-param name="exp">Aggregated glossary entries should not be referenced directly; individual members should be referenced. Check CF_addDictLinks.xml or add 'x-context' or 'x-dup' USFM attribute to the \w \w* tag.</with-param>
          </call-template>
        </for-each>
      </otherwise>
    </choose>
  </function>
  
</stylesheet>
