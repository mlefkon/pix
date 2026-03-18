#!/bin/bash
set -e  # # Exit on error: stop if any command fails while generating thumbnails.

START_TIME=$(date +%s)

MEDIA_DIR=/www/media
PHOTO_DIR=/www/cache/photo
THUMB_DIR=/www/cache/thumb

mkdir -p "$MEDIA_DIR"
mkdir -p "$PHOTO_DIR"
mkdir -p "$THUMB_DIR"

# minimum thumbnail dimension (px) — smallest side will be this many pixels
THUMB_SIZE=200

# Default max dimensions for generated web-friendly photos/videos.
PHOTO_PX_H_DEFAULT=1080 # 1080  720
PHOTO_PX_W_DEFAULT=1920 # 1920 1280
VIDEO_PX_H_DEFAULT=480  # 240 480
VIDEO_PX_W_DEFAULT=640  # 320 640
# Defaults may be overridden by environment variables. 
PHOTO_PX_H="${PHOTO_PX_H:=$PHOTO_PX_H_DEFAULT}"
PHOTO_PX_W="${PHOTO_PX_W:=$PHOTO_PX_W_DEFAULT}"
VIDEO_PX_H="${VIDEO_PX_H:=$VIDEO_PX_H_DEFAULT}"
VIDEO_PX_W="${VIDEO_PX_W:=$VIDEO_PX_W_DEFAULT}"

printf "\n" | tee -a /www/run/status
printf "Running generate_cache.sh @ %s...\n" "$(date +"%Y.%m.%d %H:%M:%S")" | tee -a /www/run/status
printf "    (This may have to be re-run if browser stalls/times out)\n" | tee -a /www/run/status
printf "    Max Dimensions (set in env vars)\n" | tee -a /www/run/status
printf "        Photos: %dx%d px\n" "$PHOTO_PX_W" "$PHOTO_PX_H" | tee -a /www/run/status
printf "        Videos: %dx%d px\n" "$VIDEO_PX_W" "$VIDEO_PX_H" | tee -a /www/run/status

# Count total files up-front for progress reporting and init counter
printf "  Scanning files" | tee -a /www/run/status
(cd /www/media       && find -type f ! \( -iname "*.txt" -o -iname "*.zip" -o -iname "*.gz" -o -iname "Thumbs.db" \) | sort > /tmp/media.txt)
printf "." | tee -a /www/run/status
(cd /www/cache/photo && find -type f | sed -e 's/\.jpg$//' -e 's/\.webm$//' | sort > /tmp/photo.txt)
printf "." | tee -a /www/run/status
(cd /www/cache/thumb && find -type f | sed -e 's/\.thumb\.jpg$//'           | sort > /tmp/thumb.txt)
printf ".\n" | tee -a /www/run/status
printf "    Computing un-cached media files" | tee -a /www/run/status
comm -23 /tmp/media.txt /tmp/photo.txt > /tmp/nocache.photo.txt  # Suppress: 2-FILE2 unique lines, 3-and common lines
printf "." | tee -a /www/run/status
comm -23 /tmp/media.txt /tmp/thumb.txt > /tmp/nocache.thumb.txt  # Suppress: 2-FILE2 unique lines, 3-and common lines
printf "." | tee -a /www/run/status
comm /tmp/nocache.photo.txt /tmp/nocache.thumb.txt > /tmp/nocache.union.txt  # No args: union of both files with duplicates removed. Alpine version is tab-delimited column format so need to trim whitespace later.
printf ".\n" | tee -a /www/run/status

TOTAL_MEDIA=$(wc -l < /tmp/media.txt)
TOTAL_UNCACHED=$(wc -l < /tmp/nocache.union.txt)
GENERATED_COUNT=0
printf "  Out of %d total media files, there are %d file(s) that need cache generated\n" "$TOTAL_MEDIA" "$TOTAL_UNCACHED" | tee -a /www/run/status
printf "  Generating web-friendly file cache:" | tee -a /www/run/status

# Recursively find files under MEDIA_DIR (deterministic order) and create thumbs
while IFS= read -r relFilePath; do  
  relFilePath="$(echo "$relFilePath" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"  # trim whitespace produced by 'comm' command
  relFilePath="${relFilePath#./}"  # trim leading './'
  filename=$(basename "$relFilePath") # don't remove extension cuz may be both photo & video (eg. .jpg .mp4) with same name.
  relDir=$(dirname "$relFilePath")
  filepath="${MEDIA_DIR}/$relFilePath"

  [ -f "$filepath" ] || continue
  printf "\n    Processing: /${relFilePath}" | tee -a /www/run/status
  if [ "$relDir" = "." ] || [ -z "$relDir" ]; then
    thumb_dir="$THUMB_DIR"
    photo_dir="$PHOTO_DIR"
  else
    thumb_dir="$THUMB_DIR/$relDir"
    photo_dir="$PHOTO_DIR/$relDir"
  fi
  mkdir -p "$thumb_dir"
  mkdir -p "$photo_dir"

  fileType=UNKNOWN
  mimetype=$(file --mime-type "$filepath")
  if echo "$mimetype" | grep -q ': image/'; then
      fileType=IMAGE
      # create web-friendly photo if missing: convert to JPG and scale longer side to max ${PHOTO_PX_W/H}px
      photo_path="$photo_dir/${filename}.jpg"  # "$photo_dir/${name_no_ext}.jpg"
      if [ ! -f "$photo_path" ]; then
        RATIO=$((PHOTO_PX_W * 1000 / PHOTO_PX_H))
        # Resize preserving aspect ratio, so that neither width nor height exceeds the max height/width.
        fileSize=$(du -h "$filepath" | awk '{print $1}')
        imgWidthHeight=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$filepath")
        printf " - Photo: (${imgWidthHeight})" | tee -a /www/run/status
        tmpFilePath="$(mktemp -u).jpg" # use a temp file to avoid incomplete files if ffmpeg fails
        # NOTE: Tried producing .webp here, size was smaller but quality was much worse.  
        #   If still want webp with similar quality to JPG (that uses: -q:v 5), will get ~25% smaller size.
        #   Try these settings:
        #      -c:v libwebp \
        #      -quality 55 \
        #      -preset photo \
        #      -compression_level 6 \
        ffmpeg -y -i "$filepath" \
          -threads 1 \
          -nostdin -loglevel error -progress pipe:1 \
          -vf "scale='if(gte(iw\,${RATIO}*ih/1000)*gt(iw\,${PHOTO_PX_W})\,${PHOTO_PX_W}\,if(gt(ih\,${PHOTO_PX_H})\,iw*${PHOTO_PX_H}/ih\,-1))':'if(gte(iw\,${RATIO}*ih/1000)*gt(iw\,${PHOTO_PX_W})\,ih*${PHOTO_PX_W}/iw\,if(gt(ih\,${PHOTO_PX_H})\,${PHOTO_PX_H}\,-1))'" \
          -q:v 5 \
          "$tmpFilePath" | awk '/out_time_ms/ { printf "."; fflush(stdout) }'
        ffmpeg_status=${PIPESTATUS:-${?}}  # Bash sets PIPESTATUS[], BusyBox uses $?
        if [ "$ffmpeg_status" -eq 0 ]; then # ffmpeg succeeded
          mv -f "$tmpFilePath" "$photo_path" 2>/dev/null # use '-f' to ignore 'can't preserve ownership' issues
          b=$(stat -c%s "$photo_path")  # for some reason 'du -h' is not working here
          if [ $b -lt 1024 ]; then u=B;p=0; elif [ $b -lt 1048576 ]; then u=K;p=1; else u=M;p=2; fi
            webFileSize="$(echo "scale=1; ${b}/1024^${p}" | bc)${u}"
          printf "(%s -> %s)" "${fileSize}" "${webFileSize}" | tee -a /www/run/status
        else
          rm -f "$tmpFilePath"  # remove incomplete output file
          printf "(Error: ffmpeg of image failed: ${filepath})" | tee -a /www/run/status
        fi
      fi
  elif echo "$mimetype" | grep -q ': video/'; then
      fileType=VIDEO
      # create web-friendly video (.webm)
      video_path="$photo_dir/${filename}.webm"
      if [ ! -f "$video_path" ]; then
        # Resize preserving aspect ratio, so that neither width nor height exceeds the max height/width.
        fileSize=$(du -h "$filepath" | awk '{print $1}')
        videoDuration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$filepath" | cut -d. -f1)
        widthHeight=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$filepath")
        widthHeight="${widthHeight%x}"
        printf " - Video: (${widthHeight}, ${videoDuration}s)" | tee -a /www/run/status
        tmpFilePath="$(mktemp -u).webm" # use a temp file to avoid incomplete files if ffmpeg fails
        VIDEO_START=$(date +%s)
        # Show progress with dot every ~20 output chunks (awk...)
        #   We need this so that server continuiously sends packets to client doesn't time out and abort process.
        # Use '-threads 1' to limit CPU usage on small VM.
        ffmpeg -i "$filepath" \
          -threads 1 \
          -nostdin -loglevel error -progress pipe:1 \
          -vf "scale=w='min(iw,${VIDEO_PX_W})':h='min(ih,${VIDEO_PX_H})':force_original_aspect_ratio=decrease" \
          -codec:v libvpx-vp9 -crf 28 -b:v 0 -codec:a libopus \
          "$tmpFilePath" | awk '/out_time_ms/ { c++; if (c % 5 == 0) { printf "."; fflush(stdout) } }'
        ffmpeg_status=${PIPESTATUS:-${?}}  # Bash sets PIPESTATUS[], BusyBox uses $?
        if [ "$ffmpeg_status" -eq 0 ]; then # ffmpeg succeeded
          mv -f "$tmpFilePath" "$video_path" 2>/dev/null # -f to ignore 'can't preserve ownership' issues
          b=$(stat -c%s "$video_path") # for some reason 'du -h' is not working here
          if [ $b -lt 1024 ]; then u=B;p=0; elif [ $b -lt 1048576 ]; then u=K;p=1; else u=M;p=2; fi
            webFileSize="$(echo "scale=1; ${b}/1024^${p}" | bc)${u}"
            #webFileSize=$(du -h "$video_path" | awk '{print $1}')
          VIDEO_END=$(date +%s)
            VIDEO_ELAPSED=$((VIDEO_END - VIDEO_START))
            VIDEO_MINUTES=$((VIDEO_ELAPSED / 60))
            VIDEO_SECONDS=$((VIDEO_ELAPSED % 60))
          printf "(%s -> %s, %dm%ds)" "${fileSize}" "${webFileSize}" "$VIDEO_MINUTES" "$VIDEO_SECONDS" | tee -a /www/run/status
        else
          rm -f "$tmpFilePath"  # remove incomplete output file
          printf "(Error: ffmpeg of video failed: ${filepath})" | tee -a /www/run/status
        fi
      fi
  elif echo "$mimetype" | grep -q ': audio/'; then
      fileType=AUDIO
      audio_path="$photo_dir/${filename}.webm"
      if [ ! -f "$audio_path" ]; then
        printf " - Audio: " | tee -a /www/run/status
        cp "$filepath" "$audio_path"
        # TODO: convert into audio-only .webm file, eg:
        #   ffmpeg -i test.m4a -c:a libopus -b:a 96k -vn test.webm
        # --> encodes as Opus, -vn → no video, -b:a 96k → great default bitrate
      fi
  else
      printf " > Error - not a video, image or audio file type: ${filepath}" | tee -a /www/run/status
  fi

  # Thumbnail
  if [ "$fileType" != "UNKNOWN" ]; then
      thumb_path="$thumb_dir/${filename}.thumb.jpg"  
      if [ ! -f "$thumb_path" ]; then
          if [ "$fileType" = "AUDIO" ]; then
              cp /www/audio.jpg "$thumb_path"
              printf " & thumb" | tee -a /www/run/status
          else  # VIDEO or IMAGE
              thumbExtractOption=()  # empty array for IMAGE
              if [ "$fileType" = "VIDEO" ]; then # for VIDEO extract single frame, use '-frames:v 1 -update 1'
                  thumbExtractOption=(-frames:v 1 -update 1)
              fi
              tmpFilePath="$(mktemp -u).jpg" # use a temp file to avoid incomplete files if ffmpeg fails
              # scale so smallest side == THUMB_SIZE then center-crop
              ffmpeg -y -i "$filepath" \
                -threads 1 \
                "${thumbExtractOption[@]}" \
                -vf "scale='if(lt(iw,ih),${THUMB_SIZE},-1)':'if(lt(ih,iw),${THUMB_SIZE},-1)',crop=${THUMB_SIZE}:${THUMB_SIZE}:(iw-${THUMB_SIZE})/2:(ih-${THUMB_SIZE})/2" \
                -q:v 5 \
                "$tmpFilePath" </dev/null >/dev/null 2>&1
              ffmpeg_status=${PIPESTATUS:-${?}}  # Bash sets PIPESTATUS[], BusyBox uses $?
              if [ "$ffmpeg_status" -eq 0 ]; then # ffmpeg succeeded
                mv -f "$tmpFilePath" "$thumb_path" 2>/dev/null # -f to ignore 'can't preserve ownership' issues
                printf " & thumb" | tee -a /www/run/status
              else
                rm -f "$tmpFilePath"  # remove incomplete output file
                printf "(Error: ffmpeg of thumb failed: ${filepath})" | tee -a /www/run/status
              fi
          fi
      fi
  fi

  GENERATED_COUNT=$((GENERATED_COUNT + 1))
  if [ $((GENERATED_COUNT % 100)) -eq 0 ]; then 
    printf "\n  Generated %d out of %d total uncached files @ %s" "$GENERATED_COUNT" "$TOTAL_UNCACHED" "$(date +%H:%M.%Ss)" | tee -a /www/run/status
  fi
done <  /tmp/nocache.union.txt
printf '\n' | tee -a /www/run/status

# If there were zero files, still print a log entry
if [ "$TOTAL_UNCACHED" -eq 0 ]; then
  printf "  Checked 0 / 0 files\n" | tee -a /www/run/status
fi

# Print Totals
printf "  New web-friendly photos/thumbs generated for: %d media files (others already existed)\n" "$GENERATED_COUNT" | tee -a /www/run/status

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))
printf "  Generate Gallery Media done (time: %dm%ds).\n" "$MINUTES" "$SECONDS" | tee -a /www/run/status
