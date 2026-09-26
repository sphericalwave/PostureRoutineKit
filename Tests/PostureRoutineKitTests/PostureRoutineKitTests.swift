//
//  PostureRoutineKitTests.swift
//  PostureRoutineKitTests
//
//  The rounds arithmetic, and the JSON shape two separately-shipped apps have
//  to keep agreeing on.
//

import XCTest
@testable import PostureRoutineKit

final class PostureRoutineKitTests: XCTestCase {

    private func shinBox(holdSec: Int = 60) -> RoutineEntryFile {
        RoutineEntryFile(skillID: UUID(), name: "Shin box", order: 0, holdSec: holdSec,
                         positionNames: ["Right", "Centre", "Left"])
    }

    private func asianSquat(holdSec: Int = 90) -> RoutineEntryFile {
        RoutineEntryFile(skillID: UUID(), name: "Asian squat", order: 1, holdSec: holdSec)
    }

    /// Timestamps are millisecond-precision on the wire, so fixtures that get
    /// compared after a round trip are built on the millisecond.
    private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000.123)

    private func routine(_ entries: [RoutineEntryFile]) -> RoutineFile {
        RoutineFile(planID: UUID(), name: "Seated", updatedAt: fixedDate, entries: entries)
    }

    // MARK: - Round arithmetic

    func testRoundSecondsCountsEveryPosition() {
        XCTAssertEqual(shinBox().roundSeconds, 180)
        XCTAssertEqual(asianSquat().roundSeconds, 90)
        XCTAssertEqual(routine([shinBox(), asianSquat()]).roundSeconds, 270)
    }

    func testEntryWithNoPositionsIsStillOneHold() {
        XCTAssertEqual(asianSquat().holdNames, [""])
        XCTAssertEqual(shinBox().holdNames, ["Right", "Centre", "Left"])
    }

    /// Rounds down — better to finish early than leave a round half-held.
    func testRoundsFittingATargetRoundDown() {
        let r = routine([shinBox(), asianSquat()])   // 270s a round
        XCTAssertEqual(r.rounds(fitting: 20 * 60), 4)   // 1200 / 270 = 4.4
        XCTAssertEqual(r.rounds(fitting: 270), 1)
        XCTAssertEqual(r.duration(forRounds: 4), 1080)
    }

    /// A target shorter than one round still runs once rather than zero times.
    func testATargetShorterThanARoundStillRunsOnce() {
        XCTAssertEqual(routine([shinBox()]).rounds(fitting: 30), 1)
    }

    func testEmptyRoutineDoesNotDivideByZero() {
        XCTAssertEqual(routine([]).rounds(fitting: 600), 1)
        XCTAssertEqual(routine([]).roundSeconds, 0)
    }

    func testRunnableRequiresEveryEntryToBeATimedHold() {
        XCTAssertTrue(routine([shinBox(), asianSquat()]).isRunnable)
        XCTAssertFalse(routine([shinBox(), asianSquat(holdSec: 0)]).isRunnable)
        XCTAssertFalse(routine([]).isRunnable)
    }

    // MARK: - Session summary

    func testSessionSummaryCountsHeldTimeNotWallClock() {
        let start = Date()
        let session = PostureSessionFile(
            planID: UUID(),
            routineName: "Seated",
            startedAt: start,
            endedAt: start.addingTimeInterval(600),
            roundsCompleted: 2,
            holds: [
                PostureHoldFile(skillID: UUID(), name: "Shin box", positionName: "Right",
                                heldSec: 60, startedAt: start, hrAvg: 96),
                PostureHoldFile(skillID: UUID(), name: "Shin box", positionName: "Left",
                                heldSec: 55, startedAt: start, hrAvg: 104),
                PostureHoldFile(skillID: UUID(), name: "Asian squat",
                                heldSec: 90, startedAt: start)
            ]
        )
        // Ten minutes elapsed, but only three and a bit were spent holding.
        XCTAssertEqual(session.wallClockSeconds, 600)
        XCTAssertEqual(session.timeUnderTension, 205)
        // The hold with no reading doesn't drag the average to zero.
        XCTAssertEqual(session.averageHR, 100)
    }

    func testAverageHRIsNilWhenNothingWasRecorded() {
        let start = Date()
        let session = PostureSessionFile(
            planID: UUID(), routineName: "x", startedAt: start, endedAt: start,
            roundsCompleted: 1,
            holds: [PostureHoldFile(skillID: UUID(), name: "x", heldSec: 30, startedAt: start)]
        )
        XCTAssertNil(session.averageHR)
    }

    func testHoldDisplayNameIncludesThePositionOnlyWhenThereIsOne() {
        let start = Date()
        let sided = PostureHoldFile(skillID: UUID(), name: "Shin box",
                                    positionName: "Right", heldSec: 60, startedAt: start)
        let plain = PostureHoldFile(skillID: UUID(), name: "Asian squat",
                                    heldSec: 90, startedAt: start)
        XCTAssertEqual(sided.displayName, "Shin box, Right")
        XCTAssertEqual(plain.displayName, "Asian squat")
    }

    // MARK: - Wire format

    /// Two apps ship separately and can be a version apart on any device, so
    /// both files have to survive a round trip unchanged.
    func testRoutineAndSessionRoundTripThroughJSON() throws {
        let original = routine([shinBox(), asianSquat()])
        let data = try RoutineContainer.encoder().encode(original)
        let decoded = try RoutineContainer.decoder().decode(RoutineFile.self, from: data)
        XCTAssertEqual(decoded, original)

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = PostureSessionFile(
            planID: original.planID, routineName: original.name,
            startedAt: start, endedAt: start.addingTimeInterval(900),
            roundsCompleted: 3,
            holds: [PostureHoldFile(skillID: UUID(), name: "Shin box", positionName: "Centre",
                                    roundIndex: 1, orderInRound: 2, heldSec: 58,
                                    startedAt: start, hrAvg: 99, hrMin: 90, hrMax: 110,
                                    hrSamples: [PostureHRSampleFile(t: 0, bpm: 90)])],
            notes: "steady"
        )
        let sessionData = try RoutineContainer.encoder().encode(session)
        let back = try RoutineContainer.decoder().decode(PostureSessionFile.self, from: sessionData)
        XCTAssertEqual(back, session)
    }

    /// Dates cross the boundary as ISO-8601, not as a floating-point offset
    /// whose meaning depends on both sides agreeing a reference date.
    func testDatesAreEncodedAsISO8601() throws {
        let session = PostureSessionFile(
            planID: UUID(), routineName: "x",
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 60),
            roundsCompleted: 1, holds: []
        )
        let json = String(decoding: try RoutineContainer.encoder().encode(session), as: UTF8.self)
        XCTAssertTrue(json.contains("1970-01-01T00:00:00"), json)
    }

    /// Plain `.iso8601` truncates to whole seconds, so a duration derived
    /// from a decoded pair was off by up to a second at each end. Sub-second
    /// detail now survives, to the millisecond.
    func testSubSecondPrecisionSurvivesTheRoundTrip() throws {
        let precise = Date(timeIntervalSince1970: 1_800_000_000.456)
        let session = PostureSessionFile(
            planID: UUID(), routineName: "x",
            startedAt: precise, endedAt: precise.addingTimeInterval(90.5),
            roundsCompleted: 1, holds: []
        )
        let back = try RoutineContainer.decoder().decode(
            PostureSessionFile.self,
            from: try RoutineContainer.encoder().encode(session)
        )
        XCTAssertEqual(back.endedAt.timeIntervalSince(back.startedAt), 90.5, accuracy: 0.002)
        XCTAssertEqual(back, session)
    }

    /// Millisecond is the floor — a date finer than that comes back rounded,
    /// which is fine for holds but must not be mistaken for exactness.
    func testPrecisionFinerThanAMillisecondIsRounded() throws {
        let tooPrecise = Date(timeIntervalSince1970: 1_800_000_000.123456)
        let session = PostureSessionFile(
            planID: UUID(), routineName: "x",
            startedAt: tooPrecise, endedAt: tooPrecise,
            roundsCompleted: 1, holds: []
        )
        let back = try RoutineContainer.decoder().decode(
            PostureSessionFile.self,
            from: try RoutineContainer.encoder().encode(session)
        )
        XCTAssertEqual(back.startedAt.timeIntervalSince1970,
                       tooPrecise.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertNotEqual(back.startedAt, tooPrecise)
    }

    /// A file written before the format carried fractions still decodes.
    func testWholeSecondTimestampsStillDecode() throws {
        let json = """
        {"endedAt":"2026-09-26T10:00:30Z","holds":[],"notes":"",\
        "planID":"\(UUID().uuidString)","roundsCompleted":1,\
        "routineName":"x","sessionID":"\(UUID().uuidString)",\
        "startedAt":"2026-09-26T10:00:00Z"}
        """
        let back = try RoutineContainer.decoder().decode(
            PostureSessionFile.self, from: Data(json.utf8)
        )
        XCTAssertEqual(back.wallClockSeconds, 30)
    }
}
