import Foundation

public extension String {
    /// Collapse runs of whitespace to single spaces and trim the ends.
    func collapsingWhitespace() -> String {
        split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lowercased, diacritic-free, punctuation-free form for fuzzy matching and
    /// search indexing. `"Café Déjà-Vu!"` → `"cafe deja vu"`.
    func foldedForSearch() -> String {
        let folded = folding(options: [.diacriticInsensitive, .caseInsensitive],
                             locale: Locale(identifier: "en_US"))
        let allowed = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return " "
        }
        return String(allowed).collapsingWhitespace()
    }

    /// Levenshtein-based similarity in 0...1 against another string, using the
    /// folded form of both. Cheap enough for a few hundred comparisons.
    func similarity(to other: String) -> Double {
        let a = Array(self.foldedForSearch())
        let b = Array(other.foldedForSearch())
        if a.isEmpty && b.isEmpty { return 1 }
        if a.isEmpty || b.isEmpty { return 0 }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = Swift.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        let distance = Double(previous[b.count])
        let maxLen = Double(Swift.max(a.count, b.count))
        return 1 - distance / maxLen
    }
}
