# Voice: Vosk for speech-to-text, not whisper.cpp

This machine's Celeron N5105 has no AVX/AVX2/FMA (SSE4.2 only). whisper.cpp's
ggml `base` model took over five minutes on 2.5 s of audio. Vosk (Kaldi)
needs no AVX and streams; the small English model transcribes in real time
here and gives utterance endpointing for free.

Piper is `piper-tts-bin` (prebuilt): the AUR `piper-tts` builds onnxruntime
from source, which this CPU cannot do in reasonable time.
