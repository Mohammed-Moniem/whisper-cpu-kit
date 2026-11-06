# Third-party notices

The model was trained and released by OpenAI as part of Whisper, then converted
and quantized by the publisher of `ggerganov/whisper.cpp` on Hugging Face. This
kit mirrors those existing model bytes unchanged and claims no model training,
fine-tuning, improved accuracy or upstream endorsement.

- Original model: https://github.com/openai/whisper (MIT).
- Converted weights: https://huggingface.co/ggerganov/whisper.cpp.
- Conversion revision: `5359861c739e955e79d9a303bcbc70fb988958b1`.
- OpenAI's 2022 copyright and MIT permission text are preserved in [LICENSE](LICENSE).

The complete v1.1.0 package contains CPU CLI builds from unmodified whisper.cpp
commit `d1be6fde11ac6e0407606b4e42fe72d34add8037`, tagged **v1.9.5 / b5454**,
plus this kit's native Windows CPU selector and shell launchers. Runtime
copyright is **2023-2026 The ggml authors**, under the MIT license.

The [licenses/](licenses/) directory preserves upstream notices for whisper.cpp,
GGML, miniaudio, stb_vorbis, JSON and identified vendored components. Its
[inventory](licenses/README.md) also retains notices for SDL2, llama and HTTP
server components from the older full Windows archive. Those additional
programs and libraries are not included in the complete v1.1.0 package. Retaining
their notices does not imply those components are present in this package.
The inventory is a scoped redistribution-notice record, not a complete binary
SBOM or security review.

The Windows CLI builds and CPU selector statically link the Microsoft C/C++
runtime and import only Windows operating-system DLLs. They were compiled
with the licensed Visual Studio 2022 tools supplied on GitHub's Windows build
runner. The included dependency records list the actual direct imports. No
Microsoft installer or SDK is redistributed in this package.

The Mac CLI builds use macOS operating-system libraries and Accelerate. These
Apple components are provided by macOS and are not redistributed. The binaries
are ad hoc signed, without Developer ID signing or notarization.

Retain this file, root [LICENSE](LICENSE) and the complete [licenses/](licenses/)
directory when redistributing the package. Exact payload hashes, model source
and build provenance are in the included `bundle-manifest.json`, `SHA256SUMS`
and `provenance/` directory. The historical v1.0.0 distribution and its own
manifests remain available in the
[repository](https://github.com/Mohammed-Moniem/whisper-cpu-kit).
Licenses, provenance and matching hashes do not certify that a model or runtime
is vulnerability-free.
