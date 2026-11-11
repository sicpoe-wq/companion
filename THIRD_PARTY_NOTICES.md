# Third-party notices

## sherpa-onnx (1.13.8)
https://github.com/k2-fsa/sherpa-onnx (Apache License 2.0). Runs on-device text-to-speech. Version 1.13.8 is pinned because 2.0 removed the espeak-ng frontend that Piper voices need.

## ONNX Runtime
https://github.com/microsoft/onnxruntime (MIT License). Bundled with sherpa-onnx.

## espeak-ng
https://github.com/espeak-ng/espeak-ng (GPL-3.0-or-later). Used by sherpa-onnx to turn text into phonemes. Its data files are downloaded together with the first natural voice.

## Piper voices
https://github.com/rhasspy/piper, packaged as int8 models by sherpa-onnx (https://github.com/k2-fsa/sherpa-onnx/releases/tag/tts-models). Voices are downloaded on demand, not bundled. Each voice carries its own licence, and its MODEL_CARD is kept next to it on the device:

| Voice | Licence |
| --- | --- |
| en_US-hfc_female-medium (Hazel, Aria's default) | CC BY-NC-SA 4.0 |
| en_US-hfc_male-medium (Hal, Julian's default) | CC BY-NC-SA 4.0 |
| en_US-ryan-medium | CC BY-NC-SA 4.0 |
| en_US-amy-medium | see MODEL_CARD |
| en_US-kristin-medium | Public domain |
| en_US-john-medium | Public domain |
| en_US-joe-medium | CC0 |
| en_US-lessac-medium | Blizzard 2013 licence (non-commercial) |
| en_GB-jenny_dioco-medium | see MODEL_CARD |
| en_GB-alan-medium | see MODEL_CARD |

Several voices are licensed for non-commercial use only. Companion is a free, non-commercial app.
