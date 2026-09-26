//
//  RoutineFile.swift
//  PostureRoutineKit
//
//  A routine as a runner needs it: the postures, in order, with how long each
//  is held and which positions it's worked through.
//
//  This is a wire format shared by two apps that ship separately — one
//  publishes routines, the other runs them and hands sessions back. Either can
//  be a version behind the other on any given device, so: add fields with
//  defaults, and never repurpose or renumber an existing one.
//

import Foundation

public struct RoutineFile: Codable, Identifiable, Sendable, Equatable {
    public var planID: UUID
    public var name: String
    public var summary: String
    /// Window length in days, carried so the runner can say when a routine is
    /// next due without reimplementing the publisher's schedule.
    public var cadenceDays: Int
    public var updatedAt: Date
    public var entries: [RoutineEntryFile]

    public var id: UUID { planID }

    public init(
        planID: UUID,
        name: String,
        summary: String = "",
        cadenceDays: Int = 7,
        updatedAt: Date = Date(),
        entries: [RoutineEntryFile] = []
    ) {
        self.planID = planID
        self.name = name
        self.summary = summary
        self.cadenceDays = cadenceDays
        self.updatedAt = updatedAt
        self.entries = entries
    }

    /// Seconds for one time through every posture. The arithmetic that turns
    /// a target session length into a number of rounds starts here.
    public var roundSeconds: Int {
        entries.reduce(0) { $0 + $1.roundSeconds }
    }

    /// True when every entry is a timed hold. A routine with a reps-based
    /// entry has nothing for a timer to count, so it can't be run guided.
    public var isRunnable: Bool {
        !entries.isEmpty && entries.allSatisfy { $0.holdSec > 0 }
    }

    /// Whole rounds that fit in `seconds`, at least one. Rounds down: better
    /// to finish early than to leave a round half-held.
    public func rounds(fitting seconds: Int) -> Int {
        guard roundSeconds > 0 else { return 1 }
        return max(1, seconds / roundSeconds)
    }

    /// How long `rounds` times through will actually take.
    public func duration(forRounds rounds: Int) -> Int {
        roundSeconds * max(1, rounds)
    }
}

public struct RoutineEntryFile: Codable, Identifiable, Sendable, Equatable {
    /// The publisher's own exercise id. The session file echoes it back, which
    /// is how a hold is reattached to the right exercise without matching on a
    /// name that either side might have edited.
    public var skillID: UUID
    public var name: String
    public var order: Int
    public var holdSec: Int
    /// Empty for a posture with one position. Otherwise the positions worked
    /// through, in order — "Right", "Centre", "Left".
    public var positionNames: [String]
    public var note: String

    public var id: UUID { skillID }

    public init(
        skillID: UUID,
        name: String,
        order: Int = 0,
        holdSec: Int = 0,
        positionNames: [String] = [],
        note: String = ""
    ) {
        self.skillID = skillID
        self.name = name
        self.order = order
        self.holdSec = holdSec
        self.positionNames = positionNames
        self.note = note
    }

    /// One name per hold: a single unnamed hold, or one per position.
    public var holdNames: [String] {
        positionNames.isEmpty ? [""] : positionNames
    }

    /// Seconds for one time through this entry — every position, held once.
    public var roundSeconds: Int { holdSec * holdNames.count }
}
