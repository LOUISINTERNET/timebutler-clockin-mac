import SwiftUI

/// FR-P5: name, version, disclaimer and the link to the API documentation.
struct AboutTab: View {
    static let apiDocumentationURL: URL = {
        guard let url = URL(string: "https://app.timebutler.com/api/v2/docs") else {
            preconditionFailure("API documentation URL literal is not a valid URL")
        }
        return url
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(AppIdentity.displayName)
                .font(.title2.bold())
            Text("Version \(Self.version) (\(Self.build))")
                .foregroundStyle(.secondary)
            Text("Inoffizielle App, nicht mit der Timebutler GmbH verbunden.")
                .font(.footnote)
            Link("Timebutler-API-Dokumentation", destination: Self.apiDocumentationURL)
                .font(.footnote)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
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
