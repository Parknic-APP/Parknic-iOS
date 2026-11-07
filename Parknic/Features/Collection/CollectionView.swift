import SwiftUI

extension AchievementProgress {
    /// "2026.10.19 달성" (KST 기준)
    var achievedDateText: String? {
        guard let achievedAt else { return nil }
        let parts = Calendar.kst.dateComponents([.year, .month, .day], from: achievedAt)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return String(format: "%04d.%02d.%02d 달성", year, month, day)
    }

    var progressText: String { "\(min(progress, target))/\(target)" }
}

/// 12h·09a — 도감. 유형별 배지 개수와 업적을 보여준다. 미획득 배지는 실루엣이다.
struct CollectionView: View {
    let viewModel: CollectionViewModel

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                PKLoadingView(title: "도감을 불러오고 있어요", message: "잠깐만요, 금방 끝나요")
            case .failed(let message):
                PKErrorView(
                    title: "도감을 불러오지 못했어요", message: LocalizedStringKey(message), retryTitle: "다시 시도"
                ) { Task { await viewModel.load() } }
            case .loaded(let collection):
                content(collection)
            }
        }
        .background(Color.canvas.ignoresSafeArea())
        .task { await viewModel.load() }
    }

    private func content(_ collection: BadgeCollection) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s20) {
                Text("도감").pkTextStyle(.display).foregroundStyle(Color.ink900)
                summaryCard(collection)
                Text("공원 유형 배지").pkTextStyle(.title2).foregroundStyle(Color.ink900)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s8), count: 3), spacing: Spacing.s8) {
                    ForEach(ParkType.allCases, id: \.self) { type in
                        typeCell(type, count: collection.count(of: type))
                    }
                }
                Text("업적").pkTextStyle(.title2).foregroundStyle(Color.ink900)
                VStack(spacing: Spacing.s8) {
                    ForEach(collection.achievements) { achievementRow($0) }
                }
            }
            .padding(Spacing.s16)
        }
        .refreshable { await viewModel.load() }
    }

    // MARK: 구성

    private func summaryCard(_ collection: BadgeCollection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("지금까지 모은 배지").pkTextStyle(.callout).foregroundStyle(Color.leaf100)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s4) {
                    Text("\(collection.totalBadges)").pkTextStyle(.timer).foregroundStyle(Color.white)
                    Text("개").pkTextStyle(.headline).foregroundStyle(Color.white)
                }
            }
            HStack(spacing: Spacing.s16) {
                stat("방문한 공원", "\(collection.visitedParks)곳")
                stat("모은 유형", "\(collection.collectedTypeCount)/\(ParkType.allCases.count)")
                stat("업적", "\(collection.achievedCount)/\(collection.achievements.count)")
            }
        }
        .padding(Spacing.s20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            Circle().fill(Color.white.opacity(0.08)).frame(width: 150, height: 150).offset(x: 30, y: -30)
        }
        .background(Color.leaf600)
        .clipShape(RoundedRectangle(cornerRadius: Radius.r30))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "지금까지 모은 배지 \(collection.totalBadges)개, 방문한 공원 \(collection.visitedParks)곳, 모은 유형 \(collection.collectedTypeCount)/\(ParkType.allCases.count), 업적 \(collection.achievedCount)/\(collection.achievements.count)")
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack(spacing: Spacing.s4) {
            Text(title).foregroundStyle(Color.leaf100)
            Text(value).foregroundStyle(Color.white)
        }
        .pkTextStyle(.callout)
    }

    private func typeCell(_ type: ParkType, count: Int) -> some View {
        VStack(spacing: Spacing.s8) {
            badgeImage(count > 0 ? type.badgeAssetName : type.lockedBadgeAssetName, fallback: type.symbolName, size: 64)
            Text(type.displayName).pkTextStyle(.callout).foregroundStyle(Color.ink900).frame(minHeight: 24)
            Group {
                if count > 0 {
                    Text("×\(count)").pkTextStyle(.headline).foregroundStyle(Color.leaf600)
                } else {
                    Text("아직 없어요").pkTextStyle(.callout).foregroundStyle(Color.ink500)
                }
            }
            // 글자 크기가 달라도 같은 줄의 카드 높이가 어긋나지 않게 줄 높이를 맞춘다.
            .frame(minHeight: 28)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.s16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(count > 0 ? "\(type.displayName) 배지 \(count)개" : "\(type.displayName) 배지 아직 없어요")
    }

    private func achievementRow(_ achievement: AchievementProgress) -> some View {
        HStack(spacing: Spacing.s12) {
            ZStack {
                badgeImage(
                    achievement.isAchieved ? "badge-achievement" : "badge-achievement-locked", fallback: "trophy", size: 50)
                Text(achievement.label)
                    .pkTextStyle(achievement.label.count > 2 ? .callout : .headline)
                    .foregroundStyle(achievement.isAchieved ? Color.ink900 : Color.ink500)
            }
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(achievement.name).pkTextStyle(.headline).foregroundStyle(Color.ink900)
                if let date = achievement.achievedDateText {
                    Text(date).pkTextStyle(.callout).foregroundStyle(Color.ink500)
                } else {
                    HStack(spacing: Spacing.s8) {
                        ProgressView(value: achievement.fraction).tint(.leaf600)
                        Text(achievement.progressText).pkTextStyle(.callout).foregroundStyle(Color.ink500)
                            .frame(minWidth: 64, alignment: .trailing)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.s12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.r24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            achievement.isAchieved
                ? "\(achievement.name), \(achievement.achievedDateText ?? "")"
                : "\(achievement.name), 진행 \(achievement.progressText)")
    }

    /// 에셋이 없으면 SF Symbol로 대신한다(최종 에셋 교체 중에도 화면이 깨지지 않게).
    @ViewBuilder
    private func badgeImage(_ name: String, fallback: String, size: CGFloat) -> some View {
        if UIImage(named: name) != nil {
            Image(name).resizable().scaledToFit().frame(width: size, height: size)
        } else {
            Image(systemName: fallback).font(.title2).foregroundStyle(Color.ink500).frame(width: size, height: size)
        }
    }
}

#Preview("도감") {
    CollectionView(
        viewModel: CollectionViewModel(repository: MockCollectionRepository(delay: .zero)))
}

#Preview("신규 회원(비어 있음)") {
    CollectionView(
        viewModel: CollectionViewModel(repository: MockCollectionRepository(delay: .zero, isEmpty: true)))
}

#Preview("로딩") {
    CollectionView(
        viewModel: CollectionViewModel(repository: MockCollectionRepository(delay: .seconds(3600)), initialState: .loading))
}

#Preview("에러") {
    CollectionView(
        viewModel: CollectionViewModel(
            repository: MockCollectionRepository(delay: .zero, failure: .network),
            initialState: .failed(APIError.network.userMessage)))
}
