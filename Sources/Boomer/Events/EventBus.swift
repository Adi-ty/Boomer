import Foundation

/// A single async stream that monitors publish to and `PetEngine` consumes.
/// Monitors run off the main actor; the engine drains `events` on the main actor.
final class EventBus: Sendable {
    let events: AsyncStream<PetEvent>
    private let continuation: AsyncStream<PetEvent>.Continuation

    init() {
        (events, continuation) = AsyncStream.makeStream(
            of: PetEvent.self,
            bufferingPolicy: .bufferingNewest(32)
        )
    }

    func publish(_ event: PetEvent) {
        continuation.yield(event)
    }
}
