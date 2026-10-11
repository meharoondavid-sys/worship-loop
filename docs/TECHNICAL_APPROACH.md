# Technical Approach

## Principle

Audio reliability is the main technical risk. Prove the audio path on real devices before committing to the complete app architecture or building a polished interface.

## Candidate architecture

- Shared cross-platform application UI, with Flutter as the initial candidate.
- A dedicated low-latency audio engine/native layer for simultaneous sample playback, gain ramps, looping, and tempo coordination.
- Evaluate a suitable native engine (including a C++/JUCE-based option) against simpler native/plugin options with a minimal prototype.
- Keep the audio engine independent from UI state: UI commands should request transport/gain/tempo changes, while the audio layer schedules them safely.
- Local persistence for sound assets, songs, and setlists.

**Do not treat the candidate stack as final until a proof of concept is built and measured.**

## Prototype milestones

1. Confirm development environment and target minimum OS/device versions.
2. Play one bundled pad sample continuously; start/stop with click-free ramps.
3. Play one percussion loop and verify stable looping.
4. Run six simultaneous channels with independent gain and transport.
5. Implement tap tempo and coordinated smooth tempo transitions.
6. Test background/locked-screen playback and audio interruptions on Android and iOS.
7. Decide whether the prototype meets latency, stability, and maintenance requirements before expanding the UI.

## Engineering rules

- Keep Worship Loop changes in this repository; never mix them into MixFlow.
- Make small, reviewable commits.
- Do not claim a build or device test passed until it has actually been run and its result checked.
- Prefer real-device audio measurements and listening tests over simulator-only validation.
- Include reproducible test notes for each milestone.
