<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:oc="http://github.com/JohnAustinDev/osis-converters"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 exclude-result-prefixes="#all">
  
  <!-- By default copy everything as is -->
  <template match="node()|@*" name="identity" mode="#all">
    <copy><apply-templates select="node()|@*" mode="#current"/></copy>
  </template>
  
  <!-- Remove any externally added cross-reference notes which do not
  contain hyperlinks (other that annotateRef). These linkless cross-
  reference notes can occur when a translation includes a small number 
  of books. !-->
  <template match="note[@type='crossReference'][@resp][not(descendant::reference[@type!='annotateRef'][@osisRef])]"/>

</stylesheet>
