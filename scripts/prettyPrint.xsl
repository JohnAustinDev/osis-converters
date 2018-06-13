<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0"
 xpath-default-namespace="http://www.bibletechnologies.net/2003/OSIS/namespace"
 xmlns="http://www.w3.org/1999/XSL/Transform"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <output method="xml" version="1.0" encoding="utf-8" omit-xml-declaration="no" indent="yes"/>
  
  <template match="node()|@*">
    <copy><apply-templates select="node()|@*"/></copy>
  </template>
  
</stylesheet>
