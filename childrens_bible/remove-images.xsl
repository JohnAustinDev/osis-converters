<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
 xmlns:osis="http://www.bibletechnologies.net/2003/OSIS/namespace">

 <!-- Remove all images and figures for use with Childrens Bible SWORD modules !-->
  
  <xsl:template match="node()|@*" name="identity">
    <xsl:copy>
       <xsl:apply-templates select="node()|@*"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="osis:figure"/>

</xsl:stylesheet>
