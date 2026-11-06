[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $SourceDirectory,
    [Parameter(Mandatory = $true)]
    [string] $OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
# Check native exit codes explicitly, including programs that write status to stderr.
if (Test-Path Variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}
trap {
    Write-Error "Windows packaging failure location: $($_.ScriptStackTrace)" -ErrorAction Continue
    throw
}

function Resolve-BuildTool {
    param([Parameter(Mandatory = $true)] [string] $Name)
    # A tool can occur more than once on the VS/runner PATH. Resolve one
    # ApplicationInfo explicitly rather than passing its .Source array.
    $command = Get-Command -Name $Name -CommandType Application -All -ErrorAction Stop |
        Select-Object -First 1
    [string] $toolPath = $command.Path
    if ([string]::IsNullOrWhiteSpace($toolPath) -or
        -not (Test-Path -LiteralPath $toolPath -PathType Leaf)) {
        throw "Cannot resolve a single executable file for $Name."
    }
    Write-Host "Resolved Windows build tool: $Name"
    return $toolPath
}

function Invoke-CheckedNative {
    param(
        [Parameter(Mandatory = $true)] [string] $Executable,
        [string[]] $Arguments = @(),
        [switch] $Capture
    )
    Write-Host "Running Windows build tool: $([IO.Path]::GetFileName($Executable))"
    $lines = @(& $Executable @Arguments 2>&1)
    $nativeExitCode = $LASTEXITCODE
    if (-not $Capture -or $nativeExitCode -ne 0) {
        foreach ($line in $lines) { Write-Host "$line" }
    }
    if ($nativeExitCode -ne 0) {
        throw "Native build command failed: $([IO.Path]::GetFileName($Executable)) (exit $nativeExitCode)."
    }
    if ($Capture) { return $lines }
}

function Assert-StaticReleaseProjects {
    param([string] $BuildDirectory)
    $requiredTargets = @('ggml-base', 'ggml-cpu', 'ggml', 'whisper', 'common', 'whisper-cli')
    $projects = @(Get-ChildItem -LiteralPath $BuildDirectory -Filter '*.vcxproj' -Recurse -File)
    foreach ($target in $requiredTargets) {
        $matchesForTarget = @($projects | Where-Object { $_.BaseName -eq $target })
        if ($matchesForTarget.Count -ne 1) {
            throw "Expected exactly one generated MSVC project for $target."
        }
        [xml] $projectXml = Get-Content -LiteralPath $matchesForTarget[0].FullName -Raw
        $namespaces = [Xml.XmlNamespaceManager]::new($projectXml.NameTable)
        $namespaces.AddNamespace('m', 'http://schemas.microsoft.com/developer/msbuild/2003')
        $runtimeNodes = @($projectXml.SelectNodes(
            "//m:ItemDefinitionGroup[contains(@Condition, 'Release|x64')]/m:ClCompile/m:RuntimeLibrary",
            $namespaces))
        if ($runtimeNodes.Count -eq 0) {
            throw "No explicit Release x64 runtime setting found for $target."
        }
        foreach ($node in $runtimeNodes) {
            if ($node.InnerText -ne 'MultiThreaded') {
                throw "The $target project is not using the static Release CRT (/MT)."
            }
        }
    }
}

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or
    -not [Environment]::Is64BitProcess) {
    throw 'Run this build script in 64-bit PowerShell on Windows with Visual Studio 2022 C++ tools.'
}

$sourceRoot = (Resolve-Path -LiteralPath $SourceDirectory).Path
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
foreach ($requiredSource in @('CMakeLists.txt', 'ggml\CMakeLists.txt', 'examples\cli\cli.cpp')) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $requiredSource) -PathType Leaf)) {
        throw "The source directory is missing $requiredSource."
    }
}
$dispatcherSource = Join-Path $PSScriptRoot 'windows-dispatch.c'
$utf8Manifest = Join-Path $PSScriptRoot 'windows-utf8.manifest'
foreach ($requiredPackagingFile in @($dispatcherSource, $utf8Manifest)) {
    if (-not (Test-Path -LiteralPath $requiredPackagingFile -PathType Leaf)) {
        throw 'The Windows dispatcher source and UTF-8 manifest must accompany this script.'
    }
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere -PathType Leaf)) {
    throw 'Cannot find the Visual Studio Installer vswhere.exe tool.'
}
$vswhereArguments = @('-latest', '-products', '*', '-version', '[17.0,18.0)',
    '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64')
$vsInstallLines = @(Invoke-CheckedNative -Executable $vswhere `
    -Arguments ($vswhereArguments + @('-property', 'installationPath')) -Capture)
if ($vsInstallLines.Count -ne 1 -or [string]::IsNullOrWhiteSpace("$($vsInstallLines[0])")) {
    throw 'Visual Studio 2022 with the x64 C++ tools is required.'
}
$vsRoot = "$($vsInstallLines[0])".Trim()
$vsVersionLines = @(Invoke-CheckedNative -Executable $vswhere `
    -Arguments ($vswhereArguments + @('-property', 'installationVersion')) -Capture)
$vsVersion = if ($vsVersionLines.Count -eq 1 -and "$($vsVersionLines[0])" -match '^\d+(\.\d+)+$') {
    "$($vsVersionLines[0])"
} else { '17.x' }
$vcvars = Join-Path $vsRoot 'VC\Auxiliary\Build\vcvarsall.bat'
if (-not (Test-Path -LiteralPath $vcvars -PathType Leaf)) {
    throw 'The Visual Studio x64 environment setup script is missing.'
}
$systemDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)
$cmdExe = Join-Path $systemDirectory 'cmd.exe'
$environmentLines = @(Invoke-CheckedNative -Executable $cmdExe `
    -Arguments @('/d', '/s', '/c', "call `"$vcvars`" x64 >nul && set") -Capture)
foreach ($line in $environmentLines) {
    if ("$line" -match '^([^=]+)=(.*)$') {
        [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
}
$env:VSLANG = '1033'
[string] $cmake = Resolve-BuildTool -Name 'cmake.exe'
[string] $compiler = Resolve-BuildTool -Name 'cl.exe'
[string] $manifestTool = Resolve-BuildTool -Name 'mt.exe'
[string] $dumpbin = Resolve-BuildTool -Name 'dumpbin.exe'

$nativeDirectory = Join-Path $outputRoot 'native\windows-x64'
$workDirectory = Join-Path $outputRoot 'build'
New-Item -ItemType Directory -Path $nativeDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $workDirectory -Force | Out-Null

$commonFlags = @(
    '-DCMAKE_POLICY_DEFAULT_CMP0091=NEW',
    '-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded',
    '-DCMAKE_CONFIGURATION_TYPES=Release',
    "-DCMAKE_GENERATOR_INSTANCE=$vsRoot",
    '-DBUILD_SHARED_LIBS=OFF',
    '-DGGML_CPU=ON',
    '-DGGML_NATIVE=OFF',
    '-DGGML_BACKEND_DL=OFF',
    '-DGGML_CPU_ALL_VARIANTS=OFF',
    '-DGGML_OPENMP=OFF',
    '-DGGML_OPENMP_FETCH=OFF',
    '-DGGML_CCACHE=OFF',
    '-DGGML_LTO=OFF',
    '-DGGML_BLAS=OFF',
    '-DGGML_LLAMAFILE=OFF',
    '-DGGML_CPU_KLEIDIAI=OFF',
    '-DGGML_CUDA=OFF',
    '-DGGML_MUSA=OFF',
    '-DGGML_HIP=OFF',
    '-DGGML_VULKAN=OFF',
    '-DGGML_METAL=OFF',
    '-DGGML_WEBGPU=OFF',
    '-DGGML_VIRTGPU=OFF',
    '-DGGML_VIRTGPU_BACKEND=OFF',
    '-DGGML_RPC=OFF',
    '-DGGML_SYCL=OFF',
    '-DGGML_OPENVINO=OFF',
    '-DGGML_ET=OFF',
    '-DGGML_OPENCL=OFF',
    '-DGGML_HEXAGON=OFF',
    '-DGGML_ZENDNN=OFF',
    '-DGGML_ZDNN=OFF',
    '-DGGML_BMI2=OFF',
    '-DGGML_AVX512=OFF',
    '-DGGML_AVX512_VBMI=OFF',
    '-DGGML_AVX512_VNNI=OFF',
    '-DGGML_AVX512_BF16=OFF',
    '-DGGML_AVX_VNNI=OFF',
    '-DWHISPER_CURL=OFF',
    '-DWHISPER_SDL2=OFF',
    '-DWHISPER_COREML=OFF',
    '-DWHISPER_OPENVINO=OFF',
    '-DWHISPER_VITISAI=OFF',
    '-DWHISPER_BUILD_TESTS=OFF',
    '-DWHISPER_BUILD_SERVER=OFF',
    '-DWHISPER_BUILD_EXAMPLES=ON',
    '-DWHISPER_BUILD_IS_DEV=OFF'
    '-DWHISPER_BUILD_NUMBER=5454'
    '-DWHISPER_BUILD_COMMIT=d1be6fde'
)

foreach ($variant in @('avx2', 'generic')) {
    $buildDirectory = Join-Path $workDirectory "windows-x64-$variant"
    $instructionSetting = if ($variant -eq 'avx2') { 'ON' } else { 'OFF' }
    $variantFlags = @("-DGGML_SSE42=$instructionSetting", "-DGGML_AVX=$instructionSetting",
        "-DGGML_AVX2=$instructionSetting")
    # With MSVC, FMA and F16C are implied by /arch:AVX2. They are not separate
    # CMake options in this source revision; the generic build enables neither.
    Invoke-CheckedNative -Executable $cmake -Arguments (@('-S', $sourceRoot, '-B', $buildDirectory,
        '-G', 'Visual Studio 17 2022', '-A', 'x64') + $commonFlags + $variantFlags)
    Assert-StaticReleaseProjects -BuildDirectory $buildDirectory
    Invoke-CheckedNative -Executable $cmake -Arguments @('--build', $buildDirectory,
        '--config', 'Release', '--target', 'whisper-cli', '--parallel', '4')
    $builtEngine = Join-Path $buildDirectory 'bin\Release\whisper-cli.exe'
    if (-not (Test-Path -LiteralPath $builtEngine -PathType Leaf)) {
        throw "The $variant build did not produce whisper-cli.exe."
    }
    Copy-Item -LiteralPath $builtEngine -Destination (Join-Path $nativeDirectory "whisper-cli-$variant.exe") -Force
}

$selector = Join-Path $nativeDirectory 'whisper-cli.exe'
Push-Location -LiteralPath $workDirectory
try {
    Invoke-CheckedNative -Executable $compiler -Arguments @('/nologo', '/O2', '/MT', '/W4', '/WX',
        "/Fe:$selector", "/Fo:$(Join-Path $workDirectory 'windows-dispatch.obj')", $dispatcherSource)
} finally {
    Pop-Location
}

$dependencyEvidence = [Collections.Generic.List[string]]::new()
$dependencyEvidence.Add('Windows x64 portable CPU executables: direct PE imports verified.')
$dependencyEvidence.Add('Every listed DLL exists in the Windows System32 directory on the build runner.')
$dependencyEvidence.Add('No external CRT, OpenMP, GGML or whisper runtime DLL imports are permitted.')
$forbiddenImport = '^(msvcp|msvcr|vcruntime|vcomp|libomp|libgcc|libstdc(pp|\+\+)|ucrtbase|ggml|whisper)'
foreach ($executableName in @('whisper-cli.exe', 'whisper-cli-avx2.exe', 'whisper-cli-generic.exe')) {
    $executable = Join-Path $nativeDirectory $executableName
    Invoke-CheckedNative -Executable $manifestTool -Arguments @('-nologo', '-manifest', $utf8Manifest,
        "-outputresource:$executable;#1")
    $dependencyLines = @(Invoke-CheckedNative -Executable $dumpbin -Arguments @('/NOLOGO', '/DEPENDENTS', $executable) -Capture)
    $imports = @($dependencyLines | ForEach-Object {
        if ("$_" -match '^\s+([a-zA-Z0-9_.-]+\.dll)\s*$') { $Matches[1] }
    } | Sort-Object -Unique)
    if ($imports.Count -eq 0) {
        throw "No imports could be parsed from $executableName."
    }
    $dependencyEvidence.Add('')
    $dependencyEvidence.Add($executableName)
    foreach ($importName in $imports) {
        if ($importName -match $forbiddenImport) {
            throw "Nonportable runtime dependency in ${executableName}: $importName"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $systemDirectory $importName) -PathType Leaf)) {
            throw "An import in $executableName is not an available System32 DLL: $importName"
        }
        $dependencyEvidence.Add("  $importName")
    }
}
$dependencyEvidence | Set-Content -LiteralPath (Join-Path $nativeDirectory 'dependencies.txt') -Encoding utf8

$buildEvidence = @(
    'Platform: Windows 10 version 1903 or later / Windows 11, x64',
    "Build tools: Visual Studio 2022 $vsVersion; MSVC Release x64",
    'Expected upstream source commit: d1be6fde11ac6e0407606b4e42fe72d34add8037',
    'Source archive verification is performed by the calling release workflow.',
    'CMake generator: Visual Studio 17 2022; configuration: Release',
    'Runtime: static MSVC CRT /MT; CMP0091=NEW; MultiThreaded checked in all six linked MSVC projects',
    'Libraries: static whisper and GGML; no dynamically loaded backends; no external OpenMP',
    'Built upstream target: whisper-cli only',
    'whisper-cli.exe: static baseline x64 CPU selector; no /arch compiler option',
    'whisper-cli-avx2.exe: AVX2, AVX, SSE4.2; FMA and F16C implied by MSVC /arch:AVX2',
    'whisper-cli-generic.exe: baseline x64/SSE2; AVX, AVX2, SSE4.2, FMA and F16C disabled',
    'All engines: GGML_NATIVE=OFF; BMI2, AVX512 and AVX-VNNI disabled',
    'GPU, BLAS, server, SDL2, libcurl, external inference backends and upstream tests disabled',
    'All three executables embed UTF-8 activeCodePage and asInvoker manifests',
    'Direct PE imports checked against System32; separate dependencies.txt contains the names',
    'Only native/windows-x64 is a runtime payload; build directories are not required to run'
)
$buildEvidence | Set-Content -LiteralPath (Join-Path $nativeDirectory 'build-config.txt') -Encoding utf8
Write-Host 'Windows portable runtime built and dependency checks passed: native/windows-x64'
