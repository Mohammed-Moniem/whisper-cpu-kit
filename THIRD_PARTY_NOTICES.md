# Third-party notices

The model was trained and released by OpenAI as part of Whisper, then converted
and quantized by the publisher of `ggerganov/whisper.cpp` on Hugging Face. This
kit mirrors the existing file unchanged and claims no model training,
fine-tuning, improved accuracy or upstream endorsement.

- Original model: https://github.com/openai/whisper (MIT).
- Converted weights: https://huggingface.co/ggerganov/whisper.cpp.
- Conversion revision: `5359861c739e955e79d9a303bcbc70fb988958b1`.
- OpenAI's 2022 copyright and MIT permission text are preserved in [LICENSE](LICENSE).

The Windows `whisper-bin-x64.zip` is the unchanged upstream **b5454** archive.
The Mac `whisper-cpu-macos-arm64-b5454.zip` contains a locally compiled Apple
Silicon CLI. Both use whisper.cpp commit
`d1be6fde11ac6e0407606b4e42fe72d34add8037`, also tagged **v1.9.5**.
Runtime copyright is **2023–2026 The ggml authors**, under the MIT license.

The Windows archive includes SDL2 2.28.5, copyright **1997–2023 Sam Lantinga**,
under the zlib license, plus additional upstream tools and their dependencies.
The scoped component notice inventory is in [licenses/README.md](licenses/README.md).
These files preserve identified upstream license texts; they are not a complete
binary SBOM or a security review.

Retain the [licenses/](licenses/) directory and root LICENSE with redistributed
artifacts. Downloadable [runtime-NOTICES.zip](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/download/v1.0.0/runtime-NOTICES.zip)
provides companion notices for the unchanged Windows archive. The Mac archive
already includes the same notices. The kit preserves those license files
unchanged from the earlier verified distribution.

The Mac runtime links macOS operating-system libraries and Accelerate; those
Apple components are not redistributed. It is a local build, not an official
upstream binary, and is not Developer ID signed or notarized.

Exact byte identities and sources are in [model-manifest.json](model-manifest.json)
and [runtime-manifest.json](runtime-manifest.json). Licenses, provenance and
matching hashes do not certify that a model or runtime is vulnerability-free.
