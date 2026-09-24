#!/usr/bin/env bash
# Proves TTS and STT (Piper speaks a sentence, Vosk reads it back) and that the
# default microphone delivers audio. Plays nothing aloud.
set -euo pipefail

voice_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home="${OMARCHY_VOICE_HOME:-$HOME/.local/share/omarchy-voice}"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo "check whether bluetooth is running" |
  piper-tts -m "$home/models/en_US-lessac-medium.onnx" -f "$tmp/tts.wav" >/dev/null 2>&1
ffmpeg -loglevel error -i "$tmp/tts.wav" -ar 16000 -ac 1 "$tmp/in.wav"
heard="$("$home/venv/bin/python" "$voice_dir/src/voice.py" --file "$tmp/in.wav" 2>/dev/null)"
[[ "$heard" == *running* ]] || { echo "STT/TTS loopback failed: '$heard'" >&2; exit 1; }
echo "tts -> stt: $heard"

timeout 2 pw-record --raw --rate 16000 --channels 1 --format s16 - >"$tmp/mic.raw" || true
[[ -s "$tmp/mic.raw" ]] || { echo "no audio from the default microphone ($(pactl get-default-source))" >&2; exit 1; }
echo "microphone: $(pactl get-default-source)"

groq="no key (vosk only)"
secret-tool lookup service groq key api >/dev/null 2>&1 && groq="key in keyring"
echo "groq: $groq"

echo "omarchy-voice checks passed."
