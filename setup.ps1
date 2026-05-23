[CmdletBinding()]
param(
    [ValidateSet("Debug", "Release", "Debug (lite)", "Release (lite)")]
    [string]$Configuration = "Release (lite)",

    [ValidateSet("x86", "x64", "ARM64EC")]
    [string]$Platform = "x64",

    [string]$Solution = "TrafficMonitor_Lite.sln",

    [switch]$Clean,

    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Find-VsWhere {
    $candidatePaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe",
        "${env:ProgramFiles}\Microsoft Visual Studio\Installer\vswhere.exe"
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -LiteralPath $candidatePath) {
            return $candidatePath
        }
    }

    $command = Get-Command "vswhere.exe" -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    return $null
}

function Get-RequiredVisualStudioComponents {
    param(
        [string]$BuildSolution,
        [string]$BuildPlatform
    )

    $components = @(
        "Microsoft.Component.MSBuild",
        "Microsoft.VisualStudio.Component.VC.CoreBuildTools",
        "Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Core",
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "Microsoft.VisualStudio.Component.VC.ATLMFC",
        "Microsoft.VisualStudio.Component.VC.Redist.14.Latest",
        "Microsoft.VisualStudio.Component.Windows10SDK.19041"
    )

    if ($BuildSolution -ieq "TrafficMonitor.sln") {
        $components += @(
            "Microsoft.VisualStudio.Component.VC.CLI.Support",
            "Microsoft.Net.Component.4.7.2.TargetingPack"
        )
    }

    if ($BuildPlatform -ieq "ARM64EC") {
        $components += @(
            "Microsoft.VisualStudio.Component.VC.Tools.ARM64",
            "Microsoft.VisualStudio.Component.VC.MFC.ARM64"
        )
    }

    return $components
}

function Find-MSBuild {
    param([string[]]$RequiredComponents)

    $vswherePath = Find-VsWhere
    if ($null -ne $vswherePath) {
        $vswhereArgs = @(
            "-latest",
            "-version", "[17.0,18.0)",
            "-products", "*",
            "-requires"
        ) + $RequiredComponents + @(
            "-find", "MSBuild\**\Bin\MSBuild.exe"
        )

        $msbuildPaths = & $vswherePath @vswhereArgs

        foreach ($msbuildPath in $msbuildPaths) {
            if (Test-Path -LiteralPath $msbuildPath) {
                return $msbuildPath
            }
        }
    }

    $command = Get-Command "msbuild.exe" -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    return $null
}

function Get-ExpectedOutputDirectory {
    param(
        [string]$RepoRoot,
        [string]$BuildPlatform,
        [string]$BuildConfiguration
    )

    if ($BuildPlatform -eq "x86") {
        return Join-Path $RepoRoot "Bin\$BuildConfiguration"
    }

    return Join-Path $RepoRoot "Bin\$BuildPlatform\$BuildConfiguration"
}

$repoRoot = $PSScriptRoot
$solutionPath = Join-Path $repoRoot $Solution
$buildFixPropsPath = Join-Path $repoRoot "build\TrafficMonitor.MSBuild.Fixes.props"

Write-Step "Checking repository"
Write-Host "Repository : $repoRoot"
Write-Host "Solution   : $solutionPath"
Write-Host "Config     : $Configuration"
Write-Host "Platform   : $Platform"
if (Test-Path -LiteralPath $buildFixPropsPath) {
    Write-Host "Build fixes: $buildFixPropsPath"
}

if (-not (Test-Path -LiteralPath $solutionPath)) {
    throw "Solution not found: $solutionPath"
}

if (Test-Administrator) {
    Write-Warning "This build script does not need Administrator rights. Use a normal PowerShell when possible."
}

if ($Solution -ieq "TrafficMonitor.sln" -and $Configuration -notlike "*(lite)*") {
    Write-Warning "Full build includes OpenHardwareMonitorApi and LibreHardwareMonitorLib.dll. The generated app manifest requires Administrator when run."
}

Write-Step "Finding MSBuild"
$requiredComponents = Get-RequiredVisualStudioComponents -BuildSolution $Solution -BuildPlatform $Platform
$msbuildPath = Find-MSBuild -RequiredComponents $requiredComponents
if ($null -eq $msbuildPath) {
    Write-Host "MSBuild / Visual Studio Build Tools with the required components were not found." -ForegroundColor Yellow
    Write-Host "Required component IDs:"
    $requiredComponents | ForEach-Object { Write-Host "  $_" }
    Write-Host "If you want this machine to install build prerequisites, inspect and run as Administrator:"
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File `"$repoRoot\setup-admin.ps1`""
    exit 2
}

Write-Host "MSBuild: $msbuildPath"

if ($SkipBuild) {
    Write-Step "SkipBuild requested"
    Write-Host "Environment check finished. Build was not started."
    exit 0
}

if ($Clean) {
    Write-Step "Cleaning"
    $cleanArgs = @(
        $solutionPath,
        "/t:Clean",
        "/p:Configuration=$Configuration",
        "/p:Platform=$Platform",
        "/p:PlatformToolset=v143",
        "/v:m"
    )

    if (Test-Path -LiteralPath $buildFixPropsPath) {
        $cleanArgs += "/p:ForceImportBeforeCppTargets=$buildFixPropsPath"
    }

    & $msbuildPath @cleanArgs

    if ($LASTEXITCODE -ne 0) {
        throw "MSBuild clean failed with exit code $LASTEXITCODE"
    }
}

Write-Step "Building"
$buildArgs = @(
    $solutionPath,
    "/m",
    "/p:Configuration=$Configuration",
    "/p:Platform=$Platform",
    "/p:PlatformToolset=v143",
    "/v:m"
)

if (Test-Path -LiteralPath $buildFixPropsPath) {
    $buildArgs += "/p:ForceImportBeforeCppTargets=$buildFixPropsPath"
}

& $msbuildPath @buildArgs

if ($LASTEXITCODE -ne 0) {
    throw "MSBuild build failed with exit code $LASTEXITCODE"
}

$outputDirectory = Get-ExpectedOutputDirectory -RepoRoot $repoRoot -BuildPlatform $Platform -BuildConfiguration $Configuration

Write-Step "Build output"
Write-Host "Expected output directory: $outputDirectory"

if (Test-Path -LiteralPath $outputDirectory) {
    Get-ChildItem -LiteralPath $outputDirectory -File |
        Where-Object { $_.Extension -in @(".exe", ".dll", ".pdb") } |
        Select-Object Name, Length, LastWriteTime |
        Format-Table -AutoSize
}
else {
    Write-Warning "Build finished but expected output directory was not found: $outputDirectory"
}
