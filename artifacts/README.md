# Downloaded runtime files

These Windows runtime and companion-license ZIPs were copied from the local
Downloads folder and matched the recorded SHA-256 values before publication.
They are ordinary Git files and are included in a clone or source ZIP.

The model is **190,085,487 bytes** and exceeds GitHub's ordinary Git file limit.
[Download ggml-small-q5_1.bin](https://github.com/Mohammed-Moniem/whisper-cpu-kit/releases/download/v1.0.0/ggml-small-q5_1.bin)
into this folder. Its SHA-256 is
`ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`.
The model is not included in Git.

Extract both ZIPs here, retain the notices, and run PowerShell in this folder:

```powershell
.\Release\whisper-cli.exe -m .\ggml-small-q5_1.bin -f .\recording.wav -l ar -ng -otxt
```

Use `-l en` or `-l hi` for English or Hindi. The Microsoft x64 Visual C++ runtime
may be required. See the root README and SECURITY.md for prerequisites and limits.
The optional Mac runtime remains available in Releases.

The SHA256SUMS in this folder covers the two Git-tracked ZIPs. It does not imply
a new malware scan or security certification; the bytes match the previously
scanned and tested release artifacts.
