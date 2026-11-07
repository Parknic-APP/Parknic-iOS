import Foundation
import Observation

/// 지도 홈. 위치 이벤트를 받아 주변 공원 조회로 넘기고, 선택한 공원·권한 상태·체크인 시작과 화면 흐름을 관리한다.
@MainActor @Observable
final class MapHomeViewModel {
    let nearby: NearbyParksViewModel
    let checkIn: CheckInCoordinator
    private(set) var authorization: LocationAuthorization = .notDetermined
    /// 마커를 눌러 고른 공원(공원 시트가 이 값으로 열린다)
    var selectedParkID: Int?
    /// 값이 바뀌면 지도가 내 위치로 이동한다(현위치 버튼, 첫 위치 수신)
    private(set) var recenterToken = 0
    /// 사용자가 「둘러보기만 할게요」를 눌러 권한 안내를 닫았다
    private(set) var isBrowsingWithoutLocation = false
    /// 지금 있는 동네 이름("신대방동"). 아직 모르거나 구하지 못하면 nil
    private(set) var neighborhoodName: String?

    /// 체크인 화면(진행·실패·완료)을 전체 화면으로 보여주는지
    var showsCheckInFlow = false
    /// 반경이 겹쳐 사용자가 골라야 할 때의 후보 공원
    var chooserParks: [Park]?
    private(set) var isStartingCheckIn = false
    /// 체크인을 시작하지 못했을 때 보여줄 문구
    var startErrorMessage: String?

    private let location: LocationProviding
    private let parkRepository: ParkRepository
    private let rankingRepository: RankingRepository
    private let reviewRepository: ReviewRepository
    private let profile: ProfileStore
    private let myPage: MyPageRepository?
    /// 기기에 저장한 프로필이 바뀌면 올려서, 지도가 내 캐릭터를 다시 그리게 한다.
    private var profileRevision = 0
    private let neighborhoodNamer: NeighborhoodNaming
    private var lastNamedLocation: Coordinate?
    private var nameTask: Task<Void, Never>?
    private var hasCentered = false

    init(
        location: LocationProviding, nearby: NearbyParksViewModel, checkIn: CheckInCoordinator, parks: ParkRepository,
        rankings: RankingRepository = MockRankingRepository(delay: .zero),
        reviews: ReviewRepository = MockReviewRepository(delay: .zero), profile: ProfileStore = UserDefaultsProfileStore(),
        neighborhood: NeighborhoodNaming = NoNeighborhoodNamer(), myPage: MyPageRepository? = nil
    ) {
        self.myPage = myPage
        self.neighborhoodNamer = neighborhood
        self.rankingRepository = rankings
        self.reviewRepository = reviews
        self.profile = profile
        self.location = location
        self.nearby = nearby
        self.checkIn = checkIn
        self.parkRepository = parks
    }

    var selectedPark: Park? {
        nearby.parks.first { $0.id == selectedParkID }
    }

    /// 권한 거부 안내(10c)를 보여줄지
    var showsLocationDenied: Bool { authorization == .denied && !isBrowsingWithoutLocation }

    // MARK: 위치

    /// 화면이 나타날 때 한 번 부른다. 위치 이벤트가 끝날 때까지 계속 처리한다.
    func run() async {
        Task { await syncProfileIfNeeded() }
        location.requestPermissionIfNeeded()
        for await event in location.events() {
            switch event {
            case .authorization(let value):
                authorization = value
                if value == .authorized { isBrowsingWithoutLocation = false }
            case .location(let coordinate):
                nearby.locationDidUpdate(coordinate)
                updateNeighborhoodName(at: coordinate)
                if !hasCentered {
                    hasCentered = true
                    recenterToken += 1
                }
            }
        }
    }

    func recenter() {
        recenterToken += 1
    }

    /// 로그인·로그아웃·탈퇴로 계정이 바뀌었다. 이전 사용자의 지도 상태를 비우고, 새 계정 기준으로 다시 조회한다.
    func accountDidChange(isSignedIn: Bool) {
        nearby.reset()
        selectedParkID = nil
        chooserParks = nil
        showsCheckInFlow = false
        profileRevision += 1
        guard isSignedIn else { return }
        nearby.retry()
        Task { await syncProfileIfNeeded() }
    }

    /// 앱을 다시 설치했거나 다른 기기에서 로그인해 기기에 프로필이 없으면, 서버의 내 프로필로 채운다(내 위치 캐릭터 표시용).
    private func syncProfileIfNeeded() async {
        guard profile.characterID == nil, let myPage, let me = try? await myPage.profile() else { return }
        profile.save(nickname: me.nickname, characterID: me.characterID)
        profileRevision += 1
    }

    /// 주변 공원을 다시 조회하는 기준(300m)만큼 움직였을 때만 동네 이름을 다시 구한다.
    /// 이름을 못 구하면(네트워크·조회 한도) 이전 이름을 그대로 둔다.
    private func updateNeighborhoodName(at coordinate: Coordinate) {
        if let last = lastNamedLocation, last.distance(to: coordinate) < NearbyParksViewModel.refetchDistanceM { return }
        lastNamedLocation = coordinate
        nameTask?.cancel()
        nameTask = Task { [neighborhoodNamer] in
            let name = await neighborhoodNamer.name(at: coordinate)
            guard !Task.isCancelled, let name else { return }
            neighborhoodName = name
        }
    }

    func browseWithoutLocation() {
        isBrowsingWithoutLocation = true
    }

    // MARK: 공원 시트

    func makeSheetViewModel(for park: Park) -> ParkSheetViewModel {
        ParkSheetViewModel(park: park, repository: parkRepository, rankingRepository: rankingRepository, reviewRepository: reviewRepository)
    }

    func availability(for park: Park) -> CheckInAvailability {
        CheckInAvailability.make(
            park: park, location: nearby.currentLocation, authorization: authorization,
            activeSession: checkIn.state.isActive ? checkIn.state.session : nil)
    }

    func distanceM(to park: Park) -> Int? {
        nearby.currentLocation.map { Int(park.coordinate.distance(to: $0).rounded()) }
    }

    // MARK: 체크인

    /// 공원 시트의 체크인 버튼. 반경이 겹치면 고르게 하고, 아니면 바로 시작한다.
    func checkInTapped(on park: Park) async {
        switch availability(for: park) {
        case .inProgressHere:
            selectedParkID = nil
            showsCheckInFlow = true
        case .available:
            // 오늘 이미 받은 공원은 후보에서 뺀다.
            let candidates = nearby.parksInRange.filter { $0.status != .earnedToday }
            if candidates.count >= 2, let location = nearby.currentLocation {
                chooserParks = candidates.sorted {
                    $0.coordinate.distance(to: location) < $1.coordinate.distance(to: location)
                }
            } else {
                await startCheckIn(at: park)
            }
        default:
            break
        }
    }

    /// 후보 중 하나를 골랐다.
    func chooseForCheckIn(_ park: Park) async {
        chooserParks = nil
        await startCheckIn(at: park)
    }

    private func startCheckIn(at park: Park) async {
        guard let location = nearby.currentLocation, !isStartingCheckIn else { return }
        isStartingCheckIn = true
        await checkIn.begin(parkID: park.id, at: location)
        isStartingCheckIn = false
        if checkIn.state.isActive {
            selectedParkID = nil
            showsCheckInFlow = true
        } else {
            startErrorMessage = checkIn.startErrorMessage
        }
    }

    /// 코디네이터 상태가 바뀔 때 부른다. 끝난 체크인(실패·완료)은 화면으로 알리고, 정리되면 목록을 새로 받는다.
    func checkInStateDidChange(_ state: CheckInState) {
        switch state {
        case .failed, .completed:
            showsCheckInFlow = true
        case .idle:
            if showsCheckInFlow {
                showsCheckInFlow = false
                nearby.refresh()
            }
        default:
            break
        }
    }

    /// 실패 화면의 「다시 체크인하기」 — 그 공원의 시트를 열어 다시 시작하게 한다.
    func retryCheckIn(parkID: Int?) {
        showsCheckInFlow = false
        if let parkID, nearby.parks.contains(where: { $0.id == parkID }) { selectedParkID = parkID }
    }

    /// 배지 획득 화면의 "N번째 배지". 목록의 내 배지 수에 이번에 받은 1개를 더한다.
    var badgeNumberAtPark: Int? {
        guard let id = checkIn.result?.badge.parkID else { return nil }
        return nearby.parks.first { $0.id == id }.map { $0.badgeCount + 1 }
    }

    var characterAssetName: String? {
        _ = profileRevision
        return profile.characterID.map { "character-\($0)" }
    }

    /// 배지 획득 화면에서 랭킹·리뷰로 가려는 경우: 체크인 화면을 닫고 그 공원 시트를 연다.
    func openParkAfterBadge() {
        let parkID = checkIn.result?.badge.parkID
        checkIn.dismiss()
        showsCheckInFlow = false
        nearby.refresh()
        if let parkID { selectedParkID = parkID }
    }

    /// 지도 위 진행 중 배너와 체크인 화면에 쓰는 값
    var checkInDisplay: CheckInProgressDisplay? {
        CheckInProgressDisplay.make(from: checkIn, parkType: checkInParkType)
    }

    var checkInParkType: ParkType {
        guard let id = checkIn.state.session?.parkID else { return .neighborhood }
        return nearby.parks.first { $0.id == id }?.type ?? .neighborhood
    }
}
