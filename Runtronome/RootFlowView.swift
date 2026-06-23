import SwiftUI

/// App entry point and flow coordinator: Sync → Phase Editor → Metronome.
///
/// Owns the in-progress plan and the chosen metronome configuration, and drives
/// navigation with a small step enum + custom transitions (no `NavigationStack`,
/// to keep the app free of default nav-bar chrome). Swapping the data source is
/// a single line below — everything downstream talks to `WorkoutFetcherService`.
struct RootFlowView: View {
    private enum Step {
        case sync, editor, metronome

        var order: Int {
            switch self {
            case .sync:      return 0
            case .editor:    return 1
            case .metronome: return 2
            }
        }
    }

    /// MVP source. Swap for `HealthKitWorkoutFetcher()` once HealthKit is enabled.
    private let fetcher: WorkoutFetcherService = MockWorkoutFetcher()

    @State private var step: Step = .sync
    @State private var plan: WorkoutPlan?
    @State private var configuration: MetronomeConfiguration?
    @State private var goingForward = true

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .sync:
            SyncView(fetcher: fetcher) { fetched in
                plan = fetched
                advance(to: .editor)
            }
            .transition(pushTransition)

        case .editor:
            // `Binding($plan)` unwraps the optional so the editor mutates in place.
            if let planBinding = Binding($plan) {
                PhaseEditorView(
                    plan: planBinding,
                    onBack: { advance(to: .sync) },
                    onSaveStart: { configured in
                        configuration = MetronomeConfiguration(plan: configured)
                        advance(to: .metronome)
                    }
                )
                .transition(pushTransition)
            }

        case .metronome:
            ContentView(configuration: configuration ?? .default)
                .transition(pushTransition)
        }
    }

    // MARK: Navigation

    private func advance(to next: Step) {
        goingForward = next.order >= step.order
        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
            step = next
        }
    }

    /// Direction-aware horizontal push/pop.
    private var pushTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: goingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: goingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }
}
