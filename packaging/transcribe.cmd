@echo off
setlocal DisableDelayedExpansion
rem CPU-only, offline transcription. No downloads or package installation.

if "%~1"=="" goto usage_error
if not "%~3"=="" goto usage_error
if "%~1"=="--help" goto usage_ok
if "%~1"=="-h" goto usage_ok

set "RECORDING=%~f1"
set "LANGUAGE=%~2"
if not defined LANGUAGE set "LANGUAGE=ar"
if "%LANGUAGE%"=="ar" goto language_ok
if "%LANGUAGE%"=="en" goto language_ok
if "%LANGUAGE%"=="hi" goto language_ok
echo ERROR: Language must be ar, en, or hi. 1>&2
exit /b 2

:language_ok
if not exist "%~dp0bin\windows-x64\whisper-cli.exe" goto missing_runtime
if not exist "%~dp0models\ggml-small-q5_1.bin" goto missing_model
if not exist "%RECORDING%" goto missing_recording
if exist "%RECORDING%\." goto missing_recording

"%~dp0bin\windows-x64\whisper-cli.exe" -m "%~dp0models\ggml-small-q5_1.bin" -f "%RECORDING%" -l "%LANGUAGE%" -ng -t 4 -otxt
exit /b %ERRORLEVEL%

:missing_runtime
echo ERROR: bin\windows-x64\whisper-cli.exe is missing. Extract the complete package. 1>&2
exit /b 1

:missing_model
echo ERROR: models\ggml-small-q5_1.bin is missing. Extract the complete package. 1>&2
exit /b 1

:missing_recording
echo ERROR: The recording must be an existing WAV file. 1>&2
exit /b 2

:usage_error
echo Usage: transcribe.cmd recording.wav [ar^|en^|hi] 1>&2
echo Languages: ar = Arabic default, en = English, hi = Hindi. 1>&2
exit /b 2

:usage_ok
echo Usage: transcribe.cmd recording.wav [ar^|en^|hi]
echo Languages: ar = Arabic default, en = English, hi = Hindi.
exit /b 0
