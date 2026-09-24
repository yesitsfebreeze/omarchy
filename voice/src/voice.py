#!/usr/bin/env python3
"""omarchy-voice, phase 1: trigger -> record one utterance -> Vosk STT ->
print -> Piper TTS reply -> idle.

  voice.py            press Enter to talk (temporary wake trigger)
  voice.py --file X   transcribe a 16 kHz mono WAV instead of the mic
  voice.py --say T    speak T and exit

No agent is called yet. Any failure is logged and the loop returns to idle.
"""

import json
import os
import subprocess
import sys
import time
import wave
from pathlib import Path

import vosk

HOME = Path(os.environ.get("OMARCHY_VOICE_HOME", Path.home() / ".local/share/omarchy-voice"))
STT_MODEL = HOME / "models/vosk-model-small-en-us-0.15"
TTS_VOICE = HOME / "models/en_US-lessac-medium.onnx"
RATE = 16000
CHUNK = RATE // 5 * 2  # 200 ms of s16 mono
MAX_UTTERANCE_S = 10
MAX_SILENCE_S = 5  # nothing heard at all
END_SILENCE_S = 1.2  # pause that ends an utterance


def log(*parts):
    print(time.strftime("%H:%M:%S"), *parts, file=sys.stderr, flush=True)


def transcribe(model, chunks):
    """Feed raw s16 chunks until the speaker pauses; return the text.

    Time is counted in audio, not wall clock, so a file reads like the mic.
    Vosk's own endpoint fires on short pauses mid-sentence, so its segments
    are joined and the utterance ends only after END_SILENCE_S without new
    words.
    """
    rec = vosk.KaldiRecognizer(model, RATE)
    parts, last, t, changed_at = [], "", 0.0, 0.0
    for chunk in chunks:
        t += len(chunk) / (2 * RATE)
        if rec.AcceptWaveform(chunk):
            text = json.loads(rec.Result()).get("text", "")
            if text:
                parts.append(text)
            now = " ".join(parts)
        else:
            now = " ".join(parts + [json.loads(rec.PartialResult()).get("partial", "")]).strip()
        if now != last:
            last, changed_at = now, t
        if t > MAX_UTTERANCE_S or (not last and t > MAX_SILENCE_S):
            break
        if last and t - changed_at > END_SILENCE_S:
            break
    parts.append(json.loads(rec.FinalResult()).get("text", ""))
    return " ".join(p for p in parts if p).strip()


def mic_chunks():
    proc = subprocess.Popen(
        ["pw-record", "--raw", "--rate", str(RATE), "--channels", "1", "--format", "s16", "-"],
        stdout=subprocess.PIPE,
    )
    try:
        while chunk := proc.stdout.read(CHUNK):
            yield chunk
    finally:
        proc.terminate()
        proc.wait()


def file_chunks(path):
    with wave.open(str(path)) as w:
        if (w.getframerate(), w.getnchannels(), w.getsampwidth()) != (RATE, 1, 2):
            raise ValueError("need 16 kHz mono s16 WAV")
        while chunk := w.readframes(CHUNK // 2):
            yield chunk


def speak(text):
    """Piper to raw audio, straight into PipeWire."""
    with open(str(TTS_VOICE) + ".json") as f:
        rate = json.load(f)["audio"]["sample_rate"]
    tts = subprocess.Popen(
        ["piper-tts", "-m", str(TTS_VOICE), "--output-raw"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
    )
    play = subprocess.Popen(
        ["pw-play", "--raw", "--rate", str(rate), "--channels", "1", "--format", "s16", "-"],
        stdin=tts.stdout,
    )
    tts.stdout.close()
    tts.communicate(text.encode() + b"\n", timeout=60)
    play.wait(timeout=60)


def reply_for(text):
    return f"You said: {text}" if text else "I didn't catch that."


def main(argv):
    if argv[:1] == ["--say"] and len(argv) == 2:
        speak(argv[1])
        return 0

    vosk.SetLogLevel(-1)
    log("loading", STT_MODEL.name)
    model = vosk.Model(str(STT_MODEL))

    if argv[:1] == ["--file"] and len(argv) == 2:
        print(transcribe(model, file_chunks(argv[1])))
        return 0

    log("idle: press Enter to talk, Ctrl-D to quit")
    while sys.stdin.readline():
        try:
            log("listening")
            text = transcribe(model, mic_chunks())
            print(text or "(nothing heard)", flush=True)
            log("speaking")
            speak(reply_for(text))
        except Exception as e:  # never act on a half-finished turn
            log(f"error: {type(e).__name__}: {e}")
        log("idle")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
