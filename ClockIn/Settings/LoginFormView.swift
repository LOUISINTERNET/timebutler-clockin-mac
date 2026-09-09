import SwiftUI

/// FR-P2: token or password sign-in, and the authenticator code step.
struct LoginFormView: View {
    static let tokenPageURL: URL = {
        guard let url = URL(string: "https://app.timebutler.com/do?ha=personaltoken&ac=6") else {
            preconditionFailure("Token page URL literal is not a valid URL")
        }
        return url
    }()

    @Bindable var model: LoginFormModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.awaitingCode {
                codeStep
            } else {
                Picker("Anmeldung", selection: $model.method) {
                    ForEach(LoginMethod.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                switch model.method {
                case .apiToken:
                    tokenStep
                case .password:
                    passwordStep
                }
            }
            if let error = model.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .disabled(model.isBusy)
    }

    private var tokenStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            SecureField("tb_…", text: $model.apiToken)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            Text("Persönliche Tokens legst du in Timebutler unter Einstellungen › Dein Konto › API-Token an.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Link("Token-Seite in Timebutler öffnen", destination: Self.tokenPageURL)
                .font(.footnote)
            submitRow(title: "Verbinden")
        }
    }

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("E-Mail", text: $model.email)
                .textContentType(.username)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            SecureField("Passwort", text: $model.password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            submitRow(title: "Anmelden")
        }
    }

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Code aus der Authenticator-App")
            TextField("123456", text: $model.totpCode)
                .textContentType(.oneTimeCode)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .onSubmit(submit)
            HStack {
                Button("Bestätigen", action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canSubmit)
                Button("Abbrechen") {
                    model.cancelCode()
                }
                if model.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
    }

    private func submitRow(title: String) -> some View {
        HStack {
            Button(title, action: submit)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canSubmit)
            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private func submit() {
        Task {
            await model.submit()
        }
    }
}
