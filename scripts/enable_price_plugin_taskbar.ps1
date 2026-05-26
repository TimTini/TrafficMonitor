param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [ValidateSet('x64', 'x86', 'Win32', 'ARM64EC')]
    [string]$Platform = 'x64'
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if ($Platform -eq 'x86') {
    $Platform = 'Win32'
}

if ($Platform -eq 'Win32') {
    $appDir = Join-Path $repoRoot "Bin\$Configuration"
}
else {
    $appDir = Join-Path $repoRoot "Bin\$Platform\$Configuration"
}

$dllPath = Join-Path $appDir 'plugins\PricePlugin.dll'
if (-not (Test-Path $dllPath)) {
    throw "PricePlugin.dll not found: $dllPath. Build it first with scripts\build_price_plugin.ps1."
}

$appDataDir = Join-Path $env:APPDATA 'TrafficMonitor'
$globalConfigPath = Join-Path $appDir 'global_cfg.ini'
$appDataConfigPath = Join-Path $appDataDir 'config.ini'
$portableDefault = -not (Test-Path $appDataConfigPath)
$portableMode = $portableDefault

if (Test-Path $globalConfigPath) {
    $globalText = Get-Content -LiteralPath $globalConfigPath -Raw -ErrorAction SilentlyContinue
    if ($globalText -match '(?im)^\s*portable_mode\s*=\s*(true|1)\s*$') {
        $portableMode = $true
    }
    elseif ($globalText -match '(?im)^\s*portable_mode\s*=\s*(false|0)\s*$') {
        $portableMode = $false
    }
}

$configDir = if ($portableMode) { $appDir } else { $appDataDir }
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $configDir 'plugins') | Out-Null

$configPath = Join-Path $configDir 'config.ini'
$pluginConfigPath = Join-Path $configDir 'plugins\PricePlugin.ini'

function Set-IniValue {
    param(
        [string]$Path,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    if (Test-Path $Path) {
        foreach ($line in Get-Content -LiteralPath $Path) {
            $lines.Add($line)
        }
    }

    $sectionHeader = "[$Section]"
    $sectionIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -ieq $sectionHeader) {
            $sectionIndex = $i
            break
        }
    }

    if ($sectionIndex -lt 0) {
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim() -ne '') {
            $lines.Add('')
        }
        $lines.Add($sectionHeader)
        $lines.Add("$Key=$Value")
        Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
        return
    }

    $insertIndex = $lines.Count
    for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[.+\]\s*$') {
            $insertIndex = $i
            break
        }
        if ($lines[$i] -match "^\s*$([regex]::Escape($Key))\s*=") {
            $lines[$i] = "$Key=$Value"
            Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
            return
        }
    }

    $lines.Insert($insertIndex, "$Key=$Value")
    Set-Content -LiteralPath $Path -Value $lines -Encoding UTF8
}

function Get-IniValue {
    param(
        [string]$Path,
        [string]$Section,
        [string]$Key,
        [string]$Default = ''
    )

    if (-not (Test-Path $Path)) {
        return $Default
    }

    $inSection = $false
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*\[(.+)\]\s*$') {
            $inSection = ($Matches[1] -ieq $Section)
            continue
        }
        if ($inSection -and $line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.*)$") {
            return $Matches[1].Trim()
        }
    }

    return $Default
}

$priceItemIds = @(
    'okx_price_btc_usdt',
    'okx_price_eth_usdt',
    'okx_price_xau_proxy'
)

$currentPluginItems = Get-IniValue -Path $configPath -Section 'task_bar' -Key 'plugin_display_item' -Default ''
$mergedItems = New-Object System.Collections.Generic.List[string]
foreach ($item in ($currentPluginItems -split ',')) {
    $trimmed = $item.Trim()
    if ($trimmed -and -not $mergedItems.Contains($trimmed)) {
        $mergedItems.Add($trimmed)
    }
}
foreach ($item in $priceItemIds) {
    if (-not $mergedItems.Contains($item)) {
        $mergedItems.Add($item)
    }
}

Set-IniValue -Path $configPath -Section 'config' -Key 'show_task_bar_wnd' -Value 'true'
Set-IniValue -Path $configPath -Section 'task_bar' -Key 'plugin_display_item' -Value ($mergedItems -join ',')

Set-IniValue -Path $pluginConfigPath -Section 'config' -Key 'api_host' -Value 'www.okx.com'
Set-IniValue -Path $pluginConfigPath -Section 'config' -Key 'update_interval_ms' -Value '1000'
Set-IniValue -Path $pluginConfigPath -Section 'config' -Key 'decimal_places' -Value '1'
Set-IniValue -Path $pluginConfigPath -Section 'config' -Key 'item_count' -Value '3'
Set-IniValue -Path $pluginConfigPath -Section 'market' -Key 'item1_label' -Value 'BTC:'
Set-IniValue -Path $pluginConfigPath -Section 'market' -Key 'item1_inst_id' -Value 'BTC-USDT'
Set-IniValue -Path $pluginConfigPath -Section 'market' -Key 'item2_label' -Value 'ETH:'
Set-IniValue -Path $pluginConfigPath -Section 'market' -Key 'item2_inst_id' -Value 'ETH-USDT'
Set-IniValue -Path $pluginConfigPath -Section 'market' -Key 'item3_label' -Value 'XAU:'
Set-IniValue -Path $pluginConfigPath -Section 'market' -Key 'item3_inst_id' -Value 'XAUT-USDT'

Write-Host "PASS: PricePlugin taskbar items enabled"
Write-Host "Config: $configPath"
Write-Host "Plugin config: $pluginConfigPath"
Write-Host "Restart TrafficMonitor to load the plugin DLL and config."
