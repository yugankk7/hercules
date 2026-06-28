import Foundation

/// Single, stable JSON encode/decode for every `*_json` column (Norm 4). One
/// shared encoder/decoder pair; `.sortedKeys` makes re-encoding the same map
/// produce a byte-identical string, which keeps upserts idempotent (Safeguard 2).
///
/// Consumers must NOT rely on JSON object key ordering for `"HH:MM"` maps — they
/// sort keys at read time.
enum StoreJSON {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    /// Encode any value to a UTF-8 JSON string; failures surface as `StoreError`.
    static func encode<T: Encodable>(_ value: T) throws -> String {
        do {
            let data = try encoder.encode(value)
            guard let string = String(data: data, encoding: .utf8) else {
                throw StoreError.encodingFailed("\(T.self): non-UTF8 output")
            }
            return string
        } catch let error as StoreError {
            throw error
        } catch {
            throw StoreError.encodingFailed("\(T.self): \(error)")
        }
    }

    /// Decode a UTF-8 JSON string back into a value; failures surface as `StoreError`.
    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        guard let data = json.data(using: .utf8) else {
            throw StoreError.decodingFailed("\(T.self): non-UTF8 input")
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw StoreError.decodingFailed("\(T.self): \(error)")
        }
    }
}
