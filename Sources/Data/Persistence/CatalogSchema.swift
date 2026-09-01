import Foundation

/// The catalog store's schema and forward-only migrations, driven by
/// `PRAGMA user_version`.
///
/// The catalog is **disposable** — it can always be re-imported from the
/// provider, and all durable user state (favourites, watch progress, channel
/// history, preferences) lives in `UserDefaults`, untouched by this store. So a
/// schema change doesn't migrate data: it drops every catalog table and lets the
/// next launch re-import. That keeps migrations trivial and impossible to get
/// subtly wrong on a user's device.
enum CatalogSchema {

    /// Bump when any `CREATE TABLE` / index / codec below changes shape.
    /// v2: `gen` column on every content table (generation-stamped imports).
    static let version = 2

    /// Bring `connection` up to `version`, wiping catalog data on any change.
    static func migrate(_ connection: SQLiteConnection) throws {
        let current = try connection.scalarInt("PRAGMA user_version")
        guard current != version else { return }

        try connection.transaction {
            if current != 0 {
                for table in allTables {
                    try connection.execute("DROP TABLE IF EXISTS \(table)")
                }
            }
            try connection.execute(createSQL)
            // PRAGMA can't be parameterised or run inside sqlite3_exec with the
            // rest — set it on its own.
            try connection.execute("PRAGMA user_version = \(version)")
        }
    }

    private static let allTables = [
        "meta", "channel", "movie", "movie_genre",
        "series", "series_genre", "episode", "epg_event",
    ]

    /// One statement block, run once on a fresh (or just-wiped) database.
    private static let createSQL = """
    CREATE TABLE meta (
        key   TEXT PRIMARY KEY,
        value TEXT
    ) WITHOUT ROWID;

    CREATE TABLE channel (
        id           TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        name_fold    TEXT NOT NULL,
        category     TEXT NOT NULL,
        logo_url     TEXT,
        country_code TEXT,
        audio_langs  TEXT NOT NULL DEFAULT '',
        sub_langs    TEXT NOT NULL DEFAULT '',
        quality      TEXT NOT NULL DEFAULT 'unknown',
        stream_url   TEXT NOT NULL,
        epg_id       TEXT,
        sort_index   INTEGER NOT NULL DEFAULT 0,
        is_adult     INTEGER NOT NULL DEFAULT 0,
        is_relevant  INTEGER NOT NULL DEFAULT 1,
        -- 0 = home country, 1 = other Nordic, 2 = English/generic, 3 = other.
        -- Recomputed by an UPDATE when the home regions change.
        region_priority INTEGER NOT NULL DEFAULT 2,
        -- Recency rank of a recently-watched channel (0 = most recent), else NULL.
        recent_rank  INTEGER,
        -- Import generation that last wrote this row. `finish` deletes rows left
        -- behind by an earlier generation (provider-removed titles).
        gen          INTEGER NOT NULL DEFAULT 0
    ) WITHOUT ROWID;
    CREATE INDEX channel_category   ON channel(category);
    CREATE INDEX channel_epg_id     ON channel(epg_id);
    CREATE INDEX channel_sort_index ON channel(sort_index);
    CREATE INDEX channel_name_fold  ON channel(name_fold);
    CREATE INDEX channel_for_you    ON channel(region_priority, sort_index);
    CREATE INDEX channel_gen        ON channel(gen);

    CREATE TABLE movie (
        id           TEXT PRIMARY KEY,
        title        TEXT NOT NULL,
        title_fold   TEXT NOT NULL,
        year         INTEGER,
        duration_min INTEGER,
        audio_langs  TEXT NOT NULL DEFAULT '',
        sub_langs    TEXT NOT NULL DEFAULT '',
        genres       TEXT NOT NULL DEFAULT '',
        quality      TEXT NOT NULL DEFAULT 'unknown',
        country_code TEXT,
        poster_url   TEXT,
        backdrop_url TEXT,
        synopsis     TEXT,
        cast_list    TEXT NOT NULL DEFAULT '',
        directors    TEXT NOT NULL DEFAULT '',
        stream_url   TEXT NOT NULL,
        added_at     REAL,
        is_adult     INTEGER NOT NULL DEFAULT 0,
        is_relevant  INTEGER NOT NULL DEFAULT 1,
        gen          INTEGER NOT NULL DEFAULT 0
    ) WITHOUT ROWID;
    CREATE INDEX movie_title_fold ON movie(title_fold);
    CREATE INDEX movie_added_at   ON movie(added_at);
    CREATE INDEX movie_year       ON movie(year);
    CREATE INDEX movie_gen        ON movie(gen);

    CREATE TABLE movie_genre (
        movie_id TEXT NOT NULL,
        genre    TEXT NOT NULL,
        PRIMARY KEY (movie_id, genre)
    ) WITHOUT ROWID;
    CREATE INDEX movie_genre_genre ON movie_genre(genre);

    CREATE TABLE series (
        id             TEXT PRIMARY KEY,
        title          TEXT NOT NULL,
        title_fold     TEXT NOT NULL,
        year           INTEGER,
        audio_langs    TEXT NOT NULL DEFAULT '',
        sub_langs      TEXT NOT NULL DEFAULT '',
        genres         TEXT NOT NULL DEFAULT '',
        quality        TEXT NOT NULL DEFAULT 'unknown',
        country_code   TEXT,
        poster_url     TEXT,
        backdrop_url   TEXT,
        synopsis       TEXT,
        provider_key   TEXT,
        added_at       REAL,
        is_adult       INTEGER NOT NULL DEFAULT 0,
        is_relevant    INTEGER NOT NULL DEFAULT 1,
        seasons_loaded INTEGER NOT NULL DEFAULT 0,
        gen            INTEGER NOT NULL DEFAULT 0
    ) WITHOUT ROWID;
    CREATE INDEX series_title_fold ON series(title_fold);
    CREATE INDEX series_added_at   ON series(added_at);
    CREATE INDEX series_gen        ON series(gen);

    CREATE TABLE series_genre (
        series_id TEXT NOT NULL,
        genre     TEXT NOT NULL,
        PRIMARY KEY (series_id, genre)
    ) WITHOUT ROWID;
    CREATE INDEX series_genre_genre ON series_genre(genre);

    CREATE TABLE episode (
        id           TEXT PRIMARY KEY,
        series_id    TEXT NOT NULL,
        season       INTEGER NOT NULL,
        episode      INTEGER NOT NULL,
        title        TEXT NOT NULL,
        overview     TEXT,
        duration_min INTEGER,
        still_url    TEXT,
        stream_url   TEXT NOT NULL,
        gen          INTEGER NOT NULL DEFAULT 0
    ) WITHOUT ROWID;
    CREATE INDEX episode_series ON episode(series_id, season, episode);
    CREATE INDEX episode_gen    ON episode(gen);

    CREATE TABLE epg_event (
        channel_epg_id TEXT NOT NULL,
        title          TEXT NOT NULL,
        subtitle       TEXT,
        description    TEXT,
        start_at       REAL NOT NULL,
        stop_at        REAL NOT NULL,
        category       TEXT,
        gen            INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (channel_epg_id, start_at)
    ) WITHOUT ROWID;
    CREATE INDEX epg_event_channel ON epg_event(channel_epg_id, start_at);
    CREATE INDEX epg_event_window  ON epg_event(start_at, stop_at);
    CREATE INDEX epg_event_gen     ON epg_event(gen);
    """
}
