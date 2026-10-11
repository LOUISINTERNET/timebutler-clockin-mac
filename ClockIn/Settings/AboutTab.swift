import AppKit
import SwiftUI

/// FR-P5: name, version, disclaimer and links, laid out like Password Filler's about tab.
/// FR-2, FR-3: the update check below the version line, disabled while Sparkle cannot check.
struct AboutTab: View {
    static let apiDocumentationURL: URL = {
        guard let url = URL(string: "https://app.timebutler.com/api/v2/docs") else {
            preconditionFailure("API documentation URL literal is not a valid URL")
        }
        return url
    }()

    static let timebutlerURL: URL = {
        guard let url = URL(string: "https://app.timebutler.com") else {
            preconditionFailure("Timebutler URL literal is not a valid URL")
        }
        return url
    }()

    let updateState: UpdateState
    let checkForUpdates: () -> Void

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                        .resizable()
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppIdentity.displayName)
                            .font(.title2.bold())
                        Text("Version \(Self.version) (Build \(Self.build))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Inoffizielle App, nicht mit der Timebutler GmbH verbunden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                Button(action: checkForUpdates) {
                    Label("Nach Updates suchen…", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!updateState.canCheckForUpdates)
            }
            Section {
                Link(destination: Self.timebutlerURL) {
                    Label("Timebutler im Browser öffnen", systemImage: "safari")
                }
                Link(destination: Self.apiDocumentationURL) {
                    Label("Timebutler-API-Dokumentation", systemImage: "book")
                }
            } header: {
                Text("Links")
            }
        }
        .formStyle(.grouped)
    }

    private static var version: String {
        infoValue("CFBundleShortVersionString")
    }

    private static var build: String {
        infoValue("CFBundleVersion")
    }

    /// Both keys come from project.yml; a missing one is a broken build, not a runtime case.
    private static func infoValue(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            preconditionFailure("Info.plist has no \(key)")
        }
        return value
    }
}
