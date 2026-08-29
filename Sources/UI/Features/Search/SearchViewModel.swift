import Foundation
import Observation

@MainActor
@Observable
public final class SearchViewModel {

    public var query = ""
    public private(set) var intent: SearchIntent = .empty
    public private(set) var results: [SearchResult] = []
    public private(set) var isSearching = false
    public private(set) var hasSearched = false
    public private(set) var interpretedFrom = ""

    public struct Chip: Identifiable {
        public let id: String
        public let label: String
        let remove: (inout SearchIntent) -> Void
    }

    public var chips: [Chip] { Self.chips(for: intent) }

    private let repository: any CatalogRepository
    private let engine: SearchEngine
    private let ai: AIService

    public init(repository: any CatalogRepository, engine: SearchEngine, ai: AIService) {
        self.repository = repository
        self.engine = engine
        self.ai = ai
    }

    public func search(vocabulary: SearchVocabulary) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }

        intent = await ai.intent(for: trimmed, vocabulary: vocabulary)
        interpretedFrom = trimmed
        await runEngine()
        hasSearched = true
    }

    public func removeChip(_ chip: Chip) {
        var updated = intent
        chip.remove(&updated)
        intent = updated
        Task { await runEngine() }
    }

    public func clear() {
        query = ""
        intent = .empty
        results = []
        hasSearched = false
    }

    private func runEngine() async {
        let catalog = await repository.snapshot()
        results = engine.search(intent, in: catalog, limit: 150)
    }

    // MARK: - Chip mapping

    static func chips(for intent: SearchIntent) -> [Chip] {
        var chips: [Chip] = []

        for kind in intent.kinds {
            let label: String
            switch kind {
            case .movie: label = "Movies"
            case .series: label = "Series"
            case .liveChannel: label = "Live TV"
            }
            chips.append(Chip(id: "kind-\(kind.rawValue)", label: label) { intent in
                intent.kinds.removeAll { $0 == kind }
            })
        }
        for genre in intent.genres {
            chips.append(Chip(id: "genre-\(genre.rawValue)", label: genre.displayName) { intent in
                intent.genres.removeAll { $0 == genre }
            })
        }
        for lang in intent.audioLanguages {
            chips.append(Chip(id: "audio-\(lang.code)", label: "\(lang.displayName) audio") { intent in
                intent.audioLanguages.removeAll { $0 == lang }
            })
        }
        for lang in intent.subtitleLanguages {
            chips.append(Chip(id: "sub-\(lang.code)", label: "\(lang.displayName) subtitles") { intent in
                intent.subtitleLanguages.removeAll { $0 == lang }
            })
        }
        if let minYear = intent.minYear {
            chips.append(Chip(id: "minYear", label: "After \(minYear - 1)") { $0.minYear = nil })
        }
        if let maxYear = intent.maxYear {
            chips.append(Chip(id: "maxYear", label: "Before \(maxYear + 1)") { $0.maxYear = nil })
        }
        if let maxDur = intent.maxDurationMinutes {
            let label = maxDur >= 60 ? "Under \(maxDur / 60)h\(maxDur % 60 == 0 ? "" : " \(maxDur % 60)m")"
                                     : "Under \(maxDur)m"
            chips.append(Chip(id: "maxDur", label: label) { $0.maxDurationMinutes = nil })
        }
        if let q = intent.minQuality, q > .unknown {
            chips.append(Chip(id: "quality", label: "\(q.shortLabel)+") { $0.minQuality = nil })
        }
        return chips
    }
}
