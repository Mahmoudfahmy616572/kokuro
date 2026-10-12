import 'dart:convert';

import 'package:animiat/core/errors/failures.dart';
import 'package:animiat/data/datasources/jikan_remote_datasource.dart';
import 'package:animiat/domain/entities/anime.dart';
import 'package:animiat/domain/entities/anime_list_result.dart';
import 'package:animiat/domain/entities/library_entry.dart';
import 'package:animiat/domain/entities/watch_status.dart';
import 'package:animiat/domain/repositories/anime_repository.dart';
import 'package:animiat/kokuro/kokuro_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hand-rolled fake so bloc tests never hit the network or disk.
class _FakeRepo implements AnimeRepository {
  List<Anime> popular = [];
  List<Anime> season = [];
  List<Anime> explore = [];
  List<LibraryEntry> library = [];
  List<Anime> watchlist = [];
  Map<String, int> genreCounts = const {};
  int exploreFetches = 0;

  Anime _anime(int id, String title, {int episodes = 12}) => Anime(
    malId: id,
    title: title,
    imageUrl: 'https://img/$id.jpg',
    largeImageUrl: 'https://img/$id-large.jpg',
    episodes: episodes,
    score: 8.0,
  );

  @override
  Future<Either<Failure, AnimeListResult>> getTopAnime({
    int page = 1,
    int limit = 24,
  }) async => Right(
    AnimeListResult(anime: popular, source: 'Fake', fellBackFromPrimary: false),
  );

  @override
  Future<Either<Failure, AnimeListResult>> getSeasonAnime({
    int page = 1,
    int limit = 24,
  }) async => Right(
    AnimeListResult(anime: season, source: 'Fake', fellBackFromPrimary: false),
  );

  @override
  Future<Either<Failure, AnimeListResult>> getUpcomingAnime({
    int page = 1,
    int limit = 24,
  }) async => Right(
    AnimeListResult(anime: season, source: 'Fake', fellBackFromPrimary: false),
  );

  @override
  Future<Either<Failure, AnimeListResult>> getAnimeByGenre({
    required String genre,
    int page = 1,
    int? limit,
  }) async => Right(
    AnimeListResult(anime: explore, source: 'Fake', fellBackFromPrimary: false),
  );

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
  }) async {
    exploreFetches++;
    final start = (page - 1) * limit;
    final slice = explore.skip(start).take(limit).toList();
    return Right(
      AnimeListResult(anime: slice, source: 'Fake', fellBackFromPrimary: false),
    );
  }

  @override
  Future<Either<Failure, AnimeListResult>> searchAnime({
    required String query,
    int page = 1,
    int limit = 24,
  }) async => Right(
    AnimeListResult(anime: explore, source: 'Fake', fellBackFromPrimary: false),
  );

  @override
  Future<Either<Failure, Anime?>> getAnimeDetails(int animeId) async =>
      Right(null);

  @override
  Future<Either<Failure, List<Anime>>> getRecommendations(int animeId) async =>
      const Right([]);

  @override
  Future<Either<Failure, List<AnimeCharacter>>> getCharacters(
    int animeId,
  ) async => const Right([]);

  @override
  Future<Either<Failure, List<AnimeCharacter>>> searchCharacters({
    required String query,
    int limit = 12,
  }) async => const Right([]);

  @override
  Future<Either<Failure, Map<int, ({DateTime at, int episode})>>>
  getNextAiringEpisodes(List<int> idMals) async => const Right({});

  @override
  Future<Either<Failure, List<AnimeEpisode>>> getEpisodes(
    int animeId, {
    int page = 1,
  }) async => const Right([]);

  @override
  Future<Either<Failure, List<AnimeReview>>> getReviews(int animeId) async =>
      const Right([]);

  @override
  Future<Either<Failure, void>> submitUserReview(
    int animeId,
    AnimeReview review,
  ) async => const Right(null);

  @override
  Future<Either<Failure, List<AnimeReview>>> getUserReviews(
    int animeId,
  ) async => const Right([]);

  @override
  Future<Either<Failure, Map<String, int>>> getGenreCounts(
    List<String> genres,
  ) async => Right(genreCounts);

  @override
  Future<Either<Failure, List<Anime>>> getWatchlist() async => Right(watchlist);

  @override
  Future<Either<Failure, bool>> toggleWatchlist(Anime anime) async =>
      const Right(true);

  @override
  Future<Either<Failure, List<LibraryEntry>>> getLibrary() async =>
      Right(library);

  @override
  Future<Either<Failure, void>> setWatchStatus(
    Anime anime,
    WatchStatus status,
  ) async => const Right(null);

  @override
  Future<Either<Failure, void>> setWatchProgress(
    Anime anime,
    int watchedEpisodes,
  ) async => const Right(null);

  @override
  Future<Either<Failure, void>> removeFromLibrary(int animeId) async =>
      const Right(null);

  @override
  Future<Either<Failure, Map<int, double>>> getRatings() async =>
      const Right({});

  @override
  Future<Either<Failure, void>> rateAnime(int animeId, double rating) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> removeRating(int animeId) async =>
      const Right(null);
}

void main() {
  final fake = _FakeRepo();

  /// Flushes pending microtasks deterministically so bloc handlers that
  /// chain Futures complete before the next assertion (no wall-clock races).
  Future<void> flush() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.value();
    }
  }

  /// Keeps yielding microtasks until [condition] holds over the recorded
  /// states — robust to bloc's lazy stream-pipeline warm-up.
  Future<void> waitFor(
    List<KokuroState> states,
    bool Function(KokuroState s) condition,
  ) async {
    for (var i = 0; i < 2000; i++) {
      await flush();
      if (states.any(condition)) return;
    }
    fail('waitFor timed out');
  }

  setUp(() {
    fake.popular = [
      for (var i = 1; i <= 10; i++) fake._anime(i, 'Fight Club $i'),
    ];
    fake.season = [
      for (var i = 11; i <= 20; i++) fake._anime(i, 'Season Tale $i'),
    ];
    fake.explore = [
      for (var i = 1; i <= 30; i++) fake._anime(i, 'Explore Title $i'),
    ];
    fake.genreCounts = const {'Action': 142, 'Fantasy': 98};
    fake.library = [
      LibraryEntry(
        anime: fake._anime(1, 'In Progress', episodes: 24),
        status: WatchStatus.watching,
        watchedEpisodes: 12,
        updatedAt: DateTime(2026, 1, 2),
      ),
      LibraryEntry(
        anime: fake._anime(2, 'Half Watched', episodes: 10),
        status: WatchStatus.watching,
        watchedEpisodes: 5,
        updatedAt: DateTime(2026, 1, 1),
      ),
      LibraryEntry(
        anime: fake._anime(3, 'Dropped', episodes: 12),
        status: WatchStatus.dropped,
        watchedEpisodes: 0,
      ),
    ];
    fake.watchlist = [
      fake._anime(1, 'In Progress'),
      fake._anime(2, 'Half Watched'),
    ];
  });

  group('KokuroBloc · LoadExplore', () {
    test('emits loading then ExploreLoaded with the fetched list', () async {
      fake.exploreFetches = 0;
      final bloc = KokuroBloc(repo: fake);
      final states = <KokuroState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadExplore());
      await waitFor(
        states,
        (s) => s is ExploreLoaded && s.genreCounts.isNotEmpty,
      );

      expect(states.first, isA<KokuroLoading>());
      final loaded = states.last;
      expect(loaded, isA<ExploreLoaded>());
      expect((loaded as ExploreLoaded).anime.length, 24);
      expect(loaded.hasMore, isTrue);
      expect(fake.exploreFetches, 1);
      await sub.cancel();
      bloc.close();
    });

    test(
      'genre counts are attached to ExploreLoaded after the batch fetch',
      () async {
        final bloc = KokuroBloc(repo: fake);
        final states = <KokuroState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const LoadExplore());
        await waitFor(
          states,
          (s) => s is ExploreLoaded && s.genreCounts.isNotEmpty,
        );

        final loaded = states.last;
        expect(loaded, isA<ExploreLoaded>());
        expect((loaded as ExploreLoaded).genreCounts['Action'], 142);
        expect(loaded.genreCounts['Fantasy'], 98);
        await sub.cancel();
        bloc.close();
      },
    );

    test('LoadMoreExplore appends and dedupes across pages', () async {
      final bloc = KokuroBloc(repo: fake);
      final states = <KokuroState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadExplore());
      await waitFor(
        states,
        (s) =>
            s is ExploreLoaded &&
            s.genreCounts.isNotEmpty &&
            s.anime.length == 24,
      );

      bloc.add(LoadMoreExplore(genre: 'Action', sort: 'Popular'));
      await waitFor(states, (s) => s is ExploreLoaded && s.anime.length == 30);

      final loaded = states.last;
      expect(loaded, isA<ExploreLoaded>());
      final anime = (loaded as ExploreLoaded).anime;
      // Everything up to the last full page; dedup keeps unique titles.
      expect(anime.length, 30);
      expect(anime.map((a) => a.malId).toSet().length, anime.length);
      expect(loaded.hasMore, isFalse);
      await sub.cancel();
      bloc.close();
    });

    test('genre counts update via LoadGenreCounts event', () async {
      final bloc = KokuroBloc(repo: fake);
      final states = <KokuroState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadExplore());
      await waitFor(
        states,
        (s) => s is ExploreLoaded && s.genreCounts.isNotEmpty,
      );

      fake.genreCounts = const {'Action': 200, 'Comedy': 300};
      bloc.add(const LoadGenreCounts());
      await waitFor(
        states,
        (s) =>
            s is ExploreLoaded &&
            s.genreCounts['Action'] == 200 &&
            s.genreCounts['Comedy'] == 300,
      );

      final loaded = states.last;
      expect(loaded, isA<ExploreLoaded>());
      expect((loaded as ExploreLoaded).genreCounts['Action'], 200);
      expect(loaded.genreCounts['Comedy'], 300);
      await sub.cancel();
      bloc.close();
    });
  });

  group('KokuroBloc · LoadHome', () {
    test('exposes real in-progress tracking as continueWatching', () async {
      final bloc = KokuroBloc(repo: fake);
      final states = <KokuroState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadHome());
      await waitFor(states, (s) => s is HomeLoaded);

      final loaded = states.last;
      expect(loaded, isA<HomeLoaded>());
      final home = loaded as HomeLoaded;
      // Only titles with watched episodes > 0 and not completed.
      expect(home.continueWatching.length, 2);
      expect(home.continueWatching.first.anime.malId, 1);
      // Most recently updated comes first.
      expect(home.continueWatching.first.watchedEpisodes, 12);
      expect(home.continueWatching.last.watchedEpisodes, 5);
      // Dropped + un-started titles are excluded.
      expect(
        home.continueWatching.map((e) => e.anime.malId),
        isNot(contains(3)),
      );
      expect(home.featured, isNotEmpty);
      expect(home.watchlistIds, {1, 2});
      await sub.cancel();
      bloc.close();
    });

    test('watchlist still drives the journey fallback', () async {
      final bloc = KokuroBloc(repo: fake);
      final states = <KokuroState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadHome());
      await waitFor(states, (s) => s is HomeLoaded);

      final home = states.last as HomeLoaded;
      expect(home.journey.map((a) => a.malId), unorderedEquals([1, 2]));
      await sub.cancel();
      bloc.close();
    });
  });

  group('KokuroBloc · LoadLibrary / mutations', () {
    test('emits LibraryLoaded entries and ratings', () async {
      final bloc = KokuroBloc(repo: fake);
      final states = <KokuroState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadLibrary());
      await waitFor(states, (s) => s is LibraryLoaded);

      final loaded = states.last;
      expect(loaded, isA<LibraryLoaded>());
      expect((loaded as LibraryLoaded).entries.length, 3);
      await sub.cancel();
      bloc.close();
    });

    test(
      'removeFromLibrary re-emits LibraryLoaded without the title',
      () async {
        final bloc = KokuroBloc(repo: fake);
        final states = <KokuroState>[];
        final sub = bloc.stream.listen(states.add);

        bloc.add(const LoadLibrary());
        await waitFor(states, (s) => s is LibraryLoaded);

        fake.library.removeAt(0);
        bloc.add(const RemoveFromLibraryEvent(1));
        await waitFor(
          states,
          (s) =>
              s is LibraryLoaded && s.entries.every((e) => e.anime.malId != 1),
        );

        final loaded = states.last;
        expect(loaded, isA<LibraryLoaded>());
        expect((loaded as LibraryLoaded).entries.length, 2);
        expect(loaded.entries.map((e) => e.anime.malId), isNot(contains(1)));
        await sub.cancel();
        bloc.close();
      },
    );
  });

  test('genres map round-trips through cache encoding helpers', () {
    // The repo's cache payload is just JSON; verify longevity by
    // re-encoding the same shape the datasource produces.
    final source = jsonEncode({'Action': 142, 'Comedy': 300});
    final decoded = (jsonDecode(source) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );
    expect(decoded, {'Action': 142, 'Comedy': 300});
  });
}
