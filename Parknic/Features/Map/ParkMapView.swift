import MapKit
import SwiftUI

/// 지도 본체. 1차는 MapKit이며, 네이버 지도로 바꿀 때 이 뷰만 교체한다.
struct ParkMapView: View {
    let parks: [Park]
    let userLocation: Coordinate?
    let selectedParkID: Int?
    /// 값이 바뀌면 내 위치로 이동한다.
    let recenterToken: Int
    let onSelect: (Park) -> Void

    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            if let userLocation {
                MapCircle(center: userLocation.clLocation, radius: Double(NearbyParksViewModel.searchRadiusM))
                    .foregroundStyle(Color.leaf500.opacity(0.08))
                    .stroke(Color.leaf600.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            }
            ForEach(parks) { park in
                Annotation(park.name, coordinate: park.coordinate.clLocation, anchor: .bottom) {
                    ParkMarker(park: park, isSelected: park.id == selectedParkID)
                        .onTapGesture { onSelect(park) }
                }
                .annotationTitles(.hidden)
            }
        }
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

extension Coordinate {
    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
