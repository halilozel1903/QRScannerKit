import Foundation

/// Drops a code that was already accepted a moment ago.
///
/// A camera sees the same code many times per second. The filter accepts it once and then ignores
/// the same string and symbology for `interval` seconds after it was last accepted.
///
/// ```swift
/// var filter = DuplicateFilter(interval: 2)
/// filter.accept("https://example.com", symbology: .qr, at: now)        // true
/// filter.accept("https://example.com", symbology: .qr, at: now + 1)    // false
/// filter.accept("https://example.com", symbology: .qr, at: now + 2.5)  // true
/// ```
public struct DuplicateFilter: Sendable {
    /// Seconds during which the same code is ignored. `0` accepts everything.
    public var interval: TimeInterval

    private var lastAccepted: [Key: Date] = [:]

    private struct Key: Hashable, Sendable {
        let string: String
        let symbology: Symbology
    }

    public init(interval: TimeInterval = 2) {
        self.interval = max(0, interval)
    }

    /// Returns `true` and remembers the code when it should be delivered, `false` for a
    /// duplicate.
    public mutating func accept(_ string: String, symbology: Symbology, at date: Date = Date()) -> Bool {
        let key = Key(string: string, symbology: symbology)
        if let last = lastAccepted[key], date.timeIntervalSince(last) < interval, date >= last {
            return false
        }
        lastAccepted[key] = date
        prune(before: date)
        return true
    }

    /// Returns whether `accept` would deliver the code, without remembering it.
    public func wouldAccept(_ string: String, symbology: Symbology, at date: Date = Date()) -> Bool {
        guard let last = lastAccepted[Key(string: string, symbology: symbology)] else { return true }
        return date.timeIntervalSince(last) >= interval || date < last
    }

    /// Forgets every code, so the next one is accepted.
    public mutating func reset() {
        lastAccepted.removeAll()
    }

    /// The number of codes remembered right now.
    public var count: Int { lastAccepted.count }

    private mutating func prune(before date: Date) {
        guard lastAccepted.count > 32 else { return }
        lastAccepted = lastAccepted.filter { date.timeIntervalSince($0.value) < interval }
    }
}
