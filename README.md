# Worship Loop

An offline-first worship accompaniment app for Android and iOS, designed for live worship settings.

## Product direction

- Three independently controlled pad layers and three percussion loop layers.
- Per-layer volume, start/stop, and a master volume.
- Tap tempo for spontaneous changes.
- Smooth percussion tempo transitions: fade out, restart in time at the new tempo, and fade in.
- Sustained pads continue playing when tempo changes.
- Local song/setlist saving and custom audio import.
- Reliable offline playback, including background/locked-screen behaviour where platform rules allow.

## Development approach

Build and validate the audio engine before polishing the full interface. Keep this project separate from MixFlow. Choose the final audio-engine implementation only after a small device-tested prototype.

## Status

**Phase 1 — specification and audio-engine feasibility prototype.**

See [Product specification](docs/PRODUCT_SPEC.md) and [Technical approach](docs/TECHNICAL_APPROACH.md).
