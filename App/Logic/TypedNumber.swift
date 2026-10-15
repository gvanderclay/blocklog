import Foundation

/// A number typed into a number-pad field: only its ASCII digits count, up to a maximum number of them.
@MainActor
enum TypedNumber {
    /// The number the text's first `maxDigits` digits spell; nil when it has none.
    static func parse(_ text: String, maxDigits: Int) -> Int? {
        Int(String(text.filter { $0.isASCII && $0.isNumber }.prefix(maxDigits)))
    }
}
