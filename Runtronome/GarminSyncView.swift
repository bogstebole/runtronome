import SwiftUI

/// Garmin Connect sync screen, hosted by the plans flow. Signs in with the
/// user's own Garmin credentials (tokens go to the Keychain), lists every
/// scheduled workout in the coming weeks, and hands the chosen one up for
/// per-phase SPM assignment.
struct GarminSyncView: View {
    var onBack: () -> Void
    /// Called with the freshly imported plans (the new ones only).
    var onImported: ([WorkoutPlan]) -> Void

    private enum Phase {
        case credentials
        case mfa(GarminMFAContext)
        case working(String)
        case review([GarminScheduledWorkout])
        case failed(String)
    }

    @State private var phase: Phase = .credentials
    @State private var email = ""
    @State private var password = ""
    @State private var mfaCode = ""
    /// Garmin ids already in the library, snapshotted when the review list
    /// loads so each row shows a stable NEW / SYNCED badge.
    @State private var alreadyImported: Set<Int64> = []
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, mfa }

    private static let rowDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 18)
                .padding(.horizontal, 24)

            content
                .padding(.horizontal, 24)
                .padding(.top, isReview ? 8 : 32)
                .frame(maxHeight: isReview ? .infinity : nil, alignment: .top)

            if !isReview { Spacer() }

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .onAppear {
            // Already signed in from a previous session → skip straight to the list.
            if GarminSession.isLoggedIn { fetchUpcoming() }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            MastheadRule()

            HStack(alignment: .center) {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("PLANS")
                            .font(.appSans(size: 11, weight: .bold))
                            .tracking(1.5)
                    }
                    .foregroundColor(Theme.textSecondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                if GarminSession.isLoggedIn {
                    Button {
                        GarminSession.logout()
                        phase = .credentials
                    } label: {
                        MetaLabel(text: "SIGN OUT", color: Theme.textTertiary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)

            Text("GARMIN SYNC")
                .font(.anton(size: 30))
                .foregroundColor(Theme.textPrimary)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                MetaLabel(text: subtitle)
                Spacer()
                if case .review(let workouts) = phase {
                    let newCount = workouts.filter { !alreadyImported.contains($0.id) }.count
                    MetaLabel(text: "\(newCount) NEW · \(workouts.count) TOTAL", color: Theme.textTertiary)
                }
            }
            .padding(.bottom, 14)

            Hairline()
        }
    }

    private var isReview: Bool {
        if case .review = phase { return true }
        return false
    }

    private var subtitle: String {
        switch phase {
        case .review: return "REVIEW & IMPORT"
        case .mfa:    return "VERIFY IT'S YOU"
        default:      return "PULL YOUR PLANNED WORKOUTS"
        }
    }

    // MARK: Content (state-driven)

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .credentials:
            VStack(spacing: 28) {
                field("EMAIL", text: $email, focus: .email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                secureField("PASSWORD", text: $password, focus: .password)
                Text("Your credentials go only to Garmin — the app keeps just the sign-in token, stored in the Keychain.")
                    .font(.appSans(size: 12, weight: .regular))
                    .foregroundColor(Theme.textTertiary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .mfa:
            VStack(spacing: 28) {
                field("MFA CODE", text: $mfaCode, focus: .mfa)
                    .keyboardType(.numberPad)
                Text("Garmin sent a verification code to your email or authenticator app.")
                    .font(.appSans(size: 12, weight: .regular))
                    .foregroundColor(Theme.textTertiary)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .working(let message):
            VStack(spacing: 18) {
                SyncSpinner(color: Theme.textPrimary, size: 34)
                MetaLabel(text: message, color: Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)

        case .review(let workouts):
            workoutList(workouts)

        case .failed(let message):
            VStack(spacing: 14) {
                Text("COULDN'T SYNC")
                    .font(.appSans(size: 14, weight: .medium))
                    .tracking(1.2)
                    .foregroundColor(Theme.textPrimary)
                Text(message)
                    .font(.appSans(size: 13, weight: .regular))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        }
    }

    // MARK: Fields (Swiss underline style)

    private func field(_ label: String, text: Binding<String>, focus: Field) -> some View {
        fieldRow(label, focus: focus) {
            TextField("", text: text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: focus)
        }
    }

    private func secureField(_ label: String, text: Binding<String>, focus: Field) -> some View {
        fieldRow(label, focus: focus) {
            SecureField("", text: text)
                .textContentType(.password)
                .focused($focusedField, equals: focus)
        }
    }

    /// Shared field chrome: label, the input (given a comfortable tap height),
    /// and an underline. The whole row is the tap target — a bare TextField is
    /// only one text-line tall and easy to miss.
    private func fieldRow(_ label: String, focus: Field, @ViewBuilder input: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(text: label, color: Theme.textTertiary)
            input()
                .font(.appSans(size: 17, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .tint(Theme.textPrimary)
                .frame(height: 28)
            Rectangle()
                .fill(focusedField == focus ? Theme.textPrimary : Theme.stroke)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = focus }
    }

    // MARK: Footer (call to action)

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .credentials:
            Button("SIGN IN & SYNC") { signIn() }
                .buttonStyle(.app(.primary))
                .opacity(email.isEmpty || password.isEmpty ? 0.4 : 1)
                .disabled(email.isEmpty || password.isEmpty)

        case .mfa:
            Button("CONFIRM CODE") { confirmMFA() }
                .buttonStyle(.app(.primary))
                .opacity(mfaCode.isEmpty ? 0.4 : 1)
                .disabled(mfaCode.isEmpty)

        case .working:
            EmptyView()

        case .review(let workouts):
            let newWorkouts = workouts.filter { !alreadyImported.contains($0.id) }
            Button(newWorkouts.isEmpty ? "ALL SYNCED" : "IMPORT \(newWorkouts.count) NEW") {
                importAll(newWorkouts)
            }
            .buttonStyle(.app(.primary))
            .opacity(newWorkouts.isEmpty ? 0.4 : 1)
            .disabled(newWorkouts.isEmpty)

        case .failed:
            Button("TRY AGAIN") {
                if GarminSession.isLoggedIn { fetchUpcoming() } else { phase = .credentials }
            }
            .buttonStyle(.app(.primary))
        }
    }

    // MARK: Review list (new vs already-synced)

    private func workoutList(_ workouts: [GarminScheduledWorkout]) -> some View {
        Group {
            if workouts.isEmpty {
                VStack(spacing: 10) {
                    Text("NOTHING SCHEDULED")
                        .font(.appSans(size: 14, weight: .medium))
                        .tracking(1.2)
                        .foregroundColor(Theme.textPrimary)
                    Text("No planned workouts on your Garmin calendar in the coming weeks.")
                        .font(.appSans(size: 12, weight: .regular))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(workouts) { workout in
                            workoutRow(workout, isNew: !alreadyImported.contains(workout.id))
                        }
                    }
                }
            }
        }
    }

    private func workoutRow(_ workout: GarminScheduledWorkout, isNew: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text(Self.rowDateFormatter.string(from: workout.date).uppercased())
                    .font(.appSans(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(isToday(workout.date) ? Theme.textPrimary : Theme.textTertiary)
                    .frame(width: 92, alignment: .leading)

                Text(workout.title)
                    .font(.appSans(size: 15, weight: .medium))
                    .foregroundColor(isNew ? Theme.textPrimary : Theme.textTertiary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                statusBadge(isNew ? "NEW" : "SYNCED", filled: isNew)
            }
            .padding(.vertical, 16)
            .opacity(isNew ? 1 : 0.6)

            Hairline()
        }
    }

    /// Small caps chip: filled white for NEW, hairline-outlined for SYNCED.
    private func statusBadge(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(.appSans(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundColor(filled ? Theme.ctaLabel : Theme.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                filled
                    ? AnyView(Rectangle().fill(Theme.ctaFill))
                    : AnyView(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
            )
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    // MARK: Actions

    private func signIn() {
        focusedField = nil
        phase = .working("SIGNING IN…")
        Task {
            do {
                switch try await GarminLogin.login(email: email, password: password) {
                case .success:
                    fetchUpcoming()
                case .mfaRequired(let context):
                    phase = .mfa(context)
                }
            } catch {
                phase = .failed(readable(error))
            }
        }
    }

    private func confirmMFA() {
        guard case .mfa(let context) = phase else { return }
        focusedField = nil
        phase = .working("CONFIRMING…")
        Task {
            do {
                try await GarminLogin.submitMFA(code: mfaCode, context: context)
                fetchUpcoming()
            } catch {
                phase = .failed(readable(error))
            }
        }
    }

    /// Load the calendar and snapshot which workouts are already in the library
    /// so the review list can tag each NEW or SYNCED.
    private func fetchUpcoming() {
        phase = .working("READING YOUR CALENDAR…")
        Task {
            do {
                let workouts = try await GarminConnectFetcher().fetchUpcoming()
                alreadyImported = PlanStore.garminWorkoutIds()
                phase = .review(workouts)
            } catch {
                phase = .failed(readable(error))
            }
        }
    }

    /// Pull the full structure of every new workout and hand them all up to be
    /// saved into the library. Already-synced workouts are left untouched.
    private func importAll(_ workouts: [GarminScheduledWorkout]) {
        guard !workouts.isEmpty else { onImported([]); return }
        Task {
            let fetcher = GarminConnectFetcher()
            var imported: [WorkoutPlan] = []
            for (index, workout) in workouts.enumerated() {
                phase = .working("IMPORTING \(index + 1)/\(workouts.count)…")
                do {
                    imported.append(try await fetcher.fetchWorkout(workout))
                } catch {
                    phase = .failed(readable(error))
                    return
                }
            }
            onImported(imported)
        }
    }

    private func readable(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Something went wrong. Try again."
    }
}
