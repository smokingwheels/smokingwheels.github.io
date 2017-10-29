REM The Smokingwheels Personal Pi-Hole Log extractor.
REM Created on the 28 Oct 2017
REM Released on the 29 Oct 2017
REM To split things up and make it easy.
REM You have a web server in your Pi-Hole.
REM
REM Copy and Add the list in there  Pi-Hole's Block Lists http://192.168.1.5/fromlog
REM /var/www/html
REM
REM In memory of Nicola Tesla  www.youtube.com/watch?v=jtewnD7LyEI
REM
PRINT "Collect Log files from /var/log/  pihole.log is the one you want for the seperator part "
PRINT
TIMER ON
ON TIMER(1) GOSUB health

REM Change input to process older logs or different location
OPEN "/home/john/Downloads/qb64/pi-hole/logs/pihole.log" FOR INPUT AS #1

OPEN "/home/john/Downloads/qb64/pi-hole/logs/query" FOR OUTPUT AS #2
OPEN "/home/john/Downloads/qb64/pi-hole/logs/cached" FOR OUTPUT AS #3
OPEN "/home/john/Downloads/qb64/pi-hole/logs/config" FOR OUTPUT AS #4
OPEN "/home/john/Downloads/qb64/pi-hole/logs/forward" FOR OUTPUT AS #5
OPEN "/home/john/Downloads/qb64/pi-hole/logs/reply" FOR OUTPUT AS #6

OPEN "/home/john/Downloads/qb64/pi-hole/logs/indexoflog" FOR OUTPUT AS #10
PRINT #10, "index", "Query", "Cached", "Config", "Forward", "Reply", "spare"
'PRINT #10, "index", "Query", "Cached", "Config", "Forward", "Reply", "spare"
PRINT #6, "index", "Query", "Cached", "Config", "Forward", "Reply", "spare"
PRINT #5, "index", "Query", "Cached", "Config", "Forward", "Reply", "spare"
PRINT #4, "index", "Query", "Cached", "Config", "Forward", "Reply", "spare"
PRINT #3, "index", "Query", "Cached", "Config", "Forward", "Reply", "spare"
PRINT #2, "index", "Query", "Cached", "Config", "Forward", "Reply", "spare"

DO WHILE NOT EOF(1)
    LINE INPUT #1, a$
    Hz = Hz + 1
    PRINT #10, a, b, c, d, e, f, a$
    lline = LEN(a$)
    a = a + 1
    FOR i = 1 TO lline
        IF MID$(a$, i, 5) = "query" THEN
            PRINT #2, a, b, c, d, e, f, a$
            b = b + 1
        END IF
        IF MID$(a$, i, 6) = "cached" THEN
            PRINT #3, a, b, c, d, e, f, a$
            c = c + 1
        END IF
        IF MID$(a$, i, 6) = "config" THEN
            PRINT #4, a, b, c, d, e, f, a$
            d = d + 1
        END IF
        IF MID$(a$, i, 9) = "forwarded" THEN
            PRINT #5, a, b, c, d, e, f, a$
            d = d + 1
        END IF
        IF MID$(a$, i, 5) = "reply" THEN
            PRINT #6, a, b, c, d, e, f, a$
            f = f + 1
        END IF
    NEXT



LOOP


CLOSE #10: CLOSE #9: CLOSE #8: CLOSE #7: CLOSE #6: CLOSE #5: CLOSE #4: CLOSE #3: CLOSE #2: CLOSE #1: CLOSE #0
LOCATE 2, 1
PRINT "Lines in log file  "; a


OPEN "/home/john/Downloads/qb64/pi-hole/logs/fromlog" FOR APPEND AS #1
OPEN "/home/john/Downloads/qb64/pi-hole/logs/query" FOR INPUT AS #2
DO WHILE NOT EOF(2)
    LINE INPUT #2, a$
    Hz = Hz + 1

    lline = LEN(a$)
    b$ = LEFT$(a$, lline - 18)
    bline = LEN(b$)
    a$ = RIGHT$(b$, bline - 125)
    a = a + 1
    FOR i = 1 TO lline
        IF MID$(a$, i, 1) = "'" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "$" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "," THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "*" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "#" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "#" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "#" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "!" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF

        IF MID$(a$, i, 1) = "@" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "%" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "^" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "&" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "(" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = ")" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "_" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "+" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "=" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = CHR$(34) THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF

        IF MID$(a$, i, 1) = ";" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "<" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = ">" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "|" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "}" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        IF MID$(a$, i, 1) = "{" THEN
            PRINT #1, "0.0.0.0 " + a$
            b = b + 1
        END IF
        'IF MID$(a$, i, 1) = "" THEN
        'PRINT #2, "0.0.0.0 " + a$
        'b = b + 1
        'END IF


    NEXT

LOOP
CLOSE #1: CLOSE #2
LOCATE 3, 1
PRINT "There you go found maybe incorect number "; b
END




END

health:
LOCATE 1, 1
PRINT "Lines rate "; Hz
Hz = 0
RETURN



