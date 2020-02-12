<?xml version="1.0" encoding="UTF-8" ?>
<stylesheet version="2.0" xmlns="http://www.w3.org/1999/XSL/Transform">
 
 <!-- Remove unnecessary osis prefixes -->
 <template match="node()|@*"><copy><apply-templates select="node()|@*"/></copy></template>
 <template match="*[namespace-uri()='http://www.bibletechnologies.net/2003/OSIS/namespace']" priority="1">
  <element name="{local-name()}" namespace="http://www.bibletechnologies.net/2003/OSIS/namespace">
    <apply-templates select="node()|@*"/>
  </element>
 </template>
  
</stylesheet>
