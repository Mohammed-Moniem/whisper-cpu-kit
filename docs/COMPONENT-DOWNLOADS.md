# Whisper CPU Kit: Components and Download Links

This list covers the current v1.1.0 kit for Windows x64, Intel Mac and Apple Silicon Mac. The supported input is 16-bit PCM WAV. The same multilingual model is used for Arabic, English and Hindi.

## Complete ready-to-run package

- [Download the complete portable ZIP — approximately 189 MB](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/download/v1.1.0/whisper-cpu-kit-portable-v1.1.0.zip)
- [GitHub repository](https://github.com/Mohammed-Moniem/whisper-cpu-kit)
- [Package manifest and file hashes](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/download/v1.1.0/bundle-manifest.json)
- [Download checksums](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/download/v1.1.0/bundle-SHA256SUMS.txt)
- [Verification results](https://github.com/Mohammed-Moniem/whisper-cpu-kit/blob/main/docs/COMPLETE-PACKAGE.md)
- [Security status and known limitations](https://github.com/Mohammed-Moniem/whisper-cpu-kit/blob/main/SECURITY.md)

The ZIP includes the model, native executables, launchers, sample recording, licenses and checksums. No Python, compiler or separate Visual C++ runtime installer is needed on the destination computer. Extract the entire ZIP and retain its folder structure.

## Model — required on both platforms, already bundled

- [Download multilingual Whisper Small Q5_1 — ggml-small-q5_1.bin, approximately 190 MB](https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-small-q5_1.bin)
- [Publisher's model file details and SHA-256](https://huggingface.co/ggerganov/whisper.cpp/blob/main/ggml-small-q5_1.bin)
- [Original OpenAI Whisper project](https://github.com/openai/whisper)

The download is the whisper.cpp author's converted and quantized model, rather than an OpenAI-hosted GGML download. Its path inside the extracted kit is `models/ggml-small-q5_1.bin`.

## Native engines — already bundled

- [Official whisper.cpp v1.9.5 / b5454 release](https://github.com/ggml-org/whisper.cpp/releases/tag/b5454)
- [Download the original upstream Windows x64 runtime ZIP](https://github.com/ggml-org/whisper.cpp/releases/download/b5454/whisper-bin-x64.zip)
- [Download the exact official source ZIP used for our Windows and Mac builds](https://codeload.github.com/ggml-org/whisper.cpp/zip/d1be6fde11ac6e0407606b4e42fe72d34add8037)

Our portable engines are custom builds of that upstream source. Their exact binaries are supplied in our complete ZIP. The original upstream Windows ZIP is a different build. The b5454 upstream release does not supply equivalent standalone Mac CLI downloads.

Included executable paths:

- Windows CPU selector: `bin/windows-x64/whisper-cli.exe`
- Windows optimized engine: `bin/windows-x64/whisper-cli-avx2.exe`
- Windows generic fallback: `bin/windows-x64/whisper-cli-generic.exe`
- Apple Silicon engine: `bin/macos-arm64/whisper-cli`
- Intel Mac engine: `bin/macos-x64/whisper-cli`

GGML and bundled audio/utility code are compiled into the engines; their source is included in the official source ZIP above.

## Kit-authored launchers and CPU selector — already bundled

- [Download the Windows launcher — transcribe.cmd](https://raw.githubusercontent.com/Mohammed-Moniem/whisper-cpu-kit/main/packaging/transcribe.cmd)
- [Download the Mac launcher — transcribe.sh](https://raw.githubusercontent.com/Mohammed-Moniem/whisper-cpu-kit/main/packaging/transcribe.sh)
- [Windows CPU selector source](https://github.com/Mohammed-Moniem/whisper-cpu-kit/blob/main/packaging/windows-dispatch.c)
- [Third-party licenses and notices](https://github.com/Mohammed-Moniem/whisper-cpu-kit/tree/main/licenses)

These are components maintained in our kit. They are not upstream whisper.cpp downloads.

## Operating-system components — no separate downloads

- Windows provides `KERNEL32.dll`, `ADVAPI32.dll` and `cmd.exe`: [Microsoft Command Prompt documentation](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/cmd).
- Our Windows executables embed the Microsoft C/C++ runtime statically: [Microsoft /MT runtime documentation](https://learn.microsoft.com/en-us/cpp/build/reference/md-mt-ld-use-run-time-library).
- macOS provides `libSystem`, `libc++`, Accelerate and the shell: [Apple Accelerate documentation](https://developer.apple.com/accelerate/).

The kit targets Windows 10 version 1903 or later / Windows 11 x64, and macOS 13.3 or later on Intel or Apple Silicon. Windows ARM64 is outside this kit's supported platforms.

## Audio conversion — optional and not bundled

Conversion is an additional step for M4A/MP4 recordings. No converter is needed when the recording already meets the supported WAV input format.

- [Official FFmpeg download page](https://www.ffmpeg.org/download.html) — FFmpeg publishes source code. The ready-made Windows and Mac executable downloads linked there are third-party builds.
- [Official FFmpeg source repository](https://git.ffmpeg.org/ffmpeg.git)
- [Official FFmpeg GitHub mirror](https://github.com/FFmpeg/FFmpeg)
- [Apple afconvert documentation](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/MultimediaPG/UsingAudio/UsingAudio.html) — a Mac conversion option supplied with macOS; supported input formats depend on available codecs.

## Alternative Windows runtime dependency

- [Download Microsoft's official VC++ x64 Redistributable](https://aka.ms/vc14/vc_redist.x64.exe)
- [Microsoft Redistributable documentation](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist)

This may be needed when using the original upstream dynamically linked Windows runtime. Our static portable executables do not require a separate Redistributable installation.

## Build tools — only for rebuilding or assembling the package

- [CMake official downloads — Windows and Mac](https://cmake.org/download/)
- [Download Microsoft Visual Studio 2022 Build Tools bootstrapper — Windows](https://aka.ms/vs/17/release/vs_buildtools.exe)
- [Microsoft C++ Build Tools information](https://visualstudio.microsoft.com/visual-cpp-build-tools/) — includes access to the MSVC compiler and Windows SDK. The current advertised toolchain may be newer than the VS 2022 toolchain used for this kit.
- [Apple Command Line Tools downloads — Mac](https://developer.apple.com/download/all/?q=command%20line%20tools)
- [Apple Command Line Tools installation documentation](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/)
- [Python official downloads](https://www.python.org/downloads/) — used only by our maintainer's ZIP-assembly script; not required for transcription or C++ compilation.

The Microsoft bootstrapper downloads installation components; it is not a complete offline installer. None of these development tools is required to run the complete portable ZIP.
