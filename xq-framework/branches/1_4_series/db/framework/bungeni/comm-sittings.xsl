<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xhtml="http://www.w3.org/1999/xhtml" xmlns:an="http://www.akomantoso.org/1.0" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:bu="http://portal.bungeni.org/1.0/" exclude-result-prefixes="xs" version="2.0">
    <xd:doc xmlns:xd="http://www.oxygenxml.com/ns/doc/xsl" scope="stylesheet">
        <xd:desc>
            <xd:p>
                <xd:b>Created on:</xd:b> Nov 16, 2011</xd:p>
            <xd:p>
                <xd:b>Author:</xd:b> anthony</xd:p>
            <xd:p> Committee item from Bungeni</xd:p>
        </xd:desc>
    </xd:doc>
    <xsl:output method="xml"/>
    <xsl:include href="context_tabs.xsl"/>
    <xsl:template match="assigned-items">
        <xsl:variable name="doc-type" select="group/bu:ontology/@type"/>
        <xsl:variable name="doc_uri" select="group/bu:ontology/bu:group/@uri"/>
        <div id="main-wrapper">
            <div id="title-holder" class="theme-lev-1-only">
                <h1 id="doc-title-blue">
                    <xsl:value-of select="group/bu:ontology/bu:legislature/bu:fullName"/>
                </h1>
            </div>
            <xsl:call-template name="doc-tabs">
                <xsl:with-param name="tab-group">
                    <xsl:value-of select="$doc-type"/>
                </xsl:with-param>
                <xsl:with-param name="uri">
                    <xsl:value-of select="$doc_uri"/>
                </xsl:with-param>
                <xsl:with-param name="tab-path">sittings</xsl:with-param>
            </xsl:call-template>
            <div id="doc-downloads">
                <ul class="ls-downloads">
                    <li>
                        <a href="#" title="get as RSS feed" class="rss">
                            <em>RSS</em>
                        </a>
                    </li>
                    <li>
                        <a href="#" title="print this document" class="print">
                            <em>PRINT</em>
                        </a>
                    </li>
                    <li>
                        <a href="#" title="get as ODT document" class="odt">
                            <em>ODT</em>
                        </a>
                    </li>
                    <li>
                        <a href="#" title="get as RTF document" class="rtf">
                            <em>RTF</em>
                        </a>
                    </li>
                    <li>
                        <a href="#" title="get as PDF document" class="pdf">
                            <em>PDF</em>
                        </a>
                    </li>
                </ul>
            </div>
            <div id="main-doc" class="rounded-eigh tab_container" role="main">
                <div id="doc-main-section">
                    <div style="width:90%;margin: 0 auto;text-align:center">
                        <table class="tbl-tgl">
                            <tr>
                                <td class="fbtd">item</td>
                                <td class="fbtd">start date</td>
                                <td class="fbtd">end date</td>
                                <td class="fbtd">due date</td>
                            </tr>
                            <xsl:for-each select="items/bu:ontology">
                                <tr class="items">
                                    <td class="fbt bclr" style="text-align-left;">
                                        <a href="{bu:document/@type}/text?uri={bu:legislativeItem/@uri}">
                                            <xsl:value-of select="bu:legislativeItem/bu:shortName"/>
                                        </a>
                                    </td>
                                    <td class="fbt bclr">None</td>
                                    <td class="fbt bclr">
                                        <xsl:value-of select="format-date(bu:legislativeItem/bu:publicationDate,$date-format,'en',(),())"/>
                                    </td>
                                    <td class="fbt bclr">None</td>
                                </tr>
                            </xsl:for-each>
                        </table>
                    </div>
                </div>
            </div>
        </div>
    </xsl:template>
</xsl:stylesheet>