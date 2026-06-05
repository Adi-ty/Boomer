import Testing
@testable import Boomer

struct PetStateMachineTests {
    private let sut = PetStateMachine()

    @Test func celebrateOnDownloadComplete() {
        let next = sut.next(for: .downloadCompleted(fileName: "movie.zip"), current: .idle, needs: Needs())
        #expect(next == .celebrating)
    }

    @Test func celebrateOnCodingAgentComplete() {
        let next = sut.next(for: .codingAgentCompleted(agent: "claude-code"), current: .idle, needs: Needs())
        #expect(next == .celebrating)
    }

    @Test func sleepWhenUserIdle() {
        #expect(sut.next(for: .userIdle, current: .idle, needs: Needs()) == .sleeping)
    }

    @Test func wakeWhenUserActive() {
        #expect(sut.next(for: .userActive, current: .sleeping, needs: Needs()) == .idle)
    }

    @Test func draggingIsSticky() {
        #expect(sut.transition(from: .dragging, to: .sleeping) == .dragging)
        #expect(sut.transition(from: .dragging, to: .falling) == .falling)
    }
}

struct NeedsTests {
    @Test func decayReducesEveryNeed() {
        var needs = Needs()
        let (h0, p0, e0) = (needs.hunger, needs.happiness, needs.energy)
        needs.decay()
        #expect(needs.hunger < h0)
        #expect(needs.happiness < p0)
        #expect(needs.energy < e0)
    }

    @Test func feedRaisesHungerAndClampsAtOne() {
        var needs = Needs(hunger: 0.9, happiness: 0.5, energy: 0.5)
        needs.feed()
        #expect(needs.hunger == 1.0)
    }

    @Test func lowEnergyMakesPetSleepy() {
        let needs = Needs(hunger: 0.8, happiness: 0.8, energy: 0.1)
        #expect(needs.mood == .sleepy)
    }
}
