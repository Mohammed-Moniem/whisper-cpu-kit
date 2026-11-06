WHISPER CPU KIT - COMPLETE OFFLINE PACKAGE

This ZIP contains native runtimes for:
  Windows x64: Windows 10/11 on an Intel or AMD 64-bit processor.
  Mac arm64: Apple Silicon (M-series).
  Mac x64: Intel Mac.
The launcher selects the runtime for your computer. On Windows, the bundled
CPU selector automatically chooses the AVX2 or generic executable.

Extract the entire ZIP to a writable folder in your user account. Keep bin/,
models/, licenses/, and the launcher together. After extraction, transcription
uses the bundled native executable and model; it needs no Python, package
manager, compiler, account, internet connection, or extra model download.

Use 16-bit PCM WAV recordings. Other audio formats are not guaranteed by these
launchers. The recording must be readable, and its containing folder must be
writable so the transcript can be saved next to the recording.

WINDOWS
Open Command Prompt in the extracted folder and run:
  transcribe.cmd "C:\Users\You\Documents\recording.wav" ar

MAC
Open Terminal in the extracted folder and run:
  ./transcribe.sh "/Users/you/Documents/recording.wav" ar

Use ar for Arabic, en for English, or hi for Hindi. Arabic is the default when
you omit the language. Quote file paths containing spaces. The recording can
be outside the package folder. The launcher also works when called by its full
path from another working folder.

To check the package with its included short English sample, run:
  Windows: transcribe.cmd sample.wav en
  Mac:     ./transcribe.sh sample.wav en

The launcher uses four CPU threads and disables GPU execution. A text file is
written beside the input: recording.wav.txt. Progress and recognized text also
appear in the terminal. Review the transcript: recognition can make substantial
errors, particularly with accents, noisy meetings, or overlapping speakers.

The Mac executable is not Developer ID signed or notarized. Follow your
organization's approved application review process if macOS blocks execution.
Do not disable system security protections. Likewise, follow corporate policy
if Windows application controls block the executable.

See SECURITY.md and the included verification/provenance documents for the
exact checks performed and their limits. Antivirus and checksum checks are
not a security certification. Keep the included third-party license notices
when redistributing this package.
