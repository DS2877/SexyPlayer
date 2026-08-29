import Foundation

/// A deliberately *messy* raw catalog — the kind of data real IPTV providers
/// hand over. The Normalizer's job is to make this presentable. Used by the
/// Simulator build and by tests.
public enum MockCatalogData {

    public static let providerID = "mock-provider-1"

    public static func rawCatalog(now: Date = .now) -> RawCatalog {
        RawCatalog(
            providerID: providerID,
            channels: channels,
            vod: movies,
            seriesEpisodes: episodes,
            epg: epg(now: now)
        )
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

    static let movies: [RawVODItem] = [
        RawVODItem(providerKey: "m-sicario", name: "VOD: Sicario (2015) 1080p", groupTitle: "Movies | Thriller", logo: nil, streamURL: "https://example.com/vod/sicario.mp4", plot: "An idealistic FBI agent is enlisted by a task force to bring down a cartel.", genreText: "Action, Crime, Thriller", releaseDate: "2015-09-18", durationSecs: 121 * 60, cast: "Emily Blunt, Benicio del Toro, Josh Brolin", director: "Denis Villeneuve"),
        RawVODItem(providerKey: "m-hereditary", name: "Hereditary 2018 [SweSub] 1080p", groupTitle: "Movies | Horror", logo: nil, streamURL: "https://example.com/vod/hereditary.mp4", plot: "A grieving family is haunted by disturbing occurrences.", genreText: "Horror, Mystery", releaseDate: "2018", durationSecs: 127 * 60, cast: "Toni Collette, Alex Wolff", director: "Ari Aster"),
        RawVODItem(providerKey: "m-conjuring", name: "The Conjuring (2013) SWE SUB 1080p", groupTitle: "Horror", logo: nil, streamURL: "https://example.com/vod/conjuring.mp4", plot: "Paranormal investigators help a family terrorized by a dark presence.", genreText: "Horror, Thriller", releaseDate: "2013-07-19", durationSecs: 112 * 60, cast: "Vera Farmiga, Patrick Wilson", director: "James Wan"),
        RawVODItem(providerKey: "m-babadook", name: "The Babadook [2014] EN 1080p SweSub", groupTitle: "Movies | Horror", logo: nil, streamURL: "https://example.com/vod/babadook.mp4", plot: "A single mother and her son are tormented by a sinister presence.", genreText: "Horror, Drama", releaseDate: "2014", durationSecs: 94 * 60, cast: "Essie Davis", director: "Jennifer Kent"),
        RawVODItem(providerKey: "m-parasite", name: "Parasite.2019.1080p.MULTI", groupTitle: "Movies | Drama", logo: nil, streamURL: "https://example.com/vod/parasite.mp4", plot: "Greed and class discrimination threaten a newly formed symbiotic relationship.", genreText: "Drama, Thriller, Comedy", releaseDate: "2019-05-30", durationSecs: 132 * 60, cast: "Song Kang-ho", director: "Bong Joon-ho"),
        RawVODItem(providerKey: "m-grandbudapest", name: "The Grand Budapest Hotel (2014) 1080p", groupTitle: "Movies | Comedy", logo: nil, streamURL: "https://example.com/vod/gbh.mp4", plot: "A concierge and his protégé become embroiled in a theft and its aftermath.", genreText: "Comedy, Adventure", releaseDate: "2014", durationSecs: 99 * 60, cast: "Ralph Fiennes", director: "Wes Anderson"),
        RawVODItem(providerKey: "m-superbad", name: "Superbad 2007 720p", groupTitle: "Comedy", logo: nil, streamURL: "https://example.com/vod/superbad.mp4", plot: "Two co-dependent high schoolers try to score alcohol for a party.", genreText: "Comedy", releaseDate: "2007", durationSecs: 113 * 60, cast: "Jonah Hill, Michael Cera", director: "Greg Mottola"),
        RawVODItem(providerKey: "m-madmax", name: "Mad Max Fury Road (2015) 4K", groupTitle: "Movies | Action", logo: nil, streamURL: "https://example.com/vod/madmax.mp4", plot: "In a post-apocalyptic wasteland, a woman rebels against a tyrant.", genreText: "Action, Adventure, Sci-Fi", releaseDate: "2015", durationSecs: 120 * 60, cast: "Tom Hardy, Charlize Theron", director: "George Miller"),
        RawVODItem(providerKey: "m-dune", name: "Dune Part Two 2024 2160p UHD", groupTitle: "Movies | Sci-Fi", logo: nil, streamURL: "https://example.com/vod/dune2.mp4", plot: "Paul Atreides unites with the Fremen to wage war against House Harkonnen.", genreText: "Sci-Fi, Adventure", releaseDate: "2024-03-01", durationSecs: 166 * 60, cast: "Timothée Chalamet, Zendaya", director: "Denis Villeneuve"),
        RawVODItem(providerKey: "m-arrival", name: "Arrival (2016) 1080p SweSub", groupTitle: "Sci-Fi", logo: nil, streamURL: "https://example.com/vod/arrival.mp4", plot: "A linguist works to communicate with extraterrestrial visitors.", genreText: "Sci-Fi, Drama, Mystery", releaseDate: "2016", durationSecs: 116 * 60, cast: "Amy Adams, Jeremy Renner", director: "Denis Villeneuve"),
        RawVODItem(providerKey: "m-en-man", name: "SE | En man som heter Ove (2015) 1080p", groupTitle: "Movies | Swedish", logo: nil, streamURL: "https://example.com/vod/ove.mp4", plot: "A grumpy widower's suicide plans are interrupted by lively new neighbours.", genreText: "Comedy, Drama", releaseDate: "2015", durationSecs: 116 * 60, cast: "Rolf Lassgård", director: "Hannes Holm"),
        RawVODItem(providerKey: "m-tirol", name: "SE: Sameblod (2016) SWE 1080p", groupTitle: "Movies | Swedish", logo: nil, streamURL: "https://example.com/vod/sameblod.mp4", plot: "A reindeer-herding Sámi girl faces racism in 1930s Sweden.", genreText: "Drama", releaseDate: "2016", durationSecs: 110 * 60, cast: "Lene Cecilia Sparrok", director: "Amanda Kernell"),
        RawVODItem(providerKey: "m-shortfilm", name: "The Silent Child (2017) short film 720p", groupTitle: "Movies | Drama", logo: nil, streamURL: "https://example.com/vod/silentchild.mp4", plot: "A deaf child learns to communicate through sign language.", genreText: "Drama", releaseDate: "2017", durationSecs: 20 * 60, cast: "Rachel Shenton", director: "Chris Overton"),
        RawVODItem(providerKey: "m-nobody", name: "Nobody.2021.1080p", groupTitle: "Action", logo: nil, streamURL: "https://example.com/vod/nobody.mp4", plot: "A bystander who intervenes in a robbery becomes a target.", genreText: "Action, Thriller", releaseDate: "2021", durationSecs: 92 * 60, cast: "Bob Odenkirk", director: "Ilya Naishuller"),
        RawVODItem(providerKey: "m-knives", name: "Knives Out (2019) 1080p MULTI", groupTitle: "Movies | Mystery", logo: nil, streamURL: "https://example.com/vod/knivesout.mp4", plot: "A detective investigates the death of the patriarch of an eccentric family.", genreText: "Comedy, Crime, Mystery", releaseDate: "2019", durationSecs: 130 * 60, cast: "Daniel Craig, Ana de Armas", director: "Rian Johnson"),
        RawVODItem(providerKey: "m-whiplash", name: "Whiplash 2014 1080p", groupTitle: "Drama", logo: nil, streamURL: "https://example.com/vod/whiplash.mp4", plot: "A young drummer enrolls at a cut-throat music conservatory.", genreText: "Drama, Music", releaseDate: "2014", durationSecs: 106 * 60, cast: "Miles Teller, J.K. Simmons", director: "Damien Chazelle"),
    ]

    // MARK: - Series episodes (structure must be reconstructed from names)

    static let episodes: [RawSeriesEpisode] = [
        RawSeriesEpisode(providerKey: "e-tlou-s01e01", name: "The Last of Us S01E01 - When You're Lost in the Darkness [SweSub] 1080p", groupTitle: "Series | Drama", logo: nil, streamURL: "https://example.com/series/tlou/s01e01.mp4", plot: "Twenty years after a fungal outbreak, Joel is tasked with smuggling Ellie."),
        RawSeriesEpisode(providerKey: "e-tlou-s01e02", name: "The Last of Us S01E02 - Infected SweSub 1080p", groupTitle: "Series | Drama", logo: nil, streamURL: "https://example.com/series/tlou/s01e02.mp4", plot: "Joel, Ellie and Tess traverse a ruined Boston."),
        RawSeriesEpisode(providerKey: "e-tlou-s01e03", name: "The Last of Us S01E03 - Long, Long Time 1080p", groupTitle: "Series | Drama", logo: nil, streamURL: "https://example.com/series/tlou/s01e03.mp4", plot: "Bill and Frank's story unfolds over years."),
        RawSeriesEpisode(providerKey: "e-tlou-s02e01", name: "The Last of Us 2x01 - Future Days 1080p", groupTitle: "Series | Drama", logo: nil, streamURL: "https://example.com/series/tlou/s02e01.mp4", plot: "Years later in Jackson, Wyoming."),
        RawSeriesEpisode(providerKey: "e-got-s01e01", name: "Game.of.Thrones.S01E01.Winter.Is.Coming.1080p", groupTitle: "Series | Fantasy", logo: nil, streamURL: "https://example.com/series/got/s01e01.mp4", plot: "Eddard Stark is torn between his family and an old friend."),
        RawSeriesEpisode(providerKey: "e-got-s01e02", name: "Game of Thrones - Season 1 Episode 2 - The Kingsroad", groupTitle: "Series | Fantasy", logo: nil, streamURL: "https://example.com/series/got/s01e02.mp4", plot: "Bran recovers; Jon leaves for the Wall."),
        RawSeriesEpisode(providerKey: "e-got-s02e01", name: "Game of Thrones S02E01 The North Remembers 1080p", groupTitle: "Series | Fantasy", logo: nil, streamURL: "https://example.com/series/got/s02e01.mp4", plot: "Tyrion arrives to take control as Hand of the King."),
        RawSeriesEpisode(providerKey: "e-thebear-s01e01", name: "The Bear S01E01 System [EN] SweSub", groupTitle: "Series | Comedy", logo: nil, streamURL: "https://example.com/series/bear/s01e01.mp4", plot: "A fine-dining chef returns to run his family's sandwich shop."),
        RawSeriesEpisode(providerKey: "e-thebear-s01e02", name: "The Bear S01E02 Hands SweSub", groupTitle: "Series | Comedy", logo: nil, streamURL: "https://example.com/series/bear/s01e02.mp4", plot: "Tensions rise in the kitchen."),
        RawSeriesEpisode(providerKey: "e-bron-s01e01", name: "SE | Bron/Broen S01E01 SWE 1080p", groupTitle: "Series | Swedish", logo: nil, streamURL: "https://example.com/series/bron/s01e01.mp4", plot: "A body is found on the Øresund Bridge between Sweden and Denmark."),
        RawSeriesEpisode(providerKey: "e-bron-s01e02", name: "SE | Bron/Broen S01E02 SWE 1080p", groupTitle: "Series | Swedish", logo: nil, streamURL: "https://example.com/series/bron/s01e02.mp4", plot: "Saga and Martin begin working together."),
        RawSeriesEpisode(providerKey: "e-chernobyl-s01e01", name: "Chernobyl S01E01 1:23:45 1080p", groupTitle: "Series | Drama", logo: nil, streamURL: "https://example.com/series/chernobyl/s01e01.mp4", plot: "An explosion at the nuclear plant."),
        RawSeriesEpisode(providerKey: "e-explained-s01e01", name: "Explained S01E01 - The Racial Wealth Gap (documentary)", groupTitle: "Series | Documentary", logo: nil, streamURL: "https://example.com/series/explained/s01e01.mp4", plot: "A look at the racial wealth gap in America."),
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
