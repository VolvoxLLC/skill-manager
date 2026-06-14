import XCTest
@testable import SkillDeckServices

final class BackupManagerTests: XCTestCase {
    func testCreatesBackupCopy() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("source/SKILL.md")
        let backupRoot = root.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "content".write(to: source, atomically: true, encoding: .utf8)

        let manager = BackupManager(backupRoot: backupRoot)
        let backup = try manager.backupFile(at: source, skillID: "demo")

        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
        XCTAssertEqual(try String(contentsOf: backup), "content")
    }
}
