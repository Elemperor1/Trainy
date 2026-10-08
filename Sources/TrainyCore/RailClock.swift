import Foundation

/// The single place Trainy reads the wall clock.
///
/// Anything that depends on "now" (trip status, freshness, relative update
/// text) takes a `RailClock` at its edge, such as a store or provider
/// initializer, and hands the resulting `Date` to pure functions. Production
/// code uses `.system`; tests pin time with `.fixed(_:)` or build a clock
/// around a reader they can advance.
struct RailClock: Sendable {
    private let read: @Sendable () -> Date

    init(_ read: @escaping @Sendable () -> Date) {
        self.read = read
    }

    /// The current instant according to this clock.
    var now: Date {
        read()
    }

    /// The real wall clock.
    static let system = RailClock { Date() }

    /// A clock that always reports `date`.
    static func fixed(_ date: Date) -> RailClock {
        RailClock { date }
    }
}
