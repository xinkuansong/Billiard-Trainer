import Foundation

/// Pauses accumulate within a visit; only a real background/exit finishes a row.
struct ActiveVisitClock {
    struct Segment: Equatable { var start: Date; var seconds: TimeInterval }
    private(set) var start: Date?
    private var runningSince: Date?
    private var accumulated: TimeInterval = 0

    mutating func resume(at date: Date) {
        guard runningSince == nil else { return }
        if start == nil { start = date }
        runningSince = date
    }
    mutating func pause(at date: Date) {
        guard let runningSince else { return }
        accumulated += max(0, date.timeIntervalSince(runningSince))
        self.runningSince = nil
    }
    mutating func finish(at date: Date) -> Segment? {
        pause(at: date)
        guard let start else { return nil }
        let segment = Segment(start: start, seconds: accumulated)
        self = ActiveVisitClock()
        return segment
    }
}
