//
//  FuzzySearchTests.swift
//  PostureRoutineKitTests
//
//  Searching that survives a dropped letter, without matching everything.
//

import XCTest
@testable import PostureRoutineKit

final class FuzzySearchTests: XCTestCase {

    func testNormalisingIgnoresCaseSpacingAndPunctuation() {
        XCTAssertEqual(FuzzySearch.normalized("Pull-Up"), "pullup")
        XCTAssertEqual(FuzzySearch.normalized("  Shin Box  "), "shinbox")
        XCTAssertEqual(FuzzySearch.normalized("ATG Standards — Lower"), "atgstandardslower")
    }

    /// The everyday case, and the reason normalising comes first.
    func testContainsIgnoresSpacingAndPunctuation() {
        XCTAssertTrue(FuzzySearch.contains("Shin box", query: "shinbox"))
        XCTAssertTrue(FuzzySearch.contains("Pull-Up", query: "pullup"))
        XCTAssertTrue(FuzzySearch.contains("meditation", query: "MEDIT"))
        XCTAssertFalse(FuzzySearch.contains("meditation", query: "squat"))
    }

    /// The search that started this: one dropped letter returned nothing.
    func testACloseMisspellingMatches() {
        XCTAssertTrue(FuzzySearch.isClose("meditation", query: "medtation"))
        XCTAssertTrue(FuzzySearch.isClose("Shin box", query: "shin bx"))
        XCTAssertTrue(FuzzySearch.isClose("Asian squat", query: "asain squat"))
    }

    /// A typo in one word of a longer name still has to match, which is why
    /// the comparison runs against windows rather than the whole string.
    func testATypoInsideALongerNameMatches() {
        XCTAssertTrue(FuzzySearch.isClose("ATG Standards — Lower", query: "standrds"))
    }

    /// Forgiving is not the same as useless.
    func testUnrelatedWordsDoNotMatch() {
        XCTAssertFalse(FuzzySearch.isClose("meditation", query: "squat"))
        XCTAssertFalse(FuzzySearch.isClose("Pull-Up", query: "jefferson"))
    }

    /// Two edits on a three-letter query would match nearly anything, so
    /// short queries get no allowance at all.
    func testShortQueriesGetNoAllowance() {
        XCTAssertEqual(FuzzySearch.allowance(for: "abs"), 0)
        XCTAssertFalse(FuzzySearch.isClose("abs", query: "ads"))
        XCTAssertTrue(FuzzySearch.contains("abs", query: "abs"))
    }

    func testAllowanceGrowsWithQueryLength() {
        XCTAssertEqual(FuzzySearch.allowance(for: "squat"), 1)
        XCTAssertEqual(FuzzySearch.allowance(for: "meditation"), 2)
        XCTAssertEqual(FuzzySearch.allowance(for: "cossack squats"), 3)
    }

    func testDistanceCountsSingleCharacterEdits() {
        XCTAssertEqual(FuzzySearch.distance(Array("cat"), Array("cat"), limit: 3), 0)
        XCTAssertEqual(FuzzySearch.distance(Array("cat"), Array("cot"), limit: 3), 1)
        XCTAssertEqual(FuzzySearch.distance(Array("cat"), Array("cats"), limit: 3), 1)
        XCTAssertEqual(FuzzySearch.distance(Array("cat"), Array("at"), limit: 3), 1)
    }

    /// Abandoning early must not report a distance under the limit.
    func testDistanceStopsCountingPastTheLimit() {
        let far = FuzzySearch.distance(Array("meditation"), Array("squat"), limit: 2)
        XCTAssertGreaterThan(far, 2)
    }

    // MARK: - Searching the catalog

    private func catalog() -> ExerciseCatalogFile {
        ExerciseCatalogFile(exercises: [
            CatalogExerciseFile(skillID: UUID(), name: "Seiza", familyName: "meditation"),
            CatalogExerciseFile(skillID: UUID(), name: "Half kneeling", familyName: "meditation"),
            CatalogExerciseFile(skillID: UUID(), name: "Pull-Up", familyName: "Pull-Ups")
        ])
    }

    func testCatalogSearchMatchesOnFamilyName() {
        let groups = catalog().search("meditation")
        XCTAssertEqual(groups.map(\.family), ["meditation"])
        XCTAssertEqual(groups[0].exercises.map(\.name).sorted(), ["Half kneeling", "Seiza"])
    }

    func testCatalogSearchRescuesAMisspeltFamily() {
        let groups = catalog().search("medtation")
        XCTAssertEqual(groups.map(\.family), ["meditation"])
        XCTAssertEqual(groups[0].exercises.count, 2)
    }

    /// An exact match must not be diluted by close ones.
    func testAnExactMatchWinsOutright() {
        let groups = catalog().search("Seiza")
        XCTAssertEqual(groups.flatMap { $0.exercises.map(\.name) }, ["Seiza"])
    }

    func testAnEmptyQueryReturnsEverything() {
        XCTAssertEqual(catalog().search("   ").flatMap(\.exercises).count, 3)
    }

    func testNothingCloseReturnsNothing() {
        XCTAssertTrue(catalog().search("bicycle").isEmpty)
    }
}
