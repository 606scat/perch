import Foundation

public enum UpdateBackup {
    /// Create an exact, independently verified snapshot. Never overwrite or
    /// automatically restore a backup over live data. The caller holds the lease.
    @discardableResult public static func create(dataURL: URL, backupRoot: URL? = nil) throws -> URL {
        let manager = FileManager.default
        let root = backupRoot ?? dataURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Perch Backups", isDirectory: true)
        let directory = root.appendingPathComponent("update-\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString)", isDirectory: true)
        let bytes = try Data(contentsOf: dataURL)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let target = directory.appendingPathComponent("data.json")
        do {
            try bytes.write(to: target, options: .withoutOverwriting)
            try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            guard try Data(contentsOf: target) == bytes else { throw CocoaError(.fileWriteUnknown) }
            return target
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }
}
