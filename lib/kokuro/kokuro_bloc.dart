import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/anime.dart';
import '../../domain/entities/library_entry.dart';
import '../../domain/entities/watch_status.dart';
import '../../domain/repositories/anime_repository.dart';
import '../../data/datasources/jikan_remote_datasource.dart';
import 'app_strings.dart';

// ══════════════════════════════════════════════════════════
//  Events
// ══════════════════════════════════════════════════════════

sealed class KokuroEvent extends Equatable {
  const KokuroEvent();
  @override
  List<Object?> get props => [];
}

class LoadHome extends KokuroEvent {
  const LoadHome();
}

class LoadExplore extends KokuroEvent {
  final String? genre;
  final String? season;
  final String? year;
  final String? studio;
  final String? type;
  final String? rating;
  final String? sort;
  final bool upcoming;
  const LoadExplore({
    this.genre,
    this.season,
    this.year,
    this.studio,
    this.type,
    this.rating,
    this.sort,
    this.upcoming = false,
  });
  @override
  List<Object?> get props => [
    genre,
    season,
    year,
    studio,
    type,
    rating,
    sort,
    upcoming,
  ];
}

class LoadMoreExplore extends KokuroEvent {
  final String? genre;
  final String? season;
  final String? year;
  final String? studio;
  final String? type;
  final String? rating;
  final String? sort;
  final bool upcoming;
  const LoadMoreExplore({
    this.genre,
    this.season,
    this.year,
    this.studio,
    this.type,
    this.rating,
    this.sort,
    this.upcoming = false,
  });
  @override
  List<Object?> get props => [
    genre,
    season,
    year,
    studio,
    type,
    rating,
    sort,
    upcoming,
  ];
}

class LoadDetail extends KokuroEvent {
  final int animeId;
  const LoadDetail(this.animeId);
  @override
  List<Object?> get props => [animeId];
}

class LoadCharacter extends KokuroEvent {
  final AnimeCharacter character;
  final int animeId;
  const LoadCharacter({required this.character, required this.animeId});
  @override
  List<Object?> get props => [character, animeId];
}

class SearchAnime extends KokuroEvent {
  final String query;
  const SearchAnime(this.query);
  @override
  List<Object?> get props => [query];
}

class LoadMoreSearch extends KokuroEvent {
  final String query;
  const LoadMoreSearch(this.query);
  @override
  List<Object?> get props => [query];
}

class LoadLibrary extends KokuroEvent {
  const LoadLibrary();
}

class LoadGenreCounts extends KokuroEvent {
  const LoadGenreCounts();
}

class SubmitReview extends KokuroEvent {
  final int animeId;
  final AnimeReview review;
  const SubmitReview({required this.animeId, required this.review});
  @override
  List<Object?> get props => [animeId, review];
}

class ToggleWatchlistItem extends KokuroEvent {
  final Anime anime;
  const ToggleWatchlistItem(this.anime);
  @override
  List<Object?> get props => [anime];
}

class SetWatchStatus extends KokuroEvent {
  final Anime anime;
  final WatchStatus status;
  const SetWatchStatus(this.anime, this.status);
  @override
  List<Object?> get props => [anime, status];
}

class SetWatchProgress extends KokuroEvent {
  final Anime anime;
  final int watchedEpisodes;
  const SetWatchProgress(this.anime, this.watchedEpisodes);
  @override
  List<Object?> get props => [anime, watchedEpisodes];
}

class RemoveFromLibraryEvent extends KokuroEvent {
  final int animeId;
  const RemoveFromLibraryEvent(this.animeId);
  @override
  List<Object?> get props => [animeId];
}

class RateAnimeEvent extends KokuroEvent {
  final int animeId;
  final double rating;
  const RateAnimeEvent({required this.animeId, required this.rating});
  @override
  List<Object?> get props => [animeId, rating];
}

class RemoveRatingEvent extends KokuroEvent {
  final int animeId;
  const RemoveRatingEvent(this.animeId);
  @override
  List<Object?> get props => [animeId];
}

// ══════════════════════════════════════════════════════════
//  States
// ══════════════════════════════════════════════════════════

sealed class KokuroState extends Equatable {
  const KokuroState();
  @override
  List<Object?> get props => [];
}

class KokuroInitial extends KokuroState {}

class KokuroLoading extends KokuroState {}

class HomeLoaded extends KokuroState {
  final List<Anime> featured;
  final List<Anime> trending;
  final List<Anime> seasonAnime;
  final List<Anime> journey;
  final List<LibraryEntry> continueWatching;
  final Anime? dailyPick;
  final Set<int> watchlistIds;
  final List<Anime> upcoming;
  final List<Anime> movies;
  final String? spotlightGenre;
  final List<Anime> spotlightTitles;
  final List<Anime> recommendedForYou;
  final String? recommendedSeedTitle;
  final List<Anime> topRated;

  const HomeLoaded({
    required this.featured,
    required this.trending,
    required this.seasonAnime,
    this.journey = const [],
    this.continueWatching = const [],
    this.dailyPick,
    this.watchlistIds = const {},
    this.upcoming = const [],
    this.movies = const [],
    this.spotlightGenre,
    this.spotlightTitles = const [],
    this.recommendedForYou = const [],
    this.recommendedSeedTitle,
    this.topRated = const [],
  });

  HomeLoaded copyWith({
    List<Anime>? featured,
    List<Anime>? trending,
    List<Anime>? seasonAnime,
    List<Anime>? journey,
    List<LibraryEntry>? continueWatching,
    Anime? dailyPick,
    Set<int>? watchlistIds,
    List<Anime>? upcoming,
    List<Anime>? movies,
    String? spotlightGenre,
    List<Anime>? spotlightTitles,
    List<Anime>? recommendedForYou,
    String? recommendedSeedTitle,
    List<Anime>? topRated,
  }) {
    return HomeLoaded(
      featured: featured ?? this.featured,
      trending: trending ?? this.trending,
      seasonAnime: seasonAnime ?? this.seasonAnime,
      journey: journey ?? this.journey,
      continueWatching: continueWatching ?? this.continueWatching,
      dailyPick: dailyPick ?? this.dailyPick,
      watchlistIds: watchlistIds ?? this.watchlistIds,
      upcoming: upcoming ?? this.upcoming,
      movies: movies ?? this.movies,
      spotlightGenre: spotlightGenre ?? this.spotlightGenre,
      spotlightTitles: spotlightTitles ?? this.spotlightTitles,
      recommendedForYou: recommendedForYou ?? this.recommendedForYou,
      recommendedSeedTitle: recommendedSeedTitle ?? this.recommendedSeedTitle,
      topRated: topRated ?? this.topRated,
    );
  }

  @override
  List<Object?> get props => [
    featured,
    trending,
    seasonAnime,
    journey,
    continueWatching,
    dailyPick,
    watchlistIds,
    topRated,
  ];
}

class ExploreLoaded extends KokuroState {
  final List<Anime> anime;
  final String? selectedGenre;
  final bool hasMore;
  final bool isLoadingMore;
  final Map<String, int> genreCounts;

  const ExploreLoaded({
    required this.anime,
    this.selectedGenre,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.genreCounts = const {},
  });

  ExploreLoaded copyWith({
    List<Anime>? anime,
    String? selectedGenre,
    bool? hasMore,
    bool? isLoadingMore,
    Map<String, int>? genreCounts,
  }) {
    return ExploreLoaded(
      anime: anime ?? this.anime,
      selectedGenre: selectedGenre ?? this.selectedGenre,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      genreCounts: genreCounts ?? this.genreCounts,
    );
  }

  @override
  List<Object?> get props => [
    anime,
    selectedGenre,
    hasMore,
    isLoadingMore,
    genreCounts,
  ];
}

class DetailLoaded extends KokuroState {
  final Anime anime;
  final List<AnimeCharacter> characters;
  final List<AnimeEpisode> episodes;
  final List<Anime> recommendations;
  final List<AnimeReview> reviews;
  final bool isInWatchlist;
  final double? userRating;
  final WatchStatus? watchStatus;
  final int watchedEpisodes;

  const DetailLoaded({
    required this.anime,
    required this.characters,
    required this.episodes,
    required this.recommendations,
    this.reviews = const [],
    this.isInWatchlist = false,
    this.userRating,
    this.watchStatus,
    this.watchedEpisodes = 0,
  });

  DetailLoaded copyWith({
    Anime? anime,
    List<AnimeCharacter>? characters,
    List<AnimeEpisode>? episodes,
    List<Anime>? recommendations,
    List<AnimeReview>? reviews,
    bool? isInWatchlist,
    double? userRating,
    WatchStatus? watchStatus,
    int? watchedEpisodes,
  }) {
    return DetailLoaded(
      anime: anime ?? this.anime,
      characters: characters ?? this.characters,
      episodes: episodes ?? this.episodes,
      recommendations: recommendations ?? this.recommendations,
      reviews: reviews ?? this.reviews,
      isInWatchlist: isInWatchlist ?? this.isInWatchlist,
      userRating: userRating ?? this.userRating,
      watchStatus: watchStatus ?? this.watchStatus,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
    );
  }

  @override
  List<Object?> get props => [
    anime,
    characters,
    episodes,
    recommendations,
    reviews,
    isInWatchlist,
    userRating,
    watchStatus,
    watchedEpisodes,
  ];
}

class CharacterLoaded extends KokuroState {
  final AnimeCharacter character;
  final List<Anime> appearances;

  const CharacterLoaded({required this.character, required this.appearances});

  @override
  List<Object?> get props => [character, appearances];
}

class SearchLoaded extends KokuroState {
  final String query;
  final List<Anime> results;

  /// Characters matching the same query (from the character search), shown
  /// as a strip above the anime grid so people can find actors, not just
  /// titles.
  final List<AnimeCharacter> characters;
  final bool hasMore;
  final bool isLoadingMore;

  const SearchLoaded({
    required this.query,
    required this.results,
    this.characters = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  SearchLoaded copyWith({
    String? query,
    List<Anime>? results,
    List<AnimeCharacter>? characters,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return SearchLoaded(
      query: query ?? this.query,
      results: results ?? this.results,
      characters: characters ?? this.characters,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    query,
    results,
    characters,
    hasMore,
    isLoadingMore,
  ];
}

class LibraryLoaded extends KokuroState {
  final List<LibraryEntry> entries;
  final Map<int, double> ratings;

  /// Watchlist titles with a real future air-date from AniList, so the
  /// notifications menu can say "next episode airs soon" instead of nothing.
  final Map<int, ({DateTime at, int episode})> upcoming;

  const LibraryLoaded({
    required this.entries,
    required this.ratings,
    this.upcoming = const {},
  });

  LibraryLoaded copyWith({
    List<LibraryEntry>? entries,
    Map<int, double>? ratings,
    Map<int, ({DateTime at, int episode})>? upcoming,
  }) {
    return LibraryLoaded(
      entries: entries ?? this.entries,
      ratings: ratings ?? this.ratings,
      upcoming: upcoming ?? this.upcoming,
    );
  }

  @override
  List<Object?> get props => [entries, ratings, upcoming];
}

class KokuroError extends KokuroState {
  final String message;
  const KokuroError(this.message);
  @override
  List<Object?> get props => [message];
}

// ══════════════════════════════════════════════════════════
//  Bloc
// ══════════════════════════════════════════════════════════

class KokuroBloc extends Bloc<KokuroEvent, KokuroState> {
  final AnimeRepository _repo;
  static const _pageSize = 24;
  bool _genreCountsLoading = false;

  KokuroBloc({required this._repo}) : super(KokuroInitial()) {
    on<LoadHome>(_onLoadHome);
    on<LoadExplore>(_onLoadExplore);
    on<LoadMoreExplore>(_onLoadMoreExplore);
    on<LoadDetail>(_onLoadDetail);
    on<LoadCharacter>(_onLoadCharacter);
    on<SearchAnime>(_onSearch);
    on<LoadMoreSearch>(_onLoadMoreSearch);
    on<LoadLibrary>(_onLoadLibrary);
    on<LoadGenreCounts>(_onLoadGenreCounts);
    on<ToggleWatchlistItem>(_onToggleWatchlist);
    on<SetWatchStatus>(_onSetWatchStatus);
    on<SetWatchProgress>(_onSetWatchProgress);
    on<RemoveFromLibraryEvent>(_onRemoveFromLibrary);
    on<RateAnimeEvent>(_onRate);
    on<RemoveRatingEvent>(_onRemoveRating);
    on<SubmitReview>(_onSubmitReview);
  }

  Future<void> _onLoadHome(LoadHome event, Emitter<KokuroState> emit) async {
    emit(KokuroLoading());

    // All six feeds resolve in parallel so the home page opens as soon as
    // the slowest single fetch returns, not the sum of every call.
    final (
      popularResult,
      seasonResult,
      watchlistResult,
      libraryResult,
      upcomingResult,
      moviesResult,
    ) = await (
      _repo.getTopAnime(page: 1, limit: 10),
      _repo.getSeasonAnime(page: 1, limit: 10),
      _repo.getWatchlist(),
      _repo.getLibrary(),
      _repo.getUpcomingAnime(page: 1, limit: 10),
      _repo.getExploreList(type: 'Movie', page: 1, limit: 12),
    ).wait;

    final List<Anime> popular = popularResult.fold(
      (_) => <Anime>[],
      (r) => r.anime,
    );
    final List<Anime> season = seasonResult.fold(
      (_) => <Anime>[],
      (r) => r.anime,
    );
    final List<Anime> watchlist = watchlistResult.fold(
      (_) => <Anime>[],
      (r) => r,
    );
    final List<LibraryEntry> library = libraryResult.fold(
      (_) => <LibraryEntry>[],
      (r) => r,
    );
    final List<Anime> upcoming = _clean(
      upcomingResult.fold((_) => <Anime>[], (r) => r.anime),
    );
    final List<Anime> movies = _clean(
      moviesResult.fold((_) => <Anime>[], (r) => r.anime),
    );

    if (popular.isEmpty && season.isEmpty) {
      emit(const KokuroError(AppStrings.couldNotLoadAnime));
      return;
    }

    // Featured = top-rated picks (score-based), deduped across lists so the
    // hero can auto-rotate through several high-scoring titles.
    final topRated = <Anime>[];
    final heroSeen = <int>{};
    for (final a in [...popular, ...season]) {
      if (a.malId != 0 && a.score > 0 && heroSeen.add(a.malId)) {
        topRated.add(a);
      }
    }
    topRated.sort((a, b) => b.score.compareTo(a.score));
    final featured = topRated.take(5).toList();
    // Safety net: if nothing scored, fall back to any unique titles.
    if (featured.isEmpty) {
      for (final a in [...popular, ...season]) {
        if (a.malId != 0 && heroSeen.add(a.malId)) featured.add(a);
      }
    }
    if (featured.isEmpty && popular.isNotEmpty) {
      featured.add(popular.first);
    }

    // Top-10 chart — same score-ranked pool as the hero, kept as a full
    // ranking (chart rows intentionally may repeat hero titles, unlike
    // the browsing rows below which never repeat a title).
    final List<Anime> topChart = topRated.take(10).toList();

    // Every browsing row below dedupes against the hero + previously picked
    // rows so no title ever repeats on the same page. User-owned lists
    // (journey/continueWatching) are exempt — they are the user's data.
    final taken = <int>{};
    for (final a in featured) {
      if (a.malId != 0) taken.add(a.malId);
    }
    final List<Anime> trending = _dedupe(
      popular.length > 1 ? popular.sublist(1) : [],
      taken,
    );
    final List<Anime> seasonAnime = _dedupe(season, taken);
    final List<Anime> moviesClean = _dedupe(movies, taken);
    final List<Anime> upcomingClean = _dedupe(upcoming, taken);

    // "Continue Your Journey" = the user's real saved list (no trending
    // fallback — that used to repeat the adjacent Trending Threads row).
    final List<Anime> journey = watchlist.take(4).toList();

    // Real in-progress tracking when present.
    final continueWatching =
        library.where((e) => e.watchedEpisodes > 0 && !e.isCompleted).toList()
          ..sort(
            (a, b) => (b.updatedAt?.millisecondsSinceEpoch ?? 0).compareTo(
              a.updatedAt?.millisecondsSinceEpoch ?? 0,
            ),
          );

    // Genre spotlight rotates through the constellation genres one per day —
    // one extra fetch gives the page a fresh curated row every day.
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final spotlightGenre =
        _spotlightGenres[dayOfYear % _spotlightGenres.length];
    final spotlightResult = await _repo.getAnimeByGenre(
      genre: spotlightGenre,
      page: 1,
      limit: 12,
    );
    final spotlightTitles = _dedupe(
      _clean(spotlightResult.fold((_) => <Anime>[], (r) => r.anime)),
      taken,
    );

    // "Because you watched" — seeded from the most recent in-progress title,
    // falling back to the first saved title.
    final Anime? seed = continueWatching.isNotEmpty
        ? continueWatching.first.anime
        : watchlist.isNotEmpty
        ? watchlist.first
        : null;
    final recommendedForYou = seed == null || seed.malId == 0
        ? <Anime>[]
        : _dedupe(
            _clean(
              (await _repo.getRecommendations(
                seed.malId,
              )).getOrElse(() => <Anime>[]),
            ),
            taken,
          );
    final String? recommendedSeedTitle =
        recommendedForYou.isEmpty || seed == null ? null : seed.title;

    // "Daily Pick" — deterministic per day, and kept distinct from the hero
    // (its pool excludes every featured slide).
    final pool = <Anime>[];
    final seen = <int>{...taken};
    for (final anime in [
      ...moviesClean,
      ...upcomingClean,
      ...spotlightTitles,
      ...recommendedForYou,
      ...seasonAnime,
      ...trending,
    ]) {
      if (anime.malId == 0 || !seen.add(anime.malId)) continue;
      pool.add(anime);
    }
    final dailyPick = pool.isNotEmpty ? pool[dayOfYear % pool.length] : null;

    emit(
      HomeLoaded(
        featured: featured,
        trending: trending,
        seasonAnime: seasonAnime,
        journey: journey,
        continueWatching: continueWatching.take(4).toList(),
        dailyPick: dailyPick,
        upcoming: upcomingClean,
        movies: moviesClean,
        spotlightGenre: spotlightTitles.isEmpty ? null : spotlightGenre,
        spotlightTitles: spotlightTitles,
        recommendedForYou: recommendedForYou,
        recommendedSeedTitle: recommendedSeedTitle,
        topRated: topChart,
        watchlistIds: watchlist.map((a) => a.malId).toSet(),
      ),
    );
  }

  Future<void> _onLoadExplore(
    LoadExplore event,
    Emitter<KokuroState> emit,
  ) async {
    emit(KokuroLoading());

    final result = event.upcoming
        ? await _repo.getUpcomingAnime(page: 1, limit: _pageSize)
        : await _repo.getExploreList(
            genre: event.genre,
            season: event.season,
            year: event.year,
            studio: event.studio,
            type: event.type,
            rating: event.rating,
            sort: event.sort,
            page: 1,
            limit: _pageSize,
          );
    final List<Anime> anime = result.fold((_) => <Anime>[], (r) => r.anime);

    emit(
      ExploreLoaded(
        anime: anime,
        selectedGenre: event.genre,
        hasMore: anime.length >= _pageSize,
      ),
    );

    await _loadGenreCounts(emit);
  }

  static const _genreNames = [
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Fantasy',
    'Horror',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Thriller',
  ];

  /// Rotation for the daily genre spotlight — one fresh curated row per day
  /// using the same constellation genres the explore page visualizes.
  static const _spotlightGenres = [
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Fantasy',
    'Horror',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
  ];

  /// Drops malformed entries (malId == 0).
  static List<Anime> _clean(List<Anime> input) =>
      input.where((a) => a.malId != 0).toList();

  /// Keeps [source] items whose id isn't already in [taken], registering the
  /// kept ids so subsequent rows never repeat a title already shown.
  static List<Anime> _dedupe(List<Anime> source, Set<int> taken) {
    final out = <Anime>[];
    for (final a in source) {
      if (a.malId == 0 || !taken.add(a.malId)) continue;
      out.add(a);
    }
    return out;
  }

  Future<void> _loadGenreCounts(Emitter<KokuroState> emit) async {
    final current = state;
    if (current is! ExploreLoaded || _genreCountsLoading) return;
    _genreCountsLoading = true;
    try {
      final result = await _repo.getGenreCounts(_genreNames);
      final counts = result.fold((_) => const <String, int>{}, (c) => c);
      // Only land the counts on the exact ExploreLoaded this request started
      // from — a newer genre switch mid-flight must not get stale numbers.
      if (!emit.isDone && identical(state, current)) {
        emit((current).copyWith(genreCounts: counts));
      }
    } finally {
      _genreCountsLoading = false;
    }
  }

  Future<void> _onLoadGenreCounts(
    LoadGenreCounts event,
    Emitter<KokuroState> emit,
  ) => _loadGenreCounts(emit);

  /// Fetches the next single page of the current explore query (one page per
  /// event) so the grid grows lazily as the user scrolls. Dedupes by MAL id
  /// so pages that overlap never duplicate titles in the grid.
  Future<void> _onLoadMoreExplore(
    LoadMoreExplore event,
    Emitter<KokuroState> emit,
  ) async {
    if (state is! ExploreLoaded) return;
    final current = state as ExploreLoaded;
    if (current.isLoadingMore || !current.hasMore) return;

    emit(current.copyWith(isLoadingMore: true));

    final seen = <int>{...current.anime.map((a) => a.malId)};
    final page = (current.anime.length ~/ _pageSize) + 1;

    final result = event.upcoming
        ? await _repo.getUpcomingAnime(page: page, limit: _pageSize)
        : await _repo.getExploreList(
            genre: event.genre,
            season: event.season,
            year: event.year,
            studio: event.studio,
            type: event.type,
            rating: event.rating,
            sort: event.sort,
            page: page,
            limit: _pageSize,
          );
    final fetched = result.fold((_) => <Anime>[], (r) => r.anime);
    final fresh = fetched
        .where((a) => a.malId == 0 || seen.add(a.malId))
        .toList();

    emit(
      current.copyWith(
        anime: [...current.anime, ...fresh],
        hasMore: fetched.length >= _pageSize,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> _onLoadDetail(
    LoadDetail event,
    Emitter<KokuroState> emit,
  ) async {
    emit(KokuroLoading());

    final detailsResult = await _repo.getAnimeDetails(event.animeId);
    final anime = detailsResult.fold((_) => null, (a) => a);

    if (anime == null) {
      emit(const KokuroError(AppStrings.animeNotFound));
      return;
    }
    final libraryF = _repo.getLibrary();
    final ratingsF = _repo.getRatings();
    final userReviewsF = _repo.getUserReviews(event.animeId);

    final charsF = _spacedEmit(
      () => _repo.getCharacters(event.animeId),
      delay: const Duration(milliseconds: 450),
    );
    final epsF = _spacedEmit(
      () => _repo.getEpisodes(event.animeId),
      delay: const Duration(milliseconds: 850),
    );
    final recsF = _spacedEmit(
      () => _repo.getRecommendations(event.animeId),
      delay: const Duration(milliseconds: 1250),
    );
    final apiReviewsF = _spacedEmit(
      () => _repo.getReviews(event.animeId),
      delay: const Duration(milliseconds: 1650),
    );

    final chars = (await charsF).fold((_) => <AnimeCharacter>[], (c) => c);
    final eps = (await epsF).fold((_) => <AnimeEpisode>[], (e) => e);
    final recs = (await recsF).fold((_) => <Anime>[], (r) => r);
    final apiReviews = (await apiReviewsF).fold(
      (_) => <AnimeReview>[],
      (r) => r,
    );

    final userReviews = (await userReviewsF).fold(
      (_) => <AnimeReview>[],
      (r) => r,
    );
    final library = (await libraryF).fold((_) => <LibraryEntry>[], (l) => l);
    LibraryEntry? entry;
    for (final e in library) {
      if (e.anime.malId == event.animeId) {
        entry = e;
        break;
      }
    }
    final ratings = (await ratingsF).fold((_) => <int, double>{}, (r) => r);

    final allReviews = [...userReviews, ...apiReviews];
    allReviews.removeWhere((r) => r.text.isEmpty);

    emit(
      DetailLoaded(
        anime: anime,
        characters: chars,
        episodes: eps,
        recommendations: recs,
        reviews: allReviews,
        isInWatchlist: entry != null,
        userRating: ratings[event.animeId],
        watchStatus: entry?.status,
        watchedEpisodes: entry?.watchedEpisodes ?? 0,
      ),
    );
  }

  /// Runs an auxiliary detail request after `delay`, keeping real Jikan
  /// request starts ~400ms apart so the 3-requests/sec throttle isn't hit.
  Future<T> _spacedEmit<T>(
    Future<T> Function() request, {
    Duration delay = const Duration(milliseconds: 350),
  }) async {
    await Future<void>.delayed(delay);
    return request();
  }

  Future<void> _onLoadCharacter(
    LoadCharacter event,
    Emitter<KokuroState> emit,
  ) async {
    emit(KokuroLoading());

    final recsResult = await _repo.getRecommendations(event.animeId);
    final appearances = recsResult.fold((_) => <Anime>[], (r) => r);

    emit(CharacterLoaded(character: event.character, appearances: appearances));
  }

  Future<void> _onSearch(SearchAnime event, Emitter<KokuroState> emit) async {
    if (event.query.trim().isEmpty) {
      add(LoadExplore());
      return;
    }

    emit(KokuroLoading());

    // Kick off both lookups before awaiting so they run in parallel:
    // the anime grid and the character-strip resolve together.
    final animeFuture = _repo.searchAnime(
      query: event.query,
      page: 1,
      limit: _pageSize,
    );
    final charFuture = _repo.searchCharacters(query: event.query, limit: 8);
    final a = await animeFuture;
    final c = await charFuture;
    final List<Anime> anime = a.fold((_) => <Anime>[], (r) => r.anime);
    final List<AnimeCharacter> characters = c.fold(
      (_) => <AnimeCharacter>[],
      (r) => r,
    );

    emit(
      SearchLoaded(
        query: event.query,
        results: anime,
        characters: characters,
        hasMore: anime.length >= _pageSize,
      ),
    );
  }

  /// Loads the next search-result page as the grid approaches the bottom.
  Future<void> _onLoadMoreSearch(
    LoadMoreSearch event,
    Emitter<KokuroState> emit,
  ) async {
    if (state is! SearchLoaded) return;
    final current = state as SearchLoaded;
    if (current.isLoadingMore || !current.hasMore) return;

    emit(current.copyWith(isLoadingMore: true));

    final seen = <int>{...current.results.map((a) => a.malId)};
    final page = (current.results.length ~/ _pageSize) + 1;

    final result = await _repo.searchAnime(
      query: event.query,
      page: page,
      limit: _pageSize,
    );
    final fetched = result.fold((_) => <Anime>[], (r) => r.anime);
    final fresh = fetched
        .where((a) => a.malId == 0 || seen.add(a.malId))
        .toList();

    emit(
      current.copyWith(
        results: [...current.results, ...fresh],
        hasMore: fetched.length >= _pageSize,
        isLoadingMore: false,
      ),
    );
  }

  Future<void> _onLoadLibrary(
    LoadLibrary event,
    Emitter<KokuroState> emit,
  ) async {
    emit(KokuroLoading());

    final libraryResult = await _repo.getLibrary();
    final ratingsResult = await _repo.getRatings();

    final entries = libraryResult.fold((_) => <LibraryEntry>[], (l) => l);
    final ratings = ratingsResult.fold((_) => <int, double>{}, (r) => r);

    // Next air-dates for everything the user is actively following.
    final ids = entries
        .where((e) => e.watchedEpisodes > 0)
        .map((e) => e.anime.malId)
        .toList();
    final airingResult = await _repo.getNextAiringEpisodes(ids);
    final upcoming = airingResult.fold(
      (_) => const <int, ({DateTime at, int episode})>{},
      (r) => r,
    );

    emit(LibraryLoaded(entries: entries, ratings: ratings, upcoming: upcoming));
  }

  Future<void> _onToggleWatchlist(
    ToggleWatchlistItem event,
    Emitter<KokuroState> emit,
  ) async {
    final result = await _repo.toggleWatchlist(event.anime);
    final nowInList = result.fold((_) => false, (v) => v);

    // Toggled from the detail screen: patch that state in place instead of
    // replacing it with a library state (which would blank the detail page).
    if (state is DetailLoaded) {
      emit(
        (state as DetailLoaded).copyWith(
          isInWatchlist: nowInList,
          watchStatus: nowInList ? WatchStatus.planToWatch : null,
          watchedEpisodes: nowInList
              ? (state as DetailLoaded).watchedEpisodes
              : 0,
        ),
      );
      return;
    }
    if (state is HomeLoaded) {
      _patchHomeMembership(emit, event.anime.malId, nowInList);
      return;
    }

    await _emitLibrary(emit);
  }

  /// Keeps the home screen's "in list" state in sync without replacing its
  /// content with a library payload.
  void _patchHomeMembership(
    Emitter<KokuroState> emit,
    int animeId,
    bool inList,
  ) {
    final current = state;
    if (current is! HomeLoaded) return;
    final ids = {...current.watchlistIds};
    if (inList) {
      ids.add(animeId);
    } else {
      ids.remove(animeId);
    }
    emit(current.copyWith(watchlistIds: ids));
  }

  Future<void> _onSetWatchStatus(
    SetWatchStatus event,
    Emitter<KokuroState> emit,
  ) async {
    await _repo.setWatchStatus(event.anime, event.status);

    if (state is DetailLoaded) {
      emit(
        (state as DetailLoaded).copyWith(
          isInWatchlist: true,
          watchStatus: event.status,
        ),
      );
      return;
    }
    if (state is HomeLoaded) {
      _patchHomeMembership(emit, event.anime.malId, true);
      return;
    }

    await _emitLibrary(emit);
  }

  Future<void> _onSetWatchProgress(
    SetWatchProgress event,
    Emitter<KokuroState> emit,
  ) async {
    await _repo.setWatchProgress(event.anime, event.watchedEpisodes);

    if (state is DetailLoaded) {
      final current = state as DetailLoaded;
      final total = event.anime.episodes;
      final clamped = total > 0
          ? event.watchedEpisodes.clamp(0, total)
          : event.watchedEpisodes;
      emit(
        current.copyWith(
          isInWatchlist: true,
          watchedEpisodes: clamped,
          watchStatus: (total > 0 && clamped >= total)
              ? WatchStatus.completed
              : (current.watchStatus ?? WatchStatus.watching),
        ),
      );
      return;
    }
    if (state is HomeLoaded) {
      _patchHomeMembership(emit, event.anime.malId, true);
      return;
    }

    await _emitLibrary(emit);
  }

  Future<void> _onRemoveFromLibrary(
    RemoveFromLibraryEvent event,
    Emitter<KokuroState> emit,
  ) async {
    await _repo.removeFromLibrary(event.animeId);

    if (state is DetailLoaded &&
        (state as DetailLoaded).anime.malId == event.animeId) {
      emit(
        (state as DetailLoaded).copyWith(
          isInWatchlist: false,
          watchStatus: null,
          watchedEpisodes: 0,
        ),
      );
      return;
    }
    if (state is HomeLoaded) {
      _patchHomeMembership(emit, event.animeId, false);
      return;
    }

    await _emitLibrary(emit);
  }

  Future<void> _emitLibrary(Emitter<KokuroState> emit) async {
    final libraryResult = await _repo.getLibrary();
    final ratingsResult = await _repo.getRatings();
    final entries = libraryResult.fold((_) => <LibraryEntry>[], (l) => l);
    final ratings = ratingsResult.fold((_) => <int, double>{}, (r) => r);
    emit(LibraryLoaded(entries: entries, ratings: ratings));
  }

  Future<void> _onRate(RateAnimeEvent event, Emitter<KokuroState> emit) async {
    await _repo.rateAnime(event.animeId, event.rating);
    final ratingsResult = await _repo.getRatings();
    final ratings = ratingsResult.fold((_) => <int, double>{}, (r) => r);

    if (state is DetailLoaded) {
      emit((state as DetailLoaded).copyWith(userRating: event.rating));
    } else {
      emit(LibraryLoaded(entries: const [], ratings: ratings));
    }
  }

  Future<void> _onRemoveRating(
    RemoveRatingEvent event,
    Emitter<KokuroState> emit,
  ) async {
    await _repo.removeRating(event.animeId);
    if (state is DetailLoaded) {
      emit((state as DetailLoaded).copyWith(userRating: null));
    }
  }

  Future<void> _onSubmitReview(
    SubmitReview event,
    Emitter<KokuroState> emit,
  ) async {
    await _repo.submitUserReview(event.animeId, event.review);

    if (state is DetailLoaded) {
      final current = state as DetailLoaded;
      final fresh = await _repo.getUserReviews(event.animeId);
      final userReviews = fresh.fold((_) => <AnimeReview>[], (r) => r);
      final allReviews = [
        ...userReviews,
        ...current.reviews.where((r) => !r.isUser),
      ];
      emit(current.copyWith(reviews: allReviews));
    }
  }
}
