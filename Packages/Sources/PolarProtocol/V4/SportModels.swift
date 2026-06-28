import Foundation

/// A sport from `GET /v4/data/sports/list` — `{ id:{id}, name }` flattened to
/// `id → name`. Reference data; the catalog is cached across syncs by Epic 4/5,
/// not re-fetched per sync. Maps to the eventual `sport_ref` table.
///
/// > Wire keys are provisional pending a captured live payload (HERC-033 AC).
public struct Sport: Decodable, Sendable, Equatable {
    public let id: Int
    public let name: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
    }

    private struct IDBlock: Decodable { let id: Int }

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `id` may be a nested `{ "id": n }` block or a bare number.
        if let block = try? c.decode(IDBlock.self, forKey: .id) {
            id = block.id
        } else {
            id = try c.decodeIfPresent(Int.self, forKey: .id) ?? -1
        }
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
    }
}
