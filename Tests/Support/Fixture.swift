import Foundation

enum FixtureError: Error, Equatable {
    case missing(String)
}

/// Loads JSON fixtures from `Tests/Fixtures`. The values are taken from the examples in
/// the Timebutler OpenAPI spec (`specs/clock-in-mac-app/docs/timebutler-openapi-v2.json`).
enum Fixture {
    static func data(_ name: String) throws -> Data {
        guard let url = Bundle(for: FixtureAnchor.self).url(forResource: name, withExtension: "json") else {
            throw FixtureError.missing(name)
        }
        return try Data(contentsOf: url)
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from name: String) throws -> Value {
        try JSONDecoder().decode(Value.self, from: data(name))
    }
}

private final class FixtureAnchor {}
