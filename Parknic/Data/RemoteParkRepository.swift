import Foundation

/// 응답 형식은 서버와 확정 전 클라이언트 가정이다(docs/api-spec.md).
struct RemoteParkRepository: ParkRepository {
    private struct ParkDTO: Decodable {
        let id: Int
        let name: String
        let parkType: ParkType
        let latitude: Double
        let longitude: Double
        let radiusM: Double
        let myStatus: String
        let myBadgeCount: Int

        var park: Park {
            Park(
                id: id, name: name, type: parkType, coordinate: Coordinate(latitude: latitude, longitude: longitude),
                radiusM: radiusM, status: ParkVisitStatus(rawValue: myStatus) ?? .none, badgeCount: myBadgeCount)
        }
    }
    private struct NearbyResponse: Decodable { let parks: [ParkDTO] }
    private struct DetailDTO: Decodable {
        let id: Int
        let name: String
        let parkType: ParkType
        let address: String
        let latitude: Double
        let longitude: Double
        let radiusM: Double
        let averageRating: Double?
        let reviewCount: Int
        let myStatus: String
        let myBadgeCount: Int
    }

    private struct TopRatedDTO: Decodable {
        let id: Int
        let name: String
        let parkType: ParkType
        let latitude: Double
        let longitude: Double
        let radiusM: Double
        let distanceM: Int
        let averageRating: Double
        let reviewCount: Int
        let myStatus: String
        let myBadgeCount: Int
    }
    private struct TopRatedResponse: Decodable { let parks: [TopRatedDTO] }

    let client: APIClient

    func nearby(center: Coordinate, radiusM: Int) async throws -> [Park] {
        let endpoint = Endpoint(
            .get, "/api/parks/nearby",
            query: [
                .init(name: "lat", value: String(center.latitude)), .init(name: "lng", value: String(center.longitude)),
                .init(name: "radius", value: String(radiusM)),
            ])
        let response: NearbyResponse = try await client.send(endpoint)
        return response.parks.map(\.park)
    }

    func detail(parkID: Int) async throws -> ParkDetail {
        let dto: DetailDTO = try await client.send(Endpoint(.get, "/api/parks/\(parkID)"))
        let park = Park(
            id: dto.id, name: dto.name, type: dto.parkType,
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude), radiusM: dto.radiusM,
            status: ParkVisitStatus(rawValue: dto.myStatus) ?? .none, badgeCount: dto.myBadgeCount)
        return ParkDetail(park: park, address: dto.address, averageRating: dto.averageRating, reviewCount: dto.reviewCount)
    }

    func topRated(center: Coordinate, radiusM: Int) async throws -> [TopRatedPark] {
        let endpoint = Endpoint(
            .get, "/api/parks/top-rated",
            query: [
                .init(name: "lat", value: String(center.latitude)), .init(name: "lng", value: String(center.longitude)),
                .init(name: "radius", value: String(radiusM)),
            ])
        let response: TopRatedResponse = try await client.send(endpoint)
        return response.parks.map { dto in
            TopRatedPark(
                park: Park(
                    id: dto.id, name: dto.name, type: dto.parkType,
                    coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude), radiusM: dto.radiusM,
                    status: ParkVisitStatus(rawValue: dto.myStatus) ?? .none, badgeCount: dto.myBadgeCount),
                distanceM: dto.distanceM, averageRating: dto.averageRating, reviewCount: dto.reviewCount)
        }
    }
}
