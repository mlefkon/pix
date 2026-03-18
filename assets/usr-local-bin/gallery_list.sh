#!/bin/bash

set -e

printf "Running gallery_list.sh @ %s...\n" "$(date +"%Y.%m.%d %H:%M:%S")" | tee -a /www/run/status

START_TIME=$(date +%s)

PHOTO_DIR=/www/cache/photo  # only need to scan this dir, not media (irrelevant) or thumb (derived from photo).
OUT_FILE=/www/cache/media-list.new.js

mkdir -p "$(dirname "$OUT_FILE")"
echo "var pixMediaItems = [" > "$OUT_FILE"

COUNT_DIR=0
COUNT_FILE=0
FILES_PER_DOT=100
printf "    (one dot equals %d files listed)\n" "$FILES_PER_DOT" | tee -a /www/run/status

# Build a FLAT album list: each directory becomes an album entry with a unique ID
declare -A album_map_array
album_id=0
printf "  Listing albums" | tee -a /www/run/status
while IFS= read -r -d '' dirpath; do
    album_id=$((album_id+1))
    # Create Gallery List entry
    relDir=${dirpath#${PHOTO_DIR}/}  # relative to PHOTO_DIR    
    title=$(printf "%s" "$relDir" | sed 's#/#: #g')  # a list of all parent folders + current folder, separated by ": "
    imgFolder="/folder.svg"  # use a generic folder image for albums
    printf "  {src: \"%s\", title: \"%s\", ID: %d,\tkind:'album'},\n" "$imgFolder" "$title" "$album_id" >> "$OUT_FILE"
    
    album_map_array["$relDir"]=$album_id  # save album_id in K/V store for later reference by photo file entries
    printf "."
    COUNT_DIR=$((COUNT_DIR + 1))
done < <(find "$PHOTO_DIR" -mindepth 1 -type d -print0 | sort -z)  # use null char(\0) terminator - handles any file name
printf "\n"

# Now list files
printf "  Listing media" | tee -a /www/run/status
batch=
while IFS= read -r -d '' photoFilePath; do    # /www/cache/photo/1920s/lefkon_irving_1929.jpg.jpg
    photoFilename=$(basename "$photoFilePath")
    name_no_ext="${photoFilename%.*}" # % removes shortest pattern from end of string --> the dot-extension
    photoRelFilePath="${photoFilePath#${PHOTO_DIR}/}" # relative to PHOTO_DIR (including photo filename)
    photoWebPath="/cache/photo/$photoRelFilePath"
  
    # get thumb
    relDir=$(dirname "$photoRelFilePath") # photo rel dir is same as thumb rel dir
    thumbRelFilePath="$relDir/${name_no_ext}.thumb.jpg"
    thumbRelFilePath=${thumbRelFilePath#./}  # trim "./" just in case relDir was "." (root dir)
    thumbWebPath="/cache/thumb/$thumbRelFilePath"
    
    title="${name_no_ext%.*}"  # remove '.*' again to get rid of orig media's file extension.
    title="${title//./ }" # replace dots with spaces for readablility.
    
    albumID=${album_map_array["$relDir"]} # lookup albumID (if any) from K/V store
    if [ -n "$albumID" ]; then
        batch="$batch"$(printf "{src:\"%s\",srct:\"%s\",title:\"%s\",albumID:%s}," "$photoWebPath" "$thumbWebPath" "$title" "$albumID")"\n" # >> "$OUT_FILE"
    else
        batch="$batch"$(printf "{src:\"%s\",srct:\"%s\",title:\"%s\"}," "$photoWebPath" "$thumbWebPath" "$title")"\n" # >> "$OUT_FILE"
    fi
    COUNT_FILE=$((COUNT_FILE + 1))
        if [ $((COUNT_FILE % FILES_PER_DOT)) -eq 0 ]; then 
            echo -e "$batch" >> "$OUT_FILE"   # write to disk in batches of $FILES_PER_DOT
            batch=
            printf "."
        fi
        if [ $((COUNT_FILE % (FILES_PER_DOT * 50) )) -eq 0 ]; then 
            printf "\n    Listed %d" "$COUNT_FILE" | tee -a /www/run/status
        fi
done < <(find "$PHOTO_DIR" -type f -print0 | sort -z) # use null terminator(\0) so can handle special chars
if [ -n "$batch" ]; then
    echo -e "$batch" >> "$OUT_FILE" 
    # Note: Javascript doesn't care about trailing commas in arrays, so no need to remove trailing comma from last entry.
fi

echo "];" >> "$OUT_FILE"

rm -f /www/cache/media-list.js
mv "$OUT_FILE" /www/cache/media-list.js

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))
printf "\n  Generated gallery list with %d albums and %d files at %s (time: %dm%ds)\n" "$COUNT_DIR" "$COUNT_FILE" "$OUT_FILE" "$MINUTES" "$SECONDS" | tee -a /www/run/status

