#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
# This makes the CGI fail fast so the HTTP response indicates failure.
set -e

printf "Content-Type: text/html\r\n\r\n"
printf "<html><head><title>Refresh</title></head>"
printf "<body>"
printf "<pre>"

printf "--------------------------\n"
printf "GENERATE Gallery Web Media\n"
printf "--------------------------\n"

printf "  (NOT first deleting existing generated-for-web photos/thumbs - to nuke everything, run 'Nuke')\n"
printf "  (it is more reliable to use the 'screen' command and run: /www/run/generate )"
printf "\n"

START_TIME=$(date +%s)
rm -f /www/run/status

/usr/local/bin/generate_cache.sh 2>&1;
printf "\n"
/usr/local/bin/cull_orphans.sh 2>&1;  # clear orphans first, since media_list is generated off of webGenMedia, not orig media
printf "\n"
/usr/local/bin/compile_list.sh 2>&1;

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))
printf "\n"
printf "Done with 'Generate for Web'. Total run time: %d minute(s) %d second(s)\n" "$MINUTES" "$SECONDS"

printf "</pre>\n"
printf "<p><a href=\"/run/admin.html\">Back to Admin</a></p>"
printf "<p><a href=\"/?nocache=%s\">Back to Gallery</a></p>" $(date +%s)
printf "</body>"
printf "</html>"
