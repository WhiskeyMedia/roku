'******************************************************
'**  Video Player Example Application -- Category Feed
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'******************************************************

'******************************************************
' Set up the category feed connection object
' This feed provides details about top level categories
'******************************************************
Function InitCategoryFeedConnection() As Object

    m.api_key = loadRegistrationToken()
    if len(m.api_key) = 0 then
        'Use default API key
        m.api_key = "eb50d95258f657233edcde6652e1c053ca4e302e"
    endif

    conn = CreateObject("roAssociativeArray")

    conn.UrlPrefix = "http://api.tested.com"
    m.UrlPrefix = conn.UrlPrefix
    conn.UrlCategoryFeed = conn.UrlPrefix + "/video_types/?api_key=" + m.api_key

    conn.Timer = CreateObject("roTimespan")

    conn.LoadCategoryFeed    = load_category_feed
    conn.GetCategoryNames    = get_category_names

    print "created feed connection for " + conn.UrlCategoryFeed
    return conn

End Function

'*********************************************************
'** Create an array of names representing the children
'** for the current list of categories. This is useful
'** for filling in the filter banner with the names of
'** all the categories at the next level in the hierarchy
'*********************************************************
Function get_category_names(categories As Object) As Dynamic

    categoryNames = CreateObject("roArray", 100, true)

    for each category in categories.kids
        'print category.Title
        categoryNames.Push(category.Title)
    next

    return categoryNames

End Function


'******************************************************************
'** Given a connection object for a category feed, fetch,
'** parse and build the tree for the feed.  the results are
'** stored hierarchically with parent/child relationships
'** with a single default node named Root at the root of the tree
'******************************************************************
Function load_category_feed(conn As Object) As Dynamic

    http = NewHttp(conn.UrlCategoryFeed)

    Dbg("url: ", http.Http.GetUrl())

    m.Timer.Mark()
    rsp = http.GetToStringWithRetry()
    Dbg("Took: ", m.Timer)

    m.Timer.Mark()
    xml=CreateObject("roXMLElement")
    if not xml.Parse(rsp) then
        print "Can't parse feed"
        return invalid
    endif
    Dbg("Parse Took: ", m.Timer)

    m.Timer.Mark()
    if xml.results = invalid then
        print "no categories tag"
        return invalid
    endif

    if islist(xml.results) = false then
        print "invalid feed body"
        return invalid
    endif

    if xml.status_code.gettext() = "100" then
        print "invalid api key"
        print "resetting to default key"
        deleteRegistrationToken()
    endif

    if xml.results.video_type[0].GetName() <> "video_type" then
        print "no initial category tag"
        return invalid
    endif

    topNode = MakeEmptyCatNode()
    topNode.Title = "root"
    topNode.isapphome = true

    print "begin category node parsing"

    categories = xml.results.GetChildElements()
    print "number of categories: " + itostr(categories.Count())

    o = MakeLatestCategory()
    topNode.AddKid(o)

    for each e in categories
        o = ParseCategoryNode(e)
        if o <> invalid then
            topNode.AddKid(o)
            print "added new child node"
        else
            print "parse returned no child node"
        endif
    next
    Dbg("Traversing: ", m.Timer)

    return topNode

End Function


'******************************************************
'MakeEmptyCatNode - use to create top node in the tree
'******************************************************
Function MakeEmptyCatNode() As Object
    return init_category_item()
End Function


'******************************************************
'MakeLatestCategoryNode - use to create latest category
'******************************************************
Function MakeLatestCategory() As dynamic
    o = init_category_item()

    print "ParseCategoryNode: " + "Latest"

    'parse the curent node to determine the type. everything except
    'special categories are considered normal, others have unique types
    print "category: " + "Latest" + " | " + "See all our latest stuff."
    o.Type = "normal"
    o.Title = "Latest"
    o.Description = "See all our latest stuff."
    o.ShortDescriptionLine1 = "Latest"
    o.ShortDescriptionLine2 = "See all our latest stuff."
    o.Feed = m.UrlPrefix + "/videos/?api_key=" + m.api_key + "&sort=-publish_date&field_list=name,deck,id,image,length_seconds,low_url,high_url,hd_url,publish_date"
    o.Type = "normal"

    return o
End Function


'***********************************************************
'Given the xml element to an <Category> tag in the category
'feed, walk it and return the top level node to its tree
'***********************************************************
Function ParseCategoryNode(xml As Object) As dynamic
    o = init_category_item()

    print "ParseCategoryNode: " + xml.GetName()
    'PrintXML(xml, 5)


    'parse the curent node to determine the type. everything except
    'special categories are considered normal, others have unique types
    if xml.GetName() = "video_type" then
        print "category: " + xml.name.gettext() + " | " + xml.deck.gettext()
        o.Type = "normal"
        o.Title = xml.name.gettext()
        o.Description = xml.deck.gettext()
        o.ShortDescriptionLine1 = xml.name.gettext()
        o.ShortDescriptionLine2 = xml.deck.gettext()
        o.Feed = m.UrlPrefix + "/videos/?api_key=" + m.api_key + "&video_type=" + xml.id.gettext() + "&sort=-publish_date&field_list=name,deck,id,image,length_seconds,low_url,high_url,hd_url,publish_date"
        'o.SDPosterURL = xml@sd_img
        'o.HDPosterURL = xml@hd_img
    elseif xml.GetName() = "categoryLeaf" then
        o.Type = "normal"
    elseif xml.GetName() = "specialCategory" then
        if invalid <> xml.GetAttributes() then
            for each a in xml.GetAttributes()
                if a = "type" then
                    o.Type = xml.GetAttributes()[a]
                    print "specialCategory: " + xml@type + "|" + xml@title + " | " + xml@description
                    o.Title = xml@title
                    o.Description = xml@Description
                    o.ShortDescriptionLine1 = xml@Title
                    o.ShortDescriptionLine2 = xml@Description
                    o.SDPosterURL = xml@sd_img
                    o.HDPosterURL = xml@hd_img
                endif
            next
        endif
    else
        print "ParseCategoryNode skip: " + xml.GetName()
        return invalid
    endif

    'only continue processing if we are dealing with a known type
    'if new types are supported, make sure to add them to the list
    'and parse them correctly further downstream in the parser
    while true
        if o.Type = "normal" exit while
        if o.Type = "special_category" exit while
        print "ParseCategoryNode unrecognized feed type"
        return invalid
    end while

    'get the list of child nodes and recursed
    'through everything under the current node
    for each e in xml.GetBody()
        name = e.GetName()
        if name = "category" then
            print "category: " + e@title + " [" + e@description + "]"
            kid = ParseCategoryNode(e)
            kid.Title = e@title
            kid.Description = e@Description
            kid.ShortDescriptionLine1 = xml@Description
            kid.SDPosterURL = xml@sd_img
            kid.HDPosterURL = xml@hd_img
            o.AddKid(kid)
        elseif name = "categoryLeaf" then
            print "categoryLeaf: " + e@title + " [" + e@description + "]"
            kid = ParseCategoryNode(e)
            kid.Title = e@title
            kid.Description = e@Description
            kid.Feed = e@feed
            o.AddKid(kid)
        elseif name = "specialCategory" then
            print "specialCategory: " + e@title + " [" + e@description + "]"
            kid = ParseCategoryNode(e)
            kid.Title = e@title
            kid.Description = e@Description
            kid.sd_img = e@sd_img
            kid.hd_img = e@hd_img
            kid.Feed = e@feed
            o.AddKid(kid)
        endif
    next

    return o
End Function


'******************************************************
'Initialize a Category Item
'******************************************************
Function init_category_item() As Object
    o = CreateObject("roAssociativeArray")
    o.Title       = ""
    o.Type        = "normal"
    o.Description = ""
    o.Kids        = CreateObject("roArray", 5, true)
    o.Parent      = invalid
    o.Feed        = ""
    o.IsLeaf      = cn_is_leaf
    o.AddKid      = cn_add_kid
    return o
End Function


'********************************************************
'** Helper function for each node, returns true/false
'** indicating that this node is a leaf node in the tree
'********************************************************
Function cn_is_leaf() As Boolean
    'if m.Kids.Count() > 0 return true
    if m.Feed <> "" return false
    return true
End Function


'*********************************************************
'** Helper function for each node in the tree to add a
'** new node as a child to this node.
'*********************************************************
Sub cn_add_kid(kid As Object)
    if kid = invalid then
        print "skipping: attempt to add invalid kid failed"
        return
     endif

    kid.Parent = m
    m.Kids.Push(kid)
End Sub
