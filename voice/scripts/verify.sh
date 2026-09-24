#!/usr/bin/env bash
# Proves the default microphone delivers audio and, with a Groq key, the remote
# round trip: Groq TTS speaks a sentence, Groq STT reads it back. Plays nothing.
set -euo pipefail

voice="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/src/voice.py"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

timeout 2 pw-record --raw --rate 16000 --channels 1 --format s16 - >"$tmp/mic.raw" || true
[[ -s "$tmp/mic.raw" ]] || { echo "no audio from the default microphone ($(pactl get-default-source))" >&2; exit 1; }
echo "microphone: $(pactl get-default-source)"

secret-tool lookup service groq key api >/dev/null 2>&1 || [[ -n "${GROQ_API_KEY:-}" ]] ||
  { echo "no Groq key: secret-tool store --label='Groq API key' service groq key api" >&2; exit 1; }

python3 - "$voice" "$tmp" <<'PY'
import importlib.util, subprocess, sys
spec = importlib.util.spec_from_file_location("voice", sys.argv[1]); v = importlib.util.module_from_spec(spec); spec.loader.exec_module(v)
wav = v.groq("speech", __import__("json").dumps({"model": v.TTS_MODEL, "voice": v.TTS_VOICE,
      "input": "Check whether bluetooth is running.", "response_format": "wav"}).encode(), "application/json")
open(f"{sys.argv[2]}/tts.wav", "wb").write(wav)
PY
ffmpeg -loglevel error -i "$tmp/tts.wav" -ar 16000 -ac 1 "$tmp/in.wav"
heard="$(python3 "$voice" --file "$tmp/in.wav")"
[[ "${heard,,}" == *bluetooth* ]] || { echo "Groq TTS -> STT failed: '$heard'" >&2; exit 1; }
echo "groq tts -> stt: $heard"

echo "omarchy-voice checks passed."
