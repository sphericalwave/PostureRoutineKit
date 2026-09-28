//
//  RoutineContainer.swift
//  PostureRoutineKit
//
//  The App Group drop box the two apps exchange files through. Neither ever
//  opens the other's database: one writes routines and reads finished
//  sessions, the other reads routines and writes sessions, and the file
//  system arbitrates. A shared SwiftData/CoreData store would be the
//  alternative, and two processes on one CloudKit-mirrored store is
//  unsupported.
//
//  The group identifier is the host's, not the package's — both apps pass the
//  same one in.
//

import Foundation

public struct RoutineContainer: Sendable {
    public let groupID: String

    public init(groupID: String) {
        self.groupID = groupID
    }

    public var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    /// Routines the publisher offers. Rewritten wholesale on every change, so
    /// a routine that was deleted or paused stops being offered.
    public var routinesDir: URL? {
        containerURL?.appending(path: "Routines", directoryHint: .isDirectory)
    }

    /// Finished sessions waiting to be imported.
    public var sessionsDir: URL? {
        containerURL?.appending(path: "PostureSessions", directoryHint: .isDirectory)
    }

    /// Past practices the publisher already imported, handed back so the
    /// runner can list them — it kept no record of its own before it had a
    /// history screen.
    public var historyDir: URL? {
        containerURL?.appending(path: "PostureHistory", directoryHint: .isDirectory)
    }

    /// Routines composed in the runner app, waiting to be made real.
    public var draftsDir: URL? {
        containerURL?.appending(path: "RoutineDrafts", directoryHint: .isDirectory)
    }

    /// The exercises a routine can be composed from.
    public var catalogURL: URL? {
        containerURL?.appending(path: "exercises.\(Self.fileExtension)")
    }

    public static let fileExtension = "json"

    /// ISO-8601 with fractional seconds — **millisecond precision**.
    ///
    /// Plain `.iso8601` truncates to whole seconds, which is too coarse here:
    /// hold durations are derived from these timestamps, so a second lost at
    /// each end shows up as a wrong number in the log. Milliseconds are far
    /// finer than anything a held posture needs.
    ///
    /// It is still a text format with finite precision, so a `Date` carrying
    /// sub-millisecond detail does not survive the round trip exactly. Don't
    /// assert `==` on a decoded date built from an arbitrary `Date()`;
    /// compare with a tolerance.
    nonisolated(unsafe) private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601.string(from: date))
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = iso8601.date(from: text) ?? fallbackISO8601.date(from: text) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath,
                          debugDescription: "Not an ISO-8601 date: \(text)")
                )
            }
            return date
        }
        return decoder
    }

    /// Whole-second timestamps still decode, so a file written by a build
    /// that predated the fractional format isn't rejected.
    nonisolated(unsafe) private static let fallbackISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // MARK: - Routines

    /// Every published routine, newest name-order first read wins. A file
    /// that won't decode is skipped rather than failing the whole read — one
    /// bad routine shouldn't hide the rest.
    public func readRoutines() -> [RoutineFile] {
        guard let dir = routinesDir,
              let urls = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
              )
        else { return [] }

        let decoder = Self.decoder()
        return urls
            .filter { $0.pathExtension == Self.fileExtension }
            .compactMap { url -> RoutineFile? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(RoutineFile.self, from: data)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Replaces the published set. Files for routines no longer listed are
    /// removed, which is how a paused one stops being offered.
    public func writeRoutines(_ routines: [RoutineFile]) throws {
        guard let dir = routinesDir else { return }
        let fm = FileManager.default
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let encoder = Self.encoder()
        var written: Set<String> = []
        for routine in routines {
            let name = "\(routine.planID.uuidString).\(Self.fileExtension)"
            written.insert(name)
            try encoder.encode(routine).write(to: dir.appending(path: name), options: .atomic)
        }
        for name in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] where !written.contains(name) {
            try? fm.removeItem(at: dir.appending(path: name))
        }
    }

    // MARK: - Sessions

    /// Drops a finished session in for the publisher to pick up.
    public func writeSession(_ session: PostureSessionFile) throws {
        guard let dir = sessionsDir else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "\(session.sessionID.uuidString).\(Self.fileExtension)")
        try Self.encoder().encode(session).write(to: url, options: .atomic)
    }

    // MARK: - History

    /// Hands a past practice back to the runner. Named by session, so writing
    /// the same one twice replaces rather than duplicates.
    public func writeHistory(_ session: PostureSessionFile) throws {
        guard let dir = historyDir else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "\(session.sessionID.uuidString).\(Self.fileExtension)")
        try Self.encoder().encode(session).write(to: url, options: .atomic)
    }

    /// Past practices waiting to be taken in, oldest first. The caller deletes
    /// each file once it has its own copy.
    public func pendingHistory() -> [(url: URL, session: PostureSessionFile)] {
        read(PostureSessionFile.self, in: historyDir)
            .sorted { $0.1.endedAt < $1.1.endedAt }
            .map { (url: $0.0, session: $0.1) }
    }

    private func read<T: Decodable>(_ type: T.Type, in dir: URL?) -> [(URL, T)] {
        guard let dir,
              let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return [] }
        let decoder = Self.decoder()
        return urls
            .filter { $0.pathExtension == Self.fileExtension }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let value = try? decoder.decode(T.self, from: data) else { return nil }
                return (url, value)
            }
    }

    // MARK: - Exercise catalog

    /// Publishes the exercises a routine can be composed from. One file,
    /// rewritten whole — an exercise that was deleted must stop being
    /// offered, and there is no sane merge of two versions of a catalog.
    public func writeCatalog(_ catalog: ExerciseCatalogFile) throws {
        guard let url = catalogURL, let dir = containerURL else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Self.encoder().encode(catalog).write(to: url, options: .atomic)
    }

    public func readCatalog() -> ExerciseCatalogFile? {
        guard let url = catalogURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? Self.decoder().decode(ExerciseCatalogFile.self, from: data)
    }

    // MARK: - Routine drafts

    /// Hands a composed routine over to be materialised.
    public func writeDraft(_ draft: RoutineDraftFile) throws {
        guard let dir = draftsDir else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "\(draft.draftID.uuidString).\(Self.fileExtension)")
        try Self.encoder().encode(draft).write(to: url, options: .atomic)
    }

    /// Drafts waiting, oldest first, paired with the file each came from.
    /// As with sessions, delete a file only once its plan exists.
    public func pendingDrafts() -> [(url: URL, draft: RoutineDraftFile)] {
        guard let dir = draftsDir,
              let urls = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
              )
        else { return [] }

        let decoder = Self.decoder()
        return urls
            .filter { $0.pathExtension == Self.fileExtension }
            .compactMap { url -> (URL, RoutineDraftFile)? in
                guard let data = try? Data(contentsOf: url),
                      let draft = try? decoder.decode(RoutineDraftFile.self, from: data)
                else { return nil }
                return (url, draft)
            }
            .sorted { $0.1.createdAt < $1.1.createdAt }
            .map { (url: $0.0, draft: $0.1) }
    }

    /// Finished sessions waiting, oldest first, paired with the file each came
    /// from. The caller deletes a file only once its rows are saved, so a
    /// crash halfway re-reads rather than losing the practice.
    public func pendingSessions() -> [(url: URL, session: PostureSessionFile)] {
        guard let dir = sessionsDir,
              let urls = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
              )
        else { return [] }

        let decoder = Self.decoder()
        return urls
            .filter { $0.pathExtension == Self.fileExtension }
            .compactMap { url -> (URL, PostureSessionFile)? in
                guard let data = try? Data(contentsOf: url),
                      let session = try? decoder.decode(PostureSessionFile.self, from: data)
                else { return nil }
                return (url, session)
            }
            .sorted { $0.1.endedAt < $1.1.endedAt }
            .map { (url: $0.0, session: $0.1) }
    }
}
