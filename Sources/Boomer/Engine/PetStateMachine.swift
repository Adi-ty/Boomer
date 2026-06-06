import Foundation

/// High-level pet states. Each maps to inputs on the Rive state machine (Phase 1).
/// Keep this enum in sync with the inputs exposed by the `.riv` files.
enum PetState: String, Equatable {
    case idle
    case walking
    case sleeping
    case dragging
    case falling
    case celebrating
    case typing
    case eating
    case playing
    case thinking
}

/// Owns the *logic* of state transitions. Rive owns the *visuals*. This type is a
/// pure value with no side effects, which makes it cheap to unit-test.
struct PetStateMachine {
    /// Decide the next state in response to an external event.
    func next(for event: PetEvent, current: PetState, needs _: Needs) -> PetState {
        switch event {
        case .downloadCompleted, .installCompleted, .codingAgentCompleted:
            .celebrating
        case .typingStarted:
            .typing
        case .typingStopped:
            current == .typing ? .idle : current
        case .userIdle:
            .sleeping
        case .userActive:
            current == .sleeping ? .idle : current
        }
    }

    /// Validate/normalize a requested transition. Some states are "sticky":
    /// e.g. you can't fall asleep while being dragged.
    func transition(from current: PetState, to requested: PetState) -> PetState {
        if current == .dragging, requested != .falling, requested != .idle {
            return .dragging
        }
        return requested
    }
}
