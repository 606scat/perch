import AppKit
import IOKit.pwr_mgt

protocol PowerAssertionBackend {
    func create(display: Bool, duration: TimeInterval) throws -> IOPMAssertionID
    func release(_ id: IOPMAssertionID)
}

struct NativePowerAssertions: PowerAssertionBackend {
    func create(display: Bool, duration: TimeInterval) throws -> IOPMAssertionID {
        let properties: [String: Any] = [
            kIOPMAssertionTypeKey: display ? kIOPMAssertionTypePreventUserIdleDisplaySleep : kIOPMAssertionTypePreventUserIdleSystemSleep,
            kIOPMAssertionNameKey: "Perch Keep Awake",
            kIOPMAssertionLevelKey: kIOPMAssertionLevelOn,
            kIOPMAssertionTimeoutKey: duration,
            kIOPMAssertionTimeoutActionKey: kIOPMAssertionTimeoutActionRelease
        ]
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithProperties(properties as CFDictionary, &id)
        guard result == kIOReturnSuccess else { throw NSError(domain: "Perch.KeepAwake", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "macOS couldn’t keep this Mac awake (\(result)). Try starting it again."]) }
        return id
    }
    func release(_ id: IOPMAssertionID) { IOPMAssertionRelease(id) }
}

@MainActor final class AwakeController: ObservableObject {
    @Published private(set) var endsAt: Date?
    @Published private(set) var keepsDisplayAwake = false
    private let backend: PowerAssertionBackend
    private var assertions: [IOPMAssertionID] = []
    private var timer: Timer?
    init(backend: PowerAssertionBackend = NativePowerAssertions()) { self.backend = backend }
    func start(minutes: Int, display: Bool, now: Date = Date()) throws {
        guard endsAt == nil else { return }
        let duration = Double(max(1, min(180, minutes))) * 60
        do {
            assertions.append(try backend.create(display: false, duration: duration))
            if display { assertions.append(try backend.create(display: true, duration: duration)) }
        } catch { stop(); throw error }
        keepsDisplayAwake = display; endsAt = now.addingTimeInterval(duration)
        let timer = Timer(timeInterval: duration, repeats: false) { [weak self] _ in Task { @MainActor in self?.stop() } }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    func expire(at now: Date) { if let end = endsAt, now >= end { stop() } }
    func stop() { timer?.invalidate(); timer = nil; assertions.forEach(backend.release); assertions = []; endsAt = nil; keepsDisplayAwake = false }
    deinit { timer?.invalidate(); assertions.forEach(backend.release) }
}
