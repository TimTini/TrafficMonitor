# Fork notes

This repository is a personal fork of the upstream TrafficMonitor project.

## What changed in this fork

- Replaced the bundled temperature-monitoring dependency with a newer LibreHardwareMonitor package layout (0.9.6, PawnIO instead of WinRing0).
- Hardware monitor init requires PawnIO and removes legacy `*.sys` driver files near the executable.
- Updated the OpenHardwareMonitorApi project to use platform-specific packaged assemblies.
- Added local build helpers and a static security check script.
- Added a public build note so the repository can be uploaded as a maintained fork rather than mistaken for the upstream source.

## Important note

This fork is not the original upstream repository.
It is a maintained copy with local fixes and additions for personal use and public sharing.

