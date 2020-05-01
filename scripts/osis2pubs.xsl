<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- Prepare osis-converters OSIS for use with html & ebook ePublications -->
  
  <!-- Use the source (translator's custom) verse system -->
  <include href="./osis2sourceVerseSystem.xsl"/>
  
  <!-- Filter out any marked elements which are not intended for this conversion -->
  <include href="./conversion.xsl"/>
  
  <!-- Remove all navmenu link lists, which are custom-created as needed -->
  <template match="list[@subType='x-navmenu']"/>
  
  <!-- Remove all NAVMENUs, which are custom-created as needed -->
  <variable name="removeNAVMENU" select="//div[@scope='NAVMENU']"/>
  <template match="div[. intersect $removeNAVMENU]"/>
  
  <!-- Remove references that target the removed NAVMENUs -->
  <variable name="removedNAVMENU_ids" as="xs:string*" 
      select="($MAINMOD_DOC/descendant::*[@osisID][ancestor::div[@scope='NAVMENU']]
              /oc:osisRef(@osisID, $MAINMOD)), 
              ($DICTMOD_DOC/descendant::*[@osisID][ancestor::div[@scope='NAVMENU']]
              /oc:osisRef(@osisID, $DICTMOD))"/>
  <template match="@osisRef" priority="99">
    <variable name="conversion"><!-- conversion.xsl -->
      <oc:tmp><next-match/></oc:tmp>
    </variable>
    <attribute name="osisRef" 
        select="oc:filter_osisRef($conversion/*/@osisRef, true(), $removedNAVMENU_ids)"/>
  </template>
  
  <!-- Report results -->
  <template match="/" priority="39">
  
    <call-template name="Note">
<with-param name="msg">Running osis2pubs.xsl</with-param>
    </call-template>
    
    <if test="$removeNAVMENU">
      <call-template name="Note">
<with-param name="msg">Removed <value-of select="count($removeNAVMENU)"/> NAVMENU div(s).</with-param>
      </call-template>
    </if>
    
    <next-match/>
  </template>
  
</stylesheet>
