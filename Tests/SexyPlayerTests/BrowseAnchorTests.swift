import XCTest
@testable import SexyPlayer

/// Covers the A–Z jump index: first-letter grouping, digit/symbol → "#",
/// diacritic folding, and that indices line up with the sorted list.
final class BrowseAnchorTests: XCTestCase {

    private func url(_ s: String) -> URL { URL(string: s)! }

    private func movie(_ title: String) -> Movie {
        Movie(id: CatalogID(rawValue: "m-\(title)"), title: title, streamURL: url("https://x/\(title)"))
    }

    private func channel(_ name: String, number: Int) -> Channel {
        Channel(id: CatalogID(rawValue: "c-\(name)"), name: name, category: "All",
                streamURL: url("https://x/\(name)"), sortIndex: number)
    }

    @MainActor
    func testMovieAnchorsGroupByFirstLetter() async {
        let repo = InMemoryCatalogRepository()
        await repo.load(Catalog(movies: [
            movie("Arrival"), movie("Amélie"), movie("Blade Runner"),
            movie("Dune"), movie("2001: A Space Odyssey"), movie("«Amores perros»"),
        ]))

        let anchors = await repo.movieTitleAnchors(filter: CatalogFilter(sort: .titleAscending))
        let letters = anchors.map(\.letter)

        XCTAssertEqual(letters.first, "#")            // "2001" sorts first, bucket "#"
        XCTAssertTrue(letters.contains("A"))
        XCTAssertTrue(letters.contains("B"))
        XCTAssertTrue(letters.contains("D"))
        XCTAssertEqual(Set(letters).count, letters.count, "one anchor per letter")

        // Indices must address the same sorted+filtered list the grid pages.
        let page = await repo.movies(filter: CatalogFilter(sort: .titleAscending), page: 0, pageSize: 100)
        for anchor in anchors {
            XCTAssertEqual(repo_anchorLetter(page[anchor.index].title), anchor.letter)
        }
    }

    @MainActor
    func testChannelAnchorsUseNameOrder() async {
        let repo = InMemoryCatalogRepository()
        await repo.load(Catalog(channels: [
            channel("Zebra TV", number: 1),
            channel("Alpha News", number: 2),
            channel("Movie Central", number: 3),
        ]))

        let anchors = await repo.channelTitleAnchors(in: "All")
        XCTAssertEqual(anchors.map(\.letter), ["A", "M", "Z"])
        XCTAssertEqual(anchors.first?.index, 0)
    }

    /// Mirrors `InMemoryCatalogRepository.anchorLetter` for the assertion above.
    private func repo_anchorLetter(_ title: String) -> String {
        let stripped = title.folding(options: .diacriticInsensitive, locale: nil)
            .drop { !$0.isLetter && !$0.isNumber }
        guard let first = stripped.first else { return "#" }
        return first.isNumber ? "#" : first.uppercased()
    }
}
