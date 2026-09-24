#!/usr/bin/env python3
"""omarchy-voice, phase 1: trigger -> record one utterance -> STT ->
print -> Piper TTS reply -> idle.

  voice.py            press Enter to talk (temporary wake trigger)
  voice.py --file X   transcribe a 16 kHz mono WAV instead of the mic
  voice.py --say T    speak T and exit

Vosk runs locally and decides when the utterance ends. The clip is then sent
to Groq's Whisper when a key is available (GROQ_API_KEY, or the keyring:
`secret-tool store --label='Groq API key' service groq key api`); without a
key, or on any Groq failure, Vosk's transcript is used.

No agent is called yet. Any failure is logged and the loop returns to idle.
"""

import io
import json
import os
import subprocess
import sys
import time
import urllib.request
import uuid
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
GROQ_URL = "https://api.groq.com/openai/v1/audio/transcriptions"
GROQ_MODEL = "whisper-large-v3-turbo"
GROQ_TIMEOUT_S = 15


def log(*parts):
    print(time.strftime("%H:%M:%S"), *parts, file=sys.stderr, flush=True)


def groq_key():
    if key := os.environ.get("GROQ_API_KEY"):
        return key
    try:
        out = subprocess.run(["secret-tool", "lookup", "service", "groq", "key", "api"],
                             capture_output=True, text=True, timeout=5)
        return out.stdout.strip() or None
    except (OSError, subprocess.TimeoutExpired):
        return None


def groq_transcribe(audio, key):
    """Raw s16 mono audio -> text via Groq Whisper. Raises on any failure."""
    wav = io.BytesIO()
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(audio)
    boundary = uuid.uuid4().hex
    fields = [("model", GROQ_MODEL), ("response_format", "json"), ("temperature", "0")]
    body = b"".join(
        f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
        for k, v in fields
    ) + (
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="utterance.wav"\r\n'
        "Content-Type: audio/wav\r\n\r\n"
    ).encode() + wav.getvalue() + f"\r\n--{boundary}--\r\n".encode()
    request = urllib.request.Request(GROQ_URL, data=body, headers={
        "Authorization": f"Bearer {key}",
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "User-Agent": "omarchy-voice",
    })
    with urllib.request.urlopen(request, timeout=GROQ_TIMEOUT_S) as response:
        return json.load(response)["text"].strip()


def recognize(model, chunks):
    """One utterance -> (text, engine). Local Vosk ends it; Groq refines it."""
    local, audio = transcribe(model, chunks)
    if not local:
        return "", "vosk"
    key = groq_key()
    if not key:
        return local, "vosk"
    try:
        return groq_transcribe(audio, key), "groq"
    except Exception as e:  # network, quota (429), bad key: stay local
        log(f"groq failed ({type(e).__name__}: {e}); using vosk")
        return local, "vosk"


def transcribe(model, chunks):
    """Feed raw s16 chunks until the speaker pauses; return (text, audio).

    Time is counted in audio, not wall clock, so a file reads like the mic.
    Vosk's own endpoint fires on short pauses mid-sentence, so its segments
    are joined and the utterance ends only after END_SILENCE_S without new
    words.
    """
    rec = vosk.KaldiRecognizer(model, RATE)
    parts, last, t, changed_at, audio = [], "", 0.0, 0.0, bytearray()
    for chunk in chunks:
        audio += chunk
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
    return " ".join(p for p in parts if p).strip(), bytes(audio)


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
        text, engine = recognize(model, file_chunks(argv[1]))
        log("engine:", engine)
        print(text)
        return 0

    log("idle: press Enter to talk, Ctrl-D to quit")
    while sys.stdin.readline():
        try:
            log("listening")
            text, engine = recognize(model, mic_chunks())
            log("engine:", engine)
            print(text or "(nothing heard)", flush=True)
            log("speaking")
            speak(reply_for(text))
        except Exception as e:  # never act on a half-finished turn
            log(f"error: {type(e).__name__}: {e}")
        log("idle")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
