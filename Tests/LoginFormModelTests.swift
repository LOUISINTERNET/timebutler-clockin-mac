import Foundation
import Testing

@MainActor
struct LoginFormModelTests {
    private let email = "user@example.com"

    @Test func tokenFormNeedsANonEmptyToken() throws {
        let harness = try TestStore(credentials: nil)
        let model = LoginFormModel(store: harness.store)
        #expect(model.method == .apiToken)
        #expect(!model.canSubmit)
        model.apiToken = "  \n"
        #expect(!model.canSubmit)
        model.apiToken = "tb_x"
        #expect(model.canSubmit)
    }

    @Test func passwordFormNeedsEmailAndPassword() throws {
        let harness = try TestStore(credentials: nil)
        let model = LoginFormModel(store: harness.store)
        model.method = .password
        model.email = email
        #expect(!model.canSubmit)
        model.password = "s3cr3t"
        #expect(model.canSubmit)
        model.email = " "
        #expect(!model.canSubmit)
    }

    @Test func passwordIsClearedAfterSubmitAndErrorShown() async throws {
        let harness = try TestStore(credentials: nil, routes: ["oauth2/token": [.fixture(400, "oauth-error")]])
        let model = LoginFormModel(store: harness.store)
        model.method = .password
        model.email = email
        model.password = "wrong"
        await model.submit()
        #expect(model.password == "")
        #expect(model.email == email)
        #expect(model.errorMessage == "E-Mail-Adresse oder Passwort ist falsch.")
        #expect(!model.isBusy)
        #expect(!harness.store.isBusy)
    }

    @Test func codeStepNeedsSixDigitsAndCompletesSignIn() async throws {
        var routes = TestStore.running
        routes["oauth2/token"] = [.fixture(200, "oauth-mfa"), .fixture(200, "oauth-token")]
        let harness = try TestStore(credentials: nil, routes: routes)
        await harness.store.start()
        defer { harness.store.stopObserving() }
        let model = LoginFormModel(store: harness.store)
        model.method = .password
        model.email = email
        model.password = "s3cr3t"
        await model.submit()
        #expect(model.awaitingCode)
        model.totpCode = "12345"
        #expect(!model.canSubmit)
        model.totpCode = "12345a"
        #expect(!model.canSubmit)
        model.totpCode = "123456"
        #expect(model.canSubmit)
        await model.submit()
        #expect(model.totpCode == "")
        #expect(!model.awaitingCode)
        #expect(harness.store.session == .active(.oauth(email: email)))
    }

    @Test func cancellingTheCodeStepReturnsToThePasswordForm() async throws {
        let harness = try TestStore(credentials: nil, routes: ["oauth2/token": [.fixture(200, "oauth-mfa")]])
        let model = LoginFormModel(store: harness.store)
        model.method = .password
        model.email = email
        model.password = "s3cr3t"
        await model.submit()
        #expect(model.awaitingCode)
        model.totpCode = "123"
        model.cancelCode()
        #expect(!model.awaitingCode)
        #expect(model.totpCode == "")
        #expect(model.errorMessage == nil)
    }

    @Test func rejectedTokenKeepsSessionAndToken() async throws {
        var routes = TestStore.running
        routes["user/profile"] = [.fixture(200, "profile"), .raw(401, Data())]
        let harness = try TestStore(credentials: .apiToken("tb_old"), routes: routes)
        await harness.store.start()
        defer { harness.store.stopObserving() }
        let model = LoginFormModel(store: harness.store)
        model.apiToken = "tb_new"
        await model.submit()
        #expect(model.errorMessage == ClockStore.rejectedTokenMessage)
        #expect(model.apiToken == "tb_new")
        #expect(harness.store.session == .active(.apiToken))
        #expect(harness.credentialStore.stored == .apiToken("tb_old"))
    }

    @Test func acceptedTokenClearsTheField() async throws {
        let harness = try TestStore(credentials: nil, routes: TestStore.running)
        await harness.store.start()
        defer { harness.store.stopObserving() }
        let model = LoginFormModel(store: harness.store)
        model.apiToken = "tb_new"
        await model.submit()
        #expect(model.apiToken == "")
        #expect(model.errorMessage == nil)
        #expect(harness.store.session == .active(.apiToken))
    }
}
