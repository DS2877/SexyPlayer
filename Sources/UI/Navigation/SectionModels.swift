import Foundation
import Observation

/// Keeps each section's view model alive for the life of the app.
///
/// `SidebarShell` renders its content with a `switch`, so SwiftUI tears the old
/// screen down and builds a new one every time the selection changes — and the
/// sidebar is *focus-driven*, so simply scrolling from Home to History destroys
/// and rebuilds seven screens on the way past. With the models owned by the
/// views, every one of those rebuilds re-ran the queries.
///
/// Holding them here means a section you've already visited comes back with its
/// data already in hand: switching sections is instant, and moving through the
/// sidebar costs nothing.
///
/// Models are created lazily on first visit, so an unopened section costs
/// nothing either.
@MainActor
@Observable
public final class SectionModels {

    private var homeModel: HomeViewModel?
    private var liveTVModel: LiveTVBrowseViewModel?
    private var moviesModel: VODBrowseViewModel?
    private var seriesModel: VODBrowseViewModel?
    private var guideModel: GuideViewModel?
    private var searchModel: SearchViewModel?

    public init() {}

    func home(_ env: AppEnvironment) -> HomeViewModel {
        if let homeModel { return homeModel }
        let model = HomeViewModel(
            repository: env.repository,
            watchProgress: env.watchProgress,
            preferences: env.preferences,
            metadata: env.metadata,
            channelHistory: env.channelHistory
        )
        if let providerID = env.activeProvider?.id { model.restoreSnapshot(providerID: providerID) }
        homeModel = model
        return model
    }

    func liveTV(_ env: AppEnvironment) -> LiveTVBrowseViewModel {
        if let liveTVModel { return liveTVModel }
        let model = LiveTVBrowseViewModel(repository: env.repository)
        liveTVModel = model
        return model
    }

    func vod(_ kind: BrowseKind, _ env: AppEnvironment) -> VODBrowseViewModel {
        switch kind {
        case .movies:
            if let moviesModel { return moviesModel }
            let model = makeVOD(kind, env)
            moviesModel = model
            return model
        case .series:
            if let seriesModel { return seriesModel }
            let model = makeVOD(kind, env)
            seriesModel = model
            return model
        }
    }

    private func makeVOD(_ kind: BrowseKind, _ env: AppEnvironment) -> VODBrowseViewModel {
        let model = VODBrowseViewModel(kind: kind, repository: env.repository,
                                       watchProgress: env.watchProgress)
        model.filter.sort = env.preferences.preferences.defaultSort
        return model
    }

    func guide(_ env: AppEnvironment) -> GuideViewModel {
        if let guideModel { return guideModel }
        let model = GuideViewModel(repository: env.repository)
        guideModel = model
        return model
    }

    func search(_ env: AppEnvironment) -> SearchViewModel {
        if let searchModel { return searchModel }
        let model = SearchViewModel(repository: env.repository, engine: env.searchEngine, ai: env.aiService)
        searchModel = model
        return model
    }

    /// Drop everything — the library underneath these models is gone
    /// (provider switched or removed).
    public func reset() {
        homeModel = nil
        liveTVModel = nil
        moviesModel = nil
        seriesModel = nil
        guideModel = nil
        searchModel = nil
    }
}
