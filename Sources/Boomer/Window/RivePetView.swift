import SwiftUI

/// The pet's on-screen body.
///
/// Phase 0 ships SF Symbol placeholder art so the behavior engine isn't blocked
/// on `.riv` assets. Phase 1 replaces the body with a `RiveViewModel`-backed view
/// whose state-machine inputs are driven by `PetEngine.state`.
struct RivePetView: View {
    let engine: PetEngine

    var body: some View {
        Image(systemName: engine.pet.species.placeholderSymbol)
            .font(.system(size: 96))
            .foregroundStyle(.orange.gradient)
            .symbolEffect(.bounce, value: engine.state)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.circle)
            .help("\(engine.pet.name) — \(engine.mood.description)")
    }
}
