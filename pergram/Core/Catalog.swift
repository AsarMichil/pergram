import Foundation

/// One generic grocery item from the bundled dictionary. `id` is permanent: it is stored on items
/// and in shared lists, so an entry is renamed by changing `name` (keeping the old name as an alias)
/// and withdrawn by setting `retired`, never by deleting it or reusing its id.
nonisolated struct CatalogEntry: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let aliases: [String]
    let aisle: Aisle
    /// The ways it is usually priced on a shelf tag, most common first.
    let soldBy: [PriceDimension]
    var retired: Bool?

    var terms: [String] { [name] + aliases }
}

/// The read-only dictionary that powers search, item linking and aisle guesses. It is never copied
/// into the store wholesale: an entry only becomes a `GroceryItem` once the shopper uses it.
nonisolated struct Catalog: Sendable {
    let version: Int
    let entries: [CatalogEntry]
    private let index: [(entry: CatalogEntry, terms: [String])]
    private let byID: [String: CatalogEntry]

    init(version: Int, entries: [CatalogEntry]) {
        self.version = version
        self.entries = entries
        let live = entries.filter { $0.retired != true }
        index = live.map { ($0, $0.terms.map(SearchText.normalize)) }
        byID = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static let empty = Catalog(version: 0, entries: [])

    private struct File: Codable {
        let catalogVersion: Int
        let items: [CatalogEntry]
    }

    static func decode(from data: Data) throws -> Catalog {
        let file = try JSONDecoder().decode(File.self, from: data)
        return Catalog(version: file.catalogVersion, entries: file.items)
    }

    /// Includes retired entries, so an item linked to one still resolves.
    func entry(id: String) -> CatalogEntry? { byID[id] }

    /// An entry whose name or an alias is the text, ignoring case and accents.
    func exactMatch(for text: String) -> CatalogEntry? {
        let query = SearchText.normalize(text)
        guard !query.isEmpty else { return nil }
        return index.first { $0.terms.contains(query) }?.entry
    }

    func search(_ text: String, limit: Int = 20) -> [CatalogEntry] {
        let query = SearchText.normalize(text)
        guard !query.isEmpty else { return [] }
        var scored: [(entry: CatalogEntry, score: Int)] = []
        for indexed in index {
            if let score = SearchText.score(query: query, terms: indexed.terms) {
                scored.append((indexed.entry, score))
            }
        }
        scored.sort { lhs, rhs in
            lhs.score != rhs.score
                ? lhs.score < rhs.score : lhs.entry.name.count < rhs.entry.name.count
        }
        return scored.prefix(limit).map(\.entry)
    }

    /// The aisle of the entry the text names, or else of the longest known term all of whose words
    /// appear in it — "organic baby spinach" lands in produce through "baby spinach". `nil` when
    /// nothing in the dictionary is recognisable.
    func guessAisle(for text: String) -> Aisle? {
        if let exact = exactMatch(for: text) { return exact.aisle }
        let words = Set(SearchText.words(of: SearchText.normalize(text)).flatMap(SearchText.forms))
        guard !words.isEmpty else { return nil }
        var best: (aisle: Aisle, length: Int)?
        for indexed in index {
            for term in indexed.terms {
                let termWords = SearchText.words(of: term)
                guard !termWords.isEmpty,
                    termWords.allSatisfy({ !SearchText.forms(of: $0).isDisjoint(with: words) })
                else { continue }
                if term.count > (best?.length ?? 0) {
                    best = (indexed.entry.aisle, term.count)
                }
            }
        }
        return best?.aisle
    }
}

/// Text folded for matching: lowercased, accents removed, punctuation other than the apostrophe
/// treated as a space. French shelf names are written with and without accents ("creme"/"crème"),
/// so matching must ignore them.
nonisolated enum SearchText {
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let spaced = folded.map { character -> Character in
            character.isLetter || character.isNumber || character == "'" ? character : " "
        }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }

    static func words(of normalized: String) -> [String] {
        normalized.split(separator: " ").map(String.init)
    }

    /// A word and its naive singular, so "tomatoes" meets "tomato" and "berries" meets "berry".
    static func forms(of word: String) -> Set<String> {
        var forms: Set<String> = [word]
        if word.hasSuffix("ies"), word.count > 4 { forms.insert(String(word.dropLast(3)) + "y") }
        if word.hasSuffix("oes"), word.count > 4 { forms.insert(String(word.dropLast(2))) }
        if word.hasSuffix("s"), !word.hasSuffix("ss"), word.count > 3 {
            forms.insert(String(word.dropLast()))
        }
        return forms
    }

    /// Lower is better: 0 exact, 1 a term starts with the query, 2 every query word starts a word of
    /// one term, 3 the query appears anywhere, 4 some word of a longer query starts a word of a term
    /// — so free text like "PC thighs" still finds the thighs. `nil` when it matches no term.
    static func score(query: String, terms: [String]) -> Int? {
        let queryWords = words(of: query)
        var best: Int?
        for term in terms {
            let score: Int?
            if term == query {
                score = 0
            } else if term.hasPrefix(query) {
                score = 1
            } else if wordsStart(words(of: term), with: queryWords) {
                score = 2
            } else if term.contains(query) {
                score = 3
            } else if queryWords.count > 1,
                anySignificantWord(of: queryWords, starts: words(of: term))
            {
                score = 4
            } else {
                score = nil
            }
            if let score, score < (best ?? .max) { best = score }
        }
        return best
    }

    /// Three letters or more, so a brand initialism or "of" does not match half the dictionary.
    private static func anySignificantWord(
        of queryWords: [String], starts termWords: [String]
    )
        -> Bool
    {
        queryWords.contains { queryWord in
            queryWord.count >= 3 && termWords.contains { $0.hasPrefix(queryWord) }
        }
    }

    private static func wordsStart(_ termWords: [String], with queryWords: [String]) -> Bool {
        !queryWords.isEmpty
            && queryWords.allSatisfy { queryWord in
                termWords.contains { $0.hasPrefix(queryWord) }
            }
    }
}
