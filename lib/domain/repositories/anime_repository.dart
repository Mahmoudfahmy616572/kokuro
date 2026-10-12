import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/anime.dart';
import '../entities/anime_list_result.dart';
import '../entities/library_entry.dart';
import '../entities/watch_status.dart';
import '../../data/datasources/jikan_remote_datasource.dart';

/// Repository contract that the presentation layer depends on
/// (dependency inversion). The implementation lives in `data/`.
abstract class AnimeRepository {
  Future<Either<Failure, AnimeListResult>> getTopAnime({int page, int limit});

  Future<Either<Failure, AnimeListResult>> getSeasonAnime({
    int page,
    int limit,
  });

  Future<Either<Failure, AnimeListResult>> getUpcomingAnime({
    int page,
    int limit,
  });

  Future<Either<Failure, AnimeListResult>> getAnimeByGenre({
    required String genre,
    int page,
    int? limit,
  });

  Future<Either<Failure, AnimeListResult>> getExploreList({
    String? genre,
    String? season,
    String? year,
    String? studio,
    String? type,
    String? rating,
    String? sort,
    int page,
    int limit,
  });

  Future<Either<Failure, AnimeListResult>> searchAnime({
    required String query,
    int page,
    int limit,
  });

  Future<Either<Failure, List<AnimeCharacter>>> searchCharacters({
    required String query,
    int limit,
  });

  /// Next air-date + episode for a set of watchlist ids (AniList).
  Future<Either<Failure, Map<int, ({DateTime at, int episode})>>>
  getNextAiringEpisodes(List<int> idMals);

  Future<Either<Failure, Anime?>> getAnimeDetails(int animeId);

  Future<Either<Failure, List<Anime>>> getRecommendations(int animeId);

  Future<Either<Failure, List<AnimeCharacter>>> getCharacters(int animeId);

  Future<Either<Failure, List<AnimeEpisode>>> getEpisodes(
    int animeId, {
    int page,
  });

  Future<Either<Failure, List<AnimeReview>>> getReviews(int animeId);

  Future<Either<Failure, void>> submitUserReview(
    int animeId,
    AnimeReview review,
  );

  Future<Either<Failure, List<AnimeReview>>> getUserReviews(int animeId);

  /// Real per-genre title counts (from Jikan pagination totals), cached
  /// alongside lists so the explore constellation shows live numbers,
  /// not hardcoded mock values.
  Future<Either<Failure, Map<String, int>>> getGenreCounts(List<String> genres);

  Future<Either<Failure, List<Anime>>> getWatchlist();

  Future<Either<Failure, bool>> toggleWatchlist(Anime anime);

  /// The watchlist enriched with the user's status + episode progress.
  Future<Either<Failure, List<LibraryEntry>>> getLibrary();

  Future<Either<Failure, void>> setWatchStatus(Anime anime, WatchStatus status);

  Future<Either<Failure, void>> setWatchProgress(
    Anime anime,
    int watchedEpisodes,
  );

  Future<Either<Failure, void>> removeFromLibrary(int animeId);

  Future<Either<Failure, Map<int, double>>> getRatings();

  Future<Either<Failure, void>> rateAnime(int animeId, double rating);

  Future<Either<Failure, void>> removeRating(int animeId);
}
