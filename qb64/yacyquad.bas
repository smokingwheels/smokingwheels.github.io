REM Copyright Gregory B Smith 2017
REM Have a play...Contact @smokingwheels....May the source be with you  #Linux...
REM It is BASIC code for QB64. The source is 15 kb and the finished result is around 1.5 MB  Windows  Linux  Mac osx  Android. I have only tested on Old versions of windows.
REM http://www.qb64.net/ IDE Compiler Download Address. Search "QB64 Webserver". But Pete from the forum is the author credit to him. Cheers
REM Dec 7 2016

DEFINT A-Z
CONST MAX_CLIENTS = 40
CONST EXPIRY_TIME = 1980 'seconds
CONST MIDNIGHT_FIX_WINDOW = 60 * 60 'seconds
CONST MAX_HEADER_SIZE = 4096 'bytes
CONST DEFAULT_HOST = "192.168.1.10" ' Change to internal IP if you want to host it. Change to localhost for testing.



CONST METHOD_HEAD = 1
CONST METHOD_GET = 2
CONST METHOD_POST = 3
DIM SHARED CRLF AS STRING
CRLF = CHR$(13) + CHR$(10)


'QB doesn't support variable-length strings in TYPEs :(
'This is sooooo ugly
'Important ones first
DIM client_handle(1 TO MAX_CLIENTS) AS INTEGER
DIM client_expiry(1 TO MAX_CLIENTS) AS DOUBLE
DIM client_request(1 TO MAX_CLIENTS) AS STRING
DIM client_uri(1 TO MAX_CLIENTS) AS STRING
DIM client_method(1 TO MAX_CLIENTS) AS INTEGER
DIM client_content_length(1 TO MAX_CLIENTS) AS LONG

'These ones are less important
DIM client_host(1 TO MAX_CLIENTS) AS STRING
DIM client_browser(1 TO MAX_CLIENTS) AS STRING
DIM client_content_encoding(1 TO MAX_CLIENTS) AS INTEGER

connections = 0
host = _OPENHOST("TCP/IP:8080")
TIMER ON
ON TIMER(1) GOSUB health
DO

    'Process old connections
    IF connections THEN
        FOR c = 1 TO MAX_CLIENTS
            IF client_handle(c) THEN
                'work on the request in an effort to finish it
                IF try_complete_request(c) THEN
                    PRINT "Completed request for: " + client_uri(c)
                    PRINT " from " + _CONNECTIONADDRESS(client_handle(c))
                    PRINT " using " + client_browser(c)
                    tear_down c
                    connections = connections - 1
                    'check for expiry
                ELSEIF TIMER >= client_expiry(c) AND TIMER < client_expiry(c) + MIDNIGHT_FIX_WINDOW THEN
                    PRINT "TIMED OUT: request for: " + client_uri(c)
                    PRINT " from " + _CONNECTIONADDRESS(client_handle(c))
                    PRINT " using " + client_browser(c)
                    respond c, "HTTP/1.1 408 Request Timeout", ""
                    tear_down c
                    connections = connections - 1
                END IF
            END IF
        NEXT
    END IF
    'Accept any new connections
    IF connections < MAX_CLIENTS THEN
        newclient = _OPENCONNECTION(host) ' monitor host connection
        DO WHILE newclient
            FOR c = 1 TO MAX_CLIENTS
                IF client_handle(c) = 0 THEN
                    client_handle(c) = newclient
                    client_method(c) = 0
                    client_content_length(c) = -1
                    client_expiry(c) = TIMER(.001) + EXPIRY_TIME
                    IF client_expiry(c) >= 86400 THEN client_expiry(c) = client_expiry(c) - 86400
                    EXIT FOR
                END IF
            NEXT
            connections = connections + 1
            IF connections >= MAX_CLIENTS THEN EXIT DO
            newclient = _OPENCONNECTION(host) ' monitor host connection
        LOOP
    END IF
    'Limit CPU usage and leave some time for stuff be sent across the network..I have it as high as 1000 on my Front End
    _LIMIT 32767 ' Feel free to increase this figure my frontend is currently set at 1000
    Hz = Hz + 1
LOOP 'UNTIL INKEY$ <> "" ' any keypress quits
health:
LOCATE 1, 1
PRINT Hz
Hz = 0
RETURN

CLOSE #host
SYSTEM

SUB tear_down (c AS INTEGER)
SHARED client_handle() AS INTEGER, client_uri() AS STRING
SHARED client_host() AS STRING, client_browser() AS STRING
SHARED client_request() AS STRING

CLOSE #client_handle(c)
'set handle to 0 so we know it's unused
client_handle(c) = 0
'set strings to empty to save memory
client_uri(c) = ""
client_host(c) = ""
client_browser(c) = ""
client_request(c) = ""

END SUB

FUNCTION try_complete_request% (c AS INTEGER)
SHARED client_handle() AS INTEGER, client_uri() AS STRING
SHARED client_host() AS STRING, client_browser() AS STRING
SHARED client_content_length() AS LONG
SHARED client_request() AS STRING, client_method() AS INTEGER

'Apparently QB64 doesn't support this yet
'ON LOCAL ERROR GOTO runtime_internal_error
DIM cur_line AS STRING

GET #client_handle(c), , s$
IF LEN(s$) = 0 THEN EXIT FUNCTION
'client_request is used to collect the client's request
'when all the headers have arrived, they are stripped away from client_request
client_request(c) = client_request(c) + s$

IF client_method(c) = 0 THEN
    header_end = INSTR(client_request(c), CRLF + CRLF)
    IF header_end = 0 THEN
        IF LEN(client_request(c)) > MAX_HEADER_SIZE THEN GOTO large_request
        EXIT FUNCTION
    END IF

    'HTTP permits the use of multiple spaces/tabs and in some cases newlines
    'to separate words. So we collapse them.
    headers$ = shrinkspace(LEFT$(client_request(c), header_end + 1))
    client_request(c) = MID$(client_request(c), header_end + 4)

    'This loop processes all the header lines
    first_line = 1
    DO
        linebreak = INSTR(headers$, CRLF)
        IF linebreak = 0 THEN EXIT DO

        cur_line = LEFT$(headers$, linebreak - 1)
        headers$ = MID$(headers$, linebreak + 2)

        IF first_line THEN
            'First line looks something like
            'GET /index.html HTTP/1.1
            first_line = 0
            space = INSTR(cur_line, " ")
            IF space = 0 THEN GOTO bad_request
            method$ = LEFT$(cur_line, space - 1)
            space2 = INSTR(space + 1, cur_line, " ")
            IF space2 = 0 THEN GOTO bad_request
            client_uri(c) = MID$(cur_line, space + 1, space2 - (space + 1))
            IF LEN(client_uri(c)) = 0 THEN GOTO bad_request
            version$ = MID$(cur_line, space2 + 1)
            SELECT CASE method$
                CASE "GET"
                    client_method(c) = METHOD_GET
                CASE "HEAD"
                    client_method(c) = METHOD_HEAD
                CASE "POST"
                    client_method(c) = METHOD_POST
                CASE ELSE
                    GOTO unimplemented
            END SELECT
            SELECT CASE version$
                CASE "HTTP/1.1"
                CASE "HTTP/1.0"
                CASE ELSE
                    GOTO bad_request
            END SELECT
        ELSE
            'These are of the form "Name: Value", e.g.
            'Host: www.qb64.net

            colon = INSTR(cur_line, ": ")
            IF colon = 0 THEN GOTO bad_request
            header$ = LCASE$(LEFT$(cur_line, colon - 1))
            value$ = MID$(cur_line, colon + 2)
            SELECT CASE header$
                CASE "cache-control"
                CASE "connection"
                CASE "date"
                CASE "pragma"
                CASE "trailer"
                CASE "transfer-encoding"
                    GOTO unimplemented
                CASE "upgrade"
                CASE "via"
                CASE "warning"

                CASE "accept"
                CASE "accept-charset"
                CASE "accept-encoding"
                CASE "accept-language"
                CASE "authorization"
                CASE "expect"
                CASE "from"
                CASE "host"
                    client_host(c) = value$
                CASE "if-match"
                CASE "if-modified-since"
                CASE "if-none-match"
                CASE "if-range"
                CASE "if-unmodified-Since"
                CASE "max-forwards"
                CASE "proxy-authorization"
                CASE "range"
                CASE "referer"
                CASE "te"
                CASE "user-agent"
                    client_browser(c) = value$

                CASE "allow"
                CASE "content-encoding"
                    IF LCASE$(value$) <> "identity" THEN GOTO unimplemented
                CASE "content-language"
                CASE "content-length"
                    IF LEN(value$) <= 6 THEN
                        client_content_length(c) = VAL(value$)
                    ELSE
                        GOTO large_request
                    END IF
                CASE "content-location"
                CASE "content-md5"
                CASE "content-range"
                CASE "content-type"
                CASE "expires"
                CASE "last-modified"

                CASE ELSE

            END SELECT
        END IF

    LOOP
    'All modern clients send a hostname, so this is mainly to prevent
    'ancient clients and bad requests from tripping us up
    IF LEN(client_host(c)) = 0 THEN client_host(c) = DEFAULT_HOST
END IF

'assume the request can be completed; set to 0 if it can't.
try_complete_request = 1
htmlstart$ = "<html><head></head><body>You requested<br /><tt>"
SELECT CASE client_method(c)
    CASE METHOD_HEAD
        respond c, "HTTP/1.1 200 OK", ""
    CASE METHOD_GET
        'Say something interesting positive things
        m$ = "<html><head></head><body>You requested nothing <tt>"
        m$ = m$ + CHR$(34) + "<div style=3D" + CHR$(34) + "color:#000; background-color:#fff; font-family:E6A89E6A5B7E9AB94, dfkai-sb;font-size:16px" + CHR$(34) + ">"
        m$ = m$ + client_uri(c) + "</tt><form action='/' method='post'>"
        REM Iframe Target 3 for 4 yacy search servers change address to suit your server and needs also can be an Android APP.
        m$ = m$ + "<p>&nbsp;</p>"
        REM pi1 4TB
        m$ = m$ + "<iframe name" + CHR$(61) + "" + CHR$(34) + "target3" + CHR$(34) + ""
        m$ = m$ + "src" + CHR$(61) + "" + CHR$(34) + "http" + CHR$(58) + "" + CHR$(47) + "" + CHR$(47) + "192.168.1.15" + CHR$(58) + "8090" + CHR$(47) + "yacyinteractive" + CHR$(46) + "html" + CHR$(63) + "display" + CHR$(61) + "2" + CHR$(34) + ""
        m$ = m$ + "width" + CHR$(61) + "" + CHR$(34) + "100" + CHR$(37) + "" + CHR$(34) + ""
        m$ = m$ + "height" + CHR$(61) + "" + CHR$(34) + "280" + CHR$(34) + ""
        m$ = m$ + "frameborder" + CHR$(61) + "" + CHR$(34) + "0" + CHR$(34) + ""
        m$ = m$ + "scrolling" + CHR$(61) + "" + CHR$(34) + "auto" + CHR$(34) + ""
        m$ = m$ + "id" + CHR$(61) + "" + CHR$(34) + "target3" + CHR$(34) + ">"
        m$ = m$ + "<" + CHR$(47) + "iframe>"
        m$ = m$ + "<p>&nbsp;</p>"
        REM pi2 meneie and mow
        m$ = m$ + "<iframe name" + CHR$(61) + "" + CHR$(34) + "target3" + CHR$(34) + ""
        m$ = m$ + "src" + CHR$(61) + "" + CHR$(34) + "http" + CHR$(58) + "" + CHR$(47) + "" + CHR$(47) + "sw" + CHR$(46) + "undo" + CHR$(46) + "it" + CHR$(58) + "8094" + CHR$(47) + "yacyinteractive" + CHR$(46) + "html" + CHR$(63) + "display" + CHR$(61) + "2" + CHR$(34) + ""
        m$ = m$ + "width" + CHR$(61) + "" + CHR$(34) + "100" + CHR$(37) + "" + CHR$(34) + ""
        m$ = m$ + "height" + CHR$(61) + "" + CHR$(34) + "280" + CHR$(34) + ""
        m$ = m$ + "frameborder" + CHR$(61) + "" + CHR$(34) + "0" + CHR$(34) + ""
        m$ = m$ + "scrolling" + CHR$(61) + "" + CHR$(34) + "auto" + CHR$(34) + ""
        m$ = m$ + "id" + CHR$(61) + "" + CHR$(34) + "target3" + CHR$(34) + ">"
        m$ = m$ + "<" + CHR$(47) + "iframe>"
        m$ = m$ + "<p>&nbsp;</p>"
        REM Quad nah_nana+nah
        m$ = m$ + "<iframe name" + CHR$(61) + "" + CHR$(34) + "target3" + CHR$(34) + ""
        m$ = m$ + "src" + CHR$(61) + "" + CHR$(34) + "http" + CHR$(58) + "" + CHR$(47) + "" + CHR$(47) + "sw" + CHR$(46) + "undo" + CHR$(46) + "it" + CHR$(58) + "8092" + CHR$(47) + "yacyinteractive" + CHR$(46) + "html" + CHR$(63) + "display" + CHR$(61) + "2" + CHR$(34) + ""
        m$ = m$ + "width" + CHR$(61) + "" + CHR$(34) + "100" + CHR$(37) + "" + CHR$(34) + ""
        m$ = m$ + "height" + CHR$(61) + "" + CHR$(34) + "280" + CHR$(34) + ""
        m$ = m$ + "frameborder" + CHR$(61) + "" + CHR$(34) + "0" + CHR$(34) + ""
        m$ = m$ + "scrolling" + CHR$(61) + "" + CHR$(34) + "auto" + CHR$(34) + ""
        m$ = m$ + "id" + CHR$(61) + "" + CHR$(34) + "target3" + CHR$(34) + ">"
        m$ = m$ + "<" + CHR$(47) + "iframe>"
        m$ = m$ + "<p>&nbsp;</p>"
        m$ = m$ + "<iframe name" + CHR$(61) + "" + CHR$(34) + "target3" + CHR$(34) + ""
        m$ = m$ + "src" + CHR$(61) + "" + CHR$(34) + "http" + CHR$(58) + "" + CHR$(47) + "" + CHR$(47) + "sw" + CHR$(46) + "undo" + CHR$(46) + "it" + CHR$(58) + "8093" + CHR$(47) + "yacyinteractive" + CHR$(46) + "html" + CHR$(63) + "display" + CHR$(61) + "2" + CHR$(34) + ""
        m$ = m$ + "width" + CHR$(61) + "" + CHR$(34) + "100" + CHR$(37) + "" + CHR$(34) + ""
        m$ = m$ + "height" + CHR$(61) + "" + CHR$(34) + "280" + CHR$(34) + ""
        m$ = m$ + "frameborder" + CHR$(61) + "" + CHR$(34) + "0" + CHR$(34) + ""
        m$ = m$ + "scrolling" + CHR$(61) + "" + CHR$(34) + "auto" + CHR$(34) + ""
        m$ = m$ + "id" + CHR$(61) + "" + CHR$(34) + "target3" + CHR$(34) + ">"
        m$ = m$ + "<" + CHR$(47) + "iframe>"
        m$ = m$ + "<p>&nbsp;</p>"
        m$ = m$ + "<p>Bought a new long bit of string is was worth 10 mS</p>"
        m$ = m$ + "<p>It cost more than Money and a car was it worth it?</p>"
        m$ = m$ + "<p>&nbsp;</p>"
        m$ = m$ + "<p>Running a YaCy Search Engine on a RaspberryPi JAVA_ARGS and hosts file it does really brake things study the list carefully before use </p>"
        m$ = m$ + "<p> -XX:+UseParNewGC -XX:ParallelGCThreads=2 </p>"
        m$ = m$ + "<p>hosts file Download <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "https://github.com/smokingwheels/Yacy_front_end/blob/master/hosts" + CHR$(34) + "> hosts </a><p>"
        m$ = m$ + "<p>&nbsp;</p>"
        m$ = m$ + "<p>Running a YaCy Search Engine on a Normal PC and 64 bit JAVA_ARGS</p>"
        m$ = m$ + "<p> -XX:+UseParNewGC -XX:ParallelGCThreads=4 -d64</p>"
        m$ = m$ + "<p>&nbsp;</p>"
        m$ = m$ + "<input type='text' name='var1' value='val1' />"
        m$ = m$ + "<input type='text' name='var2' value='val2' />"
        m$ = m$ + "<input type='submit' value='send a GET Query'>"

        'Say interesting Negatve things in a positive way

        m$ = m$ + "<p>Whats you best? Programing under the infulence??? score</p>"
        m$ = m$ + "<a href=" + CHR$(34) + "https://twitter.com/intent/tweet" + CHR$(63) + "button_hashtag" + CHR$(61) + "LoveTwitter" + CHR$(38) + "ref_src" + CHR$(61) + "twsrc" + CHR$(37) + "5Etfw" + "class" + CHR$(61) + CHR$(34) + "twitter" + CHR$(45) + "hashtag" + CHR$(45) + "button" + CHR$(34) + "data" + CHR$(45) + "show" + CHR$(45) + "count" + CHR$(61) + CHR$(34) + "false" + CHR$(34) + ">Tweet " + CHR$(35) + "LoveTwitter</a><script async src" + CHR$(61) + CHR$(34) + "//platform.twitter.com/widgets.js" + CHR$(34) + "charset" + CHR$(61) + CHR$(34) + "utf" + CHR$(45) + "8" + CHR$(34) + "></script>"
        m$ = m$ + "<p>Video  <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "https://youtu.be/_bP6aVG6L1w" + CHR$(34) + "> Video </a><p>"
        m$ = m$ + "<p>Video  <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "https://youtu.be/JGftIcp2SC0" + CHR$(34) + "> Video </a><p>"
        m$ = m$ + "<p>Sound  <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "https://soundcloud.com/smokingwheels/std-timing-reving" + CHR$(34) + "> Sound </a><p>"
        m$ = m$ + "<p>Sound  <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "https://soundcloud.com/smokingwheels/carbie-at-8-btdc-vol-up" + CHR$(34) + "> Sound </a><p>"
        m$ = m$ + "<p>Video  <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "https://soundcloud.com/smokingwheels/carbie-at-8-btdc" + CHR$(34) + "> Sound </a><p>"
        m$ = m$ + "<p>Video  <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "https://youtu.be/3f2g4RMfhS0" + CHR$(34) + "> Video </a><p>"
        m$ = m$ + "<p>Video  <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "https://youtu.be/UvVlIaTuSts" + CHR$(34) + "> Video </a><p>"
        m$ = m$ + "<p>Video  <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "https://youtu.be/uC3WUxrnbeE" + CHR$(34) + "> Video </a><p>"
        m$ = m$ + "<p>Video  <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "https://youtu.be/QRpqQvsU96c" + CHR$(34) + "> Video </a><p>"
        m$ = m$ + "<p>Search <a title=" + CHR$(34) + "" + CHR$(34) + "href=" + CHR$(34) + "http://sw.undo.it" + CHR$(58) + "8080" + CHR$(34) + "> Home </a><p>"
        m$ = m$ + "<p>&nbsp;</p>"
        m$ = m$ + "<p>Program editor from <a title=" + CHR$(34) + "QB64" + CHR$(34) + "href=" + CHR$(34) + "http://www.qb64.net/" + CHR$(34) + ">QB64</a><p>"
        m$ = m$ + "<p>BB Code  " + CHR$(91) + "url=http://www.qb64.net/" + CHR$(93) + "QB64" + CHR$(91) + "/url" + CHR$(93) + "<p>"
        m$ = m$ + "<p>Forum <a title=" + CHR$(34) + "QB64 Forum" + CHR$(34) + "href=" + CHR$(34) + "http://www.qb64.net/forum" + CHR$(34) + ">QB64 Forum</a><p>"
        m$ = m$ + "<p>BB Code  " + CHR$(91) + "url=http://www.qb64.net/Forum" + CHR$(93) + "QB64 Forum" + CHR$(91) + "/url" + CHR$(93) + "<p>"
        m$ = m$ + "<p>Yacy Search <a title=" + CHR$(34) + "YaCy Search" + CHR$(34) + "href=" + CHR$(34) + "http://yacy.net" + CHR$(34) + ">YaCy Home</a><p>"
        m$ = m$ + "<p>BB Code  " + CHR$(91) + "url=http://yacy.net" + CHR$(93) + "YaCy Home" + CHR$(91) + "/url" + CHR$(93) + "<p>"
        m$ = m$ + "<p>Double Rainbows <a title=" + CHR$(34) + "Double Rainbows" + CHR$(34) + "href=" + CHR$(34) + "https://www.physicsforums.com/threads/double-rainbows-and-the-direction-of-its-colors.924102/" + CHR$(34) + ">PhysicsForum Home</a><p>"
        m$ = m$ + "<p>BB Code  " + CHR$(91) + "url=https://www.physicsforums.com/threads/double-rainbows-and-the-direction-of-its-colors.924102/" + CHR$(93) + "Physics Forum Home" + CHR$(91) + "/url" + CHR$(93) + "<p>"
        m$ = m$ + "<p>Yacy Search <a title=" + CHR$(34) + "YaCy Search" + CHR$(34) + "href=" + CHR$(34) + "http://yacy.net" + CHR$(34) + ">YaCy Home</a><p>"
        m$ = m$ + "<p>BB Code  " + CHR$(91) + "url=http://yacy.net" + CHR$(93) + "YaCy Home" + CHR$(91) + "/url" + CHR$(93) + "<p>"
        m$ = m$ + "<p>&nbsp;</p>"
        m$ = m$ + "<p>Contact: howbighdd@yahoo.com</p>"
        m$ = m$ + "<p>Dead time 4 times" + "<a title=" + CHR$(34) + "Performance Report" + CHR$(34) + "href=" + CHR$(34) + "https://gtmetrix.com/reports/sw.undo.it/OkwLMUa7" + CHR$(34) + ">Report = Performance</a><p>"
        m$ = m$ + "<p>Fifth tri on number one?  " + CHR$(91) + "url=https://gtmetrix.com/reports/sw.undo.it/OkwLMUa7" + CHR$(93) + "Performance Report " + CHR$(91) + "/url" + CHR$(93) + "<p>"
        m$ = m$ + "</form></div></body></html>" + CRLF
        respond c, "HTTP/1.1 200 OK", m$

    CASE METHOD_POST
        IF LEN(client_request(c)) < client_content_length(c) THEN
            'message hasn't arrived yet or client disconnected
            try_complete_request = 0
        ELSE
            'Say something interesting
            m$ = "<html><head></head><body>You requested<br /><tt>"
            m$ = m$ + client_uri(c) + "</tt><br />and posted<br /><tt>"
            m$ = m$ + client_request(c) + "</tt><form action='/' method='get'>"
            m$ = m$ + "<input type='text' name='var1' value='val1' />"
            m$ = m$ + "<input type='text' name='var2' value='val2' />"
            m$ = m$ + "<input type='submit' value='send a GET query'>"
            m$ = m$ + "<p>Try and Drop out of the Rat Race tonight</p>"
            m$ = m$ + "<p>People have a problem when someone leaves or goes slow</p>"
            m$ = m$ + "<p>Whats you best? Programing under the infulence??? score</p>"
            'm$ = m$ + "<p></p>"
            'm$ = m$ + "<p></p>"
            'm$ = m$ + "<p></p>"
            'm$ = m$ + "<p></p>"
            'm$ = m$ + "<p></p>"
            'm$ = m$ + "<p></p>"
            'm$ = m$ + "<p></p>"
            'm$ = m$ + "<p></p>"

            m$ = m$ + "</form></body></html>" + CRLF

            respond c, "HTTP/1.1 200 OK", m$

        END IF
    CASE ELSE
        'This shouldn't happen because we would have EXITed FUNCTION earlier
        PRINT "ERROR: Unknown method. This should never happen."
END SELECT


EXIT FUNCTION


large_request:
respond c, "HTTP/1.1 413 Request Entity Too Large", ""
try_complete_request = 1
EXIT FUNCTION
bad_request:
respond c, "HTTP/1.1 400 Bad Request", ""
try_complete_request = 1
EXIT FUNCTION
unimplemented:
respond c, "HTTP/1.1 501 Not Implemented", ""
try_complete_request = 1
EXIT FUNCTION

runtime_internal_error:
PRINT "RUNTIME ERROR: Error code"; ERR; ", Line"; _ERRORLINE
RESUME internal_error
internal_error:
respond c, "HTTP/1.1 500 Internal Server Error", ""
try_complete_request = 1
EXIT FUNCTION


END FUNCTION

SUB respond (c AS INTEGER, header AS STRING, payload AS STRING)
SHARED client_handle() AS INTEGER
out$ = header + CRLF

out$ = out$ + "Date: " + datetime + CRLF
out$ = out$ + "Server: QweB64" + CRLF
out$ = out$ + "Last-Modified: " + datetime + CRLF
out$ = out$ + "Connection: close" + CRLF
'out$ = out$ + "Keep-Alive: timeout=15, max=99" + CRLF
'out$ = out$ + "Connection: Keep-Alive" + CRLF
IF LEN(payload) THEN
    out$ = out$ + "Content-Type: text/html; charset=UTF-8" + CRLF
    'out$ = out$ + "Transfer-Encoding: chunked" + CRLF
    out$ = out$ + "Content-Length:" + STR$(LEN(payload)) + CRLF
END IF

'extra newline to signify end of header
out$ = out$ + CRLF
PUT #client_handle(c), , out$

PUT #client_handle(c), , payload

END SUB

FUNCTION datetime$ ()
STATIC init AS INTEGER
STATIC day() AS STRING, month() AS STRING, monthtbl() AS INTEGER
IF init = 0 THEN
    init = 1
    REDIM day(0 TO 6) AS STRING
    REDIM month(0 TO 11) AS STRING
    REDIM monthtbl(0 TO 11) AS INTEGER
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
END IF
temp$ = DATE$ + " " + TIME$
m = VAL(LEFT$(temp$, 2))
d = VAL(MID$(temp$, 4, 2))
y = VAL(MID$(temp$, 7, 4))
c = 2 * (3 - (y \ 100) MOD 4)
y2 = y MOD 100
y2 = y2 + y2 \ 4
m2 = monthtbl(m - 1)
weekday = c + y2 + m2 + d

'leap year and Jan/Feb
IF ((y MOD 4 = 0) AND (y MOD 100 <> 0) OR (y MOD 400 = 0)) AND m <= 2 THEN weekday = weekday - 1

weekday = weekday MOD 7

datetime$ = day(weekday) + ", " + LEFT$(temp$, 2) + " " + month(m - 1) + " " + MID$(temp$, 7) + " GMT"

END FUNCTION

FUNCTION shrinkspace$ (str1 AS STRING)
DO
    i = INSTR(str1, CHR$(9))
    IF i = 0 THEN EXIT DO
    MID$(str1, i, 1) = " "
LOOP
DO
    i = INSTR(str1, CRLF + " ")
    IF i = 0 THEN EXIT DO
    str1 = LEFT$(str1, i - 1) + MID$(str1, i + 2)
LOOP
DO
    i = INSTR(str1, "  ")
    IF i = 0 THEN EXIT DO
    str1 = LEFT$(str1, i - 1) + MID$(str1, i + 1)
LOOP
shrinkspace = str1
END FUNCTION


