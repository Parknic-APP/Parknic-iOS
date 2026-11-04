/// 공원 유형. 서버 응답의 `parkType` 값과 1:1로 대응한다. (docs/api-spec.md)
enum ParkType: String, CaseIterable, Codable, Sendable {
    case neighborhood = "NEIGHBORHOOD"
    case children = "CHILDREN"
    case small = "SMALL"
    case sports = "SPORTS"
    case waterfront = "WATERFRONT"
    case culture = "CULTURE"
    case history = "HISTORY"

    var displayName: String {
        switch self {
        case .neighborhood: "근린공원"
        case .children: "어린이공원"
        case .small: "소공원"
        case .sports: "체육공원"
        case .waterfront: "수변공원"
        case .culture: "문화공원"
        case .history: "역사공원"
        }
    }
}
