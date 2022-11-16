 pihole-FTL sqlite3  /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE enabled = 1 AND type = 0;" > exwhite.txt
 pihole-FTL sqlite3  /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE enabled = 1 AND type = 1;" > exblack.txt
 pihole-FTL sqlite3  /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE enabled = 1 AND type = 2;" > regwhite.txt
 pihole-FTL sqlite3  /etc/pihole/gravity.db "SELECT domain FROM domainlist WHERE enabled = 1 AND type = 3;" > regblack.txt


