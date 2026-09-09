import Foundation
import Testing

struct TimebutlerAPITests {
    private func makeAPI(_ replies: [FixtureTransport.Reply], provider: FakeTokenProvider = FakeTokenProvider(token: "tb_test")) -> (TimebutlerAPI, FixtureTransport) {
        let transport = FixtureTransport(replies)
        return (TimebutlerAPI(transport: transport, tokenProvider: provider), transport)
    }

    @Test func statusSendsBearerGetAndDecodes() async throws {
        let (api, transport) = makeAPI([.fixture(200, "status-running")])
        let status = try await api.status()
        #expect(status.status == .running)
        let request = try #require(await transport.requests.first)
        #expect(request.method == "GET")
        #expect(request.url.absoluteString == "https://app.timebutler.com/api/v2/time-clock/status")
        #expect(request.headers["Authorization"] == "Bearer tb_test")
        #expect(request.headers["Accept"] == "application/json")
        #expect(request.body == nil)
    }

    @Test func summaryAndProfileDecode() async throws {
        let (api, _) = makeAPI([.fixture(200, "work-summary"), .fixture(200, "profile")])
        #expect(try await api.workSummary().commitmentMinutes == 480)
        #expect(try await api.profile().name == "Maria Müller")
    }

    @Test func performPostsToActionPath() async throws {
        let (api, transport) = makeAPI([.fixture(200, "status-running")])
        _ = try await api.perform(.start)
        let request = try #require(await transport.requests.first)
        #expect(request.method == "POST")
        #expect(request.url.path() == "/api/v2/time-clock/start")
    }

    @Test func stopEncodesStandardBodyAndDecodesOutcomes() async throws {
        let (api, transport) = makeAPI([.fixture(200, "stop-saved"), .fixture(200, "stop-confirmation"), .raw(204, Data())])
        let saved = try await api.stop(.standard())
        guard case .saved(let entry) = saved else {
            Issue.record("expected saved, got \(saved)")
            return
        }
        #expect(entry.workedMinutes == 450)
        let confirmation = try await api.stop(.standard(decision: .apply))
        guard case .confirmationRequired = confirmation else {
            Issue.record("expected confirmationRequired, got \(confirmation)")
            return
        }
        #expect(try await api.stop(.standard(decision: .ignore)) == .discarded)

        let requests = await transport.requests
        #expect(requests[0].bodyText == #"{"categoryId":0,"projectId":0}"#)
        #expect(requests[0].headers["Content-Type"] == "application/json")
        #expect(requests[1].bodyText == #"{"breakRegulation":"apply","categoryId":0,"projectId":0}"#)
        #expect(requests[2].bodyText == #"{"breakRegulation":"ignore","categoryId":0,"projectId":0}"#)
    }

    @Test func unauthorizedIsRetriedOnceWithRecoveredToken() async throws {
        let provider = FakeTokenProvider(token: "stale", recoveredToken: "fresh")
        let (api, transport) = makeAPI([.raw(401, Data()), .fixture(200, "status-idle")], provider: provider)
        let status = try await api.status()
        #expect(status.status == .idle)
        let requests = await transport.requests
        #expect(requests.count == 2)
        #expect(requests[1].headers["Authorization"] == "Bearer fresh")
        #expect(await provider.recoverCalls == 1)
    }

    @Test func secondUnauthorizedIsNotRetriedAgain() async throws {
        let provider = FakeTokenProvider(token: "stale", recoveredToken: "fresh")
        let (api, transport) = makeAPI([.raw(401, Data()), .raw(401, Data()), .fixture(200, "status-idle")], provider: provider)
        await #expect(throws: APIError.http(status: 401, action: nil, detail: "")) {
            try await api.status()
        }
        #expect(await transport.requests.count == 2)
        #expect(await provider.recoverCalls == 1)
    }

    @Test func unauthorizedWithoutRecoveryFails() async throws {
        let (api, transport) = makeAPI([.raw(401, Data())])
        await #expect(throws: APIError.http(status: 401, action: nil, detail: "")) {
            try await api.status()
        }
        #expect(await transport.requests.count == 1)
    }

    @Test func conflictCarriesActionSpecificMessage() async throws {
        let (api, _) = makeAPI([.raw(409, Data("clock already running".utf8))])
        do {
            _ = try await api.perform(.start)
            Issue.record("expected an error")
        } catch let error as APIError {
            #expect(error == .http(status: 409, action: .start, detail: "clock already running"))
            #expect(error.userMessage == "Stempeluhr läuft schon.")
        }
    }

    @Test func emptyBodyIsUnreadable() async throws {
        let (api, _) = makeAPI([.raw(200, Data())])
        await #expect(throws: APIError.unreadableResponse) {
            try await api.status()
        }
    }

    @Test func transportFailureIsMapped() async throws {
        let (api, _) = makeAPI([.failure(TransportError(description: "offline"))])
        await #expect(throws: APIError.transport("offline")) {
            try await api.status()
        }
        #expect(APIError.transport("offline").userMessage == "Keine Verbindung zu Timebutler.")
    }

    @Test func messagesFollowTheRequirementTable() {
        #expect(APIError.http(status: 400, action: nil, detail: "").userMessage == "Zeiterfassung ist für dieses Konto nicht aktiviert.")
        #expect(APIError.http(status: 401, action: .stop, detail: "").userMessage == "Zugang abgelaufen. Bitte neu anmelden.")
        #expect(APIError.http(status: 403, action: .start, detail: "").userMessage == "Starten ist nur am Terminal erlaubt.")
        #expect(APIError.http(status: 403, action: .resume, detail: "").userMessage == "Pausieren ist nur am Terminal erlaubt.")
        #expect(APIError.http(status: 403, action: .stop, detail: "").userMessage == "Stoppen ist nur am Terminal erlaubt.")
        #expect(APIError.http(status: 409, action: .pause, detail: "").userMessage == "Stempeluhr läuft nicht.")
        #expect(APIError.http(status: 409, action: .resume, detail: "").userMessage == "Stempeluhr ist nicht pausiert.")
        #expect(APIError.http(status: 409, action: .stop, detail: "").userMessage == "Stempeluhr ist nicht aktiv, zu kurz (unter 1 Minute) oder doppelter Eintrag.")
        #expect(APIError.http(status: 409, action: .cancel, detail: "").userMessage == "Stempeluhr ist bereits gestoppt.")
        #expect(APIError.http(status: 429, action: nil, detail: "").userMessage == "Zu viele Anfragen. Kurz warten.")
        #expect(APIError.http(status: 500, action: nil, detail: "").userMessage == "Timebutler meldet einen Serverfehler.")
        #expect(APIError.http(status: 502, action: nil, detail: "").userMessage == "Fehler (HTTP 502).")
        #expect(APIError.unreadableResponse.userMessage == "Antwort von Timebutler nicht lesbar.")
    }
}
