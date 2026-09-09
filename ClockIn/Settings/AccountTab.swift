import SwiftUI

/// FR-P3: who is signed in and how, or the sign-in form.
struct AccountTab: View {
    let store: ClockStore
    @State private var form: LoginFormModel

    init(store: ClockStore) {
        self.store = store
        _form = State(initialValue: LoginFormModel(store: store))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch store.session {
            case .active(let kind):
                signedIn(kind: kind)
            case .expired:
                Text("Sitzung abgelaufen.")
                    .foregroundStyle(.red)
                LoginFormView(model: form)
            case .notConfigured:
                LoginFormView(model: form)
            }
            Spacer()
        }
        .padding(20)
    }

    private func signedIn(kind: CredentialKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let profile = store.profile {
                Text(profile.name)
                    .font(.headline)
                if let department = profile.department {
                    Text(department)
                }
                Text(profile.email)
                    .foregroundStyle(.secondary)
            } else {
                Text("Profil nicht geladen")
                    .foregroundStyle(.secondary)
            }
            Text("Anmeldung: \(Self.label(for: kind))")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button("Abmelden") {
                    Task {
                        await store.signOut()
                    }
                }
                .disabled(store.isAuthenticating)
                if store.isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            if let error = store.authError {
                Text(error)
                    .font(.footnote)
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
