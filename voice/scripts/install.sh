#!/usr/bin/env bash
# omarchy-voice runtime: Python venv with Vosk, one Vosk model, one Piper voice.
# Piper itself is piper-tts-bin (packages/aur.txt). Idempotent.
set -euo pipefail

voice_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
home="${OMARCHY_VOICE_HOME:-$HOME/.local/share/omarchy-voice}"
models="$home/models"
mkdir -p "$models"

[[ -x "$home/venv/bin/python" ]] || python3 -m venv "$home/venv"
"$home/venv/bin/pip" install -q -r "$voice_dir/requirements.txt"

fetch() { # url sha256 dest
  [[ -f "$3" ]] && return
  curl -fsSLo "$3.part" "$1"
  echo "$2  $3.part" | sha256sum -c --quiet
  mv "$3.part" "$3"
}

vosk=vosk-model-small-en-us-0.15
if [[ ! -d "$models/$vosk" ]]; then
  fetch "https://alphacephei.com/vosk/models/$vosk.zip" \
    30f26242c4eb449f948e42cb302dd7a686cb29a3423a8367f99ff41780942498 "$models/$vosk.zip"
  python3 -m zipfile -e "$models/$vosk.zip" "$models"
  rm "$models/$vosk.zip"
fi

piper=https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium
fetch "$piper/en_US-lessac-medium.onnx" \
  5efe09e69902187827af646e1a6e9d269dee769f9877d17b16b1b46eeaaf019f "$models/en_US-lessac-medium.onnx"
fetch "$piper/en_US-lessac-medium.onnx.json" \
  efe19c417bed055f2d69908248c6ba650fa135bc868b0e6abb3da181dab690a0 "$models/en_US-lessac-medium.onnx.json"
