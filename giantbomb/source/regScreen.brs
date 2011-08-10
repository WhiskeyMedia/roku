' *********************************************************
' **  Roku Registration Demonstration App
' **  Support routines
' **  May 2009
' **  Copyright (c) 2009 Roku Inc. All Rights Reserved.
' *********************************************************

'******************************************************
'Perform the registration flow
'
'Returns:
'    0 - We're registered. Proceed
'    1 - We're not registered. The user canceled the process.
'    2 - We're not registered. There was an error
'******************************************************

Function doRegistration() As Integer

   'xml responses are static, but there are a few flavors available for testing
   'Generic case: getRegResult (always returns success)
   'Failure case: getRegResult_failure (always returns failure)
   'Success case: getRegResult_success (always returns success)

    m.UrlBase         = "http://10.0.1.198:8000/roku"
    m.UrlGetRegCode   = m.UrlBase + "/get-code"
    m.UrlGetRegResult = m.UrlBase + "/get-result"
    m.UrlWebSite      = "www.giantbomb.com/roku"

    m.RegToken = loadRegistrationToken()
    if isLinked() then
        print "device already linked, skipping registration process"
        return 0
    endif

    regscreen = displayRegistrationScreen()

    'main loop get a new registration code, display it and check to see if its been linked
    while true

        duration = 0

        sn = GetDeviceESN()
        regCode = getRegistrationCode(sn)

        'if we've failed to get the registration code, bail out, otherwise we'll
        'get rid of the retreiving... text and replace it with the real code
        if regCode = "" then return 2
        regscreen.SetRegistrationCode(regCode)
        print "Enter registration code " + regCode + " at " + m.UrlWebSite + " for " + sn

        'make an http request to see if the device has been registered on the backend
        while true

            status = checkRegistrationStatus(sn, regCode)
            if status < 3 return status

            getNewCode = false
            retryInterval = getRetryInterval()
            retryDuration = getRetryDuration()
            print "retry duration "; itostr(duration); " at ";  itostr(retryInterval);
            print " sec intervals for "; itostr(retryDuration); " secs max"

            'wait for the retry interval to expire or the user to press a button
            'indicating they either want to quit or fetch a new registration code
            while true
                print "Wait for " + itostr(retryInterval)
                msg = wait(retryInterval * 1000, regscreen.GetMessagePort())
                duration = duration + retryInterval
                if msg = invalid exit while

                if type(msg) = "roCodeRegistrationScreenEvent"
                    if msg.isScreenClosed()
                        print "Screen closed"
                        return 1
                    elseif msg.isButtonPressed()
                        print "Button pressed: "; msg.GetIndex(); " " msg.GetData()
                        if msg.GetIndex() = 0
                            regscreen.SetRegistrationCode("retrieving code...")
                            getNewCode = true
                            exit while
                        endif
                        if msg.GetIndex() = 1 return 1
                    endif
                endif
            end while

            if duration > retryDuration exit while
            if getNewCode exit while

            print "poll prelink again..."
        end while
    end while

End Function


'********************************************************************
'** display the registration screen in its initial state with the
'** text "retreiving..." shown.  We'll get the code and replace it
'** in the next step after we have something onscreen for teh user
'********************************************************************
Function displayRegistrationScreen() As Object

    regsite   = "go to " + m.UrlWebsite
    regscreen = CreateObject("roCodeRegistrationScreen")
    regscreen.SetMessagePort(CreateObject("roMessagePort"))

    regscreen.SetTitle("")
    regscreen.AddParagraph("Please link your Roku player to your account by visiting")
    regscreen.AddFocalText(" ", "spacing-dense")
    regscreen.AddFocalText("From your computer,", "spacing-dense")
    regscreen.AddFocalText(regsite, "spacing-dense")
    regscreen.AddFocalText("and enter this code to activate:", "spacing-dense")
    regscreen.SetRegistrationCode("retrieving code...")
    regscreen.AddParagraph("This screen will automatically update as soon as your activation completes")
    regscreen.AddButton(0, "Get a new code")
    regscreen.AddButton(1, "Back")
    regscreen.Show()

    return regscreen

End Function


'********************************************************************
'** Fetch the prelink code from the registration service. return
'** valid registration code on success or an empty string on failure
'********************************************************************
Function getRegistrationCode(sn As String) As String

    if sn = "" then return ""

    http = NewHttp(m.UrlGetRegCode)
    http.AddParam("partner", "roku")
    http.AddParam("deviceID", sn)
    http.AddParam("deviceTypeName", "roku")

    rsp = http.Http.GetToString()
    xml = CreateObject("roXMLElement")
    print "GOT: " + rsp
    print "Reason: " + http.Http.GetFailureReason()

    if not xml.Parse(rsp) then
        print "Can't parse getRegistrationCode response"
        ShowConnectionFailed()
        return ""
    endif

    if xml.GetName() <> "result"
        Dbg("Bad register response: ",  xml.GetName())
        ShowConnectionFailed()
        return ""
    endif

    if islist(xml.GetBody()) = false then
        Dbg("No registration information available")
        ShowConnectionFailed()
        return ""
    endif

    'default values for retry logic
    retryInterval = 30  'seconds
    retryDuration = 900 'seconds (aka 15 minutes)
    regCode       = ""

    'handle validation of response fields
    for each e in xml.GetBody()
        if e.GetName() = "regCode" then
            regCode = e.GetBody()  'enter this code at website
        elseif e.GetName() = "retryInterval" then
            retryInterval = strtoi(e.GetBody())
        elseif e.GetName() = "retryDuration" then
            retryDuration = strtoi(e.GetBody())
        endif
    next

    if regCode = "" then
        Dbg("Parse yields empty registration code")
        ShowConnectionFailed()
    endif

    m.retryDuration = retryDuration
    m.retryInterval = retryInterval
    m.regCode = regCode

    return regCode

End Function


'******************************************************************
'** Check the status of the registration to see if we've linked
'** Returns:
'**     0 - We're registered. Proceed.
'**     1 - Reserved. Used by calling function.
'**     2 - We're not registered. There was an error, abort.
'**     3 - We're not registered. Keep trying.
'******************************************************************
Function checkRegistrationStatus(sn As String, regCode As String) As Integer

    http = NewHttp(m.UrlGetRegResult)
    http.AddParam("partner", "roku")
    http.AddParam("deviceID", sn)
    http.AddParam("regCode", regCode)

    print "checking registration status"

    while true
        rsp = http.Http.GetToString()
        xml = CreateObject("roXMLElement")
        if not xml.Parse(rsp) then
            print "Can't parse check registration status response"
            ShowConnectionFailed()
            return 2
        endif

        if xml.GetName() <> "result" then
            print "unexpected check registration status response: ", xml.GetName()
            ShowConnectionFailed()
            return 2
        endif

        if islist(xml.GetBody()) = true then
            for each e in xml.GetBody()
                if e.GetName() = "regToken" then
                    token = e.GetBody()

                    if token <> "" and token <> invalid then
                        print "obtained registration token: " + validstr(token)
                        saveRegistrationToken(token) 'commit it
                        m.RegistrationToken = token
                        showCongratulationsScreen()
                        return 0
                    else
                        return 3
                    endif
                elseif e.GetName() = "customerId" then
                    customerId = strtoi(e.GetBody())
                elseif e.GetName() = "creationTime" then
                    creationTime = strtoi(e.GetBody())
                endif
            next
        endif
    end while

    print "result: " + validstr(regToken) +  " for " + validstr(customerId) + " at " + validstr(creationTime)

    return 3

End Function


'***************************************************************
' The retryInterval is used to control how often we retry and
' check for registration success. its generally sent by the
' service and if this hasn't been done, we just return defaults
'***************************************************************
Function getRetryInterval() As Integer
    if m.retryInterval < 1 then m.retryInterval = 30
    return m.retryInterval
End Function


'**************************************************************
' The retryDuration is used to control how long we attempt to
' retry. this value is generally obtained from the service
' if this hasn't yet been done, we just return the defaults
'**************************************************************
Function getRetryDuration() As Integer
    if m.retryDuration < 1 then m.retryDuration = 900
    return m.retryDuration
End Function


'******************************************************
'Load/Save RegistrationToken to registry
'******************************************************

Function loadRegistrationToken() As dynamic
    m.RegToken =  RegRead("RegToken", "Authentication")
    if m.RegToken = invalid then m.RegToken = ""
    return m.RegToken
End Function

Sub saveRegistrationToken(token As String)
    RegWrite("RegToken", token, "Authentication")
End Sub

Sub deleteRegistrationToken()
    RegDelete("RegToken", "Authentication")
    m.RegToken = ""
End Sub

Function isLinked() As Dynamic
    if Len(m.RegToken) > 0  then return true
    return false
End Function

'******************************************************
'Show congratulations screen
'******************************************************
Sub showCongratulationsScreen()
    port = CreateObject("roMessagePort")
    screen = CreateObject("roParagraphScreen")
    screen.SetMessagePort(port)

    screen.AddHeaderText("Congratulations!")
    screen.AddParagraph("You have successfully linked your Roku player to your account")
    screen.AddParagraph("Select 'start' to begin.")
    screen.AddButton(1, "start")
    screen.Show()

    while true
        msg = wait(0, screen.GetMessagePort())

        if type(msg) = "roParagraphScreenEvent"
            if msg.isScreenClosed()
                print "Screen closed"
                exit while
            else if msg.isButtonPressed()
                print "Button pressed: "; msg.GetIndex(); " " msg.GetData()
                exit while
            else
                print "Unknown event: "; msg.GetType(); " msg: "; msg.GetMessage()
                exit while
            endif
        endif
    end while
End Sub

