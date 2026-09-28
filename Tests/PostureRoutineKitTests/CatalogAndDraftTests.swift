//
//  CatalogAndDraftTests.swift
//  PostureRoutineKitTests
//
//  The two file types that let the runner app compose a routine: the
//  exercises it can pick from, and the draft it hands back.
//

import XCTest
@testable import PostureRoutineKit

final class CatalogAndDraftTests: XCTestCase {

    private let shinBox = UUID()
    private let squat = UUID()

    private func catalog() -> ExerciseCatalogFile {
        ExerciseCatalogFile(
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000.5),
            exercises: [
                CatalogExerciseFile(skillID: shinBox, name: "Shin box",
                                    familyName: "Seated", level: 1, suggestedHoldSec: 60),
                CatalogExerciseFile(skillID: squat, name: "Asian squat",
                                    familyName: "Seated", level: 2),
                CatalogExerciseFile(skillID: UUID(), name: "Pull-Up", familyName: "Pull-Ups")
            ]
        )
    }

    func testCatalogGroupsByFamilyInOrder() {
        let groups = catalog().byFamily
        XCTAssertEqual(groups.map(\.family), ["Pull-Ups", "Seated"])
        XCTAssertEqual(groups[1].exercises.map(\.name), ["Asian squat", "Shin box"])
    }

    func testExercisesWithNoFamilyAreGroupedRatherThanDropped() {
        let loose = ExerciseCatalogFile(exercises: [
            CatalogExerciseFile(skillID: UUID(), name: "Orphan")
        ])
        XCTAssertEqual(loose.byFamily.map(\.family), ["No family"])
    }

    func testCatalogRoundTrips() throws {
        let original = catalog()
        let back = try RoutineContainer.decoder().decode(
            ExerciseCatalogFile.self,
            from: try RoutineContainer.encoder().encode(original)
        )
        XCTAssertEqual(back, original)
    }

    // MARK: - Drafts

    private func draft(planID: UUID? = nil, holdSec: Int = 60) -> RoutineDraftFile {
        RoutineDraftFile(
            planID: planID,
            name: "Seated",
            entries: [
                RoutineEntryFile(skillID: shinBox, name: "Shin box", order: 0,
                                 holdSec: holdSec,
                                 positionNames: ["Right", "Centre", "Left"]),
                RoutineEntryFile(skillID: squat, name: "Asian squat", order: 1,
                                 holdSec: holdSec)
            ]
        )
    }

    /// A draft without a plan id is new; with one it means "update that".
    func testDraftKnowsWhetherItIsAnEdit() {
        XCTAssertFalse(draft().isEdit)
        XCTAssertTrue(draft(planID: UUID()).isEdit)
    }

    func testDraftIsOnlyValidWithANameAndTimedHolds() {
        XCTAssertTrue(draft().isValid)
        XCTAssertFalse(draft(holdSec: 0).isValid)

        var unnamed = draft()
        unnamed.name = "   "
        XCTAssertFalse(unnamed.isValid)

        var empty = draft()
        empty.entries = []
        XCTAssertFalse(empty.isValid)
    }

    func testDraftRoundSecondsCountsEveryPosition() {
        XCTAssertEqual(draft().roundSeconds, 240)
    }

    func testDraftRoundTrips() throws {
        let original = draft(planID: UUID())
        let back = try RoutineContainer.decoder().decode(
            RoutineDraftFile.self,
            from: try RoutineContainer.encoder().encode(original)
        )
        XCTAssertEqual(back.draftID, original.draftID)
        XCTAssertEqual(back.planID, original.planID)
        XCTAssertEqual(back.entries, original.entries)
    }
}

final class ExerciseNoteTests: XCTestCase {
    func testASessionWrittenBeforeExerciseNotesStillDecodes() throws {
        let json = #"{"sessionID":"6F9619FF-8B86-D011-B42D-00C04FC964FF","planID":"6F9619FF-8B86-D011-B42D-00C04FC964FE","routineName":"Hips","startedAt":"2026-09-27T10:00:00.000Z","endedAt":"2026-09-27T10:20:00.000Z","roundsCompleted":1,"holds":[],"notes":""}"#
        let file = try RoutineContainer.decoder().decode(PostureSessionFile.self, from: Data(json.utf8))
        XCTAssertNil(file.exerciseNotes)
        XCTAssertEqual(file.note(for: UUID()), "")
    }

    func testExerciseNotesRoundTrip() throws {
        let squat = UUID()
        let file = PostureSessionFile(planID: UUID(), routineName: "Hips", startedAt: Date(), endedAt: Date(),
                                      roundsCompleted: 1, holds: [],
                                      exerciseNotes: [PostureExerciseNoteFile(skillID: squat, name: "Hunter squat",
                                                                              text: "toes feel tight")])
        let back = try RoutineContainer.decoder().decode(PostureSessionFile.self,
                                                         from: RoutineContainer.encoder().encode(file))
        XCTAssertEqual(back.note(for: squat), "toes feel tight")
    }
}
