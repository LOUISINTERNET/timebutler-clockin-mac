import SwiftUI

/// FR-P3: who is signed in and how, or the sign-in form (FR-P2).
struct AccountTab: View {
    let store: ClockStore
    @State private var form: LoginFormModel

    init(store: ClockStore) {
        self.store = store
        _form = State(initialValue: LoginFormModel(store: store))
    }

    var body: some View {
        Form {
            switch store.session {
            case .active(let kind):
                signedIn(kind: kind)
            case .expired:
                Section {
                    Label("Sitzung abgelaufen. Bitte neu anmelden.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                loginSection
            case .notConfigured:
                loginSection
            }
        }
        .formStyle(.grouped)
    }

    private var loginSection: some View {
        Section {
            LoginFormView(model: form)
        } header: {
            Text("Anmeldung")
        } footer: {
            Text("Persönliche Tokens legst du in Timebutler unter Einstellungen › Dein Konto › API-Token an.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .disabled(store.isAuthenticating)
    }

    @ViewBuilder
    private func signedIn(kind: CredentialKind) -> some View {
        Section {
            if let profile = store.profile {
                SettingsRow(symbol: "person.crop.circle.fill", title: profile.name, subtitle: profile.department ?? "Keine Abteilung hinterlegt")
                SettingsRow(symbol: "envelope", title: profile.email, subtitle: "E-Mail")
            } else {
                SettingsRow(symbol: "person.crop.circle.badge.questionmark", title: "Profil nicht geladen", subtitle: "Die Stempeluhr funktioniert trotzdem.")
            }
            SettingsRow(symbol: "key.fill", title: Self.label(for: kind), subtitle: "Anmeldung")
        } header: {
            Text("Konto")
        }
        Section {
            HStack {
                Button {
                    Task {
                        await store.signOut()
                    }
                } label: {
                    Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .disabled(store.isAuthenticating)
                if store.isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if let error = store.authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private static func label(for kind: CredentialKind) -> String {
        switch kind {
        case .apiToken: LoginMethod.apiToken.title
        case .oauth: LoginMethod.password.title
        }
    }
}
