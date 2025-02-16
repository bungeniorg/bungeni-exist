xquery version "1.0";

import module namespace adm = "http://exist.bungeni.org/adm" at "admin.xqm";

(:
Order Editor container XForm
:)
declare namespace request = "http://exist-db.org/xquery/request";
declare namespace util="http://exist-db.org/xquery/util";
declare namespace bu="http://portal.bungeni.org/1.0/";
declare option exist:serialize "method=xhtml media-type=text/html indent=no";

<html xmlns="http://www.w3.org/1999/xhtml" 
    xmlns:i18n="http://exist-db.org/xquery/i18n" 
    xmlns:xhtml="http://www.w3.org/1999/xhtml" 
    xmlns:xlink="http://www.w3.org/1999/xlink" 
    xmlns:ev="http://www.w3.org/2001/xml-events" 
    xmlns:xsd="http://www.w3.org/2001/XMLSchema" 
    xmlns:bf="http://betterform.sourceforge.net/xforms" 
    xmlns:xf="http://www.w3.org/2002/xforms"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <head>
        <title>Navigation Preferences</title>
        <meta name="author" content="aowino at googlemail.com"/>
        <meta name="author" content="ashok at parliaments.info"/>
        <meta name="description" content="XForms with config options"/>
        <link rel="stylesheet" href="../../assets/admin/style.css"/>
    </head>
<body>
 <div id="xforms">
    <div style="display:none">
       <!-- 
        "master" model used by the subform
        -->
        <xf:model id="master">
            <xf:instance xmlns="" id="ui-config" src="../ui-config.xml" />
    
             <xf:submission id="save-form" 
                replace="none" 
                resource="../ui-config.xml" 
                method="put">
             </xf:submission>
             
        </xf:model>
    </div>
    <!-- MAIN MENU -->
    <div class="section" id="mainnav">{adm:main-menu('tabgroup')}</div>
    <div class="section" dojotype="dijit.layout.ContentPane">
        <!-- 
            unload the subform, we may have to call this explicitly
            on switching rows in the repeater -->
        <xf:action ev:event="unload-subforms">
            <xf:load show="none" targetid="orderby"/>
        </xf:action>
        
        <div class="headline">Navigation Configurations</div>
        <div class="description">
            <p>Edit the Navigation configurations</p>
        </div>


        <div class="section" dojotype="dijit.layout.ContentPane">
            <xf:group appearance="compact" id="ui-config" class="uiConfigGroup" >
                <!--
                List all the Navigation-items
                -->
                <div class="itemgroups">
                    <xf:group appearance="minimal" class="configsTriggerGroup">
                        <xf:trigger class="configsSubTrigger">
                            <xf:label>load selected</xf:label>
                            <xf:hint>Edit the Selected row in a form.</xf:hint>
                            <xf:action>
                                <xf:message level="ephemeral">Loading Navigation In Editor...</xf:message>
                                <xf:load show="embed" targetid="tabgroup">
                                    <xf:resource value="'./admin-navigation-subform.xml'"/>
                                </xf:load>
                            </xf:action>
                        </xf:trigger>
                    </xf:group>
        
                    <xf:repeat id="navgroups" nodeset="/ui/menugroups/menu[@name='mainnav']/xhtml:div/xhtml:ul/xhtml:li" appearance="full" class="itemgroups">
                        <xf:output ref="xhtml:a/@name"/>
                    </xf:repeat>
                    
                    <xf:group appearance="minimal" class="configsTriggerGroup">
                        <xf:trigger class="configsSubTrigger action-save">
                            <xf:label>save changes</xf:label>
                            <xf:hint>Save all your changes back to the configuratiuon document</xf:hint>
                            <xf:action>
                                <xf:message level="ephemeral">Saving Document...</xf:message>
                                <xf:send submission="save-form" />
                            </xf:action>
                        </xf:trigger>
                    </xf:group>                    
                </div>
            </xf:group>
            
            <!-- 
                the subform is embedded here 
            -->
            <xf:group appearance="full" class="configsFullGroup">
                <div class="configsSubForm">
                    <div id="tabgroup" class="editpane"/>
                </div>
            </xf:group>             
        </div>

        
    </div>
 </div>
</body>
</html>
