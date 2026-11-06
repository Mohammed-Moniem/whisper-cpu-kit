#!/bin/sh
# CPU-only, offline transcription. No downloads or package installation.
set -eu

usage() {
    printf '%s\n' 'Usage: ./transcribe.sh recording.wav [ar|en|hi]'
    printf '%s\n' 'Languages: ar = Arabic (default), en = English, hi = Hindi.'
}

if [ "$#" -eq 1 ]; then
    case "$1" in
        -h|--help) usage; exit 0 ;;
    esac
fi
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage >&2
    exit 2
fi

language=${2:-ar}
case "$language" in
    ar|en|hi) ;;
    *) printf '%s\n' 'ERROR: Language must be ar, en, or hi.' >&2; exit 2 ;;
esac

case "$0" in
    */*) launcher_dir=${0%/*} ;;
    *) launcher_dir=. ;;
esac
case "$launcher_dir" in
    /*) ;;
    *) launcher_dir=./$launcher_dir ;;
esac
package_dir=$(CDPATH= cd -P "$launcher_dir" && pwd -P)
if [ "$(uname -s)" != Darwin ]; then
    printf '%s\n' 'ERROR: This launcher supports macOS. Use transcribe.cmd on Windows.' >&2
    exit 1
fi
case "$(uname -m)" in
    arm64) binary=$package_dir/bin/macos-arm64/whisper-cli ;;
    x86_64) binary=$package_dir/bin/macos-x64/whisper-cli ;;
    *) printf '%s\n' 'ERROR: Unsupported Mac processor architecture.' >&2; exit 1 ;;
esac
model=$package_dir/models/ggml-small-q5_1.bin

if [ ! -x "$binary" ]; then
    printf '%s\n' 'ERROR: The native Mac executable is missing or is not executable. Extract the complete package.' >&2
    exit 1
fi
if [ ! -f "$model" ]; then
    printf '%s\n' 'ERROR: models/ggml-small-q5_1.bin is missing. Extract the complete package.' >&2
    exit 1
fi
if [ ! -f "$1" ]; then
    printf '%s\n' 'ERROR: The recording must be an existing WAV file.' >&2
    exit 2
fi

case "$1" in
    /*) recording=$1 ;;
    *) recording=$(pwd -P)/$1 ;;
esac

exec "$binary" -m "$model" -f "$recording" -l "$language" -ng -t 4 -otxt
