import 'dart:convert';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/anime.dart';
import '../../domain/entities/anime_list_result.dart';
import '../../domain/entities/library_entry.dart';
import '../../domain/entities/watch_status.dart';
import '../../domain/repositories/anime_repository.dart';
import '../datasources/anilist_remote_datasource.dart';
import '../datasources/jikan_remote_datasource.dart';
import '../datasources/kitsu_remote_datasource.dart';
import '../datasources/local_storage_datasource.dart';
import '../models/anime_model.dart';

/// Concrete repository. Coordinates three remote sources with a
/// Jikan -> Kitsu -> AniList fallback chain and local persistence.
class AnimeRepositoryImpl implements AnimeRepository {
  final JikanRemoteDataSource _jikan;
  final KitsuRemoteDataSource _kitsu;
  final AniListRemoteDataSource _anilist;
  final LocalStorageDataSource _local;

  String? _lastUsedSource;
  bool _fellBackFromPrimary = false;
  int _jikanFailStreak = 0;
  int _jikanOutageUntil = 0;

  // Response cache TTLs: lists refresh often, search survives longer,
  // anime details change rarely. Cache = faster revisit + offline survival.
  static const _ttlList = Duration(minutes: 20);
  static const _ttlExplore = Duration(minutes: 30);
  static const _ttlDetails = Duration(hours: 6);

  int _hashKey(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  String _cacheKey(String method, Map<String, dynamic> params) {
    final buf = StringBuffer(method);
    for (final k in params.keys.toList()..sort()) {
      buf.write('|$k=${params[k]}');
    }
    return _hashKey(buf.toString()).toRadixString(36);
  }

  String _encodeAnimeList(List<Anime> list) =>
      jsonEncode([for (final a in list) AnimeModel.fromEntity(a).toCacheMap()]);

  List<Anime>? _decodeAnimeList(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => AnimeModel.fromCacheMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  String _encodeAnime(Anime a) =>
      jsonEncode(AnimeModel.fromEntity(a).toCacheMap());

  Anime? _decodeAnime(String raw) {
    try {
      return AnimeModel.fromCacheMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  String _encodeGenreCounts(Map<String, int> counts) =>
      jsonEncode({for (final e in counts.entries) e.key: e.value});

  Map<String, int>? _decodeGenreCounts(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {for (final e in decoded.entries) e.key: (e.value as num).toInt()};
    } catch (_) {
      return null;
    }
  }

  bool get _jikanDown =>
      DateTime.now().millisecondsSinceEpoch < _jikanOutageUntil;

  /// Tracks Jikan health. After two consecutive failures we skip Jikan
  /// entirely for ~90s — a widespread 504/429 keeps every screen waiting
  /// on its timeout before the Kitsu/AniList fallbacks kick in.
  void _recordJikan(bool ok) {
    if (ok) {
      _jikanFailStreak = 0;
    } else {
      _jikanFailStreak++;
      if (_jikanFailStreak >= 2) {
        _jikanOutageUntil = DateTime.now().millisecondsSinceEpoch + 90 * 1000;
      }
    }
  }

  AnimeRepositoryImpl({
    JikanRemoteDataSource? jikan,
    KitsuRemoteDataSource? kitsu,
    AniListRemoteDataSource? anilist,
    LocalStorageDataSource? local,
  }) : _jikan = jikan ?? JikanRemoteDataSource(),
       _kitsu = kitsu ?? KitsuRemoteDataSource(),
       _anilist = anilist ?? AniListRemoteDataSource(),
       _local = local ?? LocalStorageDataSource();

  String? get lastUsedSource => _lastUsedSource;

  bool get fellBackFromPrimary => _fellBackFromPrimary;

  @override
  Future<Either<Failure, AnimeListResult>> getTopAnime({
    int page = 1,
    int limit = 24,
  }) {
    return _cachedList(
      _cacheKey('top', {'page': page, 'limit': limit}),
      _ttlList,
      () => _fetchWithFallback(
        (_) => _jikan.getTopAnime(page: page, limit: limit),
        (_) => _kitsu.getTopAnime(page: page, limit: limit),
        (_) => _anilist.getTopAnime(page: page, limit: limit),
      ),
    );
  }

  @override
  Future<Either<Failure, AnimeListResult>> getSeasonAnime({
    int page = 1,
    int limit = 24,
  }) {
    return _cachedList(
      _cacheKey('season', {'page': page, 'limit': limit}),
      _ttlList,
      () => _fetchWithFallback(
        (_) => _jikan.getSeasonAnime(page: page, limit: limit),
        (_) => _kitsu.getSeasonAnime(page: page, limit: limit),
        (_) => _anilist.getSeasonAnime(page: page, limit: limit),
      ),
    );
  }

  @override
  Future<Either<Failure, AnimeListResult>> getUpcomingAnime({
    int page = 1,
    int limit = 24,
  }) {
    return _cachedList(
      _cacheKey('upcoming', {'page': page, 'limit': limit}),
      _ttlList,
      () => _fetchWithFallback(
        (_) => _jikan.getUpcomingAnime(page: page, limit: limit),
        (_) => _kitsu.getUpcomingAnime(page: page, limit: limit),
        (_) => _anilist.getUpcomingAnime(page: page, limit: limit),
      ),
    );
  }

  @override
  Future<Either<Failure, AnimeListResult>> getAnimeByGenre({
    required String genre,
    int page = 1,
    int? limit,
  }) {
    final resolved = limit ?? 24;
    return _cachedList(
      _cacheKey('genre', {'genre': genre, 'page': page, 'limit': resolved}),
      _ttlExplore,
      () => _fetchWithFallback(
        (_) => _jikan.getAnimeByGenre(genre, page: page, limit: resolved),
        (_) => _kitsu.getAnimeByGenre(genre, page: page, limit: resolved),
        (_) => _anilist.getAnimeByGenre(genre, page: page, limit: resolved),
      ),
    );
  }

  @override
  Future<Either<Failure, AnimeListResult>> getExploreList({
    String? genre,
    String? season,
    String? year,
    String? studio,
    String? type,
    String? rating,
    String? sort,
    int page = 1,
    int limit = 24,
  }) {
    return _cachedList(
      _cacheKey('explore', {
        'genre': genre ?? '',
        'season': season ?? '',
        'year': year ?? '',
        'studio': studio ?? '',
        'type': type ?? '',
        'rating': rating ?? '',
        'sort': sort ?? '',
        'page': page,
        'limit': limit,
      }),
      _ttlExplore,
      () => _fetchWithFallback(
        (_) => _jikan.getExploreList(
          genre: genre,
          season: season,
          year: year,
          studio: studio,
          type: type,
          rating: rating,
          sort: sort,
          page: page,
          limit: limit,
        ),
        (_) => _kitsu.getExploreList(
          genre: genre,
          season: season,
          year: year,
          studio: studio,
          type: type,
          rating: rating,
          sort: sort,
          page: page,
          limit: limit,
        ),
        (_) => _anilist.getExploreList(
          genre: genre,
          season: season,
          year: year,
          studio: studio,
          type: type,
          rating: rating,
          sort: sort,
          page: page,
          limit: limit,
        ),
      ),
    );
  }

  @override
  Future<Either<Failure, AnimeListResult>> searchAnime({
    required String query,
    int page = 1,
    int limit = 24,
  }) {
    return _cachedList(
      _cacheKey('search', {'q': query, 'page': page, 'limit': limit}),
      _ttlExplore,
      () => _fetchWithFallback(
        (_) => _jikan.searchAnime(query, page: page, limit: limit),
        (_) => _kitsu.searchAnime(query, page: page, limit: limit),
        (_) => _anilist.searchAnime(query, page: page, limit: limit),
      ),
    );
  }

  @override
  Future<Either<Failure, List<AnimeCharacter>>> searchCharacters({
    required String query,
    int limit = 12,
  }) async {
    try {
      final chars = await _jikan.searchCharacters(query, limit: limit);
      _recordJikan(chars.isNotEmpty);
      return Right(chars);
    } catch (_) {
      _recordJikan(false);
      return const Right([]);
    }
  }

  @override
  Future<Either<Failure, Map<int, ({DateTime at, int episode})>>>
  getNextAiringEpisodes(List<int> idMals) async {
    try {
      final airing = await _anilist.getNextAiringEpisodes(idMals);
      return Right(airing);
    } catch (_) {
      return const Right({});
    }
  }

  /// Cache-first list fetch: fresh cache wins instantly; otherwise hit the
  /// network (via the remote chain) and persist the result. If the network
  /// fails we fall back to stale cache so the app keeps working offline.
  Future<Either<Failure, AnimeListResult>> _cachedList(
    String key,
    Duration ttl,
    Future<Either<Failure, AnimeListResult>> Function() fetch,
  ) async {
    final cached = await _local.readCache(key);
    if (cached != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cached.$2;
      if (age < ttl.inMilliseconds) {
        final list = _decodeAnimeList(cached.$1);
        if (list != null) {
          return Right(
            AnimeListResult(
              anime: list,
              source: 'Cache',
              fellBackFromPrimary: false,
            ),
          );
        }
      }
    }

    final result = await fetch();
    if (result.isRight()) {
      final data = result.getOrElse(() => throw StateError('unreachable'));
      await _local.writeCache(key, _encodeAnimeList(data.anime));
      return Right(
        AnimeListResult(
          anime: data.anime,
          source: data.source,
          fellBackFromPrimary: data.fellBackFromPrimary,
        ),
      );
    }

    // All three remotes failed — reuse stale cached data if any.
    if (cached != null) {
      final stale = _decodeAnimeList(cached.$1);
      if (stale != null) {
        return Right(
          AnimeListResult(
            anime: stale,
            source: 'Cache (stale)',
            fellBackFromPrimary: false,
          ),
        );
      }
    }
    return result;
  }

  Future<Either<Failure, AnimeListResult>> _fetchWithFallback(
    Future<List<AnimeModel>> Function(String _) primary,
    Future<List<AnimeModel>> Function(String _) fallback1,
    Future<List<AnimeModel>> Function(String _) fallback2,
  ) async {
    // 1) Primary: Jikan (skipped entirely while the outage breaker is on)
    if (!_jikanDown) {
      try {
        final primaryList = await primary('');
        _recordJikan(primaryList.isNotEmpty);
        if (primaryList.isNotEmpty) {
          _lastUsedSource = 'Jikan';
          _fellBackFromPrimary = false;
          return Right(
            AnimeListResult(
              anime: primaryList,
              source: 'Jikan',
              fellBackFromPrimary: false,
            ),
          );
        }
      } catch (_) {
        _recordJikan(false);
      }
    }

    // 2) First fallback: Kitsu
    try {
      final kitsuList = await fallback1('');
      if (kitsuList.isNotEmpty) {
        _lastUsedSource = 'Kitsu';
        _fellBackFromPrimary = true;
        return Right(
          AnimeListResult(
            anime: kitsuList,
            source: 'Kitsu',
            fellBackFromPrimary: true,
          ),
        );
      }
    } catch (_) {
      // fall through
    }

    // 3) Last fallback: AniList
    try {
      final anilistList = await fallback2('');
      if (anilistList.isNotEmpty) {
        _lastUsedSource = 'AniList';
        _fellBackFromPrimary = true;
        return Right(
          AnimeListResult(
            anime: anilistList,
            source: 'AniList',
            fellBackFromPrimary: true,
          ),
        );
      }
    } catch (_) {
      // nothing worked
    }

    _fellBackFromPrimary = _lastUsedSource != 'Jikan';
    return const Left(FetchFailure());
  }

  @override
  Future<Either<Failure, Anime?>> getAnimeDetails(int animeId) async {
    final key = _cacheKey('details', {'id': animeId});
    final cached = await _local.readCache(key);
    if (cached != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cached.$2;
      if (age < _ttlDetails.inMilliseconds) {
        final hit = _decodeAnime(cached.$1);
        if (hit != null) return Right(hit);
      }
    }

    final jikan = _jikanDown ? null : await _jikan.getAnimeDetails(animeId);
    if (jikan != null) {
      _recordJikan(true);
      await _local.writeCache(key, _encodeAnime(jikan));
      return Right(jikan);
    }
    _recordJikan(false);

    // Jikan `/full` failed (usually rate-limited), but the lightweight
    // trailer probe may still succeed — attach the trailer to whichever
    // data source actually provided the details.
    final String? trailerId;
    if (_jikanDown) {
      trailerId = null;
    } else {
      trailerId = await _jikan.getTrailerId(animeId);
    }

    final kitsu = await _kitsu.getAnimeDetails(animeId);
    if (kitsu != null) {
      Anime resolved = kitsu;
      // Kitsu ids are not MAL ids — resolve the real MAL key so characters,
      // episodes, recommendations and deep links all work downstream.
      if (kitsu.malId == animeId) {
        final realMal = await _kitsu.resolveMalId(animeId);
        if (realMal != null && realMal > 0 && realMal != kitsu.malId) {
          resolved = kitsu.copyWith(malId: realMal);
        }
      }
      if (trailerId != null && (resolved.trailerYoutubeId?.isEmpty ?? true)) {
        resolved = resolved.copyWith(trailerYoutubeId: trailerId);
      }
      await _local.writeCache(key, _encodeAnime(resolved));
      return Right(resolved);
    }

    final anilist = await _anilist.getAnimeDetails(animeId);
    if (anilist != null) {
      if (trailerId != null && (anilist.trailerYoutubeId?.isEmpty ?? true)) {
        final merged = anilist.copyWith(trailerYoutubeId: trailerId);
        await _local.writeCache(key, _encodeAnime(merged));
        return Right(merged);
      }
      await _local.writeCache(key, _encodeAnime(anilist));
      return Right(anilist);
    }

    // No remote had it — fall back to stale cache so revisits still work.
    if (cached != null) {
      final stale = _decodeAnime(cached.$1);
      if (stale != null) return Right(stale);
    }
    return Right(null);
  }

  @override
  Future<Either<Failure, List<Anime>>> getRecommendations(int animeId) async {
    final List<Anime> jikan = _jikanDown
        ? const []
        : await _jikan.getRecommendations(animeId);
    _recordJikan(jikan.isNotEmpty);
    if (jikan.isNotEmpty) return Right(jikan);

    final anilist = await _anilist.getRecommendations(animeId);
    if (anilist.isNotEmpty) return Right(anilist);

    final nakama = await _animeDetails(animeId);
    final genres = nakama?.genres ?? const [];
    final kitsu = await _kitsu.getRelatedAnime(animeId, genres: genres);
    if (kitsu.isNotEmpty) return Right(kitsu);

    return const Right([]);
  }

  @override
  Future<Either<Failure, List<AnimeCharacter>>> getCharacters(
    int animeId,
  ) async {
    // Jikan's characters endpoint is the slowest link — it stalls 20s+ per
    // attempt when MyAnimeList is degraded, and a sequential chain hid the
    // fast AniList/Kitsu hits behind that 40s wall. So the MAL-keyed
    // resolution runs first and Jikan is only consulted as a last resort.

    // Kick off the Kitsu→MAL mapping lookup in parallel with the direct
    // queries — Kitsu-sourced routes carry a Kitsu id in `malId`.
    final malIdF = _kitsu.resolveMalId(animeId).catchError((_) => null);

    // 1) AniList first — keyed by MAL id, returns in ~1s.
    List<AnimeCharacter> chars = const [];
    try {
      chars = await _anilist.getCharacters(animeId);
    } catch (_) {}
    if (chars.isNotEmpty) return Right(chars);

    // 2) Kitsu with the id as-is — correct when the route id IS a Kitsu id.
    try {
      chars = await _kitsu.getCharacters(animeId);
    } catch (_) {}
    if (chars.isNotEmpty) return Right(chars);

    // 3) Both missed — the id is very likely a Kitsu id, so retry the
    //    MAL-keyed source with the resolved mapping.
    final malId = await malIdF;
    if (malId != null && malId != animeId) {
      try {
        chars = await _anilist.getCharacters(malId);
      } catch (_) {}
      if (chars.isNotEmpty) return Right(chars);
    }

    // 4) Last resort: Jikan (skipped while the outage breaker is on).
    if (!_jikanDown) {
      chars = await _jikan.getCharacters(animeId);
      _recordJikan(chars.isNotEmpty);
      if (chars.isNotEmpty) return Right(chars);
      if (malId != null && malId != animeId) {
        chars = await _jikan.getCharacters(malId);
        _recordJikan(chars.isNotEmpty);
        if (chars.isNotEmpty) return Right(chars);
      }
    }

    return Right(chars);
  }

  @override
  Future<Either<Failure, List<AnimeEpisode>>> getEpisodes(
    int animeId, {
    int page = 1,
  }) async {
    final List<AnimeEpisode> eps = _jikanDown
        ? const []
        : await _jikan.getEpisodes(animeId, page: page);
    _recordJikan(eps.isNotEmpty);
    if (eps.isNotEmpty) return Right(eps);

    final kitsu = await _kitsu.getEpisodes(animeId, page: page);
    if (kitsu.isNotEmpty) return Right(kitsu);

    return const Right([]);
  }

  @override
  Future<Either<Failure, List<AnimeReview>>> getReviews(int animeId) async {
    final List<AnimeReview> reviews = _jikanDown
        ? const []
        : await _jikan.getReviews(animeId);
    _recordJikan(reviews.isNotEmpty);
    if (reviews.isNotEmpty) return Right(reviews);
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<AnimeReview>>> getUserReviews(int animeId) async {
    try {
      final reviews = await _local.getUserReviews(animeId);
      return Right(reviews);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> submitUserReview(
    int animeId,
    AnimeReview review,
  ) async {
    try {
      await _local.submitUserReview(animeId, review);
      return const Right(null);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getGenreCounts(
    List<String> genres,
  ) async {
    final key = _cacheKey('genre_counts', {});
    final cached = await _local.readCache(key);
    Map<String, int>? known;
    if (cached != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cached.$2;
      if (age < _ttlExplore.inMilliseconds) {
        known = _decodeGenreCounts(cached.$1);
      }
    }
    final counts = <String, int>{...?known};
    // Only the genres we still have no number for (or the whole set when
    // nothing is cached) hit the network — one batched request per genre,
    // then everything is persisted for the TTL.
    final missing = genres.where((g) => !counts.containsKey(g)).toList();
    if (missing.isNotEmpty && !_jikanDown) {
      await Future.wait(
        missing.map((g) async {
          final n = await _jikan.getGenreTotalCount(g);
          if (n > 0) counts[g] = n;
          _recordJikan(n > 0);
        }),
      );
      await _local.writeCache(key, _encodeGenreCounts(counts));
    } else if (known == null) {
      await _local.writeCache(key, _encodeGenreCounts(counts));
    }
    return Right(counts);
  }

  Future<Anime?> _animeDetails(int animeId) async {
    final jikan = await _jikan.getAnimeDetails(animeId);
    if (jikan != null) return jikan;
    final kitsu = await _kitsu.getAnimeDetails(animeId);
    return kitsu;
  }

  @override
  Future<Either<Failure, List<Anime>>> getWatchlist() async {
    try {
      final list = await _local.getWatchlist();
      return Right(list);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> toggleWatchlist(Anime anime) async {
    try {
      final current = await _local.getWatchlist();
      final exists = current.any((a) => a.malId == anime.malId);
      if (exists) {
        await _local.removeFromWatchlist(anime.malId);
        await _local.removeLibraryMeta(anime.malId);
      } else {
        await _local.addToWatchlist(AnimeModel.fromEntity(anime));
        await _local.setLibraryMeta(
          anime.malId,
          status: WatchStatus.planToWatch,
        );
      }
      return Right(!exists);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LibraryEntry>>> getLibrary() async {
    try {
      final watchlist = await _local.getWatchlist();
      final meta = await _local.getLibraryMeta();
      final entries = watchlist.map((anime) {
        final info = meta[anime.malId];
        return LibraryEntry(
          anime: anime,
          status: info?.status ?? WatchStatus.planToWatch,
          watchedEpisodes: info?.watchedEpisodes ?? 0,
          updatedAt: info?.updatedAt,
        );
      }).toList();
      return Right(entries);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setWatchStatus(
    Anime anime,
    WatchStatus status,
  ) async {
    try {
      await _local.addToWatchlist(AnimeModel.fromEntity(anime));
      await _local.setLibraryMeta(anime.malId, status: status);
      return const Right(null);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setWatchProgress(
    Anime anime,
    int watchedEpisodes,
  ) async {
    try {
      final total = anime.episodes;
      final clamped = total > 0
          ? watchedEpisodes.clamp(0, total)
          : watchedEpisodes.clamp(0, 100000);
      await _local.addToWatchlist(AnimeModel.fromEntity(anime));
      await _local.setLibraryMeta(anime.malId, watchedEpisodes: clamped);
      if (total > 0 && clamped >= total) {
        await _local.setLibraryMeta(anime.malId, status: WatchStatus.completed);
      }
      return const Right(null);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeFromLibrary(int animeId) async {
    try {
      await _local.removeFromWatchlist(animeId);
      await _local.removeLibraryMeta(animeId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<int, double>>> getRatings() async {
    try {
      final ratings = await _local.getAllRatings();
      return Right(ratings);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> rateAnime(int animeId, double rating) async {
    try {
      await _local.rateAnime(animeId, rating);
      return const Right(null);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeRating(int animeId) async {
    try {
      await _local.removeRating(animeId);
      return const Right(null);
    } on Exception catch (e) {
      return Left(LocalStorageFailure(e.toString()));
    }
  }

  void dispose() {
    _jikan.dispose();
    _kitsu.dispose();
    _anilist.dispose();
  }
}
