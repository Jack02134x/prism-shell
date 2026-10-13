#!/usr/bin/env bash
# Build wallpaper thumbnails at idle priority. Existing thumbs are skipped.
# usage: thumbs.sh <image_dir> <image_thumb_dir> <video_dir> <video_thumb_dir>
img_src=$1 img_out=$2 vid_src=$3 vid_out=$4
mkdir -p "$img_out" "$vid_out"

renice -n 19 $$ >/dev/null 2>&1
ionice -c3 -p $$ >/dev/null 2>&1

find "$img_src" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) -print0 |
    xargs -0 -r -P 6 -I{} sh -c '
        o="$2/$(basename "$1").jpg"
        [ -s "$o" ] || magick "$1[0]" -auto-orient -thumbnail "512x288^" -gravity center -extent 512x288 -quality 82 "$o" 2>/dev/null
    ' _ {} "$img_out"

find "$vid_src" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.gif' \) -print0 |
    xargs -0 -r -P 3 -I{} sh -c '
        o="$2/$(basename "$1").jpg"
        [ -s "$o" ] && exit 0
        case "$1" in
            *.gif|*.GIF) magick "$1[0]" -thumbnail "512x288^" -gravity center -extent 512x288 "$o" 2>/dev/null ;;
            *) ffmpegthumbnailer -i "$1" -o "$o" -s 512 -t 20% -q 8 2>/dev/null ;;
        esac
    ' _ {} "$vid_out"
