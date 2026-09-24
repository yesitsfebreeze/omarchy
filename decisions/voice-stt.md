# Voice: speech runs on Groq, not locally

This machine's Celeron N5105 has no AVX/AVX2/FMA (SSE4.2 only). Measured:
whisper.cpp `base` took over five minutes on 2.5 s of audio; Voxtype's
prebuilt binaries need AVX2 (only its slow CPU Whisper runs); Piper took
~17 s per sentence; Vosk was usable but inaccurate. Local speech was removed.

Both directions use Groq's free tier with one key from the keyring
(`service groq key api`): Whisper `whisper-large-v3-turbo` (2,000 requests/day)
and Orpheus `canopylabs/orpheus-v1-english` (100 requests/day, 200 characters
per request, so replies are split by sentence).

Only capture and a loudness-based end-of-utterance check run locally. Nothing
leaves the machine until the trigger fires; then only that utterance does.
