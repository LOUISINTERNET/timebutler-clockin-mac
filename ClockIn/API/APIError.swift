import Foundation

/// Failures of the Timebutler REST API, with the German texts the widget shows (FR-C11).
enum APIError: Error, Equatable, Sendable, LocalizedError {
    case transport(String)
    case unreadableResponse
    case http(status: Int, action: ClockAction?, detail: String)

    var errorDescription: String? {
        userMessage
    }

    var userMessage: String {
        switch self {
        case .transport:
            "Keine Verbindung zu Timebutler."
        case .unreadableResponse:
            "Antwort von Timebutler nicht lesbar."
        case .http(let status, let action, _):
            Self.message(status: status, action: action)
        }
    }

    private static func message(status: Int, action: ClockAction?) -> String {
        switch status {
        case 400: "Zeiterfassung ist für dieses Konto nicht aktiviert."
        case 401: "Zugang abgelaufen. Bitte neu anmelden."
        case 403: terminalOnlyMessage(action: action)
        case 409: conflictMessage(action: action)
        case 429: "Zu viele Anfragen. Kurz warten."
        case 500: "Timebutler meldet einen Serverfehler."
        default: "Fehler (HTTP \(status))."
        }
    }

    private static func terminalOnlyMessage(action: ClockAction?) -> String {
        switch action {
        case .start: "Starten ist nur am Terminal erlaubt."
        case .pause, .resume: "Pausieren ist nur am Terminal erlaubt."
        case .stop: "Stoppen ist nur am Terminal erlaubt."
        case .cancel, nil: "Diese Aktion ist nur am Terminal erlaubt."
        }
    }

    private static func conflictMessage(action: ClockAction?) -> String {
        switch action {
        case .start: "Stempeluhr läuft schon."
        case .pause: "Stempeluhr läuft nicht."
        case .resume: "Stempeluhr ist nicht pausiert."
        case .stop: "Zu kurz (unter 1 Minute) oder doppelter Eintrag."
        case .cancel: "Stempeluhr ist bereits gestoppt."
        case nil: "Aktion im aktuellen Zustand nicht möglich."
        }
    }
}
