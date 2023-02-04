Rem Have a play...Contact @smokingwheels....May the source be with you  #Linux...
Rem change line 253 in html format to you public Yacy address..
Rem http://www.qb64.net/ IDE Compiler Download Address.
Rem Dec 7 2016
DefInt A-Z
Const MAX_CLIENTS = 8
Const EXPIRY_TIME = 240 'seconds
Const MIDNIGHT_FIX_WINDOW = 60 * 60 'seconds
Const MAX_HEADER_SIZE = 4096 'bytes
Const DEFAULT_HOST = "192.168.1.20"



Const METHOD_HEAD = 1
Const METHOD_GET = 2
Const METHOD_POST = 3
Dim Shared CRLF As String
CRLF = Chr$(13) + Chr$(10)


'QB doesn't support variable-length strings in TYPEs :(
'This is sooooo ugly
'Important ones first
Dim client_handle(1 To MAX_CLIENTS) As Integer
Dim client_expiry(1 To MAX_CLIENTS) As Double
Dim client_request(1 To MAX_CLIENTS) As String
Dim client_uri(1 To MAX_CLIENTS) As String
Dim client_method(1 To MAX_CLIENTS) As Integer
Dim client_content_length(1 To MAX_CLIENTS) As Long

'These ones are less important
Dim client_host(1 To MAX_CLIENTS) As String
Dim client_browser(1 To MAX_CLIENTS) As String
Dim client_content_encoding(1 To MAX_CLIENTS) As Integer


connections = 0
host = _OpenHost("TCP/IP:8080")
Do
    'Process old connections
    If connections Then
        For c = 1 To MAX_CLIENTS
            If client_handle(c) Then
                'work on the request in an effort to finish it
                If try_complete_request(c) Then
                    Print "Completed request for: " + client_uri(c)
                    Print " from " + _ConnectionAddress(client_handle(c))
                    Print " using " + client_browser(c)
                    tear_down c
                    connections = connections - 1
                    'check for expiry
                ElseIf Timer >= client_expiry(c) And Timer < client_expiry(c) + MIDNIGHT_FIX_WINDOW Then
                    Print "TIMED OUT: request for: " + client_uri(c)
                    Print " from " + _ConnectionAddress(client_handle(c))
                    Print " using " + client_browser(c)
                    respond c, "HTTP/1.1 408 Request Timeout", ""
                    tear_down c
                    connections = connections - 1
                End If
            End If
        Next
    End If
    'Accept any new connections
    If connections < MAX_CLIENTS Then
        newclient = _OpenConnection(host) ' monitor host connection
        Do While newclient
            For c = 1 To MAX_CLIENTS
                If client_handle(c) = 0 Then
                    client_handle(c) = newclient
                    client_method(c) = 0
                    client_content_length(c) = -1
                    client_expiry(c) = Timer(.001) + EXPIRY_TIME
                    If client_expiry(c) >= 86400 Then client_expiry(c) = client_expiry(c) - 86400
                    Exit For
                End If
            Next
            connections = connections + 1
            If connections >= MAX_CLIENTS Then Exit Do
            newclient = _OpenConnection(host) ' monitor host connection
        Loop
    End If
    'Limit CPU usage and leave some time for stuff be sent across the network..I have it as high as 1000 on my Front End
    _Limit 50

Loop Until InKey$ <> "" ' any keypress quits
Close #host
System

Sub tear_down (c As Integer)
    Shared client_handle() As Integer, client_uri() As String
    Shared client_host() As String, client_browser() As String
    Shared client_request() As String

    Close #client_handle(c)
    'set handle to 0 so we know it's unused
    client_handle(c) = 0
    'set strings to empty to save memory
    client_uri(c) = ""
    client_host(c) = ""
    client_browser(c) = ""
    client_request(c) = ""

End Sub

Function try_complete_request% (c As Integer)
    Shared client_handle() As Integer, client_uri() As String
    Shared client_host() As String, client_browser() As String
    Shared client_content_length() As Long
    Shared client_request() As String, client_method() As Integer

    'Apparently QB64 doesn't support this yet
    'ON LOCAL ERROR GOTO runtime_internal_error
    Dim cur_line As String

    Get #client_handle(c), , s$
    If Len(s$) = 0 Then Exit Function
    'client_request is used to collect the client's request
    'when all the headers have arrived, they are stripped away from client_request
    client_request(c) = client_request(c) + s$

    If client_method(c) = 0 Then
        header_end = InStr(client_request(c), CRLF + CRLF)
        If header_end = 0 Then
            If Len(client_request(c)) > MAX_HEADER_SIZE Then GoTo large_request
            Exit Function
        End If

        'HTTP permits the use of multiple spaces/tabs and in some cases newlines
        'to separate words. So we collapse them.
        headers$ = shrinkspace(Left$(client_request(c), header_end + 1))
        client_request(c) = Mid$(client_request(c), header_end + 4)

        'This loop processes all the header lines
        first_line = 1
        Do
            linebreak = InStr(headers$, CRLF)
            If linebreak = 0 Then Exit Do

            cur_line = Left$(headers$, linebreak - 1)
            headers$ = Mid$(headers$, linebreak + 2)

            If first_line Then
                'First line looks something like
                'GET /index.html HTTP/1.1
                first_line = 0
                space = InStr(cur_line, " ")
                If space = 0 Then GoTo bad_request
                method$ = Left$(cur_line, space - 1)
                space2 = InStr(space + 1, cur_line, " ")
                If space2 = 0 Then GoTo bad_request
                client_uri(c) = Mid$(cur_line, space + 1, space2 - (space + 1))
                If Len(client_uri(c)) = 0 Then GoTo bad_request
                version$ = Mid$(cur_line, space2 + 1)
                Select Case method$
                    Case "GET"
                        client_method(c) = METHOD_GET
                    Case "HEAD"
                        client_method(c) = METHOD_HEAD
                    Case "POST"
                        client_method(c) = METHOD_POST
                    Case Else
                        GoTo unimplemented
                End Select
                Select Case version$
                    Case "HTTP/1.1"
                    Case "HTTP/1.0"
                    Case Else
                        GoTo bad_request
                End Select
            Else
                'These are of the form "Name: Value", e.g.
                'Host: www.qb64.net

                colon = InStr(cur_line, ": ")
                If colon = 0 Then GoTo bad_request
                header$ = LCase$(Left$(cur_line, colon - 1))
                value$ = Mid$(cur_line, colon + 2)
                Select Case header$
                    Case "cache-control"
                    Case "connection"
                    Case "date"
                    Case "pragma"
                    Case "trailer"
                    Case "transfer-encoding"
                        GoTo unimplemented
                    Case "upgrade"
                    Case "via"
                    Case "warning"

                    Case "accept"
                    Case "accept-charset"
                    Case "accept-encoding"
                    Case "accept-language"
                    Case "authorization"
                    Case "expect"
                    Case "from"
                    Case "host"
                        client_host(c) = value$
                    Case "if-match"
                    Case "if-modified-since"
                    Case "if-none-match"
                    Case "if-range"
                    Case "if-unmodified-Since"
                    Case "max-forwards"
                    Case "proxy-authorization"
                    Case "range"
                    Case "referer"
                    Case "te"
                    Case "user-agent"
                        client_browser(c) = value$

                    Case "allow"
                    Case "content-encoding"
                        If LCase$(value$) <> "identity" Then GoTo unimplemented
                    Case "content-language"
                    Case "content-length"
                        If Len(value$) <= 6 Then
                            client_content_length(c) = Val(value$)
                        Else
                            GoTo large_request
                        End If
                    Case "content-location"
                    Case "content-md5"
                    Case "content-range"
                    Case "content-type"
                    Case "expires"
                    Case "last-modified"

                    Case Else

                End Select
            End If

        Loop
        'All modern clients send a hostname, so this is mainly to prevent
        'ancient clients and bad requests from tripping us up
        If Len(client_host(c)) = 0 Then client_host(c) = DEFAULT_HOST
    End If

    'assume the request can be completed; set to 0 if it can't.
    try_complete_request = 1
    htmlstart$ = "<html><head></head><body>You requested<br /><tt>"
    Select Case client_method(c)
        Case METHOD_HEAD
            respond c, "HTTP/1.1 200 OK", ""
        Case METHOD_GET
            'Say something interesting
            html$ = "<html><head></head><body>You requested nothing <tt>"
            '        html$ = html$ + "<iframe src=" + CHR$(34) + "http://sw.remote.mx/" + CHR$(34) + " style=" + CHR$(34) + "border:1px  solid" + CHR$(59) + CHR$(34) + " name=" + CHR$(34) + "Street" + CHR$(34) + " scroling=" + CHR$(34) + "auto" + CHR$(34) + " frameborder=" + CHR$(34) + "yes" + " align=" + CHR$(34) + "center" + CHR$(34) + " height = " + CHR$(34) + "100%" + CHR$(34) + " width = " + CHR$(34) + "100%" + CHR$(34) + ">" + "</iframe>"

            html$ = html$ + client_uri(c) + "</tt><form action='/' method='post'>"
            Rem change address to suit your server and needs also can be an Android APP.
            html$ = html$ + "<iframe src=" + Chr$(34) + "http://192.168.1.15:8090/Crawler_p.html" + Chr$(34) + " style=" + Chr$(34) + "border:1px  solid" + Chr$(59) + Chr$(34) + " name=" + Chr$(34) + "Street" + Chr$(34) + " scroling=" + Chr$(34) + "auto" + Chr$(34) + " frameborder=" + Chr$(34) + "yes" + " align=" + Chr$(34) + "center" + Chr$(34) + " height = " + Chr$(34) + "50%" + Chr$(34) + " width = " + Chr$(34) + "75%" + Chr$(34) + ">" + "</iframe>"
            html$ = html$ + "<iframe src=" + Chr$(34) + "http://192.168.1.15:8090/IndexCreateLoaderQueue_p.html" + Chr$(34) + " style=" + Chr$(34) + "border:1px  solid" + Chr$(59) + Chr$(34) + " name=" + Chr$(34) + "Street" + Chr$(34) + " scroling=" + Chr$(34) + "auto" + Chr$(34) + " frameborder=" + Chr$(34) + "yes" + " align=" + Chr$(34) + "center" + Chr$(34) + " height = " + Chr$(34) + "100%" + Chr$(34) + " width = " + Chr$(34) + "100%" + Chr$(34) + ">" + "</iframe>"

            html$ = html$ + "<iframe src=" + Chr$(34) + "http://192.168.1.15:8090/Status.html" + Chr$(34) + " style=" + Chr$(34) + "border:1px  solid" + Chr$(59) + Chr$(34) + " name=" + Chr$(34) + "Street" + Chr$(34) + " scroling=" + Chr$(34) + "auto" + Chr$(34) + " frameborder=" + Chr$(34) + "yes" + " align=" + Chr$(34) + "center" + Chr$(34) + " height = " + Chr$(34) + "100%" + Chr$(34) + " width = " + Chr$(34) + "100%" + Chr$(34) + ">" + "</iframe>"

            html$ = html$ + "<iframe src=" + Chr$(34) + "http://192.168.1.15:8090/Performance_p.html" + Chr$(34) + " style=" + Chr$(34) + "border:1px  solid" + Chr$(59) + Chr$(34) + " name=" + Chr$(34) + "Street" + Chr$(34) + " scroling=" + Chr$(34) + "auto" + Chr$(34) + " frameborder=" + Chr$(34) + "yes" + " align=" + Chr$(34) + "center" + Chr$(34) + " height = " + Chr$(34) + "100%" + Chr$(34) + " width = " + Chr$(34) + "100%" + Chr$(34) + ">" + "</iframe>"

            html$ = html$ + "<iframe src=" + Chr$(34) + "http://192.168.1.15:8090/ConfigHTCache_p.html" + Chr$(34) + " style=" + Chr$(34) + "border:1px  solid" + Chr$(59) + Chr$(34) + " name=" + Chr$(34) + "Street" + Chr$(34) + " scroling=" + Chr$(34) + "auto" + Chr$(34) + " frameborder=" + Chr$(34) + "yes" + " align=" + Chr$(34) + "center" + Chr$(34) + " height = " + Chr$(34) + "100%" + Chr$(34) + " width = " + Chr$(34) + "100%" + Chr$(34) + ">" + "</iframe>"



            html$ = html$ + "<input type='text' name='var1' value='val1' />"
            html$ = html$ + "<input type='text' name='var2' value='val2' />"
            html$ = html$ + "<input type='submit' value='send a POST query'>"
            html$ = html$ + "</form></body></html>" + CRLF

            respond c, "HTTP/1.1 200 OK", html$

        Case METHOD_POST
            If Len(client_request(c)) < client_content_length(c) Then
                'message hasn't arrived yet or client disconnected
                try_complete_request = 0
            Else
                'Say something interesting
                html$ = "<html><head></head><body>You requested<br /><tt>"
                html$ = html$ + client_uri(c) + "</tt><br />and posted<br /><tt>"
                html$ = html$ + client_request(c) + "</tt><form action='/' method='get'>"
                html$ = html$ + "<input type='text' name='var1' value='val1' />"
                html$ = html$ + "<input type='text' name='var2' value='val2' />"
                html$ = html$ + "<input type='submit' value='send a GET query'>"
                html$ = html$ + "</form></body></html>" + CRLF

                respond c, "HTTP/1.1 200 OK", html$

            End If
        Case Else
            'This shouldn't happen because we would have EXITed FUNCTION earlier
            Print "ERROR: Unknown method. This should never happen."
    End Select


    Exit Function


    large_request:
    respond c, "HTTP/1.1 413 Request Entity Too Large", ""
    try_complete_request = 1
    Exit Function
    bad_request:
    respond c, "HTTP/1.1 400 Bad Request", ""
    try_complete_request = 1
    Exit Function
    unimplemented:
    respond c, "HTTP/1.1 501 Not Implemented", ""
    try_complete_request = 1
    Exit Function

    runtime_internal_error:
    Print "RUNTIME ERROR: Error code"; Err; ", Line"; _ErrorLine
    Resume internal_error
    internal_error:
    respond c, "HTTP/1.1 500 Internal Server Error", ""
    try_complete_request = 1
    Exit Function


End Function

Sub respond (c As Integer, header As String, payload As String)
    Shared client_handle() As Integer
    out$ = header + CRLF

    out$ = out$ + "Date: " + datetime + CRLF
    out$ = out$ + "Server: QweB64" + CRLF
    out$ = out$ + "Last-Modified: " + datetime + CRLF
    out$ = out$ + "Connection: close" + CRLF
    'out$ = out$ + "Keep-Alive: timeout=15, max=99" + CRLF
    'out$ = out$ + "Connection: Keep-Alive" + CRLF
    If Len(payload) Then
        out$ = out$ + "Content-Type: text/html; charset=UTF-8" + CRLF
        'out$ = out$ + "Transfer-Encoding: chunked" + CRLF
        out$ = out$ + "Content-Length:" + Str$(Len(payload)) + CRLF
    End If

    'extra newline to signify end of header
    out$ = out$ + CRLF
    Put #client_handle(c), , out$

    Put #client_handle(c), , payload

End Sub

Function datetime$ ()
    Static init As Integer
    Static day() As String, month() As String, monthtbl() As Integer
    If init = 0 Then
        init = 1
        ReDim day(0 To 6) As String
        ReDim month(0 To 11) As String
        ReDim monthtbl(0 To 11) As Integer
        day(0) = "Sun": day(1) = "Mon": day(2) = "Tue"
        day(3) = "Wed": day(4) = "Thu": day(5) = "Fri"
        day(6) = "Sat"
        month(0) = "Jan": month(1) = "Feb": month(2) = "Mar"
        month(3) = "Apr": month(4) = "May": month(5) = "Jun"
        month(6) = "Jul": month(7) = "Aug": month(8) = "Sep"
        month(9) = "Oct": month(10) = "Nov": month(11) = "Dec"
        'Source: Wikipedia
        monthtbl(0) = 0: monthtbl(1) = 3: monthtbl(2) = 3
        monthtbl(3) = 6: monthtbl(4) = 1: monthtbl(5) = 4
        monthtbl(6) = 6: monthtbl(7) = 2: monthtbl(8) = 5
        monthtbl(9) = 0: monthtbl(10) = 3: monthtbl(11) = 5
    End If
    temp$ = Date$ + " " + Time$
    m = Val(Left$(temp$, 2))
    d = Val(Mid$(temp$, 4, 2))
    y = Val(Mid$(temp$, 7, 4))
    c = 2 * (3 - (y \ 100) Mod 4)
    y2 = y Mod 100
    y2 = y2 + y2 \ 4
    m2 = monthtbl(m - 1)
    weekday = c + y2 + m2 + d

    'leap year and Jan/Feb
    If ((y Mod 4 = 0) And (y Mod 100 <> 0) Or (y Mod 400 = 0)) And m <= 2 Then weekday = weekday - 1

    weekday = weekday Mod 7

    datetime$ = day(weekday) + ", " + Left$(temp$, 2) + " " + month(m - 1) + " " + Mid$(temp$, 7) + " GMT"

End Function

Function shrinkspace$ (str1 As String)
    Do
        i = InStr(str1, Chr$(9))
        If i = 0 Then Exit Do
        Mid$(str1, i, 1) = " "
    Loop
    Do
        i = InStr(str1, CRLF + " ")
        If i = 0 Then Exit Do
        str1 = Left$(str1, i - 1) + Mid$(str1, i + 2)
    Loop
    Do
        i = InStr(str1, "  ")
        If i = 0 Then Exit Do
        str1 = Left$(str1, i - 1) + Mid$(str1, i + 1)
    Loop
    shrinkspace = str1
End Function


