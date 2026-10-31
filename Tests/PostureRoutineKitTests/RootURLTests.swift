//
//  RootURLTests.swift
//  PostureRoutineKitTests
//
//  A container rooted in a plain folder lays files out exactly as the App
//  Group one does, so a host's tests can use it instead of the real group.
//

import XCTest
@testable import PostureRoutineKit

final class RootURLTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "RootURLTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testEverythingLivesUnderTheRoot() {
        let container = RoutineContainer(rootURL: root)
        XCTAssertEqual(container.containerURL, root)
        for dir in [container.routinesDir, container.sessionsDir, container.historyDir,
                    container.draftsDir, container.catalogURL] {
            XCTAssertEqual(dir?.deletingLastPathComponent().standardizedFileURL, root.standardizedFileURL)
        }
    }

    func testCatalogRoundTripsThroughTheRoot() throws {
        let container = RoutineContainer(rootURL: root)
        let catalog = ExerciseCatalogFile(exercises: [
            CatalogExerciseFile(skillID: UUID(), name: "Seiza", familyName: "Seated")
        ])
        try container.writeCatalog(catalog)
        XCTAssertEqual(container.readCatalog()?.exercises.map(\.name), ["Seiza"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: container.catalogURL!.path))
    }
}
