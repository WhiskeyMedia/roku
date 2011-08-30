'******************************************************
'**  Video Player Example Application -- Poster Screen
'**  November 2009
'**  Copyright (c) 2009 Roku Inc. All Rights Reserved.
'******************************************************

'******************************************************
'** Perform any startup/initialization stuff prior to
'** initially showing the screen.
'******************************************************
Function preShowPosterScreen(breadA=invalid, breadB=invalid) As Object

    if validateParam(breadA, "roString", "preShowPosterScreen", true) = false return -1
    if validateParam(breadB, "roString", "preShowPosterScreen", true) = false return -1

    port=CreateObject("roMessagePort")
    screen = CreateObject("roPosterScreen")
    screen.SetMessagePort(port)
    if breadA<>invalid and breadB<>invalid then
        screen.SetBreadcrumbText(breadA, breadB)
    end if

    screen.SetListStyle("arced-16x9")
    return screen

End Function


'******************************************************
'** Display the home screen and wait for events from
'** the screen. The screen will show retrieving while
'** we fetch and parse the feeds for the game posters
'******************************************************
Function showPosterScreen(screen As Object) As Integer

    if validateParam(screen, "roPosterScreen", "showPosterScreen") = false return -1

    m.curCategory = 0
    m.curShow = 0

    initCategoryList()
    categoryList = getCategoryList(m.Categories)
    screen.SetListNames(m.CategoryNames)
    screen.SetContentList(getShowsForCategoryItem(categoryList[m.curCategory]))
    screen.Show()

    load_category = false
    while true
        msg = wait(1000, screen.GetMessagePort())
        if type(msg) = "roPosterScreenEvent" then
            print "showPosterScreen | msg = "; msg.GetMessage() " | index = "; msg.GetIndex()
            if msg.isListFocused() then
                m.curCategory = msg.GetIndex()
                m.curShow = 0
                empty_list = CreateObject("roArray", 0, true)
                screen.SetContentList(empty_list)
                screen.ShowMessage("retrieving...")
                load_category = true
                print "list focused | current category = "; msg.GetIndex()
            else if msg.isListItemFocused() then
                print "list item focused | current show = "; msg.GetIndex()
            else if msg.isListItemSelected() then
                m.curShow = msg.GetIndex()
                print "list item selected | current show = "; m.curShow
                m.curShow = displayShowDetailScreen(categoryList[m.curCategory], m.curShow, m.showList)
                screen.setFocusedListItem(m.curShow)
            else if msg.isScreenClosed() then
                return -1
            end if
        end if

        if load_category = true and type(msg) = "Invalid" then
            'get the list of shows for the currently selected item
            screen.SetFocusedListItem(m.curShow)
            m.showList = getShowsForCategoryItem(categoryList[m.curCategory])
            screen.SetContentList(m.showList)
            load_category = false
        end if

    end while

End Function


'**********************************************************
'** When a poster on the home screen is selected, we call
'** this function passing an associative array with the
'** data for the selected show.  This data should be
'** sufficient for the show detail (springboard) to display
'**********************************************************
Function displayShowDetailScreen(category as Object, showIndex as Integer, showList as Object) As Integer

    if validateParam(category, "roAssociativeArray", "displayShowDetailScreen") = false return -1

    screen = preShowDetailScreen(category.Title)
    showIndex = showDetailScreen(screen, showList, showIndex)

    return showIndex

End Function


'**************************************************************
'** Given an roAssociativeArray representing a category node
'** from the category feed tree, return an roArray containing
'** the names of all of the sub categories in the list.
'***************************************************************
Function getCategoryList(categories as Object) As Object

    if validateParam(categories, "roAssociativeArray", "getCategoryList") = false return invalid

    categoryList = CreateObject("roArray", 20, true)
    for each category in categories.kids
        categoryList.Push(category)
    next

    return categoryList

End Function


'********************************************************************
'** Return the list of shows corresponding the currently selected
'** category in the filter banner.  As the user highlights a
'** category on the top of the poster screen, the list of posters
'** displayed should be refreshed to corrrespond to the highlighted
'** item.  This function returns the list of shows for that category
'********************************************************************
Function getShowsForCategoryItem(category As Object) As Object

    if validateParam(category, "roAssociativeArray", "getCategoryList") = false return invalid

    conn = InitShowFeedConnection(category)
    showList = conn.LoadShowFeed(conn)
    return showList

End Function


'************************************************************
'** initialize the category tree.  We fetch a category list
'** from the server, parse it into a hierarchy of nodes and
'** then use this to build the home screen and pass to child
'** screen in the heirarchy. Each node terminates at a list
'** of content for the sub-category describing individual videos
'************************************************************
Function initCategoryList() As Void

    conn = InitCategoryFeedConnection()

    m.Categories = conn.LoadCategoryFeed(conn)
    m.CategoryNames = conn.GetCategoryNames(m.Categories)

End Function
