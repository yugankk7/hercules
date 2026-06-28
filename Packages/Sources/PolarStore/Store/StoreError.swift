import Foundation

/// Typed error currency for the local store, mirroring `PolarProtocol`'s
/// `AuthError` convention: redaction-safe — never carries tokens or raw payloads
/// (Norm 6). Thrown by the wire→record mappers, by JSON coding, and by reads.
public enum StoreError: Error, Equatable {
    case migrationFailed(String)
    case encodingFailed(String)
    case decodingFailed(String)
    case notFound
}
