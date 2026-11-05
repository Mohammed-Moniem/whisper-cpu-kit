# Existing artifact evidence carried into this repository

The files mirrored here are unchanged. Their hashes in SHA256SUMS match the
previously scanned and tested artifacts; this is not a new security audit.

| Artifact | Local ClamAV evidence |
| --- | --- |
| ggml-small-q5_1.bin | 4 November 2026, 23:11 Asia/Dubai; 1 file, zero detections, exit 0 |
| Windows ZIP, its 41 extracted files, final Mac executable | 5 November 2026, 07:01 Asia/Dubai; 43 files, zero detections, exit 0 |
| Final Mac and license ZIPs | 5 November 2026, 07:06 Asia/Dubai; 2 files, zero detections, exit 0 |

Engine: ClamAV 1.5.4, main63, daily28173, bytecode339; 3,628,245 signatures.
All scans ran locally. The model scan used verified official database signatures;
the databases were refreshed before the runtime checks. Retained scan summaries
are in antivirus.txt. Matching hashes establish byte identity, not safety.

The same runtime/model bytes passed actual English CPU transcription on Windows
x64 and macOS 15 ARM64 in the [earlier workflow run](https://github.com/Mohammed-Moniem/offline-transcriber-cpu/actions/runs/41959675290).
The Mac executable also completed local Arabic and synthetic Hindi inference.
Material transcription errors remained; human Hindi accuracy and the user's
recordings are unqualified. No comprehensive source or binary security audit
was completed. Known upstream issues are recorded in SECURITY.md.

This repository's manual verification workflow separately downloads its own
published files, verifies their hashes and transcribes a public English sample.
The release notes link its actual result once that workflow completes.
