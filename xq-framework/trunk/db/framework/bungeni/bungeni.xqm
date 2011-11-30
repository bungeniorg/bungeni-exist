module namespace bun = "http://exist.bungeni.org/bun";
(:import module namespace rou = "http://exist.bungeni.org/rou" at "route.xqm";:)
import module namespace cmn = "http://exist.bungeni.org/cmn" at "../common.xqm";
import module namespace config = "http://bungeni.org/xquery/config" at "../config.xqm";
import module namespace template = "http://bungeni.org/xquery/template" at "../template.xqm";
import module namespace fw = "http://bungeni.org/xquery/fw" at "../fw.xqm";
import module namespace functx = "http://www.functx.com" at "../functx.xqm";
declare namespace request = "http://exist-db.org/xquery/request";
declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo="http://exist-db.org/xquery/xslfo";


declare namespace util="http://exist-db.org/xquery/util";
declare namespace transform="http://exist-db.org/xquery/transform";
declare namespace xh = "http://www.w3.org/1999/xhtml";
declare namespace bu="http://portal.bungeni.org/1.0/";

(:
Library for common lex functions
uses bungenicommon
:)

(:~
Default Variables
:)
declare variable $bun:SORT-BY := 'bu:statusDate';
declare variable $bun:WHERE := 'body_text';

declare variable $bun:OFF-SET := 0;
declare variable $bun:LIMIT :=10;
declare variable $bun:DOCNO := 1;

(:
    Renders PDF documents using xslfo module
:)
declare function bun:gen-pdf-output($docid as xs:string) {

    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt('parl-doc.fo') 
    
    let $doc := <document>        
            {
                collection(cmn:get-lex-db())/bu:ontology[@type='document'][child::bu:legislativeItem[@uri eq $docid]]
            }
        </document>      
        
    let $transformed := transform:transform($doc,$stylesheet,())
     
    let $pdf := xslfo:render($transformed, "application/pdf", ())
     
    return response:stream-binary($pdf, "application/pdf", "output.pdf")     
    
};

declare function bun:gen-member-pdf($memberid as xs:string) {

    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt('member-info.fo') 
    
    let $doc := <document>        
            {
                collection(cmn:get-lex-db())/bu:ontology/bu:user[@uri=$memberid]/ancestor::bu:ontology
            }
        </document>
        
    let $transformed := transform:transform($doc,$stylesheet,())
     
    let $pdf := xslfo:render($transformed, "application/pdf", ())
     
    return response:stream-binary($pdf, "application/pdf", "output.pdf")     
    
};


declare function bun:list-documentitems-with-acl($acl as xs:string, $type as xs:string) {
    let $acl-filter := cmn:get-acl-filter($acl)
    
    (:~ !+FIX_THIS_WARNING - parameterized XPath queries are broken in eXist 1.5 dev, converted this to an EVAL-ed query to 
    make it work - not query on the parent axis i.e./bu:ontology[....] is also broken - so we have to use the ancestor axis :)
    
    let $eval-query := fn:concat("collection('",cmn:get-lex-db() ,"')",
                                    "/bu:ontology[@type='document']",
                                    "/bu:document[@type='",$type,"']",
                                    "/following-sibling::bu:legislativeItem",
                                    "/(bu:permissions except bu:versions)",
                                    "/bu:permission[",$acl-filter,"]",
                                    "/ancestor::bu:ontology")
    return
        util:eval($eval-query)
        (: collection(cmn:get-lex-db())/bu:ontology[@type='document']/bu:document[@type=$type]/following-sibling::bu:legislativeItem/(bu:permissions except bu:versions)/bu:permission[$acl-filter] :)
};

declare function bun:get-documentitems(
            $acl as xs:string,
            $type as xs:string,
            $url-prefix as xs:string,
            $stylesheet as xs:string,
            $offset as xs:integer, 
            $limit as xs:integer, 
            $querystr as xs:string, 
            $where as xs:string, 
            $sortby as xs:string) as element() {
    
    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt($stylesheet)    
    let $coll := bun:list-documentitems-with-acl($acl, $type)
    
    (: 
        Logical offset is set to Zero but since there is no document Zero
        in the case of 0,10 which will return 9 records in subsequence instead of expected 10 records.
        Need arises to  alter the $offset to 1 for the first page limit only.
    :)
    let $query-offset := if ($offset eq 0 ) then 1 else $offset
    
    (: input ONxml document in request :)
    let $doc := <docs> 
        <paginator>
        (: Count the total number of documents :)
        <count>{
            count(
                $coll
              )
         }</count>
        <documentType>{$type}</documentType>
        <listingUrlPrefix>{$url-prefix}</listingUrlPrefix>
        <offset>{$offset}</offset>
        <limit>{$limit}</limit>
        </paginator>
        <alisting>
        {
            if ($sortby = 'st_date_oldest') then (
               (:if (fn:ni$qrystr):)
                for $match in subsequence($coll,$offset,$limit)
                order by $match/bu:legislativeItem/bu:statusDate ascending
                return 
                    bun:get-reference($match)       
                )
                
            else if ($sortby eq 'st_date_newest') then (
                for $match in subsequence($coll,$offset,$limit)
                order by $match/bu:legislativeItem/bu:statusDate descending
                return 
                    bun:get-reference($match)       
                )
            else if ($sortby = 'sub_date_oldest') then (
                for $match in subsequence($coll,$offset,$limit)
                order by $match/bu:bungeni/bu:parliament/@date ascending
                return 
                    bun:get-reference($match)         
                )    
            else if ($sortby = 'sub_date_newest') then (
                for $match in subsequence($coll,$offset,$limit)
                order by $match/bu:bungeni/bu:parliament/@date descending
                return 
                    bun:get-reference($match)         
                )                 
            else  (
                for $match in subsequence($coll,$query-offset,$limit)
                order by $match/bu:legislativeItem/bu:statusDate descending
                return 
                    bun:get-reference($match)         
                )
                (:ft:score($m):)
        } 
        </alisting>
    </docs>
    (: !+SORT_ORDER(ah, nov-2011) - pass the $sortby parameter to the xslt rendering the listing to be able higlight
    the correct sort combo in the transformed output. See corresponding comment in XSLT :)
    return
        transform:transform($doc, 
            $stylesheet, 
            <parameters>
                <param name="sortby" value="{$sortby}" />
            </parameters>
           ) 
       
};

declare function bun:get-bills(
        $acl as xs:string, 
        $offset as xs:integer, 
        $limit as xs:integer, 
        $querystr as xs:string, 
        $where as xs:string, 
        $sortby as xs:string) as element() {
        
        bun:get-documentitems($acl, "bill", "bill/text", "legislativeitem-listing.xsl", $offset, $limit, $querystr, $where, $sortby)
};

declare function bun:get-questions(
        $acl as xs:string, 
        $offset as xs:integer, 
        $limit as xs:integer, 
        $querystr as xs:string, 
        $where as xs:string, 
        $sortby as xs:string) as element() {
  bun:get-documentitems($acl, "question", "question/text", "legislativeitem-listing.xsl", $offset, $limit, $querystr, $where, $sortby)
};

declare function bun:get-motions(
        $acl as xs:string, 
        $offset as xs:integer, 
        $limit as xs:integer, 
        $querystr as xs:string, 
        $where as xs:string, 
        $sortby as xs:string) as element() {
  bun:get-documentitems($acl, "motion", "motion/text", "legislativeitem-listing.xsl", $offset, $limit, $querystr, $where, $sortby)
};

declare function bun:get-tableddocuments(
        $acl as xs:string, 
        $offset as xs:integer, 
        $limit as xs:integer, 
        $querystr as xs:string, 
        $where as xs:string, 
        $sortby as xs:string) as element() {
  bun:get-documentitems($acl, "tableddocument", "tableddocument/text", "legislativeitem-listing.xsl", $offset, $limit, $querystr, $where, $sortby)
};

declare function bun:search-types(
        $acl as xs:string, 
        $offset as xs:integer, 
        $limit as xs:integer, 
        $querystr as xs:string, 
        $where as xs:string, 
        $sortby as xs:string,
        $typeofdoc as xs:string,
        $filter_all as xs:string,
        $filter_body as xs:string,
        $filter_docno as xs:string,
        $filter_title as xs:string) as element() {
        
        bun:search-documentitems($acl, $typeofdoc, "bill/text", "search-listing.xsl", $offset, $limit, $querystr, $where, $sortby, $filter_all, $filter_body, $filter_docno, $filter_title)
};

declare function bun:ft-search(
            $sort-rs as element()+, 
            $querystr as xs:string, 
            $filter_all as xs:string, 
            $filter_body as xs:string,  
            $filter_docno as xs:string,
            $filter_title as xs:string) as element()* {

        if ($filter_all = 'on') then (
            (:~ 
                There are special characters for Lucene that we have to escape 
                incase they form part of the user's search input. More on this...
               
                http://sewm.pku.edu.cn/src/other/clucene/doc/queryparsersyntax.html
                http://www.addedbytes.com/cheat-sheets/regular-expressions-cheat-sheet/
            :)
            let $escaped := replace($querystr,'(:)|(\+)|(\()|(!)|(\{)|(\})|(\[)|(\])','\$`')
            
            for $search-rs in $sort-rs//bu:legislativeItem[ft:query(., $escaped)]
            order by ft:score($search-rs) descending
            return $search-rs/ancestor::bu:ontology    
            )
        else if ($filter_body = 'on') then (
        
            let $escaped := replace($querystr,'(:)|(\+)|(\()|(!)|(\{)|(\})|(\[)|(\])','\$`')
                    
            for $search-rs in $sort-rs//bu:legislativeItem/bu:body[ft:query(., $escaped)]
            order by ft:score($search-rs) descending
            return $search-rs/ancestor::bu:ontology    
            )
        else if ($filter_docno = 'on') then (
            
            let $escaped := replace($querystr,'(:)|(\+)|(\()|(!)|(\{)|(\})|(\[)|(\])','\$`')
                        
            for $search-rs in $sort-rs//bu:legislativeItem/bu:registryNumber[ft:query(., $escaped)]
            order by ft:score($search-rs) descending
            return $search-rs/ancestor::bu:ontology    
            )
        else (

            let $escaped := replace($querystr,'(:)|(\+)|(\()|(!)|(\{)|(\})|(\[)|(\])','\$`')
            
            for $search-rs in $sort-rs//bu:legislativeItem/bu:shortName[ft:query(., $querystr)]
            order by ft:score($search-rs) descending
            return $search-rs/ancestor::bu:ontology    
            )            
            
};

declare function bun:get-search-context($embed_tmpl as xs:string) as node() {

        (: get the template to be embedded :)
        let $temp_tmpl := fw:app-tmpl($embed_tmpl),
            (: get the set doc-types search conf:)
            $search-filter := cmn:get-searchins-config("question")        
        
            return
            	if ($temp_tmpl/descendant::xh:ul) then (
                      element xh:li {
                        element xh:input{
                                attribute type { "checkbox" },
                                "&#160;"
                            }
                        }
                )
                else
                    ()    
};

declare function bun:search-documentitems(
            $acl as xs:string,
            $type as xs:string,
            $url-prefix as xs:string,
            $stylesheet as xs:string,
            $offset as xs:integer, 
            $limit as xs:integer, 
            $querystr as xs:string, 
            $where as xs:string, 
            $sortby as xs:string,
            $filter_all as xs:string, 
            $filter_body as xs:string,  
            $filter_docno as xs:string,
            $filter_title as xs:string) as element() {
    
    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt($stylesheet)    
    let $coll_rs := bun:list-documentitems-with-acl($acl, $type)

    (: check if search is there so as to proceed to search or not :)    
    let $coll := if ($querystr ne "") then bun:ft-search($coll_rs, $querystr, $filter_all, $filter_body, $filter_docno, $filter_title) else $coll_rs
    
    (: 
        Logical offset is set to Zero but since there is no document Zero
        in the case of 0,10 which will return 9 records in subsequence instead of expected 10 records.
        Need arises to  alter the $offset to 1 for the first page limit only.
    :)
    let $query-offset := if ($offset eq 0 ) then 1 else $offset
    
    (: input ONxml document in request :)
    let $doc := <docs> 
        <paginator>
            (: Count the total number of documents :)
            <count>{
                count(
                    $coll
                  )
             }</count>
            <documentType>{$type}</documentType>
            <searchString>{$querystr}</searchString>
            <sortBy>{$sortby}</sortBy>
            <filterTitle>{$filter_title}</filterTitle>
            <filterBody>{$filter_body}</filterBody>
            <filterDocNo>{$filter_docno}</filterDocNo>
            <filterAll>{$filter_all}</filterAll>
            <listingUrlPrefix>{$url-prefix}</listingUrlPrefix>
            <offset>{$offset}</offset>
            <limit>{$limit}</limit>
        </paginator>
        <alisting>
        {
            if ($sortby = 'st_date_oldest') then (
               (:if (fn:ni$qrystr):)
                for $match in subsequence($coll,$offset,$limit)
                order by $match/bu:legislativeItem/bu:statusDate ascending
                return 
                    bun:get-reference($match)       
                )
                
            else if ($sortby eq 'st_date_newest') then (
                for $match in subsequence($coll,$offset,$limit)
                order by $match/bu:legislativeItem/bu:statusDate descending
                return 
                    bun:get-reference($match)       
                )
            else if ($sortby = 'sub_date_oldest') then (
                for $match in subsequence($coll,$offset,$limit)
                order by $match/bu:bungeni/bu:parliament/@date ascending
                return 
                    bun:get-reference($match)         
                )    
            else if ($sortby = 'sub_date_newest') then (
                for $match in subsequence($coll,$offset,$limit)
                order by $match/bu:bungeni/bu:parliament/@date descending
                return 
                    bun:get-reference($match)         
                )                 
            else  (
                for $match in subsequence($coll,$query-offset,$limit)
                order by $match/bu:legislativeItem/bu:statusDate descending
                return 
                    bun:get-reference($match)         
                )
                (:ft:score($m):)
        } 
        </alisting>
    </docs>
    (: !+SORT_ORDER(ah, nov-2011) - pass the $sortby parameter to the xslt rendering the listing to be able higlight
    the correct sort combo in the transformed output. See corresponding comment in XSLT :)
    return
        transform:transform($doc, 
            $stylesheet, 
            <parameters>
                <param name="sortby" value="{$sortby}" />
            </parameters>
           ) 
};

(:~
    Generates Atom FEED for Bungeni Documents
    Bills, Questions, TabledDocuments and Motions.
    
    @category type of document e.g. bill
    
    Ordered by `bu:statusDate` and limited to 10 items.
    !+FIX_THIS - FOR ACL BASED ACCESS
:)
declare function bun:get-atom-feed($acl as xs:string, $doctype as xs:string, $outputtype as xs:string) as element() {
    util:declare-option("exist:serialize", "media-type=application/atom+xml method=xml"),
    
    let $server-path := "http://localhost:8180/exist/apps/framework"
    
    let $feed := <feed xmlns="http://www.w3.org/2005/Atom" xmlns:atom="http://www.w3.org/2005/Atom">
        <title>{concat(upper-case(substring($doctype, 1, 1)), substring($doctype, 2))}s Atom</title>
        <id>http://portal.bungeni.org/1.0/</id>
        <updated>{current-dateTime()}</updated>
        <generator uri="http://exist.sourceforge.net/" version="1.4.5">eXist XML Database</generator>      
        <id>urn:uuid:31337-4n70n9-w00t-l33t-5p3364</id>
        <link rel="self" href="/bills/rss" />
       {
            for $i in subsequence(bun:list-documentitems-with-acl($acl, $doctype),0,10)
            order by $i/bu:legislativeItem/bu:statusDate descending
               (:let $path :=  substring-after(substring-before(base-uri($i),'/.feed.atom'),'/db/bungeni-xml'):)
                  return ( <entry>
                            <id>{data($i/bu:legislativeItem/@uri)}</id>
                            <title>{$i/bu:legislativeItem/bu:shortName/node()}</title>
                            {
                               <summary> {
                                   $i/bu:document/@type,
                                   $i/bu:legislativeItem/bu:shortName/node()
                               }</summary>,
                               
                               
                               if ($outputtype = 'user')  then (
                                    <link rel="alternate" type="application/xhtml" href="{$server-path}/bill/text?uri={$i/bu:legislativeItem/@uri}"/>
                                )  (: "service" output :)
                                else (
                                    <link rel="alternate" type="application/xml" href="{$server-path}/bill/xml?uri={$i/bu:legislativeItem/@uri}"/>
                                )
                                
                           }
                            <content type='html'>{$i/bu:legislativeItem/bu:body/node()}</content>
                            <published>{$i/bu:legislativeItem/bu:publicationDate/node()}</published>
                            <updated>{$i/bu:legislativeItem/bu:statusDate/node()}</updated>                           
                           </entry>
                         )
       }
    </feed>
    
    return 
        $feed
};

(:~
    Returns the fetched document as XML document
    @works-with Bills, Questions, TabledDocuments and Motions.
    @category   type of document e.g. bill
    
    Ordered by `bu:statusDate` and limited to 10 items.
:)
declare function bun:get-raw-xml($docid as xs:string) as element() {
    util:declare-option("exist:serialize", "media-type=application/xml method=xml"),

    functx:remove-elements-deep(
    collection(cmn:get-lex-db())/bu:ontology[@type='document'][child::bu:legislativeItem[@uri eq $docid]],
    ('bu:versions', 'bu:permissions', 'bu:changes')
    )
};

declare function bun:get-committees($offset as xs:integer, $limit as xs:integer, $querystr as xs:string, $where as xs:string, $sortby as xs:string) as element() {
    
    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt("committees.xsl")    
    
    (: input ONxml document in request :)
    let $doc := <docs> 
        <paginator>
        (: Count the total number of groups :)
        <count>{count(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='committee'])}</count>
        <documentType>group</documentType>
        <listingUrlPrefix>committee/profile</listingUrlPrefix>        
        <offset>{$offset}</offset>
        <limit>{$limit}</limit>
        </paginator>
        <alisting>
        {
            if ($sortby = 'start_dt_oldest') then (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='committee'],$offset,$limit)
                order by $match/ancestor::bu:ontology/bu:group/bu:startDate ascending
                return 
                    <document>{$match/ancestor::bu:ontology}</document>  
                )
                
            else if ($sortby eq 'start_dt_newest') then (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='committee'],$offset,$limit)
                order by $match/ancestor::bu:ontology/bu:group/bu:startDate descending
                return 
                    <document>{$match/ancestor::bu:ontology}</document>     
                )
            else if ($sortby = 'fN_asc') then (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='committee'],$offset,$limit)
                order by $match/ancestor::bu:ontology/bu:legislature/bu:fullName ascending
                return 
                    <document>{$match/ancestor::bu:ontology}</document>      
                )    
            else if ($sortby = 'fN_desc') then (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='committee'],$offset,$limit)
                order by $match/ancestor::bu:ontology/bu:legislature/bu:fullName descending
                return 
                    <document>{$match/ancestor::bu:ontology}</document>        
                )                 
            else  (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='committee'],$offset,$limit)
                order by $match/bu:legislature/bu:statusDate descending
                return 
                    <document>{$match/ancestor::bu:ontology}</document>
                   
                )

        } 
        </alisting>
    </docs>
    (: !+SORT_ORDER(ah, nov-2011) - pass the $sortby parameter to the xslt rendering the listing to be able higlight
    the correct sort combo in the transformed output. See corresponding comment in XSLT :)
    return
        transform:transform($doc, 
            $stylesheet, 
            <parameters>
                <param name="sortby" value="{$sortby}" />
            </parameters>
           ) 
       
};

declare function bun:get-politicalgroups($offset as xs:integer, $limit as xs:integer, $querystr as xs:string, $where as xs:string, $sortby as xs:string) as element() {
    
    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt("politicalgroups.xsl")    
    
    (: input ONxml document in request :)
    let $doc := <docs> 
        <paginator>
        (: Count the total number of groups :)
        <count>{count(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='political-group'])}</count>
        <documentType>group</documentType>
        <listingUrlPrefix>committee/profile</listingUrlPrefix>        
        <offset>{$offset}</offset>
        <limit>{$limit}</limit>
        </paginator>
        <alisting>
        {
            if ($sortby = 'start_dt_oldest') then (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='political-group'],$offset,$limit)
                order by $match/ancestor::bu:ontology/bu:group/bu:startDate ascending
                return 
                    <document>{$match/ancestor::bu:ontology}</document>  
                )
                
            else if ($sortby eq 'start_dt_newest') then (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='political-group'],$offset,$limit)
                order by $match/ancestor::bu:ontology/bu:group/bu:startDate descending
                return 
                    <document>{$match/ancestor::bu:ontology}</document>     
                )
            else if ($sortby = 'fN_asc') then (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='political-group'],$offset,$limit)
                order by $match/ancestor::bu:ontology/bu:legislature/bu:fullName ascending
                return 
                    <document>{$match/ancestor::bu:ontology}</document>      
                )    
            else if ($sortby = 'fN_desc') then (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='political-group'],$offset,$limit)
                order by $match/ancestor::bu:ontology/bu:legislature/bu:fullName descending
                return 
                    <document>{$match/ancestor::bu:ontology}</document>        
                )                 
            else  (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@type='political-group'],$offset,$limit)
                order by $match/bu:legislature/bu:statusDate descending
                return 
                    <document>{$match/ancestor::bu:ontology}</document>
                   
                )

        } 
        </alisting>
    </docs>
    (: !+SORT_ORDER(ah, nov-2011) - pass the $sortby parameter to the xslt rendering the listing to be able higlight
    the correct sort combo in the transformed output. See corresponding comment in XSLT :)
    return
        transform:transform($doc, 
            $stylesheet, 
            <parameters>
                <param name="sortby" value="{$sortby}" />
            </parameters>
           ) 
       
};

(:~
    This function runs a sub-query to get related information
    It takes in primary results of main query as input to search
    for group documents with matching URI
:)
declare function bun:get-reference($docitem as node()) {
    <document>
        <output> 
        {
            $docitem
        }
        </output>
        <referenceInfo>
            <ref>
            {
                let $doc-ref := data($docitem/bu:*/bu:group/@href)
                return 
                    collection(cmn:get-lex-db())/bu:ontology/bu:group[@uri eq $doc-ref]/../bu:ministry
            }
            </ref>
        </referenceInfo>
    </document>     
};

(:~
Get document with ACL filter
:)
declare function bun:documentitem-with-acl($acl as xs:string, $docid as xs:string) {
    let $acl-filter := cmn:get-acl-filter($acl)
    let $match :=  collection(cmn:get-lex-db())/bu:ontology/bu:legislativeItem[@uri=$docid]/(bu:permissions except bu:versions)/bu:permission[$acl-filter]/ancestor::bu:ontology
    return bun:documentitem-versions-with-acl($acl-filter, $match)
};

(:~
Remove Versions to which we dont have access
:)
declare function bun:documentitem-versions-with-acl($acl-filter as xs:string, $docitem as node() ) {
  if ($docitem/self::bu:version) then
        if ($docitem//bu:permission[$acl-filter]) then
            $docitem
        else
            ()
  else 
    (:~
     return the default 
     :)
  		element { node-name($docitem)}
		  		 {$docitem/@*, 
					for $child in $docitem/node()
						return if ($child instance of element())
							   then bun:documentitem-versions-with-acl($acl-filter, $child)
							   else $child
				 }
};


declare function bun:get-parl-doc($acl as xs:string, $docid as xs:string, $_tmpl as xs:string) as element()* {

    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt($_tmpl) 
    let $acl-filter := cmn:get-acl-filter($acl)
 
    let $doc := <parl-doc> 
        {
            (: Return matching ontology document :)
            let $match := collection(cmn:get-lex-db())/bu:ontology/bu:legislativeItem[@uri=$docid]/(bu:permissions except bu:versions)/bu:permission[$acl-filter]/ancestor::bu:ontology
            return
                bun:get-ref-assigned-grps($match)   
        } 
    </parl-doc>    
    return
        transform:transform($doc, $stylesheet, ())
};

declare function bun:get-parl-group($acl as xs:string, $docid as xs:string, $_tmpl as xs:string) as element()* {

    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt($_tmpl) 
    let $acl-filter := cmn:get-acl-filter($acl)
 
    let $doc := <parl-doc> 
        {
            (: return AN document as singleton :)
            let $match := collection(cmn:get-lex-db())/bu:ontology/bu:group[@uri=$docid]/bu:permissions/bu:permission[$acl-filter]/ancestor::bu:ontology
            return
                bun:get-ref-assigned-grps($match)   
        } 
    </parl-doc>    
    return
        transform:transform($doc, $stylesheet, ())
};

declare function bun:get-ref-assigned-grps($docitem as node()) {
            <document>
                <primary> 
                {
                    $docitem
                }
                </primary>
                <secondary>
                    {
                        let $doc-ref := data($docitem/bu:*/bu:ministry/@href)
                        return 
                            collection(cmn:get-lex-db())/bu:ontology/bu:group[@uri eq $doc-ref]/ancestor::bu:ontology
                    }
                </secondary>
            </document>     
};

(:~
    Get parliamentary document based on a version URI
    +NOTES
    Follows the same structure as get-parl-doc() in that it returns 
    <document>
        <version>id</version>
        <primary/>
        <secondary/>
    </document>
:)
declare function bun:get-doc-ver($versionid as xs:string, $_tmpl as xs:string) as element()* {

    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt($_tmpl) 
    
    let $doc := <parl-doc>
        <document>
            <version>{$versionid}</version>
            <primary>         
            {
                collection(cmn:get-lex-db())/bu:ontology[@type='document']/bu:legislativeItem/bu:versions/bu:version[@uri=$versionid]/ancestor::bu:ontology
            }
            </primary>
            <secondary>
            </secondary>
        </document>
    </parl-doc>   
    
    return
        transform:transform($doc, 
                            $stylesheet, 
                            <parameters>
                                <param name="version" value="true" />
                            </parameters>)
};

declare function bun:get-doc-event($eventid as xs:string, $_tmpl as xs:string) as element()* {

    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt($_tmpl) 
    
    let $doc := <parl-doc>
        <document>
            <event>{$eventid}</event>
            <primary>         
            {
                collection(cmn:get-lex-db())/bu:ontology[@type='document']/bu:legislativeItem/bu:wfevents/bu:wfevent[@href = $eventid]/ancestor::bu:ontology
            }
            </primary>
            <secondary>
            {
                collection(cmn:get-lex-db())/bu:ontology[@type='document']/bu:document[@type='event']/../bu:legislativeItem[@uri eq $eventid]/ancestor::bu:ontology
            }            
            </secondary>
        </document>
    </parl-doc>   
    
    return
        transform:transform($doc, 
                            $stylesheet, 
                            <parameters>
                                <param name="version" value="true" />
                            </parameters>)
};

declare function bun:get-members($offset as xs:integer, $limit as xs:integer, $querystr as xs:string, $where as xs:string, $sortby as xs:string) as element() {
    
    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt("members.xsl")    
    
    (: input ONxml document in request :)
    let $doc := <docs> 
        <paginator>
        (: Count the total number of members :)
        <count>{count(collection(cmn:get-lex-db())/bu:ontology[@type='userdata']/bu:metadata[@type='user'])}</count>
        <offset>{$offset}</offset>
        <limit>{$limit}</limit>
        </paginator>
        <alisting>
        {
            if ($sortby = 'ln') then (
            
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='userdata']/bu:metadata[@type='user'],$offset,$limit)                
                order by $match/ancestor::bu:ontology/bu:user/bu:field[@name='last_name'] descending
                return 
                    bun:get-reference($match/ancestor::bu:ontology)       
                )
            else if ($sortby = 'fn') then (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='userdata']/bu:metadata[@type='user'],$offset,$limit)
                order by $match/ancestor::bu:ontology/bu:user/bu:field[@name='first_name'] descending
                return 
                    bun:get-reference($match/ancestor::bu:ontology)         
                )                
            else  (
                for $match in subsequence(collection(cmn:get-lex-db())/bu:ontology[@type='userdata']/bu:metadata[@type='user'],$offset,$limit)
                order by $match/ancestor::bu:ontology/bu:user/bu:field[@name='last_name'] descending
                return 
                    bun:get-reference($match/ancestor::bu:ontology)         
                )

        } 
        </alisting>
    </docs>
    
    return
        transform:transform($doc, $stylesheet, ()) 
       
};

declare function bun:get-member($memberid as xs:string, $_tmpl as xs:string) as element()* {

    (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt($_tmpl) 

    (: return AN Member document as singleton :)
    let $doc := collection(cmn:get-lex-db())//bu:ontology//bu:user[@uri=$memberid]/ancestor::bu:ontology
    
    return
        transform:transform($doc, $stylesheet, ())
};

declare function bun:get-parl-activities($memberid as xs:string, $_tmpl as xs:string) as element()* {

     (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt($_tmpl) 

    (: return AN Member document with his/her activities :)
    let $doc := <activities>
    <member>
    {
        collection(cmn:get-lex-db())/bu:ontology//bu:user[@uri=$memberid]/ancestor::bu:ontology
    }
    </member>
    {
    (: Get all parliamentary documents the user is either owner or signatory :)
    for $match in collection(cmn:get-lex-db())/bu:ontology[@type='document']
    where   bu:signatories/bu:signatory[@href=$memberid]/ancestor::bu:ontology or 
            bu:legislativeItem/bu:owner[@href=$memberid]/ancestor::bu:ontology
    return
        <docs>
            {
                $match
            }
        </docs>
    }
    </activities> 
    
    return
        transform:transform($doc, $stylesheet, ())    
};

declare function bun:get-assigned-items($committeeid as xs:string, $_tmpl as xs:string) as element()* {

     (: stylesheet to transform :)
    let $stylesheet := cmn:get-xslt($_tmpl) 

    (: return AN Committee document with all items assigned to it :)
    let $doc := <assigned-items>
    <group>
    {
        collection(cmn:get-lex-db())/bu:ontology[@type='group']/bu:group[@uri=$committeeid]/ancestor::bu:ontology
    }
    </group>
    {
    for $match in collection(cmn:get-lex-db())/bu:ontology[@type='document']/bu:*/bu:group[@href=$committeeid]
    return
        <items>
            {
                $match/ancestor::bu:ontology
             }
        </items>
    }
    </assigned-items> 
    
    return
        transform:transform($doc, $stylesheet, ())  
};