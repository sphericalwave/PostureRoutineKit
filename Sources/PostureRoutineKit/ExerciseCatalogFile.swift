//
//  ExerciseCatalogFile.swift
//  PostureRoutineKit
//
//  The exercises available to compose a routine from.
//
//  Exercises themselves can't move between the apps: they're where sets are
//  logged and where the training history hangs, so they belong to the app
//  that owns the log. But composing a routine only needs to know what
//  exists, so that app publishes a list and the other one picks from it.
//
//  Wire format: add fields with defaults, never repurpose one.
//

import Foundation

public struct ExerciseCatalogFile: Codable, Sendable, Equatable {
    public var updatedAt: Date
    public var exercises: [CatalogExerciseFile]

    public init(updatedAt: Date = Date(), exercises: [CatalogExerciseFile] = []) {
        self.updatedAt = updatedAt
        self.exercises = exercises
    }

    /// Grouped for a picker, families in name order, exercises within each.
    public var byFamily: [(family: String, exercises: [CatalogExerciseFile])] {
        Dictionary(grouping: exercises) { $0.familyName.isEmpty ? "No family" : $0.familyName }
            .map { (family: $0.key, exercises: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.family.localizedCaseInsensitiveCompare($1.family) == .orderedAscending }
    }
}

public struct CatalogExerciseFile: Codable, Identifiable, Sendable, Equatable {
    /// The owning app's `Skill.id`. A composed routine refers to exercises by
    /// this, so a rename on either side can't break the link.
    public var skillID: UUID
    public var name: String
    public var familyName: String
    public var level: Int
    /// The exercise's own tempo, summed, when it has one — a reasonable first
    /// guess at how long to hold it. 0 when there's nothing to go on.
    public var suggestedHoldSec: Int

    public var id: UUID { skillID }

    public init(
        skillID: UUID,
        name: String,
        familyName: String = "",
        level: Int = 1,
        suggestedHoldSec: Int = 0
    ) {
        self.skillID = skillID
        self.name = name
        self.familyName = familyName
        self.level = level
        self.suggestedHoldSec = suggestedHoldSec
    }
}
