# Complete portable package verification

The v1.1.0 release bundles the model and native CPU executables in one ZIP.
Only the released ZIP is the complete runtime download; a Git clone or GitHub
source ZIP does not include the 190 MB model.

## Build identity

- Upstream: whisper.cpp v1.9.5 / b5454, commit
  `d1be6fde11ac6e0407606b4e42fe72d34add8037`.
- Source archive SHA-256:
  `6be93b881acb415c5a25d0ef85bb6a488099de0296e072e22a66d50f20ec40b9`.
- Shared multilingual Small Q5_1 model: 190,085,487 bytes, SHA-256
  `ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`.
- Included public JFK sample: 352,078 bytes, SHA-256
  `59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e`.

The final `bundle-manifest.json` records a separate build run and packaging
commit for each platform, plus every payload file's size and hash. Both Mac
build jobs passed in [run 42177019183](https://github.com/Mohammed-Moniem/whisper-cpu-kit/actions/runs/42177019183);
the first Windows job in that run failed during build-script tool resolution.
Only successfully tested native artifacts are admitted to the assembled ZIP.

The repaired [Windows build and test run 42177998697](https://github.com/Mohammed-Moniem/whisper-cpu-kit/actions/runs/42177998697)
passed on 6 November 2026. The automatic selector chose the AVX2 engine; the
generic engine also transcribed the sample successfully. Its generic fallback
is substantially slower: the same short sample took about 7.4 seconds in the
AVX2 engine and 82.1 seconds in the generic engine on that hosted runner. These
short checks are not a timing guarantee for another laptop or a long recording.

## Dependency checks

Windows engines are compiled Release x64 with static internal libraries and
the static MSVC C/C++ runtime (`/MT`). Generated project files are checked for
`MultiThreaded` on all six linked targets. `dumpbin /DEPENDENTS` rejects external
C/C++ runtime, OpenMP, GGML and whisper DLL imports and requires each imported
DLL to exist in Windows System32. The selector is a baseline x64 program; it
checks processor and operating-system AVX support before choosing an AVX2 or
generic executable. All three embed an `asInvoker` / UTF-8 manifest.

The native ARM64 and x86_64 Mac binaries link only macOS `libSystem`, `libc++`
and Accelerate. The package supplies no Apple system libraries. Both are built
for macOS 13.3, use static internal libraries and have verified ad hoc signatures.
Metal, OpenMP, server, SDL2, curl and optional external inference backends are
disabled. Windows binaries are not Authenticode signed; Mac binaries are not
Developer ID signed or notarized.

## Execution checks

Build jobs exercise the included launchers from a different working directory
with only operating-system directories on PATH. A short English sample must
produce recognizable text containing `country`, using CPU inference. Tests
also use spaced and Hindi-script input paths, and check rejection of missing
files and unsupported language codes. Windows exercises both the automatic
selector and the generic engine directly.

Mac tests run under `sandbox-exec` with network access denied. Windows tests
create outbound-block rules for the three executables on an ephemeral Actions
VM, enable any disabled firewall profiles for the test, then restore them.
These test scripts are maintainer checks; they are not target-machine setup
steps and do not modify a user's corporate laptop.

## Final ZIP and antivirus

- File: `whisper-cpu-kit-portable-v1.1.0.zip`.
- Size: 188,903,554 bytes, about 189 MB / 180 MiB.
- SHA-256: `446b218e58f55cf61c977250cde81d1ca8a883b7dbe24b72def75cad099f1cb7`.
- Payload: 34 files, including the shared model, five native executables, two
  launchers, sample, thirteen notice files, provenance, manifest and checksums.
- ZIP inventory, CRC and stored executable permissions verified during assembly.

ClamAV **1.5.4** scanned the entire extracted 34-file package and the final ZIP
on **6 November 2026**: 35 scanned files, **0 infected**, process exit 0, no
reported scan errors or size-limit skips. Scan limits were 300 MiB per file and
900 MiB per container; the model and ZIP are below those limits. The database
was refreshed that day and its files passed `sigtool --info` verification:
main 63, daily 28174 (built 5 November), bytecode 339; 3,628,245 loaded signatures.
The earlier model/both-Mac-file scan also returned zero detections.

Zero detections means this engine and signature set found no matching malware
signature. It does not establish absence of vulnerabilities, safe handling of
malformed audio/models, exhaustive dependency CVE clearance or employer approval.

The final public-download execution checks **all passed** on 6 November 2026
in [run 42178890561](https://github.com/Mohammed-Moniem/whisper-cpu-kit/actions/runs/42178890561),
using packaging/metadata commit `bd04ad5099cab2d0cecc8f5ceb8985383894df94`:

| Runner | Result |
| --- | --- |
| [Windows Server 2022 x64](https://github.com/Mohammed-Moniem/whisper-cpu-kit/actions/runs/42178890561/job/127763625530) | PASS: ZIP/payload hashes, automatic AVX2 selection, generic engine, Unicode/space paths, restricted PATH, outbound-denied CPU transcription and input errors |
| [macOS 15 Apple Silicon](https://github.com/Mohammed-Moniem/whisper-cpu-kit/actions/runs/42178890561/job/127763625085) | PASS: ZIP/payload hashes, native architecture, system-only dependencies, Unicode/space paths, restricted PATH, network-denied CPU transcription and input errors |
| [macOS 15 Intel](https://github.com/Mohammed-Moniem/whisper-cpu-kit/actions/runs/42178890561/job/127763625495) | PASS: same Mac checks using the native x86_64 runtime |

Each job downloaded only the published ZIP, verified its archive hash and all
payload hashes, extracted it and ran the bundled launcher. No target-side
Python, compiler, package manager, model download or separate C/C++ runtime
installation was used. GitHub's recorded release-asset digest also matches the
scanned local ZIP SHA-256 above. An independent archive review verified all 34
members, all checksums and executable modes, and found no private home paths,
credential patterns, Python files or development artifacts in the payload.

The exact new ARM64 CI binary also completed two existing public Google FLEURS
Arabic fixtures and one existing synthetic Hindi fixture with the pinned model.
All exited successfully with CPU inference and emitted the expected Arabic or
Devanagari script. Arabic words and numeric times were corrupted, and the Hindi
output had phonetic misspellings. These checks establish execution and script
compatibility, not transcription accuracy or human Hindi validation. These
additional fixtures and their transcripts are not included in the release.

## Limits

These are native execution and packaging checks on GitHub-hosted Windows Server
2022 and macOS 15 runners, plus a local Apple Silicon Mac. They do not establish
testing on every Windows 10/11 or macOS 13.3 computer, employer approval,
exhaustive CVE clearance, full source audit coverage or meeting accuracy.
The CLI and model can make substantial transcription errors. Supported input
for the launchers is 16-bit PCM WAV; an audio converter is not bundled.
Known upstream reports remain in [SECURITY.md](../SECURITY.md).
