
// Isolated experiment only. Every arm has the same measurement overhead.
final class TopDownCandidateMetrics: NSObject {
    static let shared = TopDownCandidateMetrics()
    static let mode = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-topDown.candidate=") })?.components(separatedBy: "=").last ?? "baseline"
    static var reuse: Bool { mode != "baseline" }
    let lock = NSLock()
    private let started = CACurrentMediaTime()
    private var rows: [[String: Any]] = []
    private var mainFrames = 0, overlayFrames = 0
    private var timer: Timer?
    private weak var label: UILabel?
    private weak var trackedOverlay: SCNView?
    private let session = UUID().uuidString
    private var phase = "entry"

    func event(_ name: String, _ fields: [String: Any] = [:]) {
        lock.lock(); defer { lock.unlock() }
        var row = fields; row["event"] = name; row["t"] = CACurrentMediaTime() - started
        rows.append(row)
    }
    func setPhase(_ value: String) { lock.lock(); phase = value; lock.unlock(); event(value) }
    @MainActor func track(_ overlay: SCNView) { trackedOverlay = overlay }
    func frame(overlay: Bool) {
        lock.lock()
        if overlay { overlayFrames += 1 } else { mainFrames += 1 }
        let first = !overlay && mainFrames == 1
        lock.unlock()
        if first { event("firstMainFrame") }
    }
    @MainActor func install(on view: UIView) {
        guard TemporaryTopDownLatencyProbe.enabled, label == nil else { return }
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        label.isAccessibilityElement = true
        label.accessibilityIdentifier = "topDown.candidateMetrics"
        label.accessibilityLabel = "topDown.candidateMetrics"
        label.textColor = .clear
        view.addSubview(label); self.label = label
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
    }
    @MainActor func uninstall() {
        event("hostDismantled"); setPhase("exited")
    }
    @MainActor private func sample() {
        // table.scene is one AX element, so a diagnostic child is not queryable.
        if let label, let window = label.window, label.superview !== window {
            window.addSubview(label)
        }
        var usage = rusage(); let usageResult = getrusage(RUSAGE_SELF, &usage)
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let cpu = Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
            + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
        lock.lock()
        rows.append(["event": "sample", "t": CACurrentMediaTime() - started, "phase": phase,
            "cpu": cpu, "rusageStatus": usageResult, "vmStatus": result,
            "footprint": info.phys_footprint, "resident": info.resident_size,
            "mainFrames": mainFrames, "overlayFrames": overlayFrames,
            "overlayAlive": trackedOverlay != nil])
        let output: [String: Any] = ["mode": Self.mode, "rows": rows]
        lock.unlock()
        do {
            let data = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
            label?.accessibilityValue = String(decoding: data, as: UTF8.self)
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Candidate-\(session).json")
            try data.write(to: url, options: .atomic)
        } catch { assertionFailure("Candidate metrics export: \(error)") }
    }
}
