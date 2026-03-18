#!/bin/sh
set -e

echo "Nuke start @ $(date +"%Y.%m.%d %H:%M:%S")" > /www/run/status

printf "Content-Type: text/html\r\n\r\n"
printf "<html><head><title>Refresh</title></head>"
printf "<body>"
printf "<pre>"

printf "--------------------------\n"
printf "NUKE ALL Gallery Web Media\n" | tee -a /www/run/status
printf "--------------------------\n"
#printf "WhoAmI: $(whoami)</br>\n"
printf "Deleting all existing generated photos...\n" | tee -a /www/run/status
rm -rf /www/cache/photo/* 2>&1 # > /dev/null 2>&1
printf "  and thumbnails...\n" | tee -a /www/run/status
rm -rf /www/cache/thumb/* 2>&1 # > /dev/null 2>&1
printf "  (original media has not been touched)\n" | tee -a /www/run/status
printf "Done.\n" | tee -a /www/run/status
printf "\n"
printf "Now a '<a href=\"./cache.cull.list.sh\">generate</a>' should be run to re-generate web-friendly photos and thumbnails."
printf "\n"

printf "</pre>\n"
printf "<p><a href=\"/run/admin.html\">Back to Admin</a></p>"
printf "<p><a href=\"/?nocache=%s\">Back to Gallery</a></p>" $(date +%s)
printf "</body>"
printf "</html>"

echo "Nuke done  @ $(date +"%Y.%m.%d %H:%M:%S")" >> /www/run/status
