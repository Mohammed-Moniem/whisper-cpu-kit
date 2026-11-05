# Whisper CPU kit

Downloadable CPU transcription for **Arabic, English and Hindi**, using native
whisper.cpp and the multilingual Whisper Small Q5_1 model. No Python or GPU is
required. The model is **190 MB**; this is the smallest of Tiny, Base and Small
that retained the expected scripts in our limited comparison. Accuracy still
needs proofreading, especially for Arabic and Hindi.

## Windows x64

Download these three files into one folder:

- [whisper-bin-x64.zip](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/download/v1.0.0/whisper-bin-x64.zip) — unchanged upstream **b5454** CPU runtime, 8.9 MB.
- [ggml-small-q5_1.bin](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/download/v1.0.0/ggml-small-q5_1.bin) — multilingual model, 190 MB.
- [runtime-NOTICES.zip](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/download/v1.0.0/runtime-NOTICES.zip) — companion runtime licenses; retain them with the runtime.

Extract both ZIPs into that folder. Keep the model beside the ZIPs, with the
runtime's `Release/` directory underneath. Open PowerShell in that folder and
transcribe a local 16-bit PCM WAV recording:

```powershell
.\Release\whisper-cli.exe -m .\ggml-small-q5_1.bin -f .\recording.wav -l ar -ng -otxt
```

Use `-l en` for English or `-l hi` for Hindi. `-ng` selects CPU inference;
`-otxt` writes a text transcript beside the recording. The Windows archive
contains additional upstream tools; this command uses `whisper-cli.exe`.

The runtime may need Microsoft's x64 Visual C++ Redistributable. See
[Microsoft's official download instructions](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).

## Apple Silicon Mac

Download [whisper-cpu-macos-arm64-b5454.zip](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/download/v1.0.0/whisper-cpu-macos-arm64-b5454.zip)
and the same model above. Extract the ZIP, then place the model and recording
beside `whisper-cli`:

```sh
./whisper-cli -m ggml-small-q5_1.bin -f recording.wav -l ar -ng -otxt
```

This locally compiled runtime is **ARM64 only**, with a macOS **13.3** deployment
target. It has no Developer ID signature or notarization. An Intel Mac binary
is not included. The archive contains license notices.

## Integrity and verification

All downloads are in the [v1.0.0 release](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/tag/v1.0.0).
Compare their SHA-256 hashes with [SHA256SUMS](SHA256SUMS) before use. For the model:

```powershell
Get-FileHash .\ggml-small-q5_1.bin -Algorithm SHA256
```

Expected model SHA-256:
`ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`.
On macOS, use `shasum -a 256 ggml-small-q5_1.bin`.

The Windows runtime and license ZIPs are also committed under [artifacts/](artifacts/),
so a Git clone or GitHub source ZIP includes them. The 190 MB model is a Release
asset because it exceeds GitHub's ordinary Git file limit. Download it into
`artifacts/` and follow that folder's [instructions](artifacts/README.md), or use
the standalone download instructions above.

These exact artifacts previously passed local ClamAV checks and Windows/macOS
English transcription smoke tests. See [recorded results and dates](docs/SCAN-RESULTS.md).
Those historical checks are limited evidence, not a security certification or
corporate software approval. Known upstream issues remain in [SECURITY.md](SECURITY.md).
Transcription runs locally after setup; keep private recordings and transcripts
out of this public repository.

## Provenance and licenses

Whisper model: OpenAI, MIT. Converted/quantized weights:
[`ggerganov/whisper.cpp`](https://huggingface.co/ggerganov/whisper.cpp), revision
`5359861c739e955e79d9a303bcbc70fb988958b1`.
Runtime: [whisper.cpp](https://github.com/ggml-org/whisper.cpp), **v1.9.5 / b5454**,
commit `d1be6fde11ac6e0407606b4e42fe72d34add8037`.
This kit mirrors existing model and Windows binary bytes; the Mac CLI was built
locally from that runtime commit. See [model-manifest.json](model-manifest.json),
[runtime-manifest.json](runtime-manifest.json), [LICENSE](LICENSE) and
[third-party notices](THIRD_PARTY_NOTICES.md). No upstream endorsement is claimed.
