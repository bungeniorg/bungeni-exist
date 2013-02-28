xquery version "3.0";

import module namespace functx = "http://www.functx.com" at "functx.xqm";
import module namespace cmn = "http://exist.bungeni.org/cmn" at "common.xqm";
import module namespace template = "http://bungeni.org/xquery/template" at "template.xqm";
import module namespace bun = "http://exist.bungeni.org/bun" at "bungeni/bungeni.xqm";
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";
import module namespace json="http://www.json.org";

declare namespace util="http://exist-db.org/xquery/util";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace ex="http://exist-db.org/xquery/ex";
declare namespace bu="http://portal.bungeni.org/1.0/";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

(:
 : This XQuery script provides a REST API based on RESTXQ extension
 :
 : @author Anthony Oduor <aowino@googlemail.com>
 : 
 : http://localhost:8088/exist/restxq/ontology?group=document&type=Bill?offset=1&limit=5
 :
:)

declare
    %rest:path("/ontology")
    %rest:POST("{$body}")    
    %rest:form-param("role", "{$role}", "bungeni.Anonymous")     
    %rest:form-param("group", "{$group}", "*")    
    %rest:form-param("type", "{$type}", "*")
    %rest:form-param("offset", "{$offset}", 1)
    %rest:form-param("limit", "{$limit}", 10) (: set a default and then return next offset for next batch :)   
    %rest:form-param("search", "{$search}", "none")
    %rest:form-param("status", "{$status}", "*")
    %rest:form-param("daterange", "{$daterange}", "*")
    %output:method("json")
    
    (: Cascading collection based on parameters given, default apply when not given explicitly by client :)
    function local:documents(
        $body as xs:string*,
        $role as xs:string*,        
        $group as xs:string*,
        $type as xs:string*, 
        $offset as xs:int*,
        $limit as xs:int*,
        $search as xs:string*,
        $status as xs:string*,
        $daterange as xs:string*) {
        <docs>
            <role>{$role}</role>         
            <group>{$group}</group>           
            <type>{$type}</type>   
            <offset>{$offset}</offset>
            <next-offset>{($offset+$limit)}</next-offset>
            <limit>{$limit}</limit>
            <search>{$search}</search>
            <status>{$status}</status>
            <daterange>{$daterange}</daterange>
            {
                let $acl-filter-attr := cmn:get-acl-permission-as-attr-for-role($role)
                let $acl-filter-node := cmn:get-acl-permission-as-node-for-role($role)
                
                let $token-roles := tokenize($role,",")
                let $roles :=   for $arole at $pos in $token-roles
                                let $counter := count($token-roles)
                                return (
                                    fn:concat("bu:control[",cmn:get-acl-permission-as-attr-for-role($arole),"]"),
                                    if($pos lt $counter) then "and" else () )
                
                let $roles-string := fn:string-join($roles," ")
             
                (: get entire collection and apply given permission on the main document :)
                let $eval-query :=  fn:concat("collection('",cmn:get-lex-db() ,"')",
                                    (: the first node in root element has the documents main permission :)
                                    "/bu:ontology/child::node()[1]/bu:permissions",
                                    "[",$roles-string,"]/ancestor::bu:ontology")                   
                let $coll :=  util:eval($eval-query)             
            
                (: get entire collection OR trim by group types mainly: document, group, membership... :)
                let $coll-by-group :=  
                    switch($group)
                        case "*"
                            return $coll
                        default
                            return
                                for $dgroup in tokenize($group,",")
                                return $coll[@for=$dgroup]   
                
                (: from $coll-by-group get collection by docTypes mainly: Bill, Question, Motion... :)
                let $coll-by-doctype := 
                    switch($type)
                        case "*"
                            return $coll-by-group
                        default
                            return
                                for $dtype in tokenize($type,",")
                                return $coll-by-group/child::*/bu:docType[bu:value=$dtype]/ancestor::bu:ontology
                                
                (: trim $coll-by-doctype subset by bu:status :)
                let $coll-by-status := 
                    switch($status)
                        case "*"
                            return $coll-by-doctype
                        default
                            return
                                for $dstatus in $coll-by-doctype
                                where $dstatus/child::*/bu:status/bu:value eq $status 
                                return $dstatus  
                                
                (: trim $coll-by-status subset by bu:statusDate :)
                let $coll-by-statusdate := 
                    switch($daterange)
                        case "*"
                            return $coll-by-status
                        default
                            return
                                for $match in $coll-by-status
                                let $dates := tokenize($daterange,",")
                                return 
                                    $match/child::*[xs:dateTime(bu:statusDate) gt xs:dateTime(concat($dates[1],"T00:00:00"))]
                                    [xs:dateTime(bu:statusDate) lt xs:dateTime(concat($dates[2],"T23:59:59"))]/ancestor::bu:ontology                        

                (: finally search the subset collection if and only if there are is a search param given :)    
                let $ontology_rs := 
                    switch($search)
                        case "none"
                            return $coll-by-statusdate
                        default
                            return
                                bun:adv-ft-search($coll-by-statusdate, $search)                          
                  
                (: strip nodes with failing permissions recursively to all nodes :)
                let $ontology_strip_deep := for $doc in $ontology_rs
                                            return bun:treewalker-acl($acl-filter-node,document{$doc})                                 
                        
                (: strip classified nodes :)
                let $ontology_strip := functx:remove-elements-deep($ontology_strip_deep,
                                    ('bu:bungeni','bu:legislature','bu:versions', 'bu:permissions', 
                                    'bu:audits', 'bu:attachments'))
                                                      
                return 
                    (   <total>{count($ontology_rs)}</total>,
                        subsequence($ontology_strip,$offset,$limit)
                     )                  
                    (:$acl-filter-node:)
                    (:<count>{count($ontology_rs)}</count>:)
            }
        </docs>
};

declare
    %rest:GET
    %rest:path("/{$country-code}/{$type}")
    
    function local:documents($country-code as xs:string, $type as xs:string) {
        <docs>
            {
                collection(cmn:get-lex-db())/bu:ontology/bu:document/bu:docType[bu:value eq $type]
            }
        </docs>
};

declare
    %rest:GET
    %rest:path("/{$country-code}/{$type}/{$docid}")
    
    function local:documents($country-code as xs:string, $type as xs:string, $docid as xs:int) {
        <docs>
            {
                collection(cmn:get-lex-db())/bu:ontology/bu:document[bu:docType/bu:value eq $type][bu:docId = $docid]/parent::node()
            }
        </docs>
};

declare
    %rest:GET
    %rest:path("/unknown/{$name}")
    function local:goodbye($name) {
        (<rest:response>
            <http:response status="404"/>
        </rest:response>,
        <goodbye>{$name}</goodbye>
        )
};

(: 
 : Test list attachments
 :  :)
declare function local:get-mock-attachments() as node(){
    
    let $coll := <collection>
        {collection('/db/bungeni-xml')/bu:ontology/bu:attachments/bu:attachment}
        </collection>
        
    return $coll 
};

(: 
 : Retrieve collection of attachments
 : :)
declare function local:get-attachments() as node(){
    
    let $doc := <collection>
        {collection('/db/bungeni-xml')/bu:ontology[@for='document']
        [bu:document[bu:docType[bu:value[. = 'Bill']]][bu:status[bu:value[. = 'received']]]]
        /bu:attachments/bu:attachment[bu:type[bu:value[. = 'main-xml']]]}
        </collection>
        
    return $doc
};

(: 
 : Retrieve an attachment by name
 :  :)
declare function local:get-attachment-hash-by-name($name as xs:string){
    
    collection('/db/bungeni-xml')/bu:ontology[@for='document']
    [bu:document[bu:docType[bu:value[. = 'Bill']]][bu:status[bu:value[. = 'received']]]]
    /bu:attachments/bu:attachment[bu:type[bu:value[. = 'main-xml']]]
    [bu:name[.=$name]]/bu:fileHash/string()
};

(: 
 : Search for attachments by partial name
 :  and return list with hash and name
 :  :)
declare
    %rest:POST
    %rest:path("/attachments")
    %rest:form-param("search", "{$search}","*")  
    %output:method("xml")
    function local:search-for-attachments($search as xs:string*){
        <attachments>{
        
            for $i in local:get-attachments()/child::node()
            return 
                if (matches($i/bu:name/string(), $search)) then
                    <attachment>
                        <hash>{$i/bu:fileHash/string()}</hash>
                        <name>{$i/bu:name/string()}</name>
                    </attachment>
                else 
                    () 
                
        }</attachments>
};

(: 
 : Test search GET attachment list
 :  :)
declare
    %rest:GET
    %rest:path("/test/get/attachments")
    %rest:form-param("search", "{$search}","*")  
    %output:method("xml")
    function local:test-get-search-attachmemnts($search as xs:string*){
      
       local:search-for-attachments($search)   
};


(: 
 : Get an attachment by name
 :  and return document
 :  :)    
declare
    %rest:POST
    %rest:path("/attachment")
    %rest:form-param("name", "{$name}","*")  
    %output:method("xml")
    function local:get-attachment($name as xs:string*){
        
      util:parse(util:binary-to-string(util:binary-doc(concat("/db/bungeni-atts/", local:get-attachment-hash-by-name($name)))))
};

(: 
 : Test GET attachment
 :  :)
declare
    %rest:GET
    %rest:path("/test/get/attachment")
    %rest:form-param("name", "{$name}","*")  
    %output:method("xml")
    function local:test-get-attachment($name as xs:string*){
        
      local:get-attachment($name)
};

(: 
 : Authenticate and save document to /db
 :  :)
declare 
    %rest:POST
    %rest:path("/update")
    %rest:form-param("username", "{$username}","*")  
    %rest:form-param("password", "{$password}","*")  
    %rest:form-param("documentname", "{$documentname}","*")
    %rest:form-param("document", "{$document}","*")  
    %output:method("xml")
    function local:push-document($username as xs:string*, $password as xs:string*, $documentname as xs:string*, $document as xs:string*){
        
        let $login := xmldb:login("/db", $username, $password)
        let $store-return-status := xmldb:store("/db", $documentname, $document)
            return ()
};

local:goodbye("unknown")
