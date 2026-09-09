import SwiftUI

/// FR-P2: the rows of the sign-in section, token or password, and the authenticator step.
struct LoginFormView: View {
    static let tokenPageURL: URL = {
        guard let url = URL(string: "https://app.timebutler.com/do?ha=personaltoken&ac=6") else {
            preconditionFailure("Token page URL literal is not a valid URL")
        }
        return url
    }()

    @Bindable var model: LoginFormModel

    var body: some View {
        if model.awaitingCode {
            codeRows
        } else {
            Picker("Anmelden mit", selection: $model.method) {
                ForEach(LoginMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            .pickerStyle(.segmented)
            switch model.method {
            case .apiToken:
                tokenRows
            case .password:
                passwordRows
            }
        }
        if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var tokenRows: some View {
        SecureField("API-Token", text: $model.apiToken, prompt: Text("tb_…"))
            .onSubmit(submit)
        Link(destination: Self.tokenPageURL) {
            Label("Token-Seite in Timebutler öffnen", systemImage: "safari")
        }
        submitRow(title: "Verbinden", symbol: "link")
    }

    @ViewBuilder
    private var passwordRows: some View {
        TextField("E-Mail", text: $model.email)
            .textContentType(.username)
            .onSubmit(submit)
        SecureField("Passwort", text: $model.password)
            .onSubmit(submit)
        submitRow(title: "Anmelden", symbol: "person.badge.key")
    }

    @ViewBuilder
    private var codeRows: some View {
        TextField("Code aus der Authenticator-App", text: $model.totpCode, prompt: Text("123456"))
            .textContentType(.oneTimeCode)
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

    private func submitRow(title: String, symbol: String) -> some View {
        HStack {
            Button(action: submit) {
                Label(title, systemImage: symbol)
            }
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
