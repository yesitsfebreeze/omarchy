#!/usr/bin/env python3
"""omarchy-voice, phase 1: trigger -> record one utterance -> STT -> print ->
TTS reply -> idle.

  voice.py            press Enter to talk (temporary wake trigger)
  voice.py --file X   transcribe a 16 kHz mono WAV instead of the mic
  voice.py --say T    speak T and exit

Recognition and speech run remotely on Groq (Whisper, Orpheus); this CPU is
too slow for local models (decisions/voice-stt.md). Locally there is only
capture and a loudness check that ends the utterance. The key comes from
GROQ_API_KEY or the keyring:
  secret-tool store --label='Groq API key' service groq key api

No agent is called yet. Any failure is logged and the loop returns to idle.
"""

import array
import io
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
import wave

RATE = 16000
CHUNK = RATE // 5 * 2  # 200 ms of s16 mono
MAX_UTTERANCE_S = 15
MAX_WAIT_S = 5  # no speech at all
END_SILENCE_S = 1.2  # pause that ends an utterance
MIN_SPEECH_RMS = 400  # floor for the speech threshold; noise sets it higher
MIN_SPEECH_S = 0.6  # shorter loud bursts (clicks, coughs) are not speech

API = "https://api.groq.com/openai/v1/audio"
STT_MODEL = "whisper-large-v3-turbo"
TTS_MODEL = "canopylabs/orpheus-v1-english"
TTS_VOICE = "troy"
TTS_MAX_CHARS = 200  # per request, Groq's limit
TIMEOUT_S = 20


class Failed(Exception):
    pass


def log(*parts):
    print(time.strftime("%H:%M:%S"), *parts, file=sys.stderr, flush=True)


def groq_key():
    if key := os.environ.get("GROQ_API_KEY"):
        return key
    try:
        out = subprocess.run(["secret-tool", "lookup", "service", "groq", "key", "api"],
                             capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        out = None
    if out and out.stdout.strip():
        return out.stdout.strip()
    raise Failed("no Groq API key (GROQ_API_KEY or keyring service=groq key=api)")


def groq(path, body, content_type):
    request = urllib.request.Request(f"{API}/{path}", data=body, headers={
        "Authorization": f"Bearer {groq_key()}",
        "Content-Type": content_type,
        "User-Agent": "omarchy-voice",
    })
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_S) as response:
            return response.read()
    except urllib.error.HTTPError as e:
        detail = e.read(500).decode(errors="replace")
        raise Failed(f"groq {path}: HTTP {e.code}: {detail}")
    except (urllib.error.URLError, TimeoutError) as e:
        raise Failed(f"groq {path}: {e}")


def rms(chunk):
    samples = array.array("h", chunk)
    return math.sqrt(sum(s * s for s in samples) / len(samples)) if samples else 0.0


def utterance(chunks):
    """Raw s16 audio from the first loud chunk until END_SILENCE_S of quiet.

    The noise floor is learned only from quiet chunks, so speech from the
    very first chunk still counts, and less than MIN_SPEECH_S of loudness
    (the mic's start-up click, a cough) is ignored. Time is counted in audio,
    not wall clock, so a file behaves like the mic. Empty when nobody spoke.
    """
    audio, t, noise, spoke_at, quiet_since, loud_s = bytearray(), 0.0, 0.0, None, None, 0.0
    for chunk in chunks:
        dt = len(chunk) / (2 * RATE)
        t += dt
        level = rms(chunk)
        loud = level > max(MIN_SPEECH_RMS, 3 * noise)
        if not loud:  # only quiet chunks teach the noise floor
            noise = level if noise == 0.0 else min(noise, level)
        if spoke_at is None:
            if loud:
                spoke_at, loud_s, audio = t, 0.0, bytearray(audio[-CHUNK:])  # keep the onset
            elif t > MAX_WAIT_S:
                return b""
        audio += chunk
        if spoke_at is not None:
            loud_s += dt if loud else 0.0
            quiet_since = None if loud else (quiet_since or t)
            if quiet_since and t - quiet_since > END_SILENCE_S:
                if loud_s >= MIN_SPEECH_S:
                    break
                spoke_at, quiet_since = None, None  # a click or cough: keep waiting
        if t > MAX_UTTERANCE_S:
            break
    return bytes(audio) if spoke_at is not None and loud_s >= MIN_SPEECH_S else b""


def transcribe(audio):
    wav = io.BytesIO()
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(audio)
    boundary = uuid.uuid4().hex
    fields = [("model", STT_MODEL), ("response_format", "json"), ("temperature", "0")]
    body = b"".join(
        f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
        for k, v in fields
    ) + (
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="utterance.wav"\r\n'
        "Content-Type: audio/wav\r\n\r\n"
    ).encode() + wav.getvalue() + f"\r\n--{boundary}--\r\n".encode()
    answer = groq("transcriptions", body, f"multipart/form-data; boundary={boundary}")
    return json.loads(answer)["text"].strip()


def pieces(text):
    """Sentences packed into requests of at most TTS_MAX_CHARS."""
    out = []
    for sentence in re.split(r"(?<=[.!?])\s+", text.strip()):
        while len(sentence) > TTS_MAX_CHARS:
            cut = sentence.rfind(" ", 0, TTS_MAX_CHARS)
            cut = cut if cut > 0 else TTS_MAX_CHARS
            out.append(sentence[:cut])
            sentence = sentence[cut:].strip()
        if out and len(out[-1]) + 1 + len(sentence) <= TTS_MAX_CHARS:
            out[-1] += " " + sentence
        elif sentence:
            out.append(sentence)
    return out


def speak(text):
    for piece in pieces(text):
        body = json.dumps({"model": TTS_MODEL, "voice": TTS_VOICE, "input": piece,
                           "response_format": "wav"}).encode()
        wav = groq("speech", body, "application/json")
        with tempfile.NamedTemporaryFile(suffix=".wav") as f:
            f.write(wav)
            f.flush()
            subprocess.run(["pw-play", f.name], check=True, timeout=120)


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


def hear(chunks):
    audio = utterance(chunks)
    return transcribe(audio) if audio else ""


def reply_for(text):
    return f"You said: {text}" if text else "I didn't catch that."


def main(argv):
    try:
        if argv[:1] == ["--say"] and len(argv) == 2:
            speak(argv[1])
            return 0
        if argv[:1] == ["--file"] and len(argv) == 2:
            print(hear(file_chunks(argv[1])))
            return 0
    except Failed as e:
        log(f"error: {e}")
        return 1

    log("idle: press Enter to talk, Ctrl-D to quit")
    while sys.stdin.readline():
        try:
            log("listening")
            text = hear(mic_chunks())
            print(text or "(nothing heard)", flush=True)
            log("speaking")
            speak(reply_for(text))
        except Exception as e:  # never act on a half-finished turn
            log(f"error: {type(e).__name__}: {e}")
        log("idle")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
