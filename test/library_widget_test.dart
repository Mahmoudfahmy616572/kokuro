import 'package:animiat/core/errors/failures.dart';
import 'package:animiat/domain/entities/anime.dart';
import 'package:animiat/domain/entities/anime_list_result.dart';
import 'package:animiat/domain/entities/library_entry.dart';
import 'package:animiat/domain/entities/watch_status.dart';
import 'package:animiat/data/datasources/jikan_remote_datasource.dart';
import 'package:animiat/domain/repositories/anime_repository.dart';
import 'package:animiat/kokuro/kokuro_bloc.dart';
import 'package:animiat/kokuro/library_screen.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal repo supporting only the calls [LoadLibrary] makes, so the widget
/// test renders the real [LibraryScreen] without network/plugin access.
class _LibraryFakeRepo implements AnimeRepository {
  List<LibraryEntry> library = [];
  Map<int, double> ratings = {};

  Never _throw() => throw UnimplementedError('library widget test');

  @override
  Future<Either<Failure, AnimeListResult>> getTopAnime({
    int page = 1,
    int limit = 24,
  }) => _throw();

  @override
  Future<Either<Failure, AnimeListResult>> getSeasonAnime({
    int page = 1,
    int limit = 24,
  }) => _throw();

  @override
  Future<Either<Failure, AnimeListResult>> getUpcomingAnime({
    int page = 1,
    int limit = 24,
  }) => _throw();

  @override
  Future<Either<Failure, AnimeListResult>> getAnimeByGenre({
    required String genre,
    int page = 1,
    int? limit,
  }) => _throw();

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
  }) => _throw();

  @override
  Future<Either<Failure, AnimeListResult>> searchAnime({
    required String query,
    int page = 1,
    int limit = 24,
  }) => _throw();

  @override
  Future<Either<Failure, List<AnimeCharacter>>> searchCharacters({
    required String query,
    int limit = 12,
  }) => _throw();

  @override
  Future<Either<Failure, Map<int, ({DateTime at, int episode})>>>
  getNextAiringEpisodes(List<int> idMals) async => const Right({});

  @override
  Future<Either<Failure, Anime?>> getAnimeDetails(int animeId) => _throw();

  @override
  Future<Either<Failure, List<Anime>>> getRecommendations(int animeId) =>
      _throw();

  @override
  Future<Either<Failure, List<AnimeCharacter>>> getCharacters(int animeId) =>
      _throw();

  @override
  Future<Either<Failure, List<AnimeEpisode>>> getEpisodes(
    int animeId, {
    int page = 1,
  }) => _throw();

  @override
  Future<Either<Failure, List<AnimeReview>>> getReviews(int animeId) =>
      _throw();

  @override
  Future<Either<Failure, void>> submitUserReview(
    int animeId,
    AnimeReview review,
  ) => _throw();

  @override
  Future<Either<Failure, List<AnimeReview>>> getUserReviews(int animeId) =>
      _throw();

  @override
  Future<Either<Failure, Map<String, int>>> getGenreCounts(
    List<String> genres,
  ) => _throw();

  @override
  Future<Either<Failure, List<Anime>>> getWatchlist() async => const Right([]);

  @override
  Future<Either<Failure, bool>> toggleWatchlist(Anime anime) => _throw();

  @override
  Future<Either<Failure, List<LibraryEntry>>> getLibrary() async =>
      Right(library);

  @override
  Future<Either<Failure, void>> setWatchStatus(
    Anime anime,
    WatchStatus status,
  ) => _throw();

  @override
  Future<Either<Failure, void>> setWatchProgress(
    Anime anime,
    int watchedEpisodes,
  ) => _throw();

  @override
  Future<Either<Failure, void>> removeFromLibrary(int animeId) => _throw();

  @override
  Future<Either<Failure, Map<int, double>>> getRatings() async =>
      Right(ratings);

  @override
  Future<Either<Failure, void>> rateAnime(int animeId, double rating) =>
      _throw();

  @override
  Future<Either<Failure, void>> removeRating(int animeId) => _throw();
}

void main() {
  final anime1 = Anime(
    malId: 100,
    title: 'Attack on Titans',
    imageUrl: 'https://img/100.jpg',
    largeImageUrl: 'https://img/100-large.jpg',
    episodes: 24,
  );
  final anime2 = Anime(
    malId: 200,
    title: 'Death Note Light',
    imageUrl: 'https://img/200.jpg',
    largeImageUrl: 'https://img/200-large.jpg',
    episodes: 37,
  );

  Future<void> pumpLibrary(WidgetTester tester, _LibraryFakeRepo repo) async {
    SharedPreferences.setMockInitialValues({});
    final bloc = KokuroBloc(repo: repo);
    await tester.pumpWidget(
      BlocProvider<KokuroBloc>.value(
        value: bloc,
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    // Step frames manually — the loading shimmer runs an infinite animation,
    // so pumpAndSettle would never settle. LoadLibrary resolves in a few
    // microtasks, so a handful of pumps with a frame gap is enough.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 200));
    addTearDown(bloc.close);
  }

  testWidgets('renders library entries with titles', (tester) async {
    final repo = _LibraryFakeRepo()
      ..library = [
        LibraryEntry(
          anime: anime1,
          status: WatchStatus.watching,
          watchedEpisodes: 12,
          updatedAt: DateTime(2026, 2, 1),
        ),
        LibraryEntry(
          anime: anime2,
          status: WatchStatus.planToWatch,
          watchedEpisodes: 0,
          updatedAt: DateTime(2026, 2, 2),
        ),
      ]
      ..ratings = {100: 9.5};

    await pumpLibrary(tester, repo);

    expect(find.text('Attack on Titans'), findsWidgets);
    expect(find.text('Death Note Light'), findsWidgets);
  });

  testWidgets('renders empty and loading states safely', (tester) async {
    final repo = _LibraryFakeRepo();

    await pumpLibrary(tester, repo);

    expect(find.byType(LibraryScreen), findsOneWidget);
  });
}
