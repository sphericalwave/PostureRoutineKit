# PostureRoutineKit

The file format two apps use to hand a guided posture routine back and forth
through an App Group container.

One app owns the routine and the training log (torque); the other runs the
routine as a timed, spoken session (meditate). Neither opens the other's
database — a shared SwiftData/CoreData store would be the alternative, and two
processes on one CloudKit-mirrored store is unsupported. The file system
arbitrates instead.

```
torque ──writes──▶ Routines/<planID>.json ──reads──▶ meditate
                                                        │ runs it
torque ◀──reads─── PostureSessions/<id>.json ◀──writes──┘
```

## Requirements

- iOS 17+ / macOS 14+
- Swift 5.9+

## Installation

```swift
.package(url: "https://github.com/sphericalwave/PostureRoutineKit.git", branch: "main")
```

## Overview

- `RoutineFile` / `RoutineEntryFile` — the postures, in order, with how long
  each is held and which positions it's worked through. `positionNames` is
  empty for a single-position posture, or `["Right", "Centre", "Left"]` for one
  worked through several. Carries the rounds arithmetic: `roundSeconds`,
  `rounds(fitting:)`, `duration(forRounds:)`.
- `PostureSessionFile` / `PostureHoldFile` — what actually happened: one hold
  per position per round, with the seconds held (not the seconds prescribed),
  plus heart rate. `timeUnderTension` is the sum of the holds, which is not the
  wall clock — transitions and pauses fall in between.
- `RoutineContainer` — the App Group drop box. `readRoutines()`,
  `writeRoutines(_:)`, `writeSession(_:)`, `pendingSessions()`. The host passes
  its own group identifier in.

## Wire format rules

Both apps ship separately and either can be a version behind the other on any
given device. So: **add fields with defaults, never repurpose or renumber an
existing one.**

Timestamps are ISO-8601 with **millisecond** precision. Whole-second
timestamps still decode, so a file written by an older build isn't rejected.
Sub-millisecond detail is rounded — compare decoded dates with a tolerance
rather than `==`.

`pendingSessions()` hands back the file URL alongside each session. Delete the
file only once its rows are saved: a crash halfway then re-reads the practice
instead of losing it, and `sessionID` is what guards the duplicate that would
otherwise cause.

## Dependencies

None.
