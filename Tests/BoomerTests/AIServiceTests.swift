import Testing
@testable import Boomer

@MainActor
struct AIServiceTests {
    @Test func personalityStaysInCharacter() {
        let dog = AIService.personality(for: .boomer)
        #expect(dog.contains("Boomer"))
        #expect(dog.contains("golden retriever"))
        #expect(dog.contains("scheduleReminder"))

        let cat = AIService.personality(for: .buttons)
        #expect(cat.contains("Buttons"))
        #expect(cat.contains("cat"))
    }

    @Test func promptClippingLimitsLength() {
        let long = String(repeating: "a", count: 10000)
        #expect(AIService.clipForPrompt(long).count <= 6001)
        #expect(AIService.clipForPrompt("short") == "short")
    }

    @Test func thinkingStateTogglesWithGeneration() {
        let engine = PetEngine.preview(species: .dog)
        engine.beginThinking()
        #expect(engine.state == .thinking)
        engine.endThinking()
        #expect(engine.state == .idle)
    }
}
