import Foundation
import TVServices

/// tvOS Top Shelf: shows "Continue Watching" and "Recently Added" on the Apple
/// TV home screen when Aeria+ is the focused app. Reads a snapshot the app
/// writes to the shared App Group container — no app code, no network.
final class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent(completionHandler: @escaping ((any TVTopShelfContent)?) -> Void) {
        guard let payload = TopShelfStore.load() else {
            completionHandler(nil)
            return
        }

        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
        if let cw = Self.collection(title: "Continue Watching", items: payload.continueWatching) {
            sections.append(cw)
        }
        if let recent = Self.collection(title: "Recently Added", items: payload.recentlyAdded) {
            sections.append(recent)
        }

        guard !sections.isEmpty else {
            completionHandler(nil)
            return
        }
        completionHandler(TVTopShelfSectionedContent(sections: sections))
    }

    private static func collection(
        title: String, items: [TopShelfPayload.Item]
    ) -> TVTopShelfItemCollection<TVTopShelfSectionedItem>? {
        let mapped = items.compactMap(makeItem)
        guard !mapped.isEmpty else { return nil }
        let collection = TVTopShelfItemCollection(items: mapped)
        collection.title = title
        return collection
    }

    private static func makeItem(_ item: TopShelfPayload.Item) -> TVTopShelfSectionedItem {
        let node = TVTopShelfSectionedItem(identifier: item.id)
        node.title = item.title
        node.imageShape = item.routeKind == "channel" ? .square : .poster
        if let image = item.imageURL {
            node.setImageURL(image, for: [.screenScale1x, .screenScale2x])
        }
        if let link = item.deepLink {
            let action = TVTopShelfAction(url: link)
            node.displayAction = action
            node.playAction = action
        }
        return node
    }
}
