# Build TrafficMonitor from source

## Recommended build

Use the Lite solution first. It is the same solution used by the repository's release workflow and avoids the temperature-monitoring dependency.

```powershell
cd <repo-root>
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

Default values:

- Solution: `TrafficMonitor_Lite.sln`
- Configuration: `Release (lite)`
- Platform: `x64`

Expected output:

```text
<repo-root>\Bin\x64\Release (lite)\
```

## Other build examples

```powershell
# x86 Lite build
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -Platform x86

# ARM64EC Lite build
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -Platform ARM64EC

# Clean then build
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -Clean

# Full build with temperature-monitoring dependency
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1 -Solution TrafficMonitor.sln -Configuration Release -Platform x64
```

## Prerequisites

Needed for local build:

- Visual Studio 2022 Build Tools or Visual Studio 2022
- MSVC v143 C++ toolset
- Windows 10 SDK
- MFC / ATL support
- For full `TrafficMonitor.sln`: C++/CLI support and .NET Framework 4.7.2 targeting pack

`setup.ps1` only checks and builds. It does **not** install anything and does **not** need Administrator rights.

If prerequisites are missing and you want this machine to install them, inspect `setup-admin.ps1`, then run it yourself from an elevated PowerShell.

For the full build with temperature monitoring, `setup-admin.ps1` installs only the needed Visual Studio Build Tools components and then builds `TrafficMonitor.sln`.

You may run it from a normal PowerShell; it will request Administrator through Windows UAC and open an elevated PowerShell window:

```powershell
cd <repo-root>
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-admin.ps1
```

Use `-SkipBuild` if you only want to install prerequisites:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-admin.ps1 -SkipBuild
```

The admin script intentionally does not use `--includeRecommended`.

## Notes

- The full build may produce an app that requests Administrator when run.
- The Lite build defines `WITHOUT_TEMPERATURE` and does not build `OpenHardwareMonitorApi`.
- `setup.ps1` imports `build\TrafficMonitor.MSBuild.Fixes.props` to define `DISABLE_WINDOWS_WEB_EXPERIENCE_DETECTOR` for the TrafficMonitor app project. This follows the upstream `stdafx.h` note for newer MSVC / Windows SDK C++/WinRT coroutine build failures and does **not** disable temperature monitoring.
- Do not install random plugin DLLs into the `plugins` folder unless you trust their source.
