/// 프로필 캐릭터(치즈냥, 시바 등 8종). 이미지는 `character-<id>` 에셋 이름으로 참조한다.
struct AvatarCharacter: Equatable, Identifiable, Sendable {
    let id: Int
    let name: String

    var assetName: String { "character-\(id)" }
}
