import Foundation
import Darwin

/// A kernel-held lock is released even after a crash. Two app copies must not
/// load separate snapshots and later overwrite each other's saved changes.
public final class PersistenceLease {
    private let descriptor: Int32
    public init(dataURL: URL) throws {
        let directory = dataURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let update = directory.appendingPathComponent(".update-lock")
        if FileManager.default.fileExists(atPath: update.path) {
            let owner = try? String(contentsOf: update.appendingPathComponent("pid"), encoding: .utf8)
            if let owner, let pid = Int32(owner.trimmingCharacters(in: .whitespacesAndNewlines)) {
                if kill(pid, 0) == 0 || errno == EPERM { throw LeaseError.updating }
            } else { throw LeaseError.updating }
        }
        let path = directory.appendingPathComponent(".data.lock").path
        let handle = open(path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard handle >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard flock(handle, LOCK_EX | LOCK_NB) == 0 else {
            let code = errno; close(handle)
            if code == EWOULDBLOCK { throw LeaseError.alreadyOpen }
            throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
        }
        descriptor = handle
    }
    deinit { flock(descriptor, LOCK_UN); close(descriptor) }

    public enum LeaseError: LocalizedError {
        case alreadyOpen, updating
        public var errorDescription: String? {
            switch self {
            case .alreadyOpen: "Another copy of Perch is already using your data. Quit that copy before opening this one. Your data is unchanged."
            case .updating: "Perch is being updated. Wait for the installer to finish, then open Perch again. Your data is unchanged."
            }
        }
    }
}
