#!/usr/bin/env bash
# Rebuild marketing/screenshots/ios/preview_6.7.mp4 from the iOS VO sources
# in marketing/video/ios_vo/ + the music underbed in assets/audio/.
#
# Re-run this only when the VO clips, end card, or video segments change.
# The 6 ElevenLabs VO files in ios_vo/ are the canonical inputs — they were
# generated with George ("Warm, Captivating Storyteller", voice_id
# JBFqnCBsd6RMkjVDRZzb) at stability=0.45, similarity_boost=0.75,
# style=0.25, speed=1.05 (line 1) / 1.0 (lines 2-6), model
# eleven_multilingual_v2.
#
# Output spec: 1290×2796 (iPhone 6.7"), H.264 + AAC, ~25.4s, ~17 MB.
# Music underbed level: 0.10 (Jim approved 2026-04-29 — VO is dominant).

set -euo pipefail
cd "$(dirname "$0")/ios_vo"

VO_TURN="tts_Turn__20260429_145431.mp3"  # 0.5s → 3.99s
VO_CHOOSE="tts_Choos_20260429_145433.mp3"  # 4.4s → 6.07s
VO_PICK="tts_Pick__20260429_145435.mp3"  # 7.3s → 9.20s
VO_EVERY="tts_Every_20260429_145437.mp3"  # 11.5s → 13.64s
VO_CELEB="tts_Celeb_20260429_145439.mp3"  # 17.7s → 20.86s
VO_BRUSH="tts_Brush_20260429_145440.mp3"  # 22.5s → 25.38s

MUSIC="../../../assets/audio/battle_music_loop.mp3"
ENDCARD="../endcard_ios.png"
SOURCE_VIDEO="../promo_v5_26s.mp4"
OUT_DIR="../../screenshots/ios"

echo "Stage 1: combine 6 VO lines at original timestamps"
ffmpeg -y \
  -i "$VO_TURN" -i "$VO_CHOOSE" -i "$VO_PICK" \
  -i "$VO_EVERY" -i "$VO_CELEB" -i "$VO_BRUSH" \
  -filter_complex "[0:a]adelay=500|500[v1];[1:a]adelay=4400|4400[v2];[2:a]adelay=7300|7300[v3];[3:a]adelay=11500|11500[v4];[4:a]adelay=17700|17700[v5];[5:a]adelay=22500|22500[v6];[v1][v2][v3][v4][v5][v6]amix=inputs=6:duration=longest:normalize=0[vo]" \
  -map "[vo]" -c:a libmp3lame -b:a 192k -t 26 vo_combined.mp3 -loglevel error

echo "Stage 2: extract 26s music with fade-out @ volume 0.10"
ffmpeg -y -i "$MUSIC" \
  -af "atrim=0:26,afade=t=out:st=25:d=1,volume=0.10" \
  -c:a libmp3lame -b:a 192k music_26s.mp3 -loglevel error

echo "Stage 3: mix music + VO with sidechain ducking"
ffmpeg -y -i music_26s.mp3 -i vo_combined.mp3 \
  -filter_complex "[0:a][1:a]sidechaincompress=threshold=0.03:ratio=20:attack=15:release=300:makeup=2[ducked];[ducked][1:a]amix=inputs=2:duration=longest:normalize=0[mix]" \
  -map "[mix]" -c:a aac -b:a 192k -t 26 final_audio.m4a -loglevel error

echo "Stage 4: extract 0-22s of source video (no audio)"
ffmpeg -y -i "$SOURCE_VIDEO" -t 22 -an -c:v copy main_22s.mp4 -loglevel error

echo "Stage 5: build 4s endcard video at 1080x2410"
ffmpeg -y -loop 1 -t 4 -i "$ENDCARD" \
  -vf "scale=1080:2410,format=yuv420p" -r 30 -c:v libx264 -preset fast -crf 18 -an endcard_4s.mp4 -loglevel error

echo "Stage 6: concat → 26s no-audio video"
printf "file 'main_22s.mp4'\nfile 'endcard_4s.mp4'\n" > concat.txt
ffmpeg -y -f concat -safe 0 -i concat.txt -c:v libx264 -preset fast -crf 18 -r 30 video_26s_1080.mp4 -loglevel error

echo "Stage 7: mux audio + video (1080x2410)"
ffmpeg -y -i video_26s_1080.mp4 -i final_audio.m4a -c:v copy -c:a aac -b:a 192k -shortest muxed_1080.mp4 -loglevel error

echo "Stage 8: crop+scale to 1290x2796 (iPhone 6.7\")"
ffmpeg -y -i muxed_1080.mp4 -vf "scale=1290:-2,crop=1290:2796" \
  -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -c:a copy "$OUT_DIR/preview_6.7.mp4" -loglevel error

echo "Stage 9: extract poster frame at 12s"
ffmpeg -y -ss 12 -i "$OUT_DIR/preview_6.7.mp4" -frames:v 1 -q:v 2 "$OUT_DIR/preview_6.7_poster.png" -loglevel error

echo
echo "DONE."
ffprobe -v error -show_entries stream=width,height,codec_name,duration -show_entries format=size -of default=noprint_wrappers=1 "$OUT_DIR/preview_6.7.mp4"
