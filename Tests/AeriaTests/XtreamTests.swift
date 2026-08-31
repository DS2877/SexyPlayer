import XCTest
@testable import Aeria

final class XtreamTests: XCTestCase {

    // MARK: URL building

    func testAPIURLsIncludeCredentials() throws {
        let api = try XCTUnwrap(XtreamAPI(host: "example.com:8080", username: "u", password: "p"))
        let live = api.url(.liveStreams).absoluteString
        XCTAssertTrue(live.contains("player_api.php"))
        XCTAssertTrue(live.contains("username=u"))
        XCTAssertTrue(live.contains("password=p"))
        XCTAssertTrue(live.contains("action=get_live_streams"))
    }

    func testHostGetsDefaultScheme() throws {
        let api = try XCTUnwrap(XtreamAPI(host: "example.com:8080", username: "u", password: "p"))
        XCTAssertEqual(api.origin.absoluteString, "http://example.com:8080")
    }

    func testStreamURLShapes() throws {
        let api = try XCTUnwrap(XtreamAPI(host: "http://h:80", username: "user", password: "pw"))
        XCTAssertEqual(api.liveStreamURL(id: 101).absoluteString, "http://h:80/live/user/pw/101.m3u8")
        XCTAssertEqual(api.vodStreamURL(id: 55, extension: "mkv").absoluteString, "http://h:80/movie/user/pw/55.mkv")
        XCTAssertEqual(api.seriesStreamURL(episodeID: "900", extension: ".mp4").absoluteString,
                       "http://h:80/series/user/pw/900.mp4")
    }

    // MARK: DTO decoding (panels are loose with types)

    func testLenientLiveStreamDecoding() throws {
        let json = """
        [
          {"stream_id": 101, "name": "SVT1", "epg_channel_id": "svt1.se", "category_id": "5"},
          {"stream_id": "102", "name": "TV4", "category_id": 5},
          {"stream_id": null, "name": "Broken"}
        ]
        """
        let items = try JSONDecoder().decode([XtreamDTO.LiveStream].self, from: Data(json.utf8))
        XCTAssertEqual(items[0].stream_id, 101)
        XCTAssertEqual(items[1].stream_id, 102)          // decoded from string
        XCTAssertEqual(items[1].category_id, "5")        // decoded from int
        XCTAssertNil(items[2].stream_id)
    }

    func testVODMissingFieldsTolerated() throws {
        let json = #"[{"stream_id": 7, "name": "Nobody"}]"#
        let items = try JSONDecoder().decode([XtreamDTO.VODStream].self, from: Data(json.utf8))
        XCTAssertEqual(items[0].stream_id, 7)
        XCTAssertNil(items[0].container_extension)
        XCTAssertNil(items[0].plot)
    }

    func testSeriesInfoDecoding() throws {
        let json = """
        {
          "seasons": [{"season_number": 1, "name": "Season 1"}],
          "episodes": {
            "1": [
              {"id": "900", "episode_num": 1, "title": "Pilot", "container_extension": "mp4",
               "info": {"plot": "It begins.", "duration_secs": 2640}}
            ]
          }
        }
        """
        let info = try JSONDecoder().decode(XtreamDTO.SeriesInfo.self, from: Data(json.utf8))
        XCTAssertEqual(info.episodes?["1"]?.first?.id, "900")
        XCTAssertEqual(info.episodes?["1"]?.first?.episode_num, 1)
        XCTAssertEqual(info.episodes?["1"]?.first?.info?.duration_secs, 2640)
    }

    func testAuthResponseExpiredDetected() throws {
        let json = #"{"user_info": {"auth": 1, "status": "Expired"}}"#
        let auth = try JSONDecoder().decode(XtreamDTO.AuthResponse.self, from: Data(json.utf8))
        XCTAssertEqual(auth.user_info?.status, "Expired")
    }
}
