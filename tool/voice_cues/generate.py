"""Generates the spoken exercise cues in assets/audio/cues/.

The clips are made once on a developer machine with Kokoro-82M (Apache-2.0),
an open neural voice model, and shipped with the app, so the device plays
plain audio files and never synthesises or sends anything. Rerun this when
adding cues, keeping the same voice and speed so every exercise sounds alike.

Setup, in a throwaway virtual environment outside the repo:
    pip install kokoro-onnx soundfile
    download kokoro-v1.0.onnx and voices-v1.0.bin from
    https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.0

Usage:
    python generate.py <model folder> <repo>/assets/audio/cues
"""

import sys

import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

VOICE_BLEND = {"af_heart": 0.65, "af_bella": 0.35}
SPEED = 0.92

# Short sentences leave quiet time within each phase. Ellipses made the
# original delivery sound segmented; slowing it further stretched syllables.
CUES = {
    "breathe_in": "Gently breathe in.",
    "breathe_out": "And softly breathe out.",
}


def polish(audio: np.ndarray, rate: int) -> np.ndarray:
    """Preserves word endings and peaks at -6 dBFS: softer than full scale,
    still clear on a phone speaker an arm's length away."""
    audio = audio.astype(np.float32)
    if audio.size == 0 or not np.isfinite(audio).all():
        raise ValueError("Cue contains no usable audio")
    threshold = 10 ** (-45 / 20) * np.max(np.abs(audio))
    voiced = np.where(np.abs(audio) > threshold)[0]
    if voiced.size == 0:
        raise ValueError("Cue is silent")
    audio = audio[max(voiced[0] - int(0.06 * rate), 0) : voiced[-1] + int(0.20 * rate)]
    fade = min(int(0.02 * rate), len(audio) // 4)
    audio[:fade] *= np.linspace(0, 1, fade)
    audio[-fade * 4 :] *= np.linspace(1, 0, fade * 4)
    audio = audio / np.max(np.abs(audio)) * 10 ** (-6 / 20)
    return np.pad(audio, (int(0.08 * rate), int(0.18 * rate)))


def main() -> None:
    model_folder, out_folder = sys.argv[1], sys.argv[2]
    kokoro = Kokoro(
        f"{model_folder}/kokoro-v1.0.onnx", f"{model_folder}/voices-v1.0.bin"
    )
    voice = sum(kokoro.get_voice_style(name) * weight
                for name, weight in VOICE_BLEND.items())
    for name, line in CUES.items():
        audio, rate = kokoro.create(line, voice=voice, speed=SPEED, lang="en-us")
        audio = polish(audio, rate)
        if len(audio) / rate >= (4 if name == "breathe_in" else 6):
            raise ValueError(f"{name} exceeds its exercise phase")
        sf.write(f"{out_folder}/{name}.wav", audio, rate, subtype="PCM_16")


if __name__ == "__main__":
    main()
