import SwiftUI

/// A titled horizontal rail. Lazy so only visible cards render — the pattern
/// the whole app uses for large libraries.
public struct Shelf<Item: Identifiable, Card: View>: View {
    let title: String
    let subtitle: String?
    let items: [Item]
    @ViewBuilder let card: (Item) -> Card

    public init(
        title: String,
        subtitle: String? = nil,
        items: [Item],
        @ViewBuilder card: @escaping (Item) -> Card
    ) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
        self.card = card
    }

    public var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: Metrics.space2) {
                SectionHeader(title, subtitle: subtitle)
                    .padding(.horizontal, Metrics.screenMargin)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Metrics.cardSpacing) {
                        ForEach(items) { item in
                            card(item)
                        }
                    }
                    .padding(.horizontal, Metrics.screenMargin)
                    .padding(.vertical, Metrics.space3)   // room for focus lift
                }
            }
            .focusSection()
        }
    }
}
