import Foundation

/// A deliberately *messy* raw catalog — the kind of data real IPTV providers
/// hand over. The Normalizer's job is to make this presentable. Used by the
/// Simulator build and by tests.
public enum MockCatalogData {

    public static let providerID = "mock-provider-1"

    public static func rawCatalog(now: Date = .now) -> RawCatalog {
        RawCatalog(
            providerID: providerID,
            channels: channels.map { withPlayableStream($0) },
            vod: movies.enumerated().map { withPlayableStream($1, index: $0) },
            seriesEpisodes: episodes.enumerated().map { withPlayableStream($1, index: $0) },
            epg: epg(now: now)
        )
    }

    // MARK: - Real streams for the Simulator build

    /// Public-domain HLS test streams so playback actually works in the Simulator
    /// and for App Store review. Real providers supply their own URLs; nothing
    /// here is bundled content.
    static let testStreams: [String] = [
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8",
        "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8",
        "https://test-streams.mux.dev/pts_shift/master.m3u8",
    ]

    private static func stream(_ index: Int) -> String {
        testStreams[((index % testStreams.count) + testStreams.count) % testStreams.count]
    }

    private static func withPlayableStream(_ c: RawChannel) -> RawChannel {
        let idx = Int(StableHash.hash(c.providerKey) % UInt64(testStreams.count))
        return RawChannel(providerKey: c.providerKey, displayName: c.displayName, groupTitle: c.groupTitle,
                          logo: c.logo, tvgID: c.tvgID, streamURL: stream(idx))
    }

    private static func withPlayableStream(_ v: RawVODItem, index: Int) -> RawVODItem {
        RawVODItem(providerKey: v.providerKey, name: v.name, groupTitle: v.groupTitle, logo: v.logo,
                   streamURL: stream(index), plot: v.plot, genreText: v.genreText,
                   releaseDate: v.releaseDate, durationSecs: v.durationSecs, cast: v.cast, director: v.director,
                   // Staggered so "Recently Added" and the hero have a real order.
                   addedAt: Date().addingTimeInterval(-Double(index) * 6 * 3600))
    }

    private static func withPlayableStream(_ e: RawSeriesEpisode, index: Int) -> RawSeriesEpisode {
        RawSeriesEpisode(providerKey: e.providerKey, name: e.name, groupTitle: e.groupTitle, logo: e.logo,
                         streamURL: stream(index), plot: e.plot, explicitSeriesName: e.explicitSeriesName,
                         explicitSeason: e.explicitSeason, explicitEpisode: e.explicitEpisode)
    }

    // MARK: - Channels (messy names on purpose)

    static let channels: [RawChannel] = [
        RawChannel(providerKey: "ch-svt1", displayName: "SE | SVT1 HD [1080p]", groupTitle: "Sweden | General", logo: nil, tvgID: "svt1.se", streamURL: "https://example.com/live/svt1.m3u8"),
        RawChannel(providerKey: "ch-svt2", displayName: "SVT2.HD Sweden", groupTitle: "Sweden | General", logo: nil, tvgID: "svt2.se", streamURL: "https://example.com/live/svt2.m3u8"),
        RawChannel(providerKey: "ch-tv4", displayName: "TV4 HD", groupTitle: "SE: Entertainment", logo: nil, tvgID: "tv4.se", streamURL: "https://example.com/live/tv4.m3u8"),
        RawChannel(providerKey: "ch-tv4-2", displayName: "SE | TV4 FHD", groupTitle: "Sweden", logo: nil, tvgID: "tv4.se", streamURL: "https://example.com/live/tv4b.m3u8"),
        RawChannel(providerKey: "ch-kanal5", displayName: "Kanal 5 [SE] 1080P", groupTitle: "Sweden | Entertainment", logo: nil, tvgID: "kanal5.se", streamURL: "https://example.com/live/kanal5.m3u8"),
        RawChannel(providerKey: "ch-tv6", displayName: "TV6 SD", groupTitle: "Sweden", logo: nil, tvgID: "tv6.se", streamURL: "https://example.com/live/tv6.m3u8"),
        RawChannel(providerKey: "ch-svtnyh", displayName: "SVT Nyheter HD", groupTitle: "News", logo: nil, tvgID: "svtnyheter.se", streamURL: "https://example.com/live/svtn.m3u8"),
        RawChannel(providerKey: "ch-cnn", displayName: "US | CNN International FHD", groupTitle: "News", logo: nil, tvgID: "cnni.us", streamURL: "https://example.com/live/cnn.m3u8"),
        RawChannel(providerKey: "ch-bbcnews", displayName: "UK: BBC NEWS HD", groupTitle: "News", logo: nil, tvgID: "bbcnews.uk", streamURL: "https://example.com/live/bbcnews.m3u8"),
        RawChannel(providerKey: "ch-bbc1", displayName: "UK | BBC One HD", groupTitle: "United Kingdom | General", logo: nil, tvgID: "bbc1.uk", streamURL: "https://example.com/live/bbc1.m3u8"),
        RawChannel(providerKey: "ch-eurosport", displayName: "Eurosport 1 HD Sweden", groupTitle: "Sport", logo: nil, tvgID: "eurosport1.se", streamURL: "https://example.com/live/euro1.m3u8"),
        RawChannel(providerKey: "ch-vsport", displayName: "SE | V Sport Premium UHD", groupTitle: "Sweden | Sports", logo: nil, tvgID: "vsportpremium.se", streamURL: "https://example.com/live/vsport.m3u8"),
        RawChannel(providerKey: "ch-natgeo", displayName: "National Geographic HD [MULTI]", groupTitle: "Documentary", logo: nil, tvgID: "natgeo", streamURL: "https://example.com/live/natgeo.m3u8"),
        RawChannel(providerKey: "ch-discovery", displayName: "Discovery Channel FHD", groupTitle: "Documentary", logo: nil, tvgID: "discovery", streamURL: "https://example.com/live/disc.m3u8"),
        RawChannel(providerKey: "ch-cartoon", displayName: "SE | Cartoon Network HD", groupTitle: "Sweden | Kids", logo: nil, tvgID: "cartoonnetwork.se", streamURL: "https://example.com/live/cn.m3u8"),
        RawChannel(providerKey: "ch-disney", displayName: "Disney Channel HD", groupTitle: "Kids", logo: nil, tvgID: "disneychannel", streamURL: "https://example.com/live/disney.m3u8"),
        RawChannel(providerKey: "ch-mtv", displayName: "MTV 00s HD", groupTitle: "Music", logo: nil, tvgID: "mtv00s", streamURL: "https://example.com/live/mtv.m3u8"),
        RawChannel(providerKey: "ch-nrk1", displayName: "NO | NRK1 HD", groupTitle: "Norway | General", logo: nil, tvgID: "nrk1.no", streamURL: "https://example.com/live/nrk1.m3u8"),
        RawChannel(providerKey: "ch-dr1", displayName: "DK | DR1 HD", groupTitle: "Denmark | General", logo: nil, tvgID: "dr1.dk", streamURL: "https://example.com/live/dr1.m3u8"),
        RawChannel(providerKey: "ch-yle", displayName: "FI | YLE TV1 HD", groupTitle: "Finland | General", logo: nil, tvgID: "yletv1.fi", streamURL: "https://example.com/live/yle1.m3u8"),
    ]

    // MARK: - Movies
    //
    // All public-domain titles (real TMDB matches, so the demo shows real
    // posters / cast) wrapped in the kind of messy provider formatting the
    // Normalizer exists to clean up. Nothing here is bundled — playback uses
    // Apple/Mux test streams.

    static let movies: [RawVODItem] = [
        RawVODItem(providerKey: "m-notld", name: "VOD: Night of the Living Dead (1968) 1080p", groupTitle: "Movies | Horror", logo: nil, streamURL: "https://example.com/vod/notld.mp4", plot: "A disparate group of strangers barricade themselves in a farmhouse as the recently dead rise and attack the living.", genreText: "Horror, Thriller", releaseDate: "1968-10-01", durationSecs: 96 * 60, cast: "Duane Jones, Judith O'Dea", director: "George A. Romero"),
        RawVODItem(providerKey: "m-nosferatu", name: "Nosferatu 1922 [SilentFilm] Restored 1080p", groupTitle: "Movies | Horror", logo: nil, streamURL: "https://example.com/vod/nosferatu.mp4", plot: "The vampire Count Orlok expresses interest in a new residence and a real-estate agent's wife.", genreText: "Horror, Fantasy", releaseDate: "1922", durationSecs: 94 * 60, cast: "Max Schreck, Greta Schröder", director: "F. W. Murnau"),
        RawVODItem(providerKey: "m-metropolis", name: "Metropolis.1927.Restored.2160p", groupTitle: "Movies | Sci-Fi", logo: nil, streamURL: "https://example.com/vod/metropolis.mp4", plot: "In a futuristic city sharply divided between the working class and the city planners, the son of the city's mastermind falls in love with a working-class prophet.", genreText: "Sci-Fi, Drama", releaseDate: "1927-01-10", durationSecs: 153 * 60, cast: "Brigitte Helm, Alfred Abel", director: "Fritz Lang"),
        RawVODItem(providerKey: "m-caligari", name: "The Cabinet of Dr. Caligari [1920] EN SweSub", groupTitle: "Horror", logo: nil, streamURL: "https://example.com/vod/caligari.mp4", plot: "A hypnotist uses a somnambulist to commit murders in a small German town.", genreText: "Horror, Thriller, Mystery", releaseDate: "1920", durationSecs: 76 * 60, cast: "Werner Krauss, Conrad Veidt", director: "Robert Wiene"),
        RawVODItem(providerKey: "m-charade", name: "Charade (1963) 1080p MULTI", groupTitle: "Movies | Mystery", logo: nil, streamURL: "https://example.com/vod/charade.mp4", plot: "Romance and suspense in Paris as a woman is pursued by several men who want a fortune her murdered husband stole.", genreText: "Mystery, Comedy, Romance", releaseDate: "1963-12-05", durationSecs: 113 * 60, cast: "Cary Grant, Audrey Hepburn, Walter Matthau", director: "Stanley Donen"),
        RawVODItem(providerKey: "m-hisgirlfriday", name: "His Girl Friday 1940 720p", groupTitle: "Comedy", logo: nil, streamURL: "https://example.com/vod/hisgirlfriday.mp4", plot: "A newspaper editor uses every trick in the book to keep his ace reporter ex-wife from remarrying.", genreText: "Comedy, Drama, Romance", releaseDate: "1940-01-11", durationSecs: 92 * 60, cast: "Cary Grant, Rosalind Russell", director: "Howard Hawks"),
        RawVODItem(providerKey: "m-thegeneral", name: "The General (1926) - Buster Keaton - Restored 1080p", groupTitle: "Movies | Comedy", logo: nil, streamURL: "https://example.com/vod/thegeneral.mp4", plot: "During America's Civil War, Union spies steal an engineer's beloved locomotive, with his girl aboard.", genreText: "Comedy, Action, Adventure", releaseDate: "1926-12-31", durationSecs: 67 * 60, cast: "Buster Keaton, Marion Mack", director: "Buster Keaton"),
        RawVODItem(providerKey: "m-carnival", name: "Carnival of Souls.1962.SweSub.1080p", groupTitle: "Movies | Horror", logo: nil, streamURL: "https://example.com/vod/carnival.mp4", plot: "After a traumatic accident, a woman becomes drawn to a mysterious abandoned carnival.", genreText: "Horror, Mystery", releaseDate: "1962", durationSecs: 78 * 60, cast: "Candace Hilligoss", director: "Herk Harvey"),
        RawVODItem(providerKey: "m-doa", name: "D.O.A. (1949) film noir 1080p", groupTitle: "Movies | Thriller", logo: nil, streamURL: "https://example.com/vod/doa.mp4", plot: "Told in flashback, a fatally poisoned man tries to find out who killed him and why.", genreText: "Crime, Drama, Thriller", releaseDate: "1949-04-30", durationSecs: 83 * 60, cast: "Edmond O'Brien, Pamela Britton", director: "Rudolph Maté"),
        RawVODItem(providerKey: "m-detour", name: "Detour 1945 [Noir] SweSub", groupTitle: "Thriller", logo: nil, streamURL: "https://example.com/vod/detour.mp4", plot: "A hitchhiking musician is dragged into a spiral of blackmail and death on the road to Los Angeles.", genreText: "Crime, Drama, Thriller", releaseDate: "1945", durationSecs: 68 * 60, cast: "Tom Neal, Ann Savage", director: "Edgar G. Ulmer"),
        RawVODItem(providerKey: "m-plan9", name: "Plan 9 from Outer Space (1959) 720p", groupTitle: "Movies | Sci-Fi", logo: nil, streamURL: "https://example.com/vod/plan9.mp4", plot: "Aliens resurrect the dead as part of a plan to stop humanity from creating a doomsday weapon.", genreText: "Sci-Fi, Horror", releaseDate: "1959", durationSecs: 79 * 60, cast: "Gregory Walcott, Bela Lugosi", director: "Ed Wood"),
        RawVODItem(providerKey: "m-haxan", name: "SE | Häxan (1922) SWE SweSub 1080p", groupTitle: "Movies | Documentary", logo: nil, streamURL: "https://example.com/vod/haxan.mp4", plot: "A hybrid of documentary and dramatised sequences traces the history of witchcraft and superstition.", genreText: "Documentary, Horror", releaseDate: "1922-09-18", durationSecs: 105 * 60, cast: "Benjamin Christensen", director: "Benjamin Christensen"),
        RawVODItem(providerKey: "m-trip-moon", name: "A Trip to the Moon (1902) short film restored", groupTitle: "Movies | Sci-Fi", logo: nil, streamURL: "https://example.com/vod/tripmoon.mp4", plot: "A group of astronomers travel to the Moon in a cannon-propelled capsule.", genreText: "Sci-Fi, Adventure, Fantasy", releaseDate: "1902", durationSecs: 15 * 60, cast: "Georges Méliès", director: "Georges Méliès"),
        RawVODItem(providerKey: "m-sherlockjr", name: "Sherlock Jr. 1924 Buster Keaton 1080p", groupTitle: "Comedy", logo: nil, streamURL: "https://example.com/vod/sherlockjr.mp4", plot: "A film projectionist and aspiring detective is framed by a rival and dreams his way into the movie on screen.", genreText: "Comedy, Romance, Action", releaseDate: "1924-04-21", durationSecs: 45 * 60, cast: "Buster Keaton, Kathryn McGuire", director: "Buster Keaton"),
        RawVODItem(providerKey: "m-dementia13", name: "Dementia 13 (1963) Coppola 1080p", groupTitle: "Movies | Horror", logo: nil, streamURL: "https://example.com/vod/dementia13.mp4", plot: "An axe murderer terrorises an Irish family gathered at their castle estate.", genreText: "Horror, Thriller", releaseDate: "1963", durationSecs: 75 * 60, cast: "William Campbell, Luana Anders", director: "Francis Ford Coppola"),
    ]

    // MARK: - Series episodes (structure must be reconstructed from names)
    //
    // Public-domain vintage TV so the reconstruction demo works without any
    // rights questions.

    static let episodes: [RawSeriesEpisode] = [
        RawSeriesEpisode(providerKey: "e-holmes-s01e01", name: "Sherlock Holmes (1954) S01E01 - The Case of the Cunningham Heritage 1080p", groupTitle: "Series | Mystery", logo: nil, streamURL: "https://example.com/series/holmes/s01e01.mp4", plot: "Holmes and Watson meet for the first time and take on a double murder."),
        RawSeriesEpisode(providerKey: "e-holmes-s01e02", name: "Sherlock Holmes 1x02 - The Case of Lady Beryl", groupTitle: "Series | Mystery", logo: nil, streamURL: "https://example.com/series/holmes/s01e02.mp4", plot: "A noblewoman confesses to a murder Holmes is certain she did not commit."),
        RawSeriesEpisode(providerKey: "e-holmes-s01e03", name: "Sherlock Holmes - Season 1 Episode 3 - The Case of the Pennsylvania Gun", groupTitle: "Series | Mystery", logo: nil, streamURL: "https://example.com/series/holmes/s01e03.mp4", plot: "An American feud follows an immigrant to London."),
        RawSeriesEpisode(providerKey: "e-cisco-s01e01", name: "The Cisco Kid S01E01 - Boomerang [Color] 720p", groupTitle: "Series | Western", logo: nil, streamURL: "https://example.com/series/cisco/s01e01.mp4", plot: "Cisco and Pancho clear a young man wrongly accused of robbery."),
        RawSeriesEpisode(providerKey: "e-cisco-s01e02", name: "The Cisco Kid 1x02 - The Will", groupTitle: "Series | Western", logo: nil, streamURL: "https://example.com/series/cisco/s01e02.mp4", plot: "A forged will threatens to cheat a widow out of her ranch."),
        RawSeriesEpisode(providerKey: "e-cisco-s02e01", name: "The Cisco Kid S02E01 - Bell of Santa Margarita 720p", groupTitle: "Series | Western", logo: nil, streamURL: "https://example.com/series/cisco/s02e01.mp4", plot: "Cisco and Pancho protect a mission's silver bell from thieves."),
        RawSeriesEpisode(providerKey: "e-osb-s01e01", name: "One Step Beyond S01E01 - The Bride Possessed", groupTitle: "Series | Mystery", logo: nil, streamURL: "https://example.com/series/osb/s01e01.mp4", plot: "A newlywed woman begins speaking in the voice of a stranger who died violently."),
        RawSeriesEpisode(providerKey: "e-osb-s01e02", name: "One Step Beyond - Season 1 Episode 2 - Night of April 14th", groupTitle: "Series | Mystery", logo: nil, streamURL: "https://example.com/series/osb/s01e02.mp4", plot: "Passengers booked on the Titanic are troubled by premonitions."),
    ]

    // MARK: - EPG (built relative to `now` so "Tonight" always has data)

    static func epg(now: Date) -> [RawEPGEvent] {
        let cal = Calendar(identifier: .gregorian)
        let startOfEvening = cal.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now

        func slots(channelID: String, titles: [String]) -> [RawEPGEvent] {
            var events: [RawEPGEvent] = []
            var cursor = cal.date(byAdding: .hour, value: -2, to: startOfEvening) ?? startOfEvening
            for title in titles {
                let end = cal.date(byAdding: .minute, value: 60, to: cursor) ?? cursor
                events.append(RawEPGEvent(channelID: channelID, title: title, subtitle: nil,
                                          description: "\(title) on \(channelID).",
                                          start: cursor, stop: end, category: nil))
                cursor = end
            }
            return events
        }

        return
            slots(channelID: "svt1.se", titles: ["Gomorron Sverige", "Rapport", "Aktuellt", "Uppdrag granskning", "Nyheter", "Dokument inifrån"]) +
            slots(channelID: "tv4.se", titles: ["Nyhetsmorgon", "Efter fem", "Nyheterna", "Bäst i test", "Farmen", "Brottsjournalen"]) +
            slots(channelID: "kanal5.se", titles: ["Simpsons", "Friends", "Long Way Up", "MasterChef", "Alone", "Gordon Ramsay"]) +
            slots(channelID: "bbc1.uk", titles: ["Breakfast", "Bargain Hunt", "BBC News", "EastEnders", "Planet Earth III", "Match of the Day"]) +
            slots(channelID: "natgeo", titles: ["Car SOS", "Air Crash Investigation", "Drain the Oceans", "Cosmos", "Wicked Tuna", "Science of Stupid"])
    }
}
