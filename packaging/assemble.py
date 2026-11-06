#!/usr/bin/env python3
"""Build-time assembler for the self-contained native transcription ZIP.

Python is used only by the maintainer while assembling the release. No Python
source, interpreter, installer, or development tool is included in the ZIP.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import struct
import sys
import tempfile
import zipfile


REPOSITORY = "https://github.com/Mohammed-Moniem/whisper-cpu-kit"
VERSION = "1.1.0"
PACKAGE_DIRECTORY = "whisper-cpu-kit"
ZIP_NAME = "whisper-cpu-kit-portable-v1.1.0.zip"
ZIP_TIMESTAMP = (2026, 11, 6, 0, 0, 0)
MODEL_NAME = "ggml-small-q5_1.bin"
MODEL_SIZE = 190085487
MODEL_SHA256 = "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb"
SAMPLE_SIZE = 352078
SAMPLE_SHA256 = "59dfb9a4acb36fe2a2affc14bacbee2920ff435cb13cc314a08c13f66ba7860e"
UPSTREAM_COMMIT = "d1be6fde11ac6e0407606b4e42fe72d34add8037"
SOURCE_SHA256 = "6be93b881acb415c5a25d0ef85bb6a488099de0296e072e22a66d50f20ec40b9"
CHUNK_SIZE = 1024 * 1024
LICENSE_NAMES = (
    "Apache-2.0.txt", "README.md", "SDL2-zlib.txt", "Unicode-3.0.txt",
    "YaRN-MIT.txt", "cpp-httplib-MIT.txt", "llama.cpp-MIT.txt",
    "llamafile-MIT.txt", "miniaudio-license-options.txt",
    "nlohmann-json-MIT.txt", "nlohmann-json-additional-MIT-notices.txt",
    "stb_vorbis-license-options.txt", "whisper.cpp-ggml-MIT.txt",
)
ARTIFACT_FILES = {
    "windows-x64": (
        "whisper-cli.exe", "whisper-cli-avx2.exe", "whisper-cli-generic.exe",
        "dependencies.txt", "build-config.txt",
    ),
    "macos-arm64": ("whisper-cli", "dependencies.txt", "build-config.txt"),
    "macos-x64": ("whisper-cli", "dependencies.txt", "build-config.txt"),
}
PACKAGING_SOURCE_NAMES = (
    "assemble.py", "build-macos.sh", "build-windows.ps1", "source-lock.json",
    "transcribe.cmd", "transcribe.sh", "windows-dispatch.c",
    "windows-utf8.manifest", "PACKAGE-README.txt",
)
PRIVATE_HOME = re.compile(
    r'(?i)(?:/Users/|/home/|[a-z]:[\\/]+Users[\\/]+)([^/\\\s"<>]+)'
)
EXAMPLE_USER_NAMES = {"you", "username", "yourname", "user"}
SECRET = re.compile(
    r"ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|"
    + re.escape("-" * 5 + "BEGIN ")
    + r"(?:RSA |EC |OPENSSH )?" + re.escape("PRIVATE KEY" + "-" * 5)
)


def regular_file(path):
    """Reject symlinks, directories and special files at the input boundary."""
    path = Path(path)
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"Expected a regular nonsymlink file: {path.name}")
    return path


def sha256(path):
    digest = hashlib.sha256()
    with regular_file(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def identity(path):
    path = regular_file(path)
    return {"size_bytes": path.stat().st_size, "sha256": sha256(path)}


def verify_identity(path, size, digest, label):
    result = identity(path)
    if result != {"size_bytes": size, "sha256": digest}:
        raise ValueError(f"{label} does not match the pinned size and SHA-256.")
    return result


def check_public_text(data, label):
    if len(data) > 2 * CHUNK_SIZE:
        raise ValueError(f"Unexpectedly large text input: {label}")
    text = data.decode("utf-8-sig")
    for match in PRIVATE_HOME.finditer(text):
        if match.group(1).lower() not in EXAMPLE_USER_NAMES:
            raise ValueError(f"A private home-directory path appears in {label}.")
    if "/private/var/folders/" in text or SECRET.search(text):
        raise ValueError(f"Private machine data or credential-like text appears in {label}.")
    return text


def check_native_binary(path, platform):
    path = regular_file(path)
    file_size = path.stat().st_size
    with path.open("rb") as stream:
        header = stream.read(64)
        if platform == "windows-x64":
            if len(header) < 64 or header[:2] != b"MZ":
                raise ValueError(f"Expected a Windows executable: {path.name}")
            pe_offset = struct.unpack_from("<I", header, 60)[0]
            if pe_offset > file_size - 26:
                raise ValueError(f"Invalid PE header offset: {path.name}")
            stream.seek(pe_offset)
            pe_header = stream.read(26)
            machine = struct.unpack_from("<H", pe_header, 4)[0]
            characteristics = struct.unpack_from("<H", pe_header, 22)[0]
            optional_magic = struct.unpack_from("<H", pe_header, 24)[0]
            if (pe_header[:4] != b"PE\0\0" or machine != 0x8664
                    or not characteristics & 0x0002
                    or characteristics & 0x2000 or optional_magic != 0x020B):
                raise ValueError(f"Expected an x64 PE executable, without DLL type: {path.name}")
        else:
            cpu_type = 0x0100000C if platform == "macos-arm64" else 0x01000007
            if (len(header) < 32 or header[:4] != b"\xcf\xfa\xed\xfe"
                    or struct.unpack_from("<I", header, 4)[0] != cpu_type
                    or struct.unpack_from("<I", header, 12)[0] != 2):
                raise ValueError(f"Expected a thin native {platform} Mach-O executable.")


def inspect_artifacts(native_root):
    native_root = Path(native_root)
    if native_root.is_symlink() or not native_root.is_dir():
        raise ValueError("--native-root must be a nonsymlink artifact directory.")
    expected_directories = {f"native-{platform}" for platform in ARTIFACT_FILES}
    actual_directories = {entry.name for entry in native_root.iterdir()}
    if actual_directories != expected_directories:
        raise ValueError("Native root must contain exactly the three expected native-* artifact directories.")
    result = {}
    for platform, expected_names in ARTIFACT_FILES.items():
        directory = native_root / f"native-{platform}"
        if directory.is_symlink() or not directory.is_dir():
            raise ValueError(f"Invalid native artifact directory: native-{platform}")
        entries = {entry.name: entry for entry in directory.iterdir()}
        if set(entries) != set(expected_names):
            raise ValueError(f"Unexpected or missing files in native-{platform}; only its exact runtime allowlist is accepted.")
        for name, path in entries.items():
            regular_file(path)
            if name.endswith(".txt"):
                check_public_text(path.read_bytes(), f"{platform}/{name}")
            else:
                check_native_binary(path, platform)
        result[platform] = entries
    return result


def copy_file(source, destination, mode=0o644):
    source = regular_file(source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with source.open("rb") as incoming, destination.open("xb") as outgoing:
        shutil.copyfileobj(incoming, outgoing, CHUNK_SIZE)
    destination.chmod(mode)


def write_bytes(path, data, mode=0o644):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(data)
    path.chmod(mode)


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def safe_archive_name(name):
    path = PurePosixPath(name)
    if (path.is_absolute() or ".." in path.parts or "\\" in name
            or not path.parts or path.parts[0] != PACKAGE_DIRECTORY):
        raise ValueError("Unsafe ZIP member name.")


def create_zip(stage, zip_path):
    with zipfile.ZipFile(zip_path, "x", compression=zipfile.ZIP_DEFLATED,
                         compresslevel=6, allowZip64=True) as archive:
        for path in sorted(stage.rglob("*")):
            if path.is_dir():
                continue
            regular_file(path)
            name = f"{PACKAGE_DIRECTORY}/{path.relative_to(stage).as_posix()}"
            safe_archive_name(name)
            info = zipfile.ZipInfo(name, ZIP_TIMESTAMP)
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | stat.S_IMODE(path.stat().st_mode)) << 16
            info.file_size = path.stat().st_size
            with path.open("rb") as incoming, archive.open(info, "w") as outgoing:
                shutil.copyfileobj(incoming, outgoing, CHUNK_SIZE)
    with zipfile.ZipFile(zip_path, "r") as archive:
        names = archive.namelist()
        expected_names = {
            f"{PACKAGE_DIRECTORY}/{path.relative_to(stage).as_posix()}"
            for path in stage.rglob("*") if path.is_file()
        }
        if len(names) != len(set(names)) or set(names) != expected_names:
            raise ValueError("ZIP inventory does not match the staging inventory.")
        for member in archive.infolist():
            safe_archive_name(member.filename)
            if member.date_time != ZIP_TIMESTAMP or member.create_system != 3:
                raise ValueError("Unexpected ZIP timestamp or mode metadata.")
        failed_member = archive.testzip()
        if failed_member is not None:
            raise ValueError(f"ZIP CRC verification failed for {failed_member}.")


def assemble(arguments):
    repository_root = Path(__file__).resolve().parents[1]
    packaging_root = repository_root / "packaging"
    if bool(arguments.windows_build_run_id) != bool(arguments.windows_build_commit):
        raise ValueError("Supply both Windows build identity overrides together.")
    native_builds = {}
    for platform in ARTIFACT_FILES:
        run_id = arguments.build_run_id
        commit = arguments.build_commit
        if platform == "windows-x64" and arguments.windows_build_run_id:
            run_id = arguments.windows_build_run_id
            commit = arguments.windows_build_commit
        if not re.fullmatch(r"[0-9]+", run_id):
            raise ValueError(f"The {platform} build run ID must contain only decimal digits.")
        if not re.fullmatch(r"[a-f0-9]{40}", commit):
            raise ValueError(f"The {platform} build commit must be a lowercase 40-character Git SHA.")
        native_builds[platform] = {
            "repository": REPOSITORY, "commit": commit, "run_id": run_id,
            "run_url": f"{REPOSITORY}/actions/runs/{run_id}",
        }
    artifacts = inspect_artifacts(arguments.native_root)
    model_identity = verify_identity(Path(arguments.model), MODEL_SIZE, MODEL_SHA256, "Model")
    sample_identity = verify_identity(Path(arguments.sample), SAMPLE_SIZE, SAMPLE_SHA256, "Public JFK sample")
    lock = json.loads(regular_file(packaging_root / "source-lock.json").read_text(encoding="utf-8"))
    for key, expected in {
        "upstream_commit": UPSTREAM_COMMIT, "version": "1.9.5",
        "source_sha256": SOURCE_SHA256, "model_sha256": MODEL_SHA256,
    }.items():
        if lock.get(key) != expected:
            raise ValueError(f"The packaging source lock has an unexpected {key}.")
    license_root = repository_root / "licenses"
    if license_root.is_symlink() or {entry.name for entry in license_root.iterdir()} != set(LICENSE_NAMES):
        raise ValueError("The licenses directory must contain exactly its thirteen preserved notice files.")
    for name in LICENSE_NAMES:
        check_public_text(regular_file(license_root / name).read_bytes(), f"licenses/{name}")
    for name in ("LICENSE", "SECURITY.md", "THIRD_PARTY_NOTICES.md"):
        check_public_text(regular_file(repository_root / name).read_bytes(), name)
    for name in ("PACKAGE-README.txt", "transcribe.cmd", "transcribe.sh"):
        check_public_text(regular_file(packaging_root / name).read_bytes(), name)

    output_root = Path(arguments.output).expanduser().absolute()
    if output_root.is_symlink():
        raise ValueError("The output directory must not be a symlink.")
    output_root.mkdir(parents=True, exist_ok=True)
    output_names = (PACKAGE_DIRECTORY, ZIP_NAME, "bundle-manifest.json", "bundle-SHA256SUMS.txt")
    for name in output_names:
        if (output_root / name).exists() or (output_root / name).is_symlink():
            raise ValueError(f"Refusing to replace an existing assembly output: {name}")

    with tempfile.TemporaryDirectory(prefix=".assemble-", dir=output_root) as temporary:
        temporary_root = Path(temporary)
        stage = temporary_root / PACKAGE_DIRECTORY
        stage.mkdir(mode=0o755)
        for platform, entries in artifacts.items():
            for name in ARTIFACT_FILES[platform]:
                if name.endswith(".txt"):
                    target = stage / "provenance" / platform / name
                    copy_file(entries[name], target)
                else:
                    target = stage / "bin" / platform / name
                    copy_file(entries[name], target, 0o755)
        copy_file(Path(arguments.model), stage / "models" / MODEL_NAME)
        copy_file(Path(arguments.sample), stage / "sample.wav")
        # Confirm the copied payload too, rather than assuming source files
        # stayed unchanged between their initial verification and copying.
        verify_identity(stage / "models" / MODEL_NAME, MODEL_SIZE, MODEL_SHA256, "Staged model")
        verify_identity(stage / "sample.wav", SAMPLE_SIZE, SAMPLE_SHA256, "Staged public JFK sample")
        copy_file(packaging_root / "PACKAGE-README.txt", stage / "README.txt")
        for name in ("LICENSE", "SECURITY.md", "THIRD_PARTY_NOTICES.md"):
            copy_file(repository_root / name, stage / name)
        for name in LICENSE_NAMES:
            copy_file(license_root / name, stage / "licenses" / name)
        for name, newline, mode in (("transcribe.cmd", "\r\n", 0o644), ("transcribe.sh", "\n", 0o755)):
            content = (packaging_root / name).read_text(encoding="utf-8-sig")
            content = content.replace("\r\n", "\n").replace("\r", "\n")
            write_bytes(stage / name, content.replace("\n", newline).encode("utf-8"), mode)

        binary_records = {}
        for path in sorted((stage / "bin").rglob("*")):
            if path.is_file():
                binary_records[path.relative_to(stage).as_posix()] = identity(path)
        file_records = {}
        for path in sorted(stage.rglob("*")):
            if path.is_file():
                name = path.relative_to(stage).as_posix()
                if not name.startswith("bin/") and name not in (f"models/{MODEL_NAME}", "sample.wav"):
                    check_public_text(path.read_bytes(), name)
                file_records[name] = identity(path)
        manifest = {
            "schema_version": 1,
            "package": {"name": PACKAGE_DIRECTORY, "version": VERSION, "repository": REPOSITORY,
                        "zip_filename": ZIP_NAME, "assembled_on": "2026-11-06",
                        "python_required_to_run": False, "internet_required_to_run": False},
            "upstream_source": {
                "repository": "https://github.com/ggml-org/whisper.cpp", "version": "1.9.5",
                "build_number": 5454, "commit": UPSTREAM_COMMIT,
                "archive_url": lock["source_url"], "archive_sha256": SOURCE_SHA256,
            },
            "native_builds": native_builds,
            "packaging_sources": {
                f"packaging/{name}": identity(packaging_root / name)
                for name in PACKAGING_SOURCE_NAMES
            },
            "model": {"path": f"models/{MODEL_NAME}", **model_identity,
                      "conversion_repository": "https://huggingface.co/ggerganov/whisper.cpp",
                      "conversion_revision": "5359861c739e955e79d9a303bcbc70fb988958b1"},
            "sample": {"path": "sample.wav", **sample_identity,
                       "source_url": f"https://github.com/ggml-org/whisper.cpp/blob/{UPSTREAM_COMMIT}/samples/jfk.wav"},
            "binaries": binary_records,
            "files": file_records,
            "limits": ["Hashes and antivirus checks do not certify security.",
                       "Mac binaries are ad hoc signed, not Developer ID signed or notarized.",
                       "Recognition can make substantial errors; review transcripts.",
                       "Corporate application controls may require employer approval."],
        }
        manifest_data = json_bytes(manifest)
        check_public_text(manifest_data, "bundle-manifest.json")
        write_bytes(stage / "bundle-manifest.json", manifest_data)
        checksum_lines = [
            f"{sha256(path)}  {path.relative_to(stage).as_posix()}\n"
            for path in sorted(stage.rglob("*")) if path.is_file()
        ]
        write_bytes(stage / "SHA256SUMS", "".join(checksum_lines).encode("ascii"))
        zip_path = temporary_root / ZIP_NAME
        create_zip(stage, zip_path)
        external_manifest = temporary_root / "bundle-manifest.json"
        write_bytes(external_manifest, manifest_data)
        external_checksums = temporary_root / "bundle-SHA256SUMS.txt"
        write_bytes(external_checksums, (
            f"{sha256(zip_path)}  {ZIP_NAME}\n"
            f"{sha256(external_manifest)}  bundle-manifest.json\n"
        ).encode("ascii"))
        # Publish only fully assembled, CRC-checked outputs. Unrelated output
        # files are preserved, and existing owned names are never replaced.
        for name in output_names:
            target = output_root / name
            if target.exists() or target.is_symlink():
                raise ValueError(f"An assembly output appeared while building: {name}")
        stage.rename(output_root / PACKAGE_DIRECTORY)
        for name in (ZIP_NAME, "bundle-manifest.json", "bundle-SHA256SUMS.txt"):
            source = temporary_root / name
            target = output_root / name
            with source.open("rb") as incoming, target.open("xb") as outgoing:
                shutil.copyfileobj(incoming, outgoing, CHUNK_SIZE)
            target.chmod(0o644)
    result = identity(output_root / ZIP_NAME)
    print(json.dumps({"zip": ZIP_NAME, **result, "staged_file_count": len(checksum_lines) + 1,
                      "zip_crc_check": "passed", "python_required_to_run": False}, sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-root", required=True, type=Path)
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--sample", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--build-run-id", default="42177019183")
    parser.add_argument("--build-commit", default="443a0b202bb2cfebfca4735aa38f86ddc82d765c")
    parser.add_argument("--windows-build-run-id")
    parser.add_argument("--windows-build-commit")
    arguments = parser.parse_args()
    try:
        assemble(arguments)
    except (OSError, ValueError, UnicodeError, json.JSONDecodeError, zipfile.BadZipFile) as error:
        print(f"Assembly stopped: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
