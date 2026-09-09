import Foundation

/// `application/x-www-form-urlencoded` body encoding for the OAuth token endpoint.
enum FormEncoding {
    /// The unreserved set of RFC 3986, spelled out so that non-ASCII letters (which
    /// `CharacterSet.alphanumerics` contains) are always percent-encoded.
    private static let unreservedCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func encode(_ fields: [(name: String, value: String)]) -> Data {
        let pairs = fields.map { "\(escape($0.name))=\(escape($0.value))" }
        return Data(pairs.joined(separator: "&").utf8)
    }

    private static func escape(_ value: String) -> String {
        guard let escaped = value.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) else {
            preconditionFailure("Percent-encoding failed for a form field")
        }
        return escaped
    }
}
