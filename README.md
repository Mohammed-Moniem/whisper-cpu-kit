# Whisper CPU kit

Portable, offline transcription for **Arabic, English and Hindi** on Windows
x64, Apple Silicon Macs and Intel Macs.

## Download the complete package

**[Download whisper-cpu-kit-portable-v1.1.0.zip](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/download/v1.1.0/whisper-cpu-kit-portable-v1.1.0.zip)**

Extract the entire ZIP. It contains the multilingual **Small Q5_1 model**,
native executables for all three platforms, automatic launchers, a short test
recording, checksums, provenance and licenses. No Python, compiler, package
manager, account, internet connection or additional download is needed to
transcribe a supported recording after extraction. Windows executables include
the MSVC runtime statically; no separate Visual C++ installer is needed.

Supported systems:

| System | Included runtime |
| --- | --- |
| Windows 10 version 1903 or later / Windows 11, Intel or AMD x64 | Automatic AVX2 selection, plus a generic CPU fallback |
| macOS 13.3 or later, Apple Silicon | Native ARM64 CPU executable |
| macOS 13.3 or later, Intel Mac | Native x86_64 CPU executable |

Windows ARM64 and older macOS versions are outside this package's supported
platforms. On macOS the binaries have ad hoc signatures, without Developer ID
signing or notarization. Corporate application controls may require IT approval.

## Run it

Use a **16-bit PCM WAV** recording. Open a terminal in the extracted
`whisper-cpu-kit` folder:

Windows Command Prompt:

```bat
transcribe.cmd "C:\Users\You\Documents\recording.wav" ar
```

Mac Terminal:

```sh
./transcribe.sh "/Users/you/Documents/recording.wav" ar
```

Use `ar` for Arabic, `en` for English or `hi` for Hindi. Arabic is the default.
The launcher chooses the native executable, disables GPU execution and uses
four CPU threads. The transcript is saved beside the recording as
`recording.wav.txt`; that folder must be writable.

Test with the included public English sample:

```bat
transcribe.cmd sample.wav en
```

```sh
./transcribe.sh sample.wav en
```

Audio conversion software is not included. Convert recordings in another format
to 16-bit PCM WAV using an approved tool before running the launcher.

## Integrity and verification

The [v1.1.0 release](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/tag/v1.1.0)
includes the ZIP, [bundle-SHA256SUMS.txt](bundle-SHA256SUMS.txt) and
[bundle-manifest.json](bundle-manifest.json). The extracted package also contains
`SHA256SUMS` covering every payload file. Verify the ZIP before extraction:

```powershell
Get-FileHash .\whisper-cpu-kit-portable-v1.1.0.zip -Algorithm SHA256
```

```sh
shasum -a 256 whisper-cpu-kit-portable-v1.1.0.zip
```

See [complete-package verification](docs/COMPLETE-PACKAGE.md) for build,
dependency, offline execution and antivirus evidence. These checks do not
certify security or establish employer approval. Known upstream reports and
limitations are recorded in [SECURITY.md](SECURITY.md).

The 190 MB model is the smallest of Tiny, Base and Small that retained the
expected scripts in our limited comparison. Recognition can still make
substantial errors, especially for Arabic and Hindi. Proofread transcripts;
meeting accuracy has not been qualified. Keep private recordings and transcripts
out of this public repository.

## Contents and provenance

```text
whisper-cpu-kit/
  transcribe.cmd
  transcribe.sh
  bin/windows-x64/whisper-cli.exe
  bin/windows-x64/whisper-cli-avx2.exe
  bin/windows-x64/whisper-cli-generic.exe
  bin/macos-arm64/whisper-cli
  bin/macos-x64/whisper-cli
  models/ggml-small-q5_1.bin
  sample.wav
  README.txt
  SECURITY.md
  THIRD_PARTY_NOTICES.md
  LICENSE
  licenses/
  provenance/
  bundle-manifest.json
  SHA256SUMS
```

Runtime: [whisper.cpp](https://github.com/ggml-org/whisper.cpp), **v1.9.5 / b5454**,
commit `d1be6fde11ac6e0407606b4e42fe72d34add8037`. This package builds the
unmodified upstream CLI and adds launchers and a Windows CPU selector. Build
scripts, source hashes and dependency gates are in [packaging/](packaging/).
Python is used by the maintainer's ZIP assembler; it is not needed on a target
computer and is not included in the runtime ZIP.

Model: OpenAI Whisper, MIT, converted/quantized by
[`ggerganov/whisper.cpp`](https://huggingface.co/ggerganov/whisper.cpp), revision
`5359861c739e955e79d9a303bcbc70fb988958b1`. Model bytes are unchanged, with SHA-256
`ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`.
Retain [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md).
No upstream endorsement is claimed.

Download the release ZIP to obtain the complete runtime package. GitHub's
automatically generated source ZIP and an ordinary clone contain the packaging
sources and historical files; they do not contain the 190 MB model. The older
[v1.0.0 release](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/tag/v1.0.0)
remains available as a historical distribution with separate downloads.
