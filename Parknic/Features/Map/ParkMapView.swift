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
    let onSelect: (Park) -> Void

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            if let characterAssetName, UIImage(named: characterAssetName) != nil {
                UserAnnotation { UserAvatarMarker(assetName: characterAssetName) }
            } else {
                UserAnnotation()
            }
            if let userLocation {
                MapCircle(center: userLocation.clLocation, radius: Double(NearbyParksViewModel.searchRadiusM))
                    .foregroundStyle(Color.leaf500.opacity(0.08))
                    .stroke(Color.leaf600.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            ForEach(parks) { park in
                // 시안의 초록 공원 면처럼, 체크인 판정 반경을 공원 영역으로 보여준다.
                MapCircle(center: park.coordinate.clLocation, radius: Double(park.radiusM))
                    .foregroundStyle(Color.leaf300.opacity(0.5))
                    .stroke(Color.ink900.opacity(0.55), lineWidth: 1.5)
            }
            ForEach(parks) { park in
                Annotation(park.name, coordinate: park.coordinate.clLocation, anchor: .bottom) {
                    ParkMarker(park: park, isSelected: park.id == selectedParkID)
                        .onTapGesture { onSelect(park) }
                }
                .annotationTitles(.hidden)
            }
        }
        // 시안은 상점·역 같은 장소 표시 없이 길과 공원만 보이므로 장소 표시를 끄고 지도를 흐리게 쓴다.
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {}
        .onChange(of: recenterToken) { recenter() }
        .onAppear { if userLocation != nil { recenter() } }
    }

    private func recenter() {
        guard let userLocation else { return }
        withAnimation {
            position = .region(
                MKCoordinateRegion(center: userLocation.clLocation, latitudinalMeters: 2600, longitudinalMeters: 2600))
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
