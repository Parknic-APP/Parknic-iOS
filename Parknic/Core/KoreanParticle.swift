/// 받침 유무에 따라 달라지는 조사
enum KoreanParticle {
    /// 마지막 글자가 한글이면 받침 유무를, 아니면 nil을 돌려준다.
    static func hasFinalConsonant(_ text: String) -> Bool? {
        guard let scalar = text.unicodeScalars.last, (0xAC00...0xD7A3).contains(scalar.value) else { return nil }
        return (scalar.value - 0xAC00) % 28 != 0
    }

    /// "치즈냥" → "치즈냥이랑", "시바" → "시바랑". 한글이 아니면 "(이)랑"을 붙인다.
    static func withIRang(_ name: String) -> String {
        switch hasFinalConsonant(name) {
        case true: name + "이랑"
        case false: name + "랑"
        case nil: name + "(이)랑"
        }
    }
}
