#if DEBUG
import Foundation
import SwiftUI

/// Stores with canned data for the SwiftUI previews of the widget. The API behind them
/// never answers, so previews cannot trigger network calls.
extension ClockStore {
    static func preview(session: SessionState = .active(.apiToken), state: ClockState = .running, pendingBreakRegulation: BreakRegulation? = nil, lastError: String? = nil, lastMessage: String? = nil) -> ClockStore {
        let store = ClockStore(api: previewAPI, sessionManager: previewSessionManager)
        store.session = session
        store.fetchedAt = Date()
        store.summary = WorkSummary(commitmentMinutes: 480, workedMinutes: 192, remainingMinutes: 288, percentDone: 40, breakMinutes: 30)
        store.status = TimeClockStatus(status: state, startTimestamp: state == .idle ? nil : Int64(Date().addingTimeInterval(-14_400).timeIntervalSince1970 * 1000), pauseTimestamp: state == .paused ? Int64(Date().timeIntervalSince1970 * 1000) : nil, workTimeElapsedSeconds: state == .idle ? 0 : 14_400, breakElapsedSeconds: state == .paused ? 600 : 0, accumulatedBreakSeconds: state == .idle ? 0 : 1800, waitSeconds: state == .waiting ? 120 : nil, isBusinessTripActive: false, startOnlyOnTerminal: false, pauseOnlyOnTerminal: false, stopOnlyOnTerminal: false)
        store.pendingBreakRegulation = pendingBreakRegulation
        store.lastError = lastError
        store.lastMessage = lastMessage
        return store
    }

    static let previewRegulation = BreakRegulation(hasNoRemedy: false, obligatory: false, correctionWorkMinutes: 30, correctionBreakMinutes: 30, resultingWorkMinutes: 420, resultingBreakMinutes: 60, detailText: "Die Pausenregelung verlangt 60 Minuten Pause bei mehr als 9 Stunden Arbeit.")

    private static let previewAPI = TimebutlerAPI(transport: PreviewTransport(), tokenProvider: StaticTokenProvider(token: "preview"))

    private static let previewSessionManager: SessionManager = {
        do {
            return try SessionManager(credentialStore: PreviewCredentialStore(), oauthClient: OAuthClient(transport: PreviewTransport()))
        } catch {
            preconditionFailure("Preview credential store never throws: \(error)")
        }
    }()
}

@MainActor
private let previewPreferences: Preferences = {
    guard let defaults = UserDefaults(suiteName: "app.clockin.preview") else {
        preconditionFailure("Preview defaults suite could not be created")
    }
    return Preferences(defaults: defaults)
}()

@MainActor
private let previewCollapsed: Preferences = {
    guard let defaults = UserDefaults(suiteName: "app.clockin.preview.collapsed") else {
        preconditionFailure("Preview defaults suite could not be created")
    }
    let preferences = Preferences(defaults: defaults)
    preferences.widgetCollapsed = true
    return preferences
}()

private struct PreviewTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        throw TransportError(description: "Previews are offline")
    }
}

private struct PreviewCredentialStore: CredentialStore {
    func load() throws -> Credentials? {
        nil
    }

    func save(_ credentials: Credentials) throws {}

    func delete() throws {}
}

#Preview("Arbeit") {
    WidgetView(store: .preview(state: .running), preferences: previewPreferences, openSettings: {})
        .padding()
}

#Preview("Eingeklappt") {
    WidgetView(store: .preview(state: .running), preferences: previewCollapsed, openSettings: {})
        .padding()
}

#Preview("Pause") {
    WidgetView(store: .preview(state: .paused, lastMessage: "Gespeichert: 7:30 (Pause 0:30)"), preferences: previewPreferences, openSettings: {})
        .padding()
}

#Preview("Gestoppt") {
    WidgetView(store: .preview(state: .idle, lastError: "Keine Verbindung zu Timebutler."), preferences: previewPreferences, openSettings: {})
        .padding()
}

#Preview("Wartet") {
    WidgetView(store: .preview(state: .waiting), preferences: previewPreferences, openSettings: {})
        .padding()
}

#Preview("Pausenregelung") {
    WidgetView(store: .preview(state: .running, pendingBreakRegulation: ClockStore.previewRegulation), preferences: previewPreferences, openSettings: {})
        .padding()
}

#Preview("Abgelaufen") {
    WidgetView(store: .preview(session: .expired), preferences: previewPreferences, openSettings: {})
        .padding()
}

#Preview("Nicht angemeldet") {
    WidgetView(store: .preview(session: .notConfigured), preferences: previewPreferences, openSettings: {})
        .padding()
}
#endif
