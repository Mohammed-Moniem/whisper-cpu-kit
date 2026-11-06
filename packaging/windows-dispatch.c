/* Native Windows x64 CPU selector. Build with cl /O2 /MT /W4 (no /arch flag). */
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <intrin.h>
#include <process.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

#if !defined(_MSC_VER) || !defined(_M_X64)
#error Build this selector with MSVC targeting Windows x64.
#endif

enum { PATH_CAPACITY = 32768, COMMAND_LINE_LIMIT = 32767 };

static int can_run_avx2(void) {
    int registers[4];
    unsigned int maximum_leaf;
    const unsigned int required_ecx = (1u << 12) /* FMA */
        | (1u << 20) /* SSE4.2 */ | (1u << 26) /* XSAVE */
        | (1u << 27) /* OSXSAVE */ | (1u << 28) /* AVX */
        | (1u << 29); /* F16C */

    __cpuidex(registers, 0, 0);
    maximum_leaf = (unsigned int) registers[0];
    if (maximum_leaf < 7u) {
        return 0;
    }
    __cpuidex(registers, 1, 0);
    if (((unsigned int) registers[2] & required_ecx) != required_ecx) {
        return 0;
    }
    /* Execute XGETBV only after checking CPU and OS XSAVE support. */
    if ((_xgetbv(0) & 6u) != 6u) { /* OS must preserve XMM and YMM state. */
        return 0;
    }
    __cpuidex(registers, 7, 0);
    return ((unsigned int) registers[1] & (1u << 5)) != 0; /* AVX2 */
}

/* _wspawnv concatenates its arguments without escaping them. Encode one
 * argument using the Microsoft CRT parsing rules, including empty strings,
 * embedded quotes and trailing backslashes. No command shell is involved. */
static wchar_t *quote_argument(const wchar_t *argument, size_t *length) {
    const size_t input_length = wcslen(argument);
    const wchar_t *input = argument;
    wchar_t *quoted;
    wchar_t *output;

    if (input_length > COMMAND_LINE_LIMIT) {
        return NULL;
    }
    quoted = (wchar_t *) malloc((input_length * 2u + 3u) * sizeof(wchar_t));
    if (quoted == NULL) {
        return NULL;
    }
    output = quoted;
    *output++ = L'"';
    for (;;) {
        size_t slashes = 0;
        size_t count;
        while (*input == L'\\') {
            ++slashes;
            ++input;
        }
        count = (*input == L'"' || *input == L'\0') ? slashes * 2u : slashes;
        while (count-- != 0u) {
            *output++ = L'\\';
        }
        if (*input == L'\0') {
            break;
        }
        if (*input == L'"') {
            *output++ = L'\\';
        }
        *output++ = *input++;
    }
    *output++ = L'"';
    *output = L'\0';
    *length = (size_t) (output - quoted);
    return quoted;
}

int wmain(int argc, wchar_t **argv) {
    wchar_t module_path[PATH_CAPACITY];
    const wchar_t *engine;
    wchar_t *basename;
    wchar_t **child_arguments = NULL;
    DWORD path_length;
    size_t prefix_length;
    size_t engine_length;
    size_t command_length = 1u; /* terminating NUL */
    intptr_t child_result;
    int exit_code = 1;
    int index;

    path_length = GetModuleFileNameW(NULL, module_path, PATH_CAPACITY);
    if (path_length == 0u || path_length >= PATH_CAPACITY) {
        fwprintf(stderr, L"Cannot locate the CPU selector executable (Windows error %lu).\n",
            (unsigned long) GetLastError());
        return 1;
    }
    basename = wcsrchr(module_path, L'\\');
    if (basename == NULL) {
        fwprintf(stderr, L"Cannot determine the CPU selector directory.\n");
        return 1;
    }
    ++basename;
    prefix_length = (size_t) (basename - module_path);
    engine = can_run_avx2() ? L"whisper-cli-avx2.exe" : L"whisper-cli-generic.exe";
    engine_length = wcslen(engine);
    if (prefix_length + engine_length >= PATH_CAPACITY) {
        fwprintf(stderr, L"The CPU engine path is too long. Move the kit to a shorter directory.\n");
        return 1;
    }
    wmemcpy(basename, engine, engine_length + 1u);

    if (argc < 1 || argc > COMMAND_LINE_LIMIT) {
        fwprintf(stderr, L"Invalid argument count.\n");
        return 1;
    }
    child_arguments = (wchar_t **) calloc((size_t) argc + 1u, sizeof(wchar_t *));
    if (child_arguments == NULL) {
        fwprintf(stderr, L"Not enough memory to start the CPU engine.\n");
        return 1;
    }
    for (index = 0; index < argc; ++index) {
        size_t quoted_length;
        child_arguments[index] = quote_argument(index == 0 ? module_path : argv[index], &quoted_length);
        if (child_arguments[index] == NULL) {
            fwprintf(stderr, L"Cannot prepare the CPU engine arguments (memory or length limit).\n");
            goto cleanup;
        }
        command_length += quoted_length + (index == 0 ? 0u : 1u);
        if (command_length > COMMAND_LINE_LIMIT) {
            fwprintf(stderr, L"The CPU engine command line is too long.\n");
            goto cleanup;
        }
    }

    fwprintf(stderr, L"CPU selector: %ls\n", engine);
    fflush(NULL);
    errno = 0;
    child_result = _wspawnv(_P_WAIT, module_path, (const wchar_t *const *) child_arguments);
    if (child_result == -1) {
        fwprintf(stderr, L"Cannot start %ls (CRT error %d). Keep both CPU engine executables beside this selector.\n",
            engine, errno);
        goto cleanup;
    }
    exit_code = (int) child_result;

cleanup:
    for (index = 0; index < argc; ++index) {
        free(child_arguments[index]);
    }
    free(child_arguments);
    return exit_code;
}
