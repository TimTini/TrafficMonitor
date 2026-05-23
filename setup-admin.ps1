[CmdletBinding()]
param(
    [ValidateSet("Lite", "Full")]
    [string]$BuildFlavor = "Full",

    [ValidateSet("x86", "x64", "ARM64EC")]
    [string]$Platform = "x64",

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

function Start-ElevatedCopy {
    $scriptPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptPath = $MyInvocation.MyCommand.Path
    }

    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        throw "Cannot determine script path for self-elevation."
    }

    $argumentList = @(
        "-NoExit",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$scriptPath`"",
        "-BuildFlavor", "`"$BuildFlavor`"",
        "-Platform", "`"$Platform`""
    )

    if ($SkipBuild) {
        $argumentList += "-SkipBuild"
    }

    Write-Host "This script needs Administrator rights to install Visual Studio Build Tools."
    Write-Host "Requesting elevation through Windows UAC. Approve the prompt to continue."
    Write-Host "No admin rights are bypassed; Windows will ask you first."

    try {
        Start-Process `
            -FilePath "powershell.exe" `
            -Verb RunAs `
            -ArgumentList ($argumentList -join " ")
    }
    catch {
        throw "Elevation was cancelled or failed. No changes were made. $($_.Exception.Message)"
    }
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

function Find-VisualStudioInstaller {
    $candidatePaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
    )

    foreach ($candidatePath in $candidatePaths) {
        if (Test-Path -LiteralPath $candidatePath) {
            return $candidatePath
        }
    }

    return $null
}

function Get-RequiredVisualStudioComponents {
    param(
        [string]$Flavor,
        [string]$BuildPlatform
    )

    # Minimal component list for this repository. Do not use --includeRecommended.
    $components = @(
        "Microsoft.Component.MSBuild",
        "Microsoft.VisualStudio.Component.VC.CoreBuildTools",
        "Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Core",
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "Microsoft.VisualStudio.Component.VC.ATLMFC",
        "Microsoft.VisualStudio.Component.VC.Redist.14.Latest",
        "Microsoft.VisualStudio.Component.Windows10SDK.19041"
    )

    if ($Flavor -eq "Full") {
        # Full build compiles OpenHardwareMonitorApi, which is a C++/CLI project targeting .NET Framework 4.7.2.
        $components += @(
            "Microsoft.VisualStudio.Component.VC.CLI.Support",
            "Microsoft.Net.Component.4.7.2.TargetingPack"
        )
    }

    if ($BuildPlatform -eq "ARM64EC") {
        $components += @(
            "Microsoft.VisualStudio.Component.VC.Tools.ARM64",
            "Microsoft.VisualStudio.Component.VC.MFC.ARM64"
        )
    }

    return $components
}

function Test-VisualStudioComponentsInstalled {
    param([string[]]$RequiredComponents)

    $vswherePath = Find-VsWhere
    if ($null -eq $vswherePath) {
        return $false
    }

    $vswhereArgs = @(
        "-latest",
        "-version", "[17.0,18.0)",
        "-products", "*",
        "-requires"
    ) + $RequiredComponents + @(
        "-property", "installationPath"
    )

    $installationPath = & $vswherePath @vswhereArgs
    return -not [string]::IsNullOrWhiteSpace($installationPath)
}

function Find-AnyVisualStudioInstallation {
    $vswherePath = Find-VsWhere
    if ($null -eq $vswherePath) {
        return $null
    }

    $installationPath = & $vswherePath -latest -version "[17.0,18.0)" -products * -property installationPath
    if ([string]::IsNullOrWhiteSpace($installationPath)) {
        return $null
    }

    return $installationPath
}

function Install-BuildToolsWithWinget {
    param([string[]]$RequiredComponents)

    $winget = Get-Command "winget.exe" -ErrorAction SilentlyContinue
    if ($null -eq $winget) {
        throw "winget.exe was not found. Install Visual Studio 2022 Build Tools manually, then run setup.ps1."
    }

    $overrideParts = @(
        "--wait",
        "--passive",
        "--norestart"
    )

    foreach ($component in $RequiredComponents) {
        $overrideParts += "--add $component"
    }

    $visualStudioInstallerArgs = $overrideParts -join " "

    Write-Step "Installing Visual Studio 2022 Build Tools with minimal components"
    Write-Host "winget override:"
    Write-Host $visualStudioInstallerArgs

    & $winget.Source install `
        --id Microsoft.VisualStudio.2022.BuildTools `
        --source winget `
        --accept-source-agreements `
        --accept-package-agreements `
        --override $visualStudioInstallerArgs

    if ($LASTEXITCODE -eq 3010) {
        Write-Warning "Visual Studio installer requested a reboot."
    }
    elseif ($LASTEXITCODE -ne 0) {
        throw "winget install failed with exit code $LASTEXITCODE"
    }
}

function Add-ComponentsToExistingVisualStudio {
    param(
        [string]$InstallPath,
        [string[]]$RequiredComponents
    )

    $installerPath = Find-VisualStudioInstaller
    if ($null -eq $installerPath) {
        throw "Visual Studio is installed, but Visual Studio Installer was not found."
    }

    $installerArgs = @(
        "modify",
        "--installPath", $InstallPath,
        "--passive",
        "--norestart"
    )

    foreach ($component in $RequiredComponents) {
        $installerArgs += @("--add", $component)
    }

    Write-Step "Adding missing minimal components to existing Visual Studio installation"
    Write-Host "Install path: $InstallPath"
    Write-Host "Installer   : $installerPath"
    Write-Host "Components  :"
    $RequiredComponents | ForEach-Object { Write-Host "  $_" }

    & $installerPath @installerArgs

    if ($LASTEXITCODE -eq 3010) {
        Write-Warning "Visual Studio Installer requested a reboot."
    }
    elseif ($LASTEXITCODE -ne 0) {
        throw "Visual Studio Installer modify failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Administrator)) {
    Start-ElevatedCopy
    exit 0
}

$requiredComponents = Get-RequiredVisualStudioComponents -Flavor $BuildFlavor -BuildPlatform $Platform

Write-Step "Required Visual Studio components"
$requiredComponents | ForEach-Object { Write-Host "  $_" }

if (Test-VisualStudioComponentsInstalled -RequiredComponents $requiredComponents) {
    Write-Step "Prerequisites already installed"
}
else {
    $existingInstallPath = Find-AnyVisualStudioInstallation
    if ($null -ne $existingInstallPath) {
        Add-ComponentsToExistingVisualStudio -InstallPath $existingInstallPath -RequiredComponents $requiredComponents
    }
    else {
        Install-BuildToolsWithWinget -RequiredComponents $requiredComponents
    }
}

if (-not (Test-VisualStudioComponentsInstalled -RequiredComponents $requiredComponents)) {
    throw "Visual Studio Build Tools install/modify finished, but required components are still not detected. A reboot or manual Visual Studio Installer check may be required."
}

if ($SkipBuild) {
    Write-Step "SkipBuild requested"
    Write-Host "Prerequisites are ready. Build was not started."
    exit 0
}

if ($BuildFlavor -eq "Full") {
    $solution = "TrafficMonitor.sln"
    $configuration = "Release"
}
else {
    $solution = "TrafficMonitor_Lite.sln"
    $configuration = "Release (lite)"
}

Write-Step "Building TrafficMonitor"
& (Join-Path $PSScriptRoot "setup.ps1") `
    -Solution $solution `
    -Configuration $configuration `
    -Platform $Platform

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Done."
