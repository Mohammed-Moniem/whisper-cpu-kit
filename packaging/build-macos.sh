#!/bin/sh
# Build the pinned upstream CLI with only macOS system runtime dependencies.
# The calling workflow verifies the downloaded source archive before this step.
set -eu

if [ "$#" -ne 3 ]; then
    printf '%s\n' 'Usage: sh packaging/build-macos.sh SOURCE_DIR OUTPUT_DIR arm64|x86_64' >&2
    exit 2
fi
if [ "$(uname -s)" != Darwin ]; then
    printf '%s\n' 'ERROR: The Mac runtime must be built on macOS.' >&2
    exit 1
fi
arch=$3
case "$arch" in
    arm64|x86_64) ;;
    *) printf '%s\n' 'ERROR: Architecture must be arm64 or x86_64.' >&2; exit 2 ;;
esac
if [ "$(uname -m)" != "$arch" ]; then
    printf '%s\n' 'ERROR: Requested architecture must match the build host.' >&2
    exit 1
fi

case "$1" in
    /*) source_candidate=$1 ;;
    *) source_candidate=$(pwd -P)/$1 ;;
esac
source_dir=$(CDPATH= cd -P "$source_candidate" && pwd -P)
case "$2" in
    /*) output_candidate=$2 ;;
    *) output_candidate=$(pwd -P)/$2 ;;
esac
if [ ! -f "$source_dir/CMakeLists.txt" ] || [ ! -f "$source_dir/examples/cli/cli.cpp" ]; then
    printf '%s\n' 'ERROR: SOURCE_DIR must contain the extracted whisper.cpp source.' >&2
    exit 1
fi
if ! grep -q '^set(WHISPER_VERSION_MAJOR 1)$' "$source_dir/CMakeLists.txt" ||
   ! grep -q '^set(WHISPER_VERSION_MINOR 9)$' "$source_dir/CMakeLists.txt" ||
   ! grep -q '^set(WHISPER_VERSION_PATCH 5)$' "$source_dir/CMakeLists.txt"; then
    printf '%s\n' 'ERROR: Expected whisper.cpp 1.9.5 source.' >&2
    exit 1
fi

work_dir=$(mktemp -d /tmp/whisper-macos-build.XXXXXX)
work_dir=$(CDPATH= cd -P "$work_dir" && pwd -P)
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

# A parent CMake project avoids upstream standalone configuration writing
# bindings/javascript/package.json back into the source directory.
mkdir "$work_dir/project"
cat > "$work_dir/project/CMakeLists.txt" <<'CMAKE'
cmake_minimum_required(VERSION 3.14)
project(whisper_cpu_portable C CXX)
add_compile_options(
    "-ffile-prefix-map=${WHISPER_SOURCE_DIR}=/whisper.cpp"
    "-fdebug-prefix-map=${WHISPER_SOURCE_DIR}=/whisper.cpp"
    "-ffile-prefix-map=${PORTABLE_BUILD_ROOT}=/portable-build"
    "-fdebug-prefix-map=${PORTABLE_BUILD_ROOT}=/portable-build"
)
add_subdirectory("${WHISPER_SOURCE_DIR}" upstream)
CMAKE

cc=$(xcrun --find clang)
cxx=$(xcrun --find clang++)
sdk=$(xcrun --sdk macosx --show-sdk-path)

set -- \
    -G 'Unix Makefiles' \
    -DCMAKE_BUILD_TYPE=Release \
    "-DCMAKE_C_COMPILER=$cc" \
    "-DCMAKE_CXX_COMPILER=$cxx" \
    -DCMAKE_C_FLAGS:STRING= \
    -DCMAKE_CXX_FLAGS:STRING= \
    -DCMAKE_EXE_LINKER_FLAGS:STRING= \
    "-DCMAKE_OSX_SYSROOT=$sdk" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=13.3 \
    "-DCMAKE_OSX_ARCHITECTURES=$arch" \
    "-DWHISPER_SOURCE_DIR:PATH=$source_dir" \
    "-DPORTABLE_BUILD_ROOT:PATH=$work_dir" \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_IS_DEV=OFF \
    -DWHISPER_BUILD_NUMBER=5454 \
    -DWHISPER_BUILD_COMMIT=d1be6fde11ac6e0407606b4e42fe72d34add8037 \
    -DWHISPER_BUILD_EXAMPLES=ON \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF \
    -DWHISPER_CURL=OFF \
    -DWHISPER_SDL2=OFF \
    -DWHISPER_COREML=OFF \
    -DWHISPER_OPENVINO=OFF \
    -DGGML_BACKEND_DL=OFF \
    -DGGML_NATIVE=OFF \
    -DGGML_CPU=ON \
    -DGGML_CPU_ALL_VARIANTS=OFF \
    -DGGML_CCACHE=OFF \
    -DGGML_METAL=OFF \
    -DGGML_ACCELERATE=ON \
    -DGGML_BLAS=ON \
    -DGGML_BLAS_VENDOR=Apple \
    -DGGML_OPENMP=OFF \
    -DGGML_CUDA=OFF \
    -DGGML_VULKAN=OFF \
    -DGGML_RPC=OFF \
    -DGGML_BUILD_TESTS=OFF \
    -DGGML_BUILD_EXAMPLES=OFF

if [ "$arch" = arm64 ]; then
    set -- "$@" -DGGML_CPU_ARM_ARCH=armv8-a
else
    set -- "$@" \
        -DGGML_SSE42=ON \
        -DGGML_AVX=OFF \
        -DGGML_AVX2=OFF \
        -DGGML_AVX_VNNI=OFF \
        -DGGML_FMA=OFF \
        -DGGML_F16C=OFF \
        -DGGML_BMI2=OFF \
        -DGGML_AVX512=OFF \
        -DGGML_AVX512_VBMI=OFF \
        -DGGML_AVX512_VNNI=OFF \
        -DGGML_AVX512_BF16=OFF \
        -DGGML_AMX_TILE=OFF \
        -DGGML_AMX_INT8=OFF \
        -DGGML_AMX_BF16=OFF
fi

cmake -S "$work_dir/project" -B "$work_dir/build" "$@"
cmake --build "$work_dir/build" --config Release --target whisper-cli --parallel 4
binary=$work_dir/build/bin/whisper-cli
if [ ! -x "$binary" ]; then
    printf '%s\n' 'ERROR: Build did not produce whisper-cli.' >&2
    exit 1
fi

if [ "$(lipo -archs "$binary")" != "$arch" ]; then
    printf '%s\n' 'ERROR: Built executable has an unexpected architecture.' >&2
    exit 1
fi
file -b "$binary" > "$work_dir/file.txt"
if ! grep -q "Mach-O 64-bit executable $arch" "$work_dir/file.txt"; then
    printf '%s\n' 'ERROR: Expected a native 64-bit Mach-O executable.' >&2
    exit 1
fi

otool -L "$binary" > "$work_dir/dependencies.raw"
if ! awk 'NR > 1 {
    count++;
    if ($1 !~ /^\/usr\/lib\// && $1 !~ /^\/System\/Library\//) {
        print "ERROR: Non-system runtime dependency: " $1 > "/dev/stderr";
        bad = 1;
    }
} END { if (count == 0) bad = 1; exit bad }' "$work_dir/dependencies.raw"; then
    exit 1
fi

xcrun vtool -show-build "$binary" > "$work_dir/deployment.raw"
if ! awk '$1 == "minos" {
    count++;
    if ($2 != "13.3") bad = 1;
} END { if (count != 1) bad = 1; exit bad }' "$work_dir/deployment.raw"; then
    printf '%s\n' 'ERROR: Built executable must target macOS 13.3.' >&2
    exit 1
fi

# Ad hoc signing preserves local executable integrity without implying a
# Developer ID identity, notarization, or corporate application approval.
codesign --force --sign - "$binary"
codesign --verify --strict "$binary"
"$binary" --version > "$work_dir/version.txt"
if ! grep -qx 'whisper.cpp version: 1.9.5' "$work_dir/version.txt"; then
    printf '%s\n' 'ERROR: Built executable reports an unexpected version.' >&2
    exit 1
fi

mkdir -p "$output_candidate"
output_dir=$(CDPATH= cd -P "$output_candidate" && pwd -P)
case "$output_dir/" in
    "$source_dir/"*)
        printf '%s\n' 'ERROR: Output directory must be outside the upstream source.' >&2
        exit 1 ;;
esac
cp "$binary" "$output_dir/whisper-cli"
chmod 755 "$output_dir/whisper-cli"
sed '1s@.*@whisper-cli:@' "$work_dir/dependencies.raw" > "$output_dir/dependencies.txt"

cat > "$output_dir/build-config.txt" <<EOF
Upstream: ggml-org/whisper.cpp
Version: 1.9.5
Build number: 5454
Source commit pinned by calling workflow: d1be6fde11ac6e0407606b4e42fe72d34add8037
Architecture: $arch
Configuration: Release; target whisper-cli; Unix Makefiles; parallel 4
macOS deployment target: 13.3
Compiler: Apple clang from xcrun
Static internal libraries: BUILD_SHARED_LIBS=OFF; GGML_BACKEND_DL=OFF
CPU: GGML_CPU=ON; GGML_NATIVE=OFF; GGML_CPU_ALL_VARIANTS=OFF
System acceleration: GGML_ACCELERATE=ON; GGML_BLAS=ON; GGML_BLAS_VENDOR=Apple
Disabled: Metal; OpenMP; CUDA; Vulkan; RPC; CoreML; OpenVINO; curl; SDL2; tests; server
Source and temporary build paths remapped in C/C++ file/debug metadata
Signing: ad hoc; not Developer ID signed or notarized
EOF
if [ "$arch" = arm64 ]; then
    printf '%s\n' 'ARM baseline: GGML_CPU_ARM_ARCH=armv8-a' >> "$output_dir/build-config.txt"
else
    printf '%s\n' 'Intel baseline: SSE4.2; AVX/AVX2/AVX-VNNI/FMA/F16C/BMI2/AVX512/AMX disabled' >> "$output_dir/build-config.txt"
fi
"$cc" --version > "$work_dir/compiler.txt"
sed -n '1p' "$work_dir/compiler.txt" >> "$output_dir/build-config.txt"
cat "$work_dir/file.txt" >> "$output_dir/build-config.txt"
sed '1s@.*@whisper-cli:@' "$work_dir/deployment.raw" >> "$output_dir/build-config.txt"
cat "$work_dir/version.txt" >> "$output_dir/build-config.txt"
(cd "$output_dir" && shasum -a 256 whisper-cli) >> "$output_dir/build-config.txt"

printf 'Built native Mac CPU runtime for %s.\n' "$arch"
