#!/usr/bin/env bash
# Cuts the raw take of scripts/record-hero.sh into the website's hero clip
# (site/media/hero.mp4, 16:10 1280x800 H.264, no audio), its poster
# (site/media/hero.jpg) and the README's moving preview (Resources/readme/hero.webp;
# GitHub cannot play a committed video, but it plays an animated WebP).
# The last moment fades into the first frame, so the loop has no visible cut.
# Needs ffmpeg built with libwebp. Runs anywhere, no Mac needed.
# Usage: scripts/make-hero-video.sh [raw.mov]
#   default input: raw.mov on the hero-video/<branch> branch CI pushed, or set
#   BRANCH=hero-video/pr-N. START and END (seconds) pick the part of the take.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
START="${START:-0}"
END="${END:-21}"
FADE="${FADE:-0.6}"
raw="${1:-}"
if [ -z "$raw" ]; then
  branch="${BRANCH:?set BRANCH=hero-video/pr-N or pass the raw take}"
  tmp=$(mktemp -d)
  git -C "$ROOT" fetch -q origin "$branch"
  git -C "$ROOT" show "FETCH_HEAD:raw.mov" > "$tmp/raw.mov"
  raw="$tmp/raw.mov"
fi

len=$(echo "$END - $START" | bc -l)
offset=$(echo "$len - $FADE" | bc -l)
# The top of the screen in 16:10, menu bar included, then 1280x800.
crop="crop=iw:trunc(iw*10/16/2)*2:0:0,scale=1280:800:flags=lanczos,fps=30,setsar=1,format=yuv420p"

ffmpeg -nostdin -v error -y -i "$raw" -filter_complex "
  [0:v]trim=start=$START:end=$END,setpts=PTS-STARTPTS,$crop,split[a][b];
  [b]trim=end_frame=1,loop=loop=-1:size=1,trim=duration=$FADE,setpts=PTS-STARTPTS[first];
  [a][first]xfade=transition=fade:duration=$FADE:offset=${offset}[v]" \
  -map "[v]" -an -c:v libx264 -preset slow -crf 24 -profile:v high -pix_fmt yuv420p \
  -movflags +faststart "$ROOT/site/media/hero.mp4"

ffmpeg -nostdin -v error -y -i "$ROOT/site/media/hero.mp4" -frames:v 1 -q:v 3 "$ROOT/site/media/hero.jpg"

mkdir -p "$ROOT/Resources/readme"
ffmpeg -nostdin -v error -y -i "$ROOT/site/media/hero.mp4" \
  -vf "fps=12,scale=720:-1:flags=lanczos" \
  -an -c:v libwebp_anim -quality 55 -compression_level 6 -loop 0 \
  "$ROOT/Resources/readme/hero.webp"

for f in site/media/hero.mp4 site/media/hero.jpg Resources/readme/hero.webp; do
  echo "Wrote $f ($(du -k "$ROOT/$f" | cut -f1) KB)"
done
