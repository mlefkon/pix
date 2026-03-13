#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

echo "Starting Apache Pix Gallery @ $(date +"%Y.%m.%d %H:%M:%S")"

echo "Admin user: ${USER_ADMIN:-(none)}"
if [ -z "$USER_ADMIN" ]; then
    rm -f /www/run/.htaccess
else
    echo "  Basic auth will be enabled to access admin functions."
    touch /etc/apache2/.htpasswd.admin
    touch /etc/apache2/.htpasswd.user
    htpasswd -b /etc/apache2/.htpasswd.admin "$USER_ADMIN" "$USER_ADMIN"
    htpasswd -b /etc/apache2/.htpasswd.user  "$USER_ADMIN" "$USER_ADMIN"
fi

# USER_GUEST_CSV: assign multiple regular users to accomodate different languges, families, etc
echo "Guest users: ${USER_GUEST_CSV:-(none)}"
if [ -z "$USER_GUEST_CSV" ]; then
    rm -f /www/.htaccess
else
    echo "  Basic auth will be enabled to access site."
    touch /etc/apache2/.htpasswd.user
    IFS=',' read -ra USERS <<< "$USER_GUEST_CSV"
    for user in "${USERS[@]}"; do
        user_no_spaces=${user//[[:space:]]/}
        htpasswd -b /etc/apache2/.htpasswd.user "$user_no_spaces" "$user_no_spaces"
    done
fi

if [ -n "$INDEX_HTML_HEAD_TAG_INSERT" ]; then
    echo "Custom text to insert at the start of index.html's <HEAD> tag (eg. for Google Analytics, etc):"
    echo -e "  ${INDEX_HTML_HEAD_TAG_INSERT}"
    sed -i "s#<head>#<head>${INDEX_HTML_HEAD_TAG_INSERT}#" /www/index.html
fi

mkdir -p /www/media
mkdir -p /www/cache

rm -f /www/run/status
if [ -f /www/cache/media-list.js ]; then
  echo "Media list already exists, skipping compile_list.sh"
else
  echo "Media list does not exist, running compile_list.sh"
  su -s /bin/sh apache -c /usr/local/bin/compile_list.sh
fi

echo "Notes:"
echo "  Media files located at: /www/media"
echo "  If you add/remove media files, use admin interface to update cache: https://pix.leftek.com/run/admin.html"
echo "  Setup docker volumes to:"
echo "    /www/media  (host volume)"
echo "    /www/cache  (can be host or docker volume)"

echo "Entry Startup Complete. Starting Apache..."
httpd -D FOREGROUND    # Start Apache in foreground
