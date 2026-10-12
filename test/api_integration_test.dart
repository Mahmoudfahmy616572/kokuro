// Integration + fallback tests for the new Clean Architecture layers.
//  - Real network checks run against Kitsu (reliable) and the repository.
//  - The fallback chain is verified deterministically with stub datasources.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animiat/core/errors/exceptions.dart';
import 'package:animiat/data/datasources/anilist_remote_datasource.dart';
import 'package:animiat/data/datasources/jikan_remote_datasource.dart';
import 'package:animiat/data/datasources/kitsu_remote_datasource.dart';
import 'package:animiat/data/datasources/local_storage_datasource.dart';
import 'package:animiat/data/models/anime_model.dart';
import 'package:animiat/data/repositories/anime_repository_impl.dart';

const _kitsuTime = Timeout(Duration(seconds: 25));

class _FailingJikan extends JikanRemoteDataSource {
  @override
  Future<List<AnimeModel>> getTopAnime({int page = 1, int limit = 24}) {
    throw const ServerException('Jikan down (test stub)');
  }
}

class _StubKitsu extends KitsuRemoteDataSource {
  @override
  Future<List<AnimeModel>> getTopAnime({int page = 1, int limit = 24}) async {
    return const [
      AnimeModel(
        malId: 1,
        title: 'Kitsu Stub',
        imageUrl: '',
        largeImageUrl: '',
      ),
    ];
  }
}

class _EmptyAniList extends AniListRemoteDataSource {
  @override
  Future<List<AnimeModel>> getTopAnime({int page = 1, int limit = 24}) async {
    return [];
  }
}

AnimeRepositoryImpl _repo({
  JikanRemoteDataSource? jikan,
  KitsuRemoteDataSource? kitsu,
  AniListRemoteDataSource? anilist,
  LocalStorageDataSource? local,
}) {
  return AnimeRepositoryImpl(
    jikan: jikan ?? _FailingJikan(),
    kitsu: kitsu ?? _StubKitsu(),
    anilist: anilist ?? _EmptyAniList(),
    local: local ?? LocalStorageDataSource(),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Kitsu (reliable fallback)', () {
    late KitsuRemoteDataSource ds;

    setUp(() => ds = KitsuRemoteDataSource());
    tearDown(() => ds.dispose());

    test('getTopAnime parses real data', () async {
      final animes = await ds.getTopAnime(limit: 5);
      expect(animes, isNotEmpty);
      final first = animes.first;
      expect(first.malId, greaterThan(0));
      expect(first.title, isNotEmpty);
      expect(first.imageUrl, isNotEmpty);
    }, timeout: _kitsuTime);

    test('searchAnime returns matches for "one piece"', () async {
      final animes = await ds.searchAnime('one piece', limit: 5);
      expect(animes, isNotEmpty);
    }, timeout: _kitsuTime);
  });

  group('Repository fallback chain (deterministic stubs)', () {
    test('falls back to Kitsu when Jikan fails', () async {
      final repo = _repo();
      addTearDown(repo.dispose);

      final result = await repo.getTopAnime();
      expect(result.isRight(), isTrue);
      final data = result.getOrElse(
        () => throw StateError('should not happen'),
      );
      expect(data.source, 'Kitsu');
      expect(data.fellBackFromPrimary, isTrue);
      expect(data.anime, isNotEmpty);
    });

    test('returns FetchFailure when every source is empty/down', () async {
      final repo = _repo(
        jikan: _FailingJikan(),
        kitsu: _EmptyKitsu(),
        anilist: _EmptyAniList(),
      );
      addTearDown(repo.dispose);

      final result = await repo.getTopAnime();
      expect(result.isLeft(), isTrue);
    });

    test(
      'search + watchlist + ratings round-trip through local storage',
      () async {
        final repo = _repo(local: LocalStorageDataSource());
        addTearDown(repo.dispose);

        final anime = const AnimeModel(
          malId: 42,
          title: 'ناروتو',
          imageUrl: '',
          largeImageUrl: '',
        );

        final added = await repo.toggleWatchlist(anime);
        expect(added.isRight(), isTrue);
        expect(added.getOrElse(() => false), isTrue);

        final removed = await repo.toggleWatchlist(anime);
        expect(removed.getOrElse(() => false), isFalse);

        final rated = await repo.rateAnime(42, 8.5);
        expect(rated.isRight(), isTrue);
        final ratings = await repo.getRatings();
        expect(ratings.getOrElse(() => const {}), {42: 8.5});

        final removedRating = await repo.removeRating(42);
        expect(removedRating.isRight(), isTrue);
        final empty = await repo.getRatings();
        expect(empty.getOrElse(() => const {}), isEmpty);
      },
    );
  });
}

class _EmptyKitsu extends KitsuRemoteDataSource {
  @override
  Future<List<AnimeModel>> getTopAnime({int page = 1, int limit = 24}) async {
    return const [];
  }
}
