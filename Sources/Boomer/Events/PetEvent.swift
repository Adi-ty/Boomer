import Foundation

/// Things that happen in the world that the pet can react to. Monitors publish
/// these onto the `EventBus`; `PetEngine` consumes them.
enum PetEvent: Sendable, Equatable {
    case downloadCompleted(fileName: String)
    case installCompleted(appName: String)
    case codingAgentCompleted(agent: String)
    case typingStarted
    case typingStopped
    case userIdle
    case userActive
}
