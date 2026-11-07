import MapKit
import SwiftUI

/// 지도 본체. 1차는 MapKit이며, 네이버 지도로 바꿀 때 이 뷰만 교체한다.
struct ParkMapView: View {
    let parks: [Park]
    let userLocation: Coordinate?
    let selectedParkID: Int?
    /// 값이 바뀌면 내 위치로 이동한다.
    let recenterToken: Int
    /// 내 위치에 올릴 캐릭터 에셋 이름. 없으면 기본 파란 점을 쓴다.
    var characterAssetName: String?
    /// 설정한 주변 공원 조회 반경(m). 점선 원으로 보여준다.
    var searchRadiusM = SearchRadius.default.meters
    let onSelect: (Park) -> Void
    /// 마커가 아닌 지도 빈 곳을 눌렀다(열려 있는 공원 시트를 닫는 데 쓴다).
    var onTapMap: () -> Void = {}

    /// 처음 들어올 때와 현위치 버튼을 누를 때 지도에 보이는 가로 폭(m). 공원을 불러오는 반경(설정에서 1~2km)과 별개로 이 크기를 유지한다.
    static let visibleWidthM = 1200.0

    private static let koreaVeil: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 32.5, longitude: 123.5), CLLocationCoordinate2D(latitude: 32.5, longitude: 132.5),
        CLLocationCoordinate2D(latitude: 39.5, longitude: 132.5), CLLocationCoordinate2D(latitude: 39.5, longitude: 123.5),
    ]

    /// 위치가 아직 오지 않았어도 권한이 있으면 처음부터 내 위치 근처로 시작한다(한국 전체가 먼저 보이지 않게).
    /// `.automatic`은 한국 전체를 덮는 막(`koreaVeil`)까지 담아 한반도 전체가 보이므로, 폴백은 좁은 영역(서울 시청 주변)으로 둔다.
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
                latitudinalMeters: ParkMapView.visibleWidthM, longitudinalMeters: ParkMapView.visibleWidthM)))
    @State private var hasPlacedCamera = false
    /// 마커를 누른 직후의 지도 탭은 무시한다(마커 탭과 지도 탭이 함께 들어오는 경우를 막는다).
    @State private var lastMarkerTap = Date.distantPast

    var body: some View {
        Map(position: $position) {
            if let characterAssetName, UIImage(named: characterAssetName) != nil {
                UserAnnotation { UserAvatarMarker(assetName: characterAssetName) }
            } else {
                UserAnnotation()
            }
            // 시안의 평평한 크림색 바탕에 가깝도록, 한국 전체를 덮는 옅은 크림색 막으로 지도 색을 눌러준다.
            MapPolygon(coordinates: Self.koreaVeil)
                .foregroundStyle(Color.mapVeil.opacity(0.55))
                .mapOverlayLevel(level: .aboveRoads)
            if let userLocation {
                MapCircle(center: userLocation.clLocation, radius: Double(searchRadiusM))
                    .foregroundStyle(Color.leaf500.opacity(0.08))
                    .stroke(Color.leaf600.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            ForEach(parks) { park in
                // 시안의 초록 공원 면처럼, 체크인 판정 반경을 둘레로 살짝 일렁이는 공원 영역으로 보여준다.
                MapPolygon(coordinates: ParkArea.outline(for: park).map(\.clLocation))
                    .foregroundStyle(Color.leaf300.opacity(0.6))
                    .stroke(Color.ink900.opacity(0.6), lineWidth: 1.5)
            }
            ForEach(parks) { park in
                Annotation(park.name, coordinate: park.coordinate.clLocation, anchor: .bottom) {
                    ParkMarker(park: park, isSelected: park.id == selectedParkID)
                        .onTapGesture {
                            lastMarkerTap = Date()
                            onSelect(park)
                        }
                }
                .annotationTitles(.hidden)
            }
        }
        // 시안은 상점·역 같은 장소 표시 없이 길과 공원만 보이므로 장소 표시를 끄고 지도를 흐리게 쓴다.
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {}
        .onTapGesture {
            guard Date().timeIntervalSince(lastMarkerTap) > 0.4 else { return }
            onTapMap()
        }
        .onChange(of: recenterToken) { recenter(animated: hasPlacedCamera) }
        .onChange(of: userLocation) { _, new in
            if !hasPlacedCamera, new != nil { recenter(animated: false) }
        }
        .onAppear { if userLocation != nil { recenter(animated: false) } }
    }

    /// 내 위치를 중심으로 가로 `visibleWidthM`만 보이게 옮긴다. 처음 맞출 때는 애니메이션 없이 바로 놓는다.
    private func recenter(animated: Bool) {
        guard let userLocation else { return }
        let region = MKCoordinateRegion(
            center: userLocation.clLocation, latitudinalMeters: Self.visibleWidthM, longitudinalMeters: Self.visibleWidthM)
        hasPlacedCamera = true
        if animated {
            withAnimation { position = .region(region) }
        } else {
            position = .region(region)
        }
    }
}

/// 내 위치 표시: 흰 원 + 초록 테두리 안에 내 캐릭터.
private struct UserAvatarMarker: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .padding(4)
            .frame(width: 44, height: 44)
            .background(Color.white, in: Circle())
            .overlay(Circle().stroke(Color.leaf600, lineWidth: 3))
            .pkShadow(.soft2)
            .accessibilityLabel("내 위치")
    }
}

extension Coordinate {
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
