# Product Specification

## Goal

Build a dependable, offline-first accompaniment instrument for worship leaders and musicians who need ambient pads and percussion loops that can be controlled live without distracting from playing.

## MVP scope

### Audio layers
- 3 pad channels and 3 percussion channels (6 total).
- Independent play/stop and volume for each channel.
- Master output volume.
- Built-in starter sound library plus local custom audio import.
- Avoid clicks during start, stop, sound changes, and gain changes by using appropriate short ramps/crossfades.

### Tempo
- Tap tempo.
- A tempo value that can be edited directly.
- Percussion follows the selected tempo.
- Default tempo-change behaviour is **Smooth Transition**:
  1. Coordinate active percussion layers.
  2. Fade down over a selectable duration: 1/4 bar, 1/2 bar, or 1 bar.
  3. Restart/alignment at a musical beat or bar boundary for the new tempo.
  4. Fade back to the saved per-layer level.
- Where possible, provide a coordinated transition option so percussion layers stay rhythmically aligned.
- Pads sustain through tempo changes by default.
- A transition must not unexpectedly change the user's saved layer volumes.
- Define and test a supported BPM range during the prototype rather than assuming every imported loop works at every tempo.

### Songs and setlists
- Create, rename, reorder, and delete local setlists.
- Add, reorder, and remove songs in a setlist.
- Save each song's tempo, chosen audio for each layer, and per-layer levels.
- Persist data locally and restore it after app restarts.
- MVP does not require cloud sync or account creation.

### Reliability
- Offline playback after the app and included assets are installed.
- Test behaviour with screen locked/backgrounded where each OS permits it.
- Handle phone calls, audio focus interruptions, route changes, and app suspension predictably.
- No clicks or glitches during ordinary use; validate on real Android and iOS devices.
- Support wired/Bluetooth output where practical, while documenting device-dependent latency.

## Explicitly out of scope for MVP
- Cloud sync and account systems.
- Sharing setlists between users.
- Subscription or in-app purchases.
- MIDI mapping.
- Large marketplace/downloadable sound catalog.
- Complex multi-output routing.

## Initial acceptance tests
1. Six channels can play simultaneously for a 60-minute device test without audible glitches or growing timing drift.
2. Every channel can be started/stopped and its level changed independently.
3. Master volume affects the complete mix without changing saved per-channel levels.
4. Tap tempo is stable and responsive.
5. Tempo changes trigger the configured smooth transition, with percussion returning on the musical grid and pads continuing to sustain.
6. Two or more percussion layers can transition together without losing their relative alignment.
7. Imported audio and saved setlists remain available offline and survive an app restart.
8. Audio interruption and locked-screen behaviour are tested separately on Android and iOS.

## Product decisions still to validate
- Supported audio formats, loop metadata, and tempo range.
- Whether imported percussion loops must include BPM metadata or can be analysed.
- Final audio-engine technology after the prototype.
- Exact transition timing semantics (next beat versus next bar) and fade curve.
