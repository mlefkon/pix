#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
# This makes the CGI fail fast so the HTTP response indicates failure.
set -e

printf "Content-Type: text/html\r\n\r\n"
printf "<html><head><title>Compile List</title><meta charset="utf-8" /></head>"
printf "<body>"
printf "<pre>"

printf "-------\n"
printf "REFRESH\n"
printf "-------\n"

printf "  Just regenerating gallery list from cached photos & thumbs.\n"

printf "\n"

START_TIME=$(date +%s)
rm -f /www/run/status





/usr/local/bin/compile_list.sh 2>&1;

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))
printf "\n"
printf "Done with 'Refresh Gallery'. Total run time: %d minute(s) %d second(s)\n" "$MINUTES" "$SECONDS"

printf "</pre>\n"
printf "<p><a href=\"/run/admin.html\">Back to Admin</a></p>"
printf "<p><a href=\"/?nocache=%s\">Back to Gallery</a></p>" $(date +%s)
printf "</body>"
printf "</html>"
