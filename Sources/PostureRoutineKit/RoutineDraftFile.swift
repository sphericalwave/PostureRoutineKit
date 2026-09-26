//
//  RoutineDraftFile.swift
//  PostureRoutineKit
//
//  A routine composed in the runner app and handed to the owning app to be
//  made real.
//
//  It is a *draft*, not a routine: the app that owns the log also owns
//  scheduling, cycles and reminders, so a routine only becomes a first-class
//  plan once that app has materialised it. Until then it has no plan id and
//  nothing checks off against it.
//
//  Wire format: add fields with defaults, never repurpose one.
//

import Foundation

public struct RoutineDraftFile: Codable, Identifiable, Sendable, Equatable {
    /// Identifies this draft for as long as it takes to be materialised, so
    /// a file re-read after a crash doesn't create the plan twice.
    public var draftID: UUID
    /// Set when editing a routine that already exists, so the owning app
    /// updates that plan rather than creating a second one beside it. nil
    /// means this is new.
    public var planID: UUID?
    public var name: String
    public var summary: String
    public var cadenceDays: Int
    public var createdAt: Date
    public var entries: [RoutineEntryFile]

    public var id: UUID { draftID }

    public init(
        draftID: UUID = UUID(),
        planID: UUID? = nil,
        name: String,
        summary: String = "",
        cadenceDays: Int = 7,
        createdAt: Date = Date(),
        entries: [RoutineEntryFile] = []
    ) {
        self.draftID = draftID
        self.planID = planID
        self.name = name
        self.summary = summary
        self.cadenceDays = cadenceDays
        self.createdAt = createdAt
        self.entries = entries
    }

    public var isEdit: Bool { planID != nil }

    /// Enough to be worth materialising: a name, and at least one timed hold.
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !entries.isEmpty
            && entries.allSatisfy { $0.holdSec > 0 }
    }

    public var roundSeconds: Int {
        entries.reduce(0) { $0 + $1.roundSeconds }
    }
}
