import Foundation
import Testing
@testable import HuskCore

struct JournalTests {
    @Test func symlinkJournalCannotReadOrOverwriteAnotherFile() async throws {
        let fixture = try Fixture(); defer { fixture.clean() }
        let victim = try fixture.file("victim.json")
        let original = try Data(contentsOf: victim)
        let directory = fixture.root.appendingPathComponent("journal")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("operations.json"), withDestinationURL: victim)
        let journal = OperationJournal(directory: directory)
        do { _ = try await journal.records(); Issue.record("Symlink history was read") }
        catch RemovalError.changed { }
        do { try await journal.clear(); Issue.record("Symlink history was cleared") }
        catch RemovalError.changed { }
        #expect(try Data(contentsOf: victim) == original)
    }
}
