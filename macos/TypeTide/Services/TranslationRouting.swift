import Foundation

struct TranslationRoute: Equatable {
    let source: Language?
    let target: Language
}

enum TranslationRouting {
    static func resolve(
        text: String,
        mode: TranslationDirection,
        isWrite: Bool,
        native: Language,
        foreign: Language
    ) -> TranslationRoute {
        switch mode {
        case .nativeToForeign:
            return TranslationRoute(source: native, target: foreign)
        case .foreignToNative:
            return TranslationRoute(source: foreign, target: native)
        case .auto:
            let detected = Language.detect(in: text)
            let target: Language
            if detected == native {
                target = foreign
            } else if detected == foreign {
                target = native
            } else {
                target = isWrite ? foreign : native
            }
            return TranslationRoute(source: detected, target: target)
        }
    }
}
