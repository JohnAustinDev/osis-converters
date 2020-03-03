<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:xs="http://www.w3.org/2001/XMLSchema"
 exclude-result-prefixes="#all">
 
  <!-- Prepare osis-converters OSIS for use with html & ebook ePublications -->
  
  <!-- Filter out any marked elements which are not intended for this conversion -->
  <include href="./conversion.xsl"/>
  
  <!-- Use the source (translator's custom) verse system -->
  <include href="./osis2sourceVerseSystem.xsl"/>
  
  <variable name="isDict" select="/osis/osisText/header/work[@osisWork = /osis/osisText/@osisIDWork]/type[@type='x-glossary']"/>
  
  <template match="/">
    <call-template name="Note"><with-param name="msg">Running osis2pubs.xsl</with-param></call-template>
    <next-match/>
  </template>
  
  <!-- Remove all navmenu link lists, which are custom-created as needed -->
  <template match="list[@subType='x-navmenu']"/>
  
  <!-- Remove all NAVMENUs, which are custom-created as needed -->
  <template match="div[@scope='NAVMENU']"/>
  
  <!-- Check for references that target removed NAVMENU divs -->
  <variable name="myRemovedOsisIDs" as="xs:string" select="string-join(
    ($DICTMOD_DOC | $MAINMOD_DOC)/descendant::*[@osisID]
    [ancestor::div[@scope='NAVMENU']]/
    @osisID/concat(oc:myWork(.),':',replace(.,'^[^:]*:','')), ' ')"/>
  <template match="reference[not(ancestor::*[starts-with(@subType,'x-navmenu')])]
                   [tokenize(@osisRef, '\s+') = tokenize($myRemovedOsisIDs, '\s+')]/@osisRef">
    <attribute name="osisRef" select="oc:trimOsisRef(., $myRemovedOsisIDs)"/>
  </template>
  
</stylesheet>
