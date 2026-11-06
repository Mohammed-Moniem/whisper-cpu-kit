#!/bin/sh
# Test the extracted offline kit using public sample audio only.
set -eu

if [ "$#" -ne 1 ]; then
    printf '%s\n' 'Usage: sh packaging/test-macos.sh COMPLETE_PACKAGE_DIR' >&2
    exit 2
fi
if [ "$(uname -s)" != Darwin ]; then
    printf '%s\n' 'ERROR: This test requires macOS.' >&2
    exit 1
fi
if [ ! -x /usr/bin/sandbox-exec ]; then
    printf '%s\n' 'ERROR: sandbox-exec is unavailable; network-denied transcription was not verified.' >&2
    exit 1
fi
arch=$(uname -m)
case "$arch" in
    arm64) runtime_subdir=macos-arm64 ;;
    x86_64) runtime_subdir=macos-x64 ;;
    *) printf '%s\n' 'ERROR: Unsupported Mac architecture.' >&2; exit 1 ;;
esac
case "$1" in
    /*) package_candidate=$1 ;;
    *) package_candidate=$(pwd -P)/$1 ;;
esac
package_dir=$(CDPATH= cd -P "$package_candidate" && pwd -P)

work_dir=$(mktemp -d /tmp/whisper-macos-test.XXXXXX)
work_dir=$(CDPATH= cd -P "$work_dir" && pwd -P)
trap 'rm -rf "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM
stage_dir=$work_dir/portable\ package\ with\ spaces
caller_dir=$work_dir/separate\ working\ directory
mkdir "$stage_dir" "$caller_dir"
cp -R "$package_dir/." "$stage_dir/"

restricted_path=/usr/bin:/bin:/usr/sbin:/sbin
if [ -f "$stage_dir/SHA256SUMS" ]; then
    (cd "$stage_dir" && PATH=$restricted_path /usr/bin/shasum -a 256 -c SHA256SUMS)
    checksums=passed
else
    checksums='not supplied by this minimal test stage'
fi

binary=$stage_dir/bin/$runtime_subdir/whisper-cli
launcher=$stage_dir/transcribe.sh
model=$stage_dir/models/ggml-small-q5_1.bin
sample=$stage_dir/sample.wav
if [ ! -x "$binary" ] || [ ! -x "$launcher" ] || [ ! -f "$model" ] || [ ! -f "$sample" ]; then
    printf '%s\n' 'ERROR: Package requires its executable launcher, native runtime, model, and sample.wav.' >&2
    exit 1
fi
if [ "$(/usr/bin/lipo -archs "$binary")" != "$arch" ]; then
    printf '%s\n' 'ERROR: Runtime architecture does not match this Mac.' >&2
    exit 1
fi
/usr/bin/otool -L "$binary" > "$work_dir/dependencies.txt"
if ! /usr/bin/awk 'NR > 1 {
    count++;
    if ($1 !~ /^\/usr\/lib\// && $1 !~ /^\/System\/Library\//) {
        print "ERROR: Non-system runtime dependency: " $1 > "/dev/stderr";
        bad = 1;
    }
} END { if (count == 0) bad = 1; exit bad }' "$work_dir/dependencies.txt"; then
    exit 1
fi

# sandbox-exec applies this policy only to these test processes. It does not
# change Gatekeeper, quarantine attributes, or any machine security setting.
sandbox_profile='(version 1)(allow default)(deny network*)'
recording=$caller_dir/sample\ हिंदी\ with\ spaces.wav
cp "$sample" "$recording"
cd "$caller_dir"

if PATH=$restricted_path /usr/bin/sandbox-exec -p "$sandbox_profile" \
    "$launcher" "$recording" en > "$work_dir/transcription.stdout" 2> "$work_dir/transcription.stderr"; then
    :
else
    status=$?
    cat "$work_dir/transcription.stderr" >&2
    printf 'ERROR: Network-denied CPU transcription failed with exit code %s.\n' "$status" >&2
    exit 1
fi
if [ ! -f "$recording.txt" ] || ! /usr/bin/grep -qi country "$recording.txt"; then
    printf '%s\n' 'ERROR: Expected English sample transcript was not produced.' >&2
    exit 1
fi
if ! /usr/bin/grep -Eq 'use gpu[[:space:]]*=[[:space:]]*0' "$work_dir/transcription.stderr" ||
   ! /usr/bin/grep -Eq 'system_info:.*CPU[[:space:]]*:' "$work_dir/transcription.stderr"; then
    printf '%s\n' 'ERROR: Runtime output did not confirm GPU disabled and CPU execution.' >&2
    exit 1
fi

expect_input_error() {
    name=$1
    shift
    if PATH=$restricted_path /usr/bin/sandbox-exec -p "$sandbox_profile" \
        "$launcher" "$@" > "$work_dir/$name.stdout" 2> "$work_dir/$name.stderr"; then
        status=0
    else
        status=$?
    fi
    if [ "$status" -ne 2 ]; then
        cat "$work_dir/$name.stderr" >&2
        printf 'ERROR: %s must return exit code 2; received %s.\n' "$name" "$status" >&2
        exit 1
    fi
    if /usr/bin/grep -qi 'loading model' "$work_dir/$name.stderr"; then
        printf 'ERROR: %s loaded the model before rejecting invalid input.\n' "$name" >&2
        exit 1
    fi
}

expect_input_error invalid-language "$recording" fr
expect_input_error missing-recording "$caller_dir/recording that does not exist.wav" en

printf '%s\n' \
    "Package checksum verification: $checksums" \
    "Native architecture: $arch" \
    'Runtime dependencies: macOS system libraries/frameworks only' \
    'Package path with spaces and different working directory: passed' \
    'Recording path with Unicode and spaces: passed' \
    'CPU transcription with GPU disabled: passed' \
    'Network denied for transcription and input-error tests by sandbox-exec' \
    "Restricted PATH: $restricted_path" \
    'Invalid language and missing recording: exit 2 before model loading' \
    'Mac offline package tests passed.'
