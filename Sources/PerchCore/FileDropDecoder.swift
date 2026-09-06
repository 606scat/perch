import AppKit

public enum FileDropDecoder {
    @MainActor public static func urls(from pasteboard: NSPasteboard) -> [URL] {
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ?? []
        var seen = Set<URL>()
        return objects.compactMap { ($0 as? NSURL).map { $0 as URL } }
            .filter { $0.isFileURL && seen.insert($0.standardizedFileURL).inserted }
    }
}
