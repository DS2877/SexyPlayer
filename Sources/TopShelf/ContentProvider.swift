import Foundation
import TVServices

/// tvOS Top Shelf: shows "Continue Watching" and "Recently Added" on the Apple TV
/// home screen when Aeria+ is the focused app. Reads a snapshot the app writes to
/// the shared App Group container; no app code or network of its own.
final class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent() async -> (any TVTopShelfContent)? {
        guard let payload = TopShelfStore.load() else { return nil }

        let sections = [
            Self.section(title: "Continue Watching", items: payload.continueWatching),
            Self.section(title: "Recently Added", items: payload.recentlyAdded),
        ].compactMap { $0 }

        return sections.isEmpty ? nil : TVTopShelfSectionedContent(sections: sections)
    }

    private static func section(title: String, items: [TopShelfPayload.Item]) -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        let mapped = items.compactMap(sectionedItem)
        guard !mapped.isEmpty else { return nil }
        let collection = TVTopShelfItemCollection(items: mapped)
        collection.title = title
        return collection
    }

    private static func sectionedItem(_ item: TopShelfPayload.Item) -> TVTopShelfSectionedItem? {
        let node = TVTopShelfSectionedItem(identifier: item.id)
        node.title = item.title
        if let image = item.imageURL {
            node.setImageURL(image, for: [.screenScale1x, .screenScale2x])
        }
        node.imageShape = (item.routeKind == "channel") ? .square : .poster
        if let link = item.deepLink {
            node.displayAction = TVTopShelfAction(url: link)
            node.playAction = TVTopShelfAction(url: link)
        }
        return node
    }
}
