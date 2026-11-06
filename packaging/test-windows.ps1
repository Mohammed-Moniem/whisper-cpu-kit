param([Parameter(Mandatory=$true)][string]$PackageDirectory)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'This firewall-isolated verification script is intended for an ephemeral GitHub Actions VM only.' }
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$launcher = Join-Path $package 'transcribe.cmd'
$recording = Join-Path $package 'sample हिंदी.wav'
Copy-Item -LiteralPath (Join-Path $package 'sample.wav') -Destination $recording -Force
if (-not (Test-Path -LiteralPath $recording -PathType Leaf)) { throw 'The Unicode test recording was not created as a regular file.' }
$argumentProbe = Join-Path $env:TEMP ('whisper-cmd-argument-' + [guid]::NewGuid().ToString('N') + '.cmd')
# Static ASCII probe text: the Unicode path is passed as an argument, never
# interpolated into command-shell source. This isolates CMD argument handling.
@'
@echo off
setlocal DisableDelayedExpansion
if not exist "%~1" exit /b 3
set "INPUT_ATTRIBUTES=%~a1"
if "%INPUT_ATTRIBUTES:~0,1%"=="d" exit /b 4
echo CMD argument resolved to an existing file; attributes: %INPUT_ATTRIBUTES%
exit /b 0
'@ | Set-Content -LiteralPath $argumentProbe -Encoding ascii
$model = Join-Path $package 'models/ggml-small-q5_1.bin'
if ((Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb') { throw 'Model mismatch' }
if (Test-Path -LiteralPath (Join-Path $package 'SHA256SUMS')) {
  foreach ($line in Get-Content -LiteralPath (Join-Path $package 'SHA256SUMS')) {
    if ($line -notmatch '^([a-f0-9]{64})  (.+)$') { throw 'Malformed checksum entry' }
    $expected = $Matches[1]
    $path = Join-Path $package $Matches[2]
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw "Package hash mismatch: $path" }
  }
}
$native = Join-Path $package 'bin/windows-x64'
$rules = @()
$disabledProfiles = @()
$oldPath = $env:PATH
$oldLocation = Get-Location
try {
  # Only these three test executables are denied outbound access on the CI VM.
  $profiles = @(Get-NetFirewallProfile)
  $disabledProfiles = @($profiles | Where-Object { -not $_.Enabled } | ForEach-Object { $_.Name })
  if ($disabledProfiles.Count -gt 0) { Set-NetFirewallProfile -Name $disabledProfiles -Enabled True }
  foreach ($exe in Get-ChildItem -LiteralPath $native -Filter '*.exe') {
    $rule = 'WhisperCpuKit-' + [guid]::NewGuid().ToString('N')
    New-NetFirewallRule -DisplayName $rule -Direction Outbound -Action Block -Program $exe.FullName -Profile Any | Out-Null
    $rules += $rule
  }
  $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
  Set-Location -LiteralPath $env:TEMP
  & $argumentProbe $recording
  if ($LASTEXITCODE -ne 0) { throw "CMD Unicode file-argument probe failed: $LASTEXITCODE" }
  & $launcher $recording en
  if ($LASTEXITCODE -ne 0) { throw "Launcher failed: $LASTEXITCODE" }
  if ((Get-Content -LiteralPath "$recording.txt" -Raw) -notmatch '(?i)country') { throw 'Expected English text missing' }
  & $launcher $recording fr
  if ($LASTEXITCODE -ne 2) { throw 'Invalid-language exit code mismatch' }
  & $launcher (Join-Path $package 'missing.wav') en
  if ($LASTEXITCODE -ne 2) { throw 'Missing-file exit code mismatch' }
  & (Join-Path $native 'whisper-cli-generic.exe') -m $model -f (Join-Path $package 'sample.wav') -l en -ng -t 4 -otxt -of (Join-Path $package 'generic-smoke')
  if ($LASTEXITCODE -ne 0) { throw 'Generic engine failed' }
  if ((Get-Content -LiteralPath (Join-Path $package 'generic-smoke.txt') -Raw) -notmatch '(?i)country') { throw 'Generic output mismatch' }
  Write-Output 'PASS: Windows static engines, native CPU selection, Unicode/space paths, restricted PATH, outbound network denial, CPU transcription and argument errors.'
} finally {
  $env:PATH = $oldPath
  Set-Location -LiteralPath $oldLocation
  Remove-Item -LiteralPath $argumentProbe -Force -ErrorAction SilentlyContinue
  foreach ($rule in $rules) { Remove-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue }
  if ($disabledProfiles.Count -gt 0) { Set-NetFirewallProfile -Name $disabledProfiles -Enabled False }
}
