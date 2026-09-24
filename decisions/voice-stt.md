# Voice: Vosk for speech-to-text, not whisper.cpp

This machine's Celeron N5105 has no AVX/AVX2/FMA (SSE4.2 only). whisper.cpp's
ggml `base` model took over five minutes on 2.5 s of audio. Vosk (Kaldi)
needs no AVX and streams; the small English model transcribes in real time
here and gives utterance endpointing for free.

Piper is `piper-tts-bin` (prebuilt): the AUR `piper-tts` builds onnxruntime
from source, which this CPU cannot do in reasonable time.

Recognition itself goes to Groq's free Whisper tier (`whisper-large-v3-turbo`,
2,000 requests/day) when a key is in the keyring (`service groq key api`):
far more accurate than the small Vosk model, and under a second. Vosk stays
local for endpointing and is the fallback on any Groq failure, so the loop
works offline. Only the recorded utterance leaves the machine.
