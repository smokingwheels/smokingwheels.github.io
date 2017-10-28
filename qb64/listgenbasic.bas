REM https://pi-hole.net
REM  Network-wide ad blocking via your own Linux hardware.
REM Also creates hosts file.
OPEN "/home/john/Downloads/qb64/pi-hole/lists/hosts.txt" FOR OUTPUT AS #1

OPEN "/home/john/Downloads/qb64/pi-hole/lists/1" FOR INPUT AS #2
PRINT #1, "127.0.0.1 localhost #IPv4 localhost"
PRINT #1, "::1 localhost #IPv6 localhost"
PRINT "list 1"
PRINT #1, "# list 1"
DO WHILE NOT EOF(2)
    DO WHILE b < 9
        LINE INPUT #2, a$
        b = b + 1
    LOOP
    LINE INPUT #2, a$
    'parse list may need edit 127.0.0.1 also could be "0.0.0.0" + [CHR$(9) or CHR$(32)]
    PRINT #1, "0.0.0.0 " + a$
    a = a + 1
LOOP
CLOSE #2: b = 0
PRINT a
REM Add more loops as needed.
CLOSE #1

