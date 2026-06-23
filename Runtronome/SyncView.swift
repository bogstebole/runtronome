import SwiftUI

/// View 1 — fetch today's structured workout from the chosen source and present
/// it as a tappable card. Owns only its own loading/error state; the fetched
/// plan is handed up to the flow coordinator via `onContinue`.
struct SyncView: View {
    let fetcher: WorkoutFetcherService
    var onContinue: (WorkoutPlan) -> Void

    private enum Phase: Equatable {
        case idle
        case loading
        case loaded(WorkoutPlan)
        case failed(String)
    }

    @State private var phase: Phase = .idle

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 72)
                .padding(.horizontal, 24)

            Spacer()

            content
                .padding(.horizontal, 24)

            Spacer()

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("WORKOUT SYNC")
                .font(.momoTrust(size: 11, weight: .regular))
                .foregroundColor(Theme.textTertiary)
            Text("Pull today's plan")
                .font(.momoTrust(size: 24, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        }
    }

    // MARK: Content (state-driven)

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .idle:
            statusBlock(
                icon: "arrow.triangle.2.circlepath",
                title: "Not synced yet",
                subtitle: "Fetch your structured workout to assign a cadence to each phase."
            )

        case .loading:
            VStack(spacing: 18) {
                SyncSpinner(color: Theme.textPrimary, size: 34)
                Text("FETCHING WORKOUT…")
                    .font(.momoTrust(size: 11, weight: .regular))
                    .foregroundColor(Theme.textTertiary)
            }
            .transition(.opacity)

        case .loaded(let plan):
            WorkoutPlanCard(plan: plan) { onContinue(plan) }
                .transition(.move(edge: .bottom).combined(with: .opacity))

        case .failed(let message):
            statusBlock(
                icon: "exclamationmark.triangle",
                title: "Couldn't sync",
                subtitle: message
            )
        }
    }

    private func statusBlock(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundColor(Theme.textSecondary)
            Text(title)
                .font(.momoTrust(size: 17, weight: .medium))
                .foregroundColor(Theme.textPrimary)
            Text(subtitle)
                .font(.momoTrust(size: 13, weight: .regular))
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Footer (call to action)

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .loaded:
            // Quietly allow a re-sync once a plan is shown.
            Button(action: sync) {
                Text("SYNC AGAIN")
                    .font(.momoTrust(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(PressableButtonStyle())

        default:
            Button(action: sync) {
                RuntronomeButton(style: .primary(
                    text: isFailed ? "TRY AGAIN" : "SYNC WITH GARMIN / HEALTH",
                    systemImage: "arrow.down.circle",
                    loading: phase == .loading
                ))
            }
            .buttonStyle(PressableButtonStyle())
            .disabled(phase == .loading)
        }
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    // MARK: Sync

    private func sync() {
        Task {
            withAnimation(.easeInOut(duration: 0.2)) { phase = .loading }
            do {
                let plan = try await fetcher.fetchTodaysWorkout()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .loaded(plan) }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Try again."
                withAnimation(.easeInOut(duration: 0.2)) { phase = .failed(message) }
            }
        }
    }
}
