//
//  PostureSessionFile.swift
//  PostureRoutineKit
//
//  What the runner hands back after working through a routine. Durations are
//  what was actually held, not what was prescribed — a hold cut short reports
//  short, because the log is a record of what happened.
//
//  Wire format: add fields with defaults, never repurpose one. See RoutineFile.
//

import Foundation

public struct PostureSessionFile: Codable, Identifiable, Sendable, Equatable {
    /// Identifies this practice for as long as it takes to be imported. The
    /// importer keeps it so a file re-read after a crash doesn't log twice.
    public var sessionID: UUID
    public var planID: UUID
    public var routineName: String
    public var startedAt: Date
    public var endedAt: Date
    public var roundsCompleted: Int
    public var holds: [PostureHoldFile]
    public var notes: String
    /// A comment per exercise, written on the summary. Optional on the wire
    /// so sessions written before it existed still decode.
    public var exerciseNotes: [PostureExerciseNoteFile]?
    /// The assist each exercise was held with. Optional on the wire, like
    /// `exerciseNotes`.
    public var exerciseAssists: [PostureExerciseAssistFile]?
    /// Bumped each time the practice is corrected after the fact. Nil is the
    /// original; an importer that already has this session replaces what it
    /// logged when a higher revision arrives.
    public var revision: Int?

    public var id: UUID { sessionID }

    /// The comment left on one exercise, or "".
    public func note(for skillID: UUID) -> String {
        exerciseNotes?.first { $0.skillID == skillID }?.text ?? ""
    }

    /// The assist one exercise was held with, if any.
    public func assist(for skillID: UUID) -> PostureExerciseAssistFile? {
        exerciseAssists?.first { $0.skillID == skillID }
    }

    public init(
        sessionID: UUID = UUID(),
        planID: UUID,
        routineName: String,
        startedAt: Date,
        endedAt: Date,
        roundsCompleted: Int,
        holds: [PostureHoldFile],
        notes: String = "",
        exerciseNotes: [PostureExerciseNoteFile]? = nil,
        exerciseAssists: [PostureExerciseAssistFile]? = nil,
        revision: Int? = nil
    ) {
        self.sessionID = sessionID
        self.planID = planID
        self.routineName = routineName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.roundsCompleted = roundsCompleted
        self.holds = holds
        self.notes = notes
        self.exerciseNotes = exerciseNotes
        self.exerciseAssists = exerciseAssists
        self.revision = revision
    }

    /// Total time actually spent holding, which is not the same as the wall
    /// clock — transitions and pauses fall between holds.
    public var timeUnderTension: Int {
        holds.reduce(0) { $0 + $1.heldSec }
    }

    public var wallClockSeconds: Int {
        max(0, Int(endedAt.timeIntervalSince(startedAt).rounded()))
    }

    /// Mean of the per-hold averages that actually recorded one.
    public var averageHR: Int? {
        let readings = holds.map(\.hrAvg).filter { $0 > 0 }
        guard !readings.isEmpty else { return nil }
        return readings.reduce(0, +) / readings.count
    }
}

public struct PostureHoldFile: Codable, Sendable, Equatable {
    public var skillID: UUID
    /// The name as it was at run time, so a hold still imports if the
    /// exercise was renamed or deleted in between.
    public var name: String
    /// "" for a single-position posture.
    public var positionName: String
    public var roundIndex: Int
    public var orderInRound: Int
    public var heldSec: Int
    public var startedAt: Date
    public var hrAvg: Int
    public var hrMin: Int
    public var hrMax: Int
    /// Seconds from the start of this hold, paired with the reading.
    public var hrSamples: [PostureHRSampleFile]

    public init(
        skillID: UUID,
        name: String,
        positionName: String = "",
        roundIndex: Int = 0,
        orderInRound: Int = 0,
        heldSec: Int,
        startedAt: Date,
        hrAvg: Int = 0,
        hrMin: Int = 0,
        hrMax: Int = 0,
        hrSamples: [PostureHRSampleFile] = []
    ) {
        self.skillID = skillID
        self.name = name
        self.positionName = positionName
        self.roundIndex = roundIndex
        self.orderInRound = orderInRound
        self.heldSec = heldSec
        self.startedAt = startedAt
        self.hrAvg = hrAvg
        self.hrMin = hrMin
        self.hrMax = hrMax
        self.hrSamples = hrSamples
    }

    /// "Shin box, Right" — what the review lists and the log annotates.
    public var displayName: String {
        positionName.isEmpty ? name : "\(name), \(positionName)"
    }
}

public struct PostureHRSampleFile: Codable, Sendable, Equatable {
    public var t: Double
    public var bpm: Int

    public init(t: Double, bpm: Int) {
        self.t = t
        self.bpm = bpm
    }
}

public struct PostureExerciseNoteFile: Codable, Sendable, Equatable {
    public var skillID: UUID
    /// As it was at run time, like `PostureHoldFile.name`.
    public var name: String
    public var text: String

    public init(skillID: UUID, name: String, text: String) {
        self.skillID = skillID
        self.name = name
        self.text = text
    }
}

public struct PostureExerciseAssistFile: Codable, Sendable, Equatable {
    public var skillID: UUID
    /// As it was at run time, like `PostureHoldFile.name`.
    public var name: String
    /// Pounds taken off. Positive; the importer logs it as negative load.
    public var lbs: Double
    /// "Overhead pulley" — may be empty.
    public var setup: String

    public init(skillID: UUID, name: String, lbs: Double, setup: String = "") {
        self.skillID = skillID
        self.name = name
        self.lbs = lbs
        self.setup = setup
    }

    /// "Overhead pulley −35 lb", or "−35 lb" with no setup named.
    public var label: String {
        let amount = "\u{2212}\(lbs.formatted(.number.precision(.fractionLength(0...1)))) lb"
        return setup.isEmpty ? amount : "\(setup) \(amount)"
    }
}
