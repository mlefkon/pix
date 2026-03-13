#!/bin/bash
set -e   # Exit on error: stop if any command fails.

START_TIME=$(date +%s)

MEDIA_DIR=/www/media
PHOTO_DIR=/www/cache/photo
THUMB_DIR=/www/cache/thumb

mkdir -p "$MEDIA_DIR"
mkdir -p "$PHOTO_DIR"
mkdir -p "$THUMB_DIR"

printf "\n" | tee -a /www/run/status
printf "Running cull_orphans.sh @ %s...\n" "$(date +"%Y.%m.%d %H:%M:%S")" | tee -a /www/run/status
# Test if MEDIA_DIR has any accessible files
if [ "$(find "$MEDIA_DIR" -type f 2>/dev/null | wc -l)" -eq 0 ]; then
    echo "  ERROR: MEDIA_DIR is inaccessable or has no files"
    exit 0
fi

printf "  Scanning files" | tee -a /www/run/status
(cd /www/media       && find -type f ! \( -iname "*.txt" -o -iname "*.zip" -o -iname "*.gz" -o -iname "Thumbs.db" \) | sort > /tmp/media.txt)
printf "." | tee -a /www/run/status
(cd /www/cache/photo && find -type f | sed -e 's/\.jpg$//' -e 's/\.webm$//' | sort > /tmp/photo.txt)
printf "." | tee -a /www/run/status
(cd /www/cache/thumb && find -type f | sed -e 's/\.thumb\.jpg$//'           | sort > /tmp/thumb.txt)
printf ".\n" | tee -a /www/run/status

printf "    Computing orphans" | tee -a /www/run/status
comm -13 /tmp/media.txt /tmp/photo.txt > /tmp/photo.orphans.txt
printf "." | tee -a /www/run/status
comm -13 /tmp/media.txt /tmp/thumb.txt > /tmp/thumb.orphans.txt
printf ".\n" | tee -a /www/run/status


printf "  Removing any orphaned thumbs (%d files)\n" $(wc -l < /tmp/thumb.orphans.txt) | tee -a /www/run/status
xargs -a /tmp/thumb.orphans.txt -I {} sh -c 'rm -v "/www/cache/thumb/{}.thumb.jpg"' | tee -a /www/run/status
printf "  Removing any orphaned photos (%d files)\n" $(wc -l < /tmp/photo.orphans.txt) | tee -a /www/run/status
xargs -a /tmp/photo.orphans.txt -I {} sh -c '
    if [ -e "/www/cache/photo/{}.jpg" ];  then rm -v "/www/cache/photo/{}.jpg";  fi; 
    if [ -e "/www/cache/photo/{}.webm" ]; then rm -v "/www/cache/photo/{}.webm"; fi;' | tee -a /www/run/status

printf "  Removing any empty photo directories\n" | tee -a /www/run/status
find "$PHOTO_DIR" -depth -type d -empty -exec rmdir -v {} \; | tee -a /www/run/status
printf "  Removing any empty thumb directories\n" | tee -a /www/run/status
find "$THUMB_DIR" -depth -type d -empty -exec rmdir -v {} \; | tee -a /www/run/status

# Verify
printf "  Rescanning" | tee -a /www/run/status
    (cd /www/cache/photo && find -type f | sed -e 's/\.jpg$//' -e 's/\.webm$//' | sort > /tmp/photo.txt)
    printf "." | tee -a /www/run/status
    (cd /www/cache/thumb && find -type f | sed -e 's/\.thumb\.jpg$//'           | sort > /tmp/thumb.txt)
    printf ".\n" | tee -a /www/run/status
MEDIA_cnt=$(wc -l < /tmp/media.txt)
PHOTO_cnt=$(wc -l < /tmp/photo.txt)
THUMB_cnt=$(wc -l < /tmp/thumb.txt)
if [ "$MEDIA_cnt" -ne "$PHOTO_cnt" ] || [ "$PHOTO_cnt" -ne "$THUMB_cnt" ]; then
  printf '  Warning: File counts do not match !!!\n' | tee -a /www/run/status
  printf "    Verification Count:\n" | tee -a /www/run/status
  printf "      MEDIA files: %d\n" "$MEDIA_cnt" | tee -a /www/run/status
  printf "      CACHED:\n" | tee -a /www/run/status
  printf "        PHOTO files: %d\n" "$PHOTO_cnt" | tee -a /www/run/status
  printf "        THUMB files: %d\n" "$THUMB_cnt" | tee -a /www/run/status
  printf "    'Generate' may need to be re-run.  Either:\n" | tee -a /www/run/status
  printf "      - ffmpeg has failed on processing some media files, or\n" | tee -a /www/run/status
  printf "      - Generate has not been run yet, so some files are missing.\n" | tee -a /www/run/status
  printf "    Listing media files that are missing cached photos/thumbs:\n" | tee -a /www/run/status

  comm -23 /tmp/media.txt /tmp/photo.txt > /tmp/media.missing.photo.txt
  comm -23 /tmp/media.txt /tmp/thumb.txt > /tmp/media.missing.thumb.txt
  if [ $(comm -23 /tmp/media.missing.photo.txt /tmp/media.missing.thumb.txt | wc -l) -ne 0 ]; then
    printf "      Missing Photos:\n" | tee -a /www/run/status
    comm -23 /tmp/media.missing.photo.txt /tmp/media.missing.thumb.txt | tee -a /www/run/status
  fi
  if [ $(comm -13 /tmp/media.missing.photo.txt /tmp/media.missing.thumb.txt | wc -l) -ne 0 ]; then
    printf "      Missing Thumbs:\n" | tee -a /www/run/status
    comm -13 /tmp/media.missing.photo.txt /tmp/media.missing.thumb.txt | tee -a /www/run/status
  fi
  if [ $(comm -12 /tmp/media.missing.photo.txt /tmp/media.missing.thumb.txt | wc -l) -ne 0 ]; then
    printf "      Missing Photos & Thumbs:\n" | tee -a /www/run/status
    comm -12 /tmp/media.missing.photo.txt /tmp/media.missing.thumb.txt | tee -a /www/run/status
  fi
else
  printf "  Verification: All media/photo/thumb file counts match\n" | tee -a /www/run/status
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))
printf "  Done culling unneeded cache files (time: %dm%ds).\n" "$MINUTES" "$SECONDS" | tee -a /www/run/status
