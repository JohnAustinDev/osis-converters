<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
 
  <!-- Prepare osis-converters OSIS for use with html & ebook ePublications -->
  
  <include href="./functions.xsl"/>
  
  <!-- Filter out any marked elements which are not intended for this conversion -->
  <include href="./conversion.xsl"/>
  
  <!-- Use the source (translator's custom) verse system -->
  <include href="./osis2sourceVerseSystem.xsl"/>
  
  <!-- References to these navmenu keywords may have been written by navigationMenu.xsl -->
  <param name="uiIntroduction" select="oc:sarg('uiIntroduction', /, concat('-- ', //header/work[child::type[@type='x-bible']]/title[1]))"/>
  <param name="uiDictionary" select="oc:sarg('uiDictionary', /, concat('- ', //header/work[child::type[@type='x-glossary']]/title[1]))"/>
  
  <variable name="isBible" select="/osis/osisText/header/work[@osisWork = /osis/osisText/@osisIDWork]/type[@type='x-bible']"/>
  <variable name="biblemod" select="/osis/osisText/header/work[child::type[@type='x-bible']]/@osisWork"/>
  <variable name="dictmod" select="/osis/osisText/header/work[child::type[@type='x-glossary']]/@osisWork"/>
  
  <!-- Remove any duplicate material in the dictionary which is also included in the Bible module -->
  <template match="div[not($isBible)][@annotateType='x-feature'][@annotateRef='INT']"/>
  
  <!-- eBooks filter out all navmenus -->
  <template match="list[$conversion = 'epub'][@subType='x-navmenu']"/>
  
  <!-- eBooks don't use the NAVMENU glossary -->
  <template match="div[$conversion = 'epub'][@scope='NAVMENU']"/>
  
  <!-- Forward NAVMENU top links -->
  <template match="reference[@osisRef=concat($dictmod, ':', oc:encodeOsisRef($uiIntroduction))]/@osisRef">
    <attribute name="osisRef" select="concat($biblemod,':','BIBLE_TOP')"/>
  </template>
  <template match="reference[@osisRef=concat($dictmod, ':', oc:encodeOsisRef($uiDictionary))]/@osisRef">
    <attribute name="osisRef" select="concat($dictmod,':','DICT_TOP')"/>
  </template>

</stylesheet>
