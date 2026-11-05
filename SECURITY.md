# Security status

This kit redistributes a model and native CPU runtimes with recorded artifact
verification. A matching hash establishes byte identity. Zero antivirus
detections means the named engine/database found no matching signature on the
scan date. Neither proves the absence of vulnerabilities.

## Upstream reports checked on 4 November 2026

The Windows x64 **b5454** ZIP and locally built Mac ARM64 CLI use whisper.cpp
commit `d1be6fde11ac6e0407606b4e42fe72d34add8037`, also tagged **v1.9.5**.
The following statuses are the recorded review on that date, not a claim that
every upstream issue has been rechecked for this mirror:

| Report | Trigger | Recorded status |
| --- | --- | --- |
| [CVE-2026-110810](https://security-tracker.debian.org/tracker/CVE-2026-110810) | Malformed model tensor-type field; out-of-bounds read | Fixed in upstream 1.9.5, commit `60c0be6ac8fa71b1a2ae2dd938a31a34a508e774`. |
| [CVE-2026-17512](https://security-tracker.debian.org/tracker/CVE-2026-17512) | Audio shorter than 201 samples; out-of-bounds read | Debian tracked 1.9.5 as affected; [fix PR 3925](https://github.com/ggml-org/whisper.cpp/pull/3925) was open when checked. |
| [CVE-2026-17513](https://security-tracker.debian.org/tracker/CVE-2026-17513) | Invalid model `ftype`; process abort | Debian tracked 1.9.5 as affected; [report 3924](https://github.com/ggml-org/whisper.cpp/issues/3924) was closed by a stale bot, which does not establish a fix. |
| [CVE-2026-10298](https://security-tracker.debian.org/tracker/CVE-2026-10298) | Zero-dimension model header; process abort | Unresolved in the tracker when checked; Debian described negligible security impact. |

For the older invalid-free report CVE-2025-14569, an upstream maintainer
[reported a fix](https://github.com/ggml-org/whisper.cpp/issues/3501) through
commit `cec1dd9`, which updated miniaudio. Tracker and upstream statuses can differ.
These are existing upstream reports; this repository does not patch the runtime.

## Checks and limits

[Scan results](docs/SCAN-RESULTS.md) record the model scan on 4 November 2026,
runtime scans on 5 November 2026 and historical English CPU smoke tests.
These do not establish exhaustive dependency CVE clearance, binary/source
audit coverage, recording accuracy or employer approval. The Mac binary is not
Developer ID signed or notarized. The extra tools in the Windows ZIP have not
all been functionally tested.

A prior Codex Security source scan failed to start with "The selected scan target
changed while the scan was starting. Try again." It produced no scan ID or
completed source-audit report and is not claimed as a completed audit.

For corporate use, have the exact build and known issues reviewed under your
employer's software policy. Verify hashes before loading the model, run local
file transcription as a normal user and keep recordings in approved local
storage. Do not publish private recordings, transcripts or credentials here.

Report runtime defects to [whisper.cpp](https://github.com/ggml-org/whisper.cpp).
For a mirror-byte mismatch, open an issue in this repository with expected and
actual hashes, without attaching private data.
