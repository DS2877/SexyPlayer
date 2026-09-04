# PR — `import-progress-checklist` → `main`

`main` is ~205 commits behind and needs to catch up to the real state of the
app. This is a **fast-forward** (main has nothing the branch doesn't).

**Open it:**
https://github.com/DS2877/aeria/compare/main...import-progress-checklist

(The repo was renamed `SexyPlayer` → `aeria`; the old URL redirects.)

Or, since it's a clean fast-forward and you're the only committer, you can skip
the PR entirely:

```bash
git checkout main
git merge --ff-only import-progress-checklist
git push origin main
git checkout import-progress-checklist
```

---

## Title

```
Bring main up to date: SQLite catalog store, Aeria+ rebrand, launch-speed + feature sprints, Xcode Cloud fix
```

## Body

```
`main` was last updated at the M6 milestone (real provider import). Everything
since has lived on `import-progress-checklist`. This merges it all.

## The arc

- **SQLite catalog store** — the in-memory catalog was replaced by a real
  on-disk SQLite store (`CatalogDatabase`, two connections + WAL, generation-
  stamped streaming imports). Memory no longer scales with library size.
- **Aeria+ rebrand** — name, wordmark, blue (#3B9EFF) accent, app icon, Top
  Shelf, GitHub Pages site under `docs/`.
- **Feature-complete tvOS client** — Home (two-phase shaped rebuild + instant
  snapshot paint), VOD + Live TV browse with A–Z rails, Guide, natural-language
  Search, native + VLC playback with resume / zapping / Now Playing, Favorites,
  History, parental PIN, onboarding.
- **Launch-speed + sidebar sprint** (`release/SPRINT-speed-and-sidebar.md`) —
  schema v3 visibility-led composite indexes, a Europe-focused region filter
  with an English/Nordic language escape hatch, a facet cache, A–Z anchors
  computed in SQL, and a collapsing icon rail with keep-alive section panels.
  Fixes "way too slow" and "the menu isn't premium".
- **Feature + polish sprint** (`release/SPRINT-2026-09-features.md`) — NEW
  badges, a My List row, play-Continue-Watching-from-Home, "see all" a genre,
  series-detail depth (episode/season watched-marking), Surprise Me, a sleep
  timer, search "New to your library", resume-from-History, and a redesigned
  series episode section.
- **Xcode Cloud** — `ci_scripts/ci_post_clone.sh` generates the (gitignored)
  `.xcodeproj` with XcodeGen so Xcode Cloud can build. See
  `release/XCODE-CLOUD.md`.

## Verification

Built and run on a real Apple TV against a real Xtream provider — the user
confirms it builds and the speed regression is resolved. Full test suite
(~34 files) is green. A high-effort review pass over the two sprints produced
9 findings; the actionable ones are fixed in `73e745b` (review-pass fixes),
the rest are documented in `release/SPRINT-2026-09-features.md` §5.

## Not changed

Bundle id `com.aeriaplus.appletv`, entitlements, App Group, privacy manifests,
`SWIFT_VERSION`, `NSAllowsArbitraryLoads`.
```
