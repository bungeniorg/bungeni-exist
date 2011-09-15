xquery version "1.0";

(: Adapted code from http://seewhatithink.sourceforge.net/ by Adam Retter :)

module namespace template = "http://bungeni.org/xquery/template";

declare namespace xh = "http://www.w3.org/1999/xhtml";
declare namespace pg = "http://bungeni.org/page";

import module namespace config = "http://bungeni.org/xquery/config" at "config.xqm";

(: rewrite src, href and action attribute uri's :)
declare function template:adjust-relative-paths($request-rel-path as xs:string, $attr as attribute()) {
    if(fn:local-name($attr) = ("src", "href", "action") and not(starts-with($attr, "/") or starts-with($attr, "http://") or starts-with($attr, "https://") or starts-with($attr, "../") or starts-with($attr, "#")))then (: starts-with($attr, "../") stops paths being processed more than once :)
            attribute {node-name($attr)} { 
                template:make-relative-uri($request-rel-path, $attr)
            }
        else 
            $attr
};

declare function template:make-relative-uri($request-rel-path as xs:string, $uri as xs:string) as xs:string {
    fn:concat(
        fn:string-join(
            for $sub-path-count in 1 to fn:count(fn:tokenize($request-rel-path, "/")) -2 return
                "../"
            ,
            ""
        ),
        $uri
    )
};

declare function template:copy-and-replace($request-rel-path as xs:string, $element as element(), $content as element()*) {
  element {node-name($element)} {
     for $attr in $element/@* return
        template:adjust-relative-paths($request-rel-path, $attr)
     ,
     for $child in $element/node() return
        if($child instance of element()) then
            
            if($content/node-name(.) = node-name($child) and $child/@id = $content/@id)then
            (: if(node-name($child) = (xs:QName("xh:div"), xs:QName("xh:ul")) and $child/@id = $content/@id)then :)
                template:copy-and-replace($request-rel-path, $content[@id eq $child/@id], ())
            else
                template:copy-and-replace($request-rel-path, $child, $content)
        else
            $child
    }
};

declare function template:merge($request-rel-path as xs:string, $template1 as document-node(), $template2 as document-node()?) as document-node() {
    if(empty($template2))then
        $template1
    else
        document {
            template:copy-and-replace($request-rel-path, $template1/element(), $template2/element())
        }
};


declare function template:set-title($content as element(), $title as xs:string) as  element() {
	if ($content/self::xh:title)
	then <title>{$title}</title>
	else element { node-name($content)}
		  		 {$content/@*, 
					for $child in $content/node()
						return if ($child instance of element())
							   then template:set-title($child, $title)
							   else $child
				 }
};

declare function template:filter-page-namespace(
      $element as element()) as element() {
   element {node-name($element) }
             { $element/@*,
               for $child in $element/node()[not(namespace-uri(.)='http://bungeni.org/page')]
                  return if ($child instance of element())
                    then template:filter-page-namespace($child)
                    else $child
           }
};


declare function template:process-page-meta($doc as element()) as element() {
	(: Get the page info element :)
	let $page-info := $doc//pg:info
	(: Now remove the page namespace from the final document :)
	let $final := template:filter-page-namespace($doc)
    (: For now only the title is specified in page namespace - but this will be expanded
       to support other things :)
	(: Set the title and return the page :)
	return 
		template:set-title($final, $page-info/pg:title/text())
};


declare function template:process-template($rel-path as xs:string, $request-rel-path as xs:string, $template-name as xs:string, $content as document-node()+) {  (:document-node(element(xh:div))* :)
    let $template := fn:doc(fn:concat($rel-path, "/", $template-name)),
    $div-content := $content/xh:div[@id] | $content/xh:div[not(exists(@id))]/xh:div[@id] 
    (: extracts top level content and content from within an id less container :)
    let $processed-doc := template:copy-and-replace($request-rel-path, $template/xh:html, $div-content)
    return template:process-page-meta($processed-doc)
};


