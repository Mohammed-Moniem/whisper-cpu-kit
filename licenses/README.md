# Runtime redistribution notices

Keep this directory with copies of the native runtime archives. These notices
preserve the licenses and copyright notices of the identified upstream
components; they do not change their licenses.

| Notice file | Component and source |
| --- | --- |
| `whisper.cpp-ggml-MIT.txt` | whisper.cpp / ggml, copied from `LICENSE` in whisper.cpp v1.9.5, commit `d1be6fde11ac6e0407606b4e42fe72d34add8037` |
| `miniaudio-license-options.txt` | Audio decoding, copied from the final license block in `examples/miniaudio.h` in that source revision; preserves the public domain and MIT No Attribution alternatives |
| `stb_vorbis-license-options.txt` | Ogg Vorbis decoding, copied from the final license block in `examples/stb_vorbis.c`; preserves the MIT and public domain alternatives |
| `llamafile-MIT.txt` | CPU matrix kernels, copied from `ggml/src/ggml-cpu/llamafile/sgemm.cpp` |
| `YaRN-MIT.txt` | Rotary embedding algorithm notice in `ggml/src/ggml-cpu/ops.cpp`, with the MIT permission text |
| `SDL2-zlib.txt` | `SDL2.dll` in the official Windows archive; upstream SDL2 2.28.5 `LICENSE.txt` |
| `cpp-httplib-MIT.txt` | HTTP server dependency; [cpp-httplib v0.20.0 LICENSE](https://github.com/yhirose/cpp-httplib/blob/v0.20.0/LICENSE), plus the copyright notice in the actual vendored `examples/server/httplib.h` |
| `nlohmann-json-MIT.txt` | JSON dependency; [nlohmann/json v3.11.2 LICENSE.MIT](https://github.com/nlohmann/json/blob/v3.11.2/LICENSE.MIT) |
| `nlohmann-json-additional-MIT-notices.txt` | Additional copyright lines preserved from the vendored `examples/json.hpp` |
| `Apache-2.0.txt` | [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.txt), retained for the Abseil-derived C++11 fallback documented inside that JSON header; this fallback is excluded by C++14 and later builds |
| `llama.cpp-MIT.txt` | `llama.dll` in the full official Windows archive; [llama.cpp v0.6.0 LICENSE](https://github.com/ggml-org/llama.cpp/blob/v0.6.0/LICENSE), the dependency tag specified by whisper.cpp v1.9.5 `examples/talk-llama/CMakeLists.txt` |
| `Unicode-3.0.txt` | [Unicode data license](https://www.unicode.org/license.txt), retained for the Unicode data used by the llama runtime |

The local macOS command-line build does not include SDL2, the HTTP server or
the llama library. Its runtime dependencies are Apple operating-system
frameworks and libraries, which are not redistributed in this package.
The full Windows archive includes additional upstream tools, so its companion
notices also cover the identified dependencies of those tools. These records
are a scoped redistribution-notice inventory, not a complete binary SBOM or
a security review.

OpenAI Whisper model and package licenses are also preserved in the root
`LICENSE` and `THIRD_PARTY_NOTICES.md` files.
