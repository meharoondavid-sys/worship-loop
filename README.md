# Worship Loop

An offline-first worship accompaniment app for Android and iOS, designed for live worship settings.

## Current progress

- Project specification and technical approach are documented.
- An interactive Flutter mixer UI preview is in `lib/main.dart`.
- The preview includes three pad channels, three percussion channels, per-layer level controls, a master level, tap tempo, and smooth-transition settings.
- GitHub Actions is configured to analyze, test, build, and upload an Android debug APK preview.

**Important:** The current mixer is a UI prototype. Play/stop buttons change preview state only; real audio playback and tempo-synchronised loop transitions are not implemented yet.

## Product direction

- Three independently controlled pad layers and three percussion loop layers (six total).
- Per-layer volume, start/stop, and master volume.
- Tap tempo for spontaneous changes.
- Smooth percussion tempo transitions: fade out, restart in time at the new tempo, and fade in.
- Sustained pads continue playing when tempo changes.
- Local song/setlist saving and custom audio import.
- Reliable offline playback, including background/locked-screen behaviour where platform rules allow.

## Development approach

Build and validate the audio engine before polishing the full interface. Keep this project separate from MixFlow. Choose the final audio-engine implementation only after a small device-tested prototype.

## Links

- [Product specification](docs/PRODUCT_SPEC.md)
- [Technical approach](docs/TECHNICAL_APPROACH.md)
- [Mixer UI preview source](lib/main.dart)
- [Android preview build workflow](.github/workflows/android-preview.yml)

## Next milestone

Run the remote Android preview workflow, review its build/test results, and use the APK artifact to gather initial layout feedback on an Android device. Audio-engine feasibility still needs a separate device-tested prototype.
