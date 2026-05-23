# TrafficMonitor security review

Review date: 2026-05-19

Repository:

- URL: https://github.com/zhongyang219/TrafficMonitor
- Local path: repository root
- Reviewed commit: `7901ce07727ee2b220dc5666f934fe69be03f3af`

## Scope

This was a lightweight source and build-supply-chain review:

- scanned for committed secrets;
- inspected build scripts, project files, GitHub Actions, and tracked binaries;
- inspected update, plugin-loading, network, and auto-start code paths;
- did not run the application;
- did not perform reverse engineering or sandbox malware detonation;
- did not complete a local build because Visual Studio/MSBuild is not installed on this machine.

## Findings

### PASS: no obvious committed secrets

High-confidence token/key patterns did not match:

- AWS access key style;
- Google API key style;
- GitHub classic/fine-grained token style;
- OpenAI `sk-...` style;
- Slack token style;
- PEM private-key header.

Sensitive keyword assignment scan also found no candidates.

### PASS: build-time script looks minimal

The only tracked batch script is:

- `TrafficMonitor\print_compile_time.bat`

It deletes and recreates local `compile_time.txt` with the current date/time. It does not download, install, elevate, or execute remote content.

The Visual Studio projects use MSBuild v143 and normal Visual C++ imports.

### REVIEW: embedded binary dependency

Tracked binary:

```text
OpenHardwareMonitorApi/LibreHardwareMonitorLib.dll
SHA256: a0f2728f1734c236a9d02d9e25a88bc4f8cb7bd1faff1770726beb7af06bf8dc
FileVersion: 0.9.4.0
ProductVersion: 0.9.4+b8077435b898d57539956388cddf49f7dacb86f7
```

The DLL is not Authenticode-signed according to a local .NET signature check. It is a .NET assembly named `LibreHardwareMonitorLib` with no public-key token.

As of this review date, the upstream LibreHardwareMonitor GitHub releases page shows `v0.9.6` as the latest release, so the bundled `0.9.4` DLL is not current:

- https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases

Impact:

- Full `TrafficMonitor.sln` depends on this DLL through `OpenHardwareMonitorApi`.
- The repository's Lite solution avoids this dependency.
- Hardware-monitoring libraries may require low-level driver access; review before running with Administrator rights.

Recommendation:

- Build `TrafficMonitor_Lite.sln` first.
- Only build/run full `TrafficMonitor.sln` if you need temperature monitoring.
- If using full mode, compare the bundled DLL hash against a trusted upstream release before running.

### REVIEW: full build requests Administrator at runtime

`TrafficMonitor\TrafficMonitor.vcxproj` sets:

```xml
<UACExecutionLevel>RequireAdministrator</UACExecutionLevel>
```

for non-lite configurations that link `OpenHardwareMonitorApi.lib`.

Impact:

- Building does not need Administrator.
- Running the full output can prompt for Administrator.

Recommendation:

- Prefer the Lite configuration unless the full hardware-temperature feature is required.

### REVIEW: plugin model loads native DLLs

`TrafficMonitor\PluginManager.cpp` loads every `*.dll` from the app `plugins` directory using `LoadLibrary`, then calls `TMPluginGetInstance`.

Impact:

- Plugin DLLs execute native code inside the TrafficMonitor process.
- This is expected for a plugin system, but the plugin folder is a trust boundary.

Recommendation:

- Only use plugins from trusted sources.
- Do not copy unknown DLLs into `plugins`.

### REVIEW: update checks use HTTPS metadata and open a browser link

Update logic fetches version metadata from GitHub/Gitee over HTTPS:

- `TrafficMonitor\UpdateHelper.cpp`
- `version_utf8.info`

If a newer version is found, the app prompts the user and opens the download link with `ShellExecute`. I did not find silent download-and-execute behavior in the update path.

Residual risk:

- Trust is placed in remote update metadata.
- Links are opened externally, not cryptographically verified by this code path.

### REVIEW: network calls disclose basic client metadata

The app can call external services for update checks, plugin version checks, and public IP lookup:

- GitHub/Gitee release metadata;
- TrafficMonitorPlugins metadata;
- `https://ip.cn/`;
- `https://v4.yinghualuo.cn/bejson`;
- `https://v6.yinghualuo.cn/bejson`.

Impact:

- These calls can disclose IP address, user-agent, and timing to the service.

### REVIEW: GitHub Actions are tag-pinned, not commit-SHA pinned

`.github\workflows\main.yml` uses actions such as:

- `actions/checkout@v3`
- `microsoft/setup-msbuild@v2`
- `josStorer/get-current-time@v2.0.2`
- `actions/upload-artifact@v4`

Impact:

- Fine for local builds.
- For release-hardening, pin actions to immutable commit SHAs and update `checkout` if maintaining a fork.

## Build recommendation

Use:

```powershell
cd <repo-root>
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

If prerequisites are missing, inspect and run the admin installer yourself:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-admin.ps1
```

By default this installs minimal Visual Studio Build Tools components for the full temperature-enabled build, then builds `TrafficMonitor.sln`.

## Re-run local security check

```powershell
cd <repo-root>
powershell -NoProfile -ExecutionPolicy Bypass -File .\security-check.ps1
```
