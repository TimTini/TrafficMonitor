param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [ValidateSet('x64', 'x86', 'Win32', 'ARM64EC')]
    [string]$Platform = 'x64'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot 'PricePlugin\PricePlugin.vcxproj'

if ($Platform -eq 'x86') {
    $Platform = 'Win32'
}

function Find-MSBuild {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
        if ($msbuild) {
            return $msbuild
        }
    }

    $command = Get-Command msbuild.exe -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw 'MSBuild.exe not found. Install Visual Studio Build Tools with C++ workload.'
}

$msbuildPath = Find-MSBuild
Write-Host "MSBuild: $msbuildPath"
Write-Host "Project:  $projectPath"
Write-Host "Config:   $Configuration|$Platform"

& $msbuildPath $projectPath /m /p:Configuration=$Configuration /p:Platform=$Platform
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($Platform -eq 'Win32') {
    $dllPath = Join-Path $repoRoot "Bin\$Configuration\plugins\PricePlugin.dll"
}
else {
    $dllPath = Join-Path $repoRoot "Bin\$Platform\$Configuration\plugins\PricePlugin.dll"
}

if (Test-Path $dllPath) {
    Write-Host "PASS: $dllPath"
}
else {
    throw "Build finished but DLL not found: $dllPath"
}
