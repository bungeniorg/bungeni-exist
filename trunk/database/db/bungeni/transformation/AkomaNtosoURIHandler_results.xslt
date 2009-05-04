<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:an="http://www.akomantoso.org/1.0" xmlns:handler="http://exist.bungeni.org/query/AkomaNtosoURIHandler" version="2.0">
    <!--
        Copyright  Adam Retter 2008 <adam.retter@googlemail.com>
        
        Akoma Ntoso URI Handler Results Transformation for XML 1.0 to XHTML 1.1
        
        Author: Adam Retter
        Version: 1.0
    --><xsl:output encoding="UTF-8" doctype-public="-//W3C//DTD XHTML 1.1//EN" doctype-system="http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd" indent="yes" omit-xml-declaration="no" method="xhtml" media-type="text/html"/><xsl:include href="error.xslt"/><xsl:template match="handler:results"><html xml:lang="eng" lang="eng"><head><title>Akoma Ntoso Results</title></head><body><h1>Results</h1><xsl:apply-templates/></body></html></xsl:template><xsl:template match="an:akomantoso"><div class="result"><xsl:apply-templates/></div></xsl:template><xsl:template match="an:act | an:bill | an:debaterecord | an:minutes | an:tabled"><div class="{local-name(.)}"><xsl:apply-templates/><p>Date: <xsl:value-of select="an:meta/an:identification//an:date/@date"/></p><a href="{an:meta/an:identification//an:uri/@href}">Open the <xsl:value-of select="local-name(an:meta/an:identification/child::element())"/> of the <xsl:value-of select="local-name(.)"/></a></div></xsl:template><xsl:template match="an:preface"><xsl:apply-templates/></xsl:template><xsl:template match="an:p"><xsl:apply-templates/></xsl:template><xsl:template match="an:ActTitle"><h2><xsl:value-of select="."/></h2></xsl:template><xsl:template match="an:ActPurpose"><p class="purpose"><xsl:value-of select="."/></p></xsl:template></xsl:stylesheet>