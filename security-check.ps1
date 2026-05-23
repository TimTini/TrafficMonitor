[CmdletBinding()]
param(
    [int]$MaxMatches = 80
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "== $Title ==" -ForegroundColor Cyan
}

function Get-Sha256Hex {
    param([string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        return (($sha256.ComputeHash($stream) | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
        $stream.Dispose()
    }
}

function Invoke-Ripgrep {
    param(
        [string]$Pattern,
        [string[]]$ExtraArgs = @()
    )

    $rg = Get-Command "rg.exe" -ErrorAction SilentlyContinue
    if ($null -eq $rg) {
        Write-Warning "rg.exe was not found. Skipping pattern: $Pattern"
        return @()
    }

    $baseArgs = @(
        "-n",
        "--hidden",
        "--glob", "!.git/**",
        "--glob", "!*.png",
        "--glob", "!*.bmp",
        "--glob", "!*.jpg",
        "--glob", "!*.jpeg",
        "--glob", "!*.ico",
        "--glob", "!*.dll",
        "--glob", "!*.pdb",
        "--glob", "!BUILD_FROM_SOURCE.md",
        "--glob", "!SECURITY_REVIEW.md",
        "--glob", "!security-check.ps1"
    )

    $results = & $rg.Source @baseArgs @ExtraArgs $Pattern $repoRoot 2>$null
    if ($LASTEXITCODE -gt 1) {
        throw "rg.exe failed with exit code $LASTEXITCODE for pattern: $Pattern"
    }

    return @($results)
}

Write-Section "Repository"
Write-Host "Path: $repoRoot"
git -C $repoRoot status --short --branch
git -C $repoRoot log -1 --format="Commit: %H%nDate:   %ci%nTitle:  %s"

Write-Section "High-confidence secret patterns"
$secretPattern = "AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|ghp_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{50,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----"
$secretMatches = Invoke-Ripgrep -Pattern $secretPattern
if ($secretMatches.Count -eq 0) {
    Write-Host "PASS: no high-confidence secrets matched."
}
else {
    Write-Host "REVIEW: possible secrets found:" -ForegroundColor Yellow
    $secretMatches | Select-Object -First $MaxMatches
}

Write-Section "Sensitive keyword assignments"
$keywordPattern = "\b(password|passwd|pwd|secret|token|api[_-]?key|client[_-]?secret|access[_-]?key)\b.{0,40}[:=]"
$keywordMatches = Invoke-Ripgrep -Pattern $keywordPattern -ExtraArgs @("-i")
if ($keywordMatches.Count -eq 0) {
    Write-Host "PASS: no sensitive assignment patterns matched."
}
else {
    Write-Host "REVIEW: sensitive keyword assignment candidates:" -ForegroundColor Yellow
    $keywordMatches | Select-Object -First $MaxMatches
}

Write-Section "Tracked binaries and scripts"
$trackedFiles = git -C $repoRoot ls-files
$trackedFiles |
    Where-Object { $_ -match "\.(exe|dll|sys|msi|ps1|bat|cmd)$" } |
    ForEach-Object {
        $fullPath = Join-Path $repoRoot $_
        $fileInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($fullPath)
        [PSCustomObject]@{
            Path = $_
            Length = (Get-Item -LiteralPath $fullPath).Length
            SHA256 = Get-Sha256Hex -Path $fullPath
            ProductVersion = $fileInfo.ProductVersion
            FileVersion = $fileInfo.FileVersion
        }
    } |
    Format-Table -AutoSize -Wrap

Write-Section "Build-time commands"
$buildCommandPattern = "<(PreBuildEvent|PostBuildEvent|PreLinkEvent|Command)>|Exec "
$buildCommandMatches = Invoke-Ripgrep -Pattern $buildCommandPattern -ExtraArgs @("--glob", "*.vcxproj", "--glob", "*.targets", "--glob", "*.props", "--glob", "*.yml", "--glob", "*.yaml", "--glob", "*.bat", "--glob", "*.cmd")
if ($buildCommandMatches.Count -eq 0) {
    Write-Host "PASS: no build-time command patterns matched."
}
else {
    $buildCommandMatches | Select-Object -First $MaxMatches
}

Write-Section "Network URLs"
$urlMatches = Invoke-Ripgrep -Pattern "https?://"
if ($urlMatches.Count -eq 0) {
    Write-Host "PASS: no URL patterns matched."
}
else {
    $urlMatches | Select-Object -First $MaxMatches
}

Write-Section "Execution and dynamic loading API candidates"
$executionPattern = "\b(ShellExecuteW?|CreateProcessW?|WinExec|system\(|LoadLibrary[A-Z]?|GetProcAddress|RegSetValue|RegCreateKey|RegDeleteKey)\b"
$executionMatches = Invoke-Ripgrep -Pattern $executionPattern -ExtraArgs @("--glob", "*.cpp", "--glob", "*.h", "--glob", "*.hpp")
if ($executionMatches.Count -eq 0) {
    Write-Host "PASS: no execution API candidates matched."
}
else {
    $executionMatches | Select-Object -First $MaxMatches
}

Write-Section "Summary"
Write-Host "This is a lightweight static check. Review SECURITY_REVIEW.md for conclusions and residual risks."
