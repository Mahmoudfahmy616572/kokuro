// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../domain/entities/anime.dart';
import '../domain/entities/watch_status.dart';
import '../data/datasources/jikan_remote_datasource.dart';
import 'tokens.dart';
import 'components.dart';
import 'story_thread.dart';
import 'episode_player.dart';
import 'kokuro_bloc.dart';
import 'loading_widgets.dart';
import 'app_strings.dart';
import 'translation_service.dart';

class AnimeDetailScreen extends StatefulWidget {
  final int animeId;

  /// The Anime object already known at tap-time (from the card the user
  /// pressed). Lets the page paint its header instantly instead of waiting
  /// for the slow hydrated load (characters/episodes/reviews...).
  final Anime? anime;

  const AnimeDetailScreen({super.key, required this.animeId, this.anime});

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  int? _playingEpisode;

  /// Latest hydrated detail block, cached so an in-flight reload or a failed
  /// refresh never blanks the page back to a full-screen spinner.
  DetailLoaded? _lastDetail;
  String? _translatedSynopsis;

  static const _tabs = [
    AppStrings.tabStory,
    AppStrings.tabCharacters,
    AppStrings.tabEpisodes,
    AppStrings.tabReviews,
    AppStrings.tabRelated,
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KokuroBloc>().add(LoadDetail(widget.animeId));
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  /// A [DetailLoaded] assembled purely from the tap-time [Anime] so every
  /// header/hero/dna widget can render before the hydrated load lands.
  DetailLoaded _preview() {
    final anime = widget.anime!;
    return DetailLoaded(
      anime: anime,
      characters: const [],
      episodes: const [],
      recommendations: const [],
      reviews: const [],
      isInWatchlist: false,
      userRating: null,
      watchStatus: null,
      watchedEpisodes: 0,
    );
  }

  void _refreshDetail() {
    context.read<KokuroBloc>().add(LoadDetail(widget.animeId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      floatingActionButton: _buildFab(),
      body: BlocBuilder<KokuroBloc, KokuroState>(
        builder: (context, state) {
          // Only react to THIS anime's detail. After pushing a related anime
          // (detail → detail) the shared bloc flips to the OTHER anime's
          // DetailLoaded; without this guard the screen underneath would
          // repaint as the wrong title and stay wrong when the route pops.
          if (state is DetailLoaded && state.anime.malId == widget.animeId) {
            // Cache for refresh/retry so a reload never blank-screens.
            _lastDetail = state;
            // Translate synopsis to Arabic if not already done.
            if (_translatedSynopsis == null &&
                state.anime.synopsis.isNotEmpty) {
              TranslationService.toArabic(state.anime.synopsis).then((t) {
                if (mounted) setState(() => _translatedSynopsis = t);
              });
            }
            return _buildDetailContent(state);
          }
          final cached = _lastDetail;
          if (cached != null && cached.anime.malId == widget.animeId) {
            // A refresh is in flight over existing content — keep it on
            // screen with a thin progress line instead of a full loader.
            return _buildDetailContent(cached, refreshing: true);
          }
          if (widget.anime != null) {
            // First load: paint the header from tap-time data immediately.
            return _buildProgressive(state);
          }
          if (state is KokuroError) {
            return _buildFullError(state);
          }
          return const Center(
            child: KokuroLoader(label: AppStrings.enteringStory),
          );
        },
      ),
    );
  }

  Widget _buildFullError(KokuroError state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: K.coral, size: 48),
          const SizedBox(height: K.s16),
          Text(state.message, style: K.bodyLarge),
          const SizedBox(height: K.s16),
          KokuroButton(
            label: AppStrings.retry,
            icon: Icons.refresh,
            filled: false,
            accentColor: K.accent,
            onPressed: _refreshDetail,
          ),
        ],
      ),
    );
  }

  /// First-load scaffold: instant header + DNA from the tap-time [Anime],
  /// the rest of the page shows a loading body (or the error banner if the
  /// hydrate call already failed).
  Widget _buildProgressive(KokuroState state) {
    final anime = widget.anime!;
    final preview = _preview();
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(anime: anime, state: null),
        SliverToBoxAdapter(child: _buildCinematicHeader(anime, preview)),
        if (anime.trailerYoutubeId != null &&
            anime.trailerYoutubeId!.isNotEmpty)
          SliverToBoxAdapter(
            child: _TrailerTeaser(
              youtubeId: anime.trailerYoutubeId!,
              posterUrl: anime.largeImageUrl.isNotEmpty
                  ? anime.largeImageUrl
                  : anime.imageUrl,
            ),
          ),
        SliverToBoxAdapter(child: _buildAtAGlance(anime, preview)),
        if (state is KokuroError)
          SliverToBoxAdapter(child: _buildErrorBanner(state.message)),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: KokuroLoader(
              label: state is KokuroError
                  ? AppStrings.loadingFullStory
                  : AppStrings.enteringStory,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: K.s24, vertical: K.s8),
      padding: const EdgeInsets.all(K.s16),
      decoration: BoxDecoration(
        color: K.coral.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(K.r12),
        border: Border.all(color: K.coral.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: K.coral, size: 20),
          const SizedBox(width: K.s12),
          Expanded(child: Text(message, style: K.bodyMedium)),
          const SizedBox(width: K.s12),
          KokuroButton(
            label: AppStrings.retry,
            icon: Icons.refresh,
            filled: false,
            accentColor: K.accent,
            onPressed: _refreshDetail,
          ),
        ],
      ),
    );
  }

  /// Watch CTA floating at the bottom-right once content is on screen.
  Widget _buildFab() {
    final state = _lastDetail;
    if (state == null || state.anime.malId != widget.animeId) {
      return const SizedBox.shrink();
    }
    final next = state.anime.episodes > 0
        ? (state.watchedEpisodes + 1).clamp(1, state.anime.episodes)
        : 1;
    return FloatingActionButton.extended(
      onPressed: () => _openEpisode(state, next),
      backgroundColor: K.accent,
      foregroundColor: Colors.white,
      elevation: 6,
      heroTag: 'detail-watch-fab-${widget.animeId}',
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(
        state.watchedEpisodes >= state.anime.episodes &&
                state.anime.episodes > 0
            ? AppStrings.rewatch
            : state.watchedEpisodes > 0
            ? AppStrings.continueWatching
            : AppStrings.watch,
        style: K.titleMedium.copyWith(fontSize: 14, color: Colors.white),
      ),
    );
  }

  Widget _buildDetailContent(DetailLoaded state, {bool refreshing = false}) {
    final anime = state.anime;
    final content = CustomScrollView(
      slivers: [
        _buildSliverAppBar(anime: anime, state: state),
        SliverToBoxAdapter(child: _buildCinematicHeader(anime, state)),
        if (anime.trailerYoutubeId != null &&
            anime.trailerYoutubeId!.isNotEmpty)
          SliverToBoxAdapter(
            child: _TrailerTeaser(
              youtubeId: anime.trailerYoutubeId!,
              posterUrl: anime.largeImageUrl.isNotEmpty
                  ? anime.largeImageUrl
                  : anime.imageUrl,
            ),
          ),
        SliverToBoxAdapter(child: _buildAtAGlance(anime, state)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _TabBarDelegate(tabCtrl: _tabCtrl, tabs: _tabs),
        ),
        SliverToBoxAdapter(child: _buildTabContent(state)),
      ],
    );
    if (!refreshing) return content;
    return Stack(
      children: [
        content,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: K.bg.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(K.accent),
          ),
        ),
      ],
    );
  }

  // ── Episode playback + automatic watch tracking ──────────

  void _openEpisode(DetailLoaded state, int number) {
    setState(() => _playingEpisode = number);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(K.s24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: EpisodePlayer(
              anime: state.anime,
              episodeNumber: number,
              totalEpisodes: state.anime.episodes,
              onStarted: () => _trackEpisodeStarted(number),
              onCompleted: () => _trackEpisodeCompleted(state.anime, number),
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _playingEpisode = null);
    });
  }

  void _trackEpisodeStarted(int number) {
    final bloc = context.read<KokuroBloc>();
    final current = bloc.state;
    if (current is! DetailLoaded) return;
    if (!current.isInWatchlist) {
      bloc.add(SetWatchStatus(current.anime, WatchStatus.watching));
    }
    // Episode `number` is now in progress, so everything before it is done.
    if (number - 1 > current.watchedEpisodes) {
      bloc.add(SetWatchProgress(current.anime, number - 1));
    }
  }

  void _trackEpisodeCompleted(Anime anime, int number) {
    final bloc = context.read<KokuroBloc>();
    final current = bloc.state;
    if (current is! DetailLoaded) return;
    if (number > current.watchedEpisodes) {
      bloc.add(SetWatchProgress(anime, number));
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('تم تحديد الحلقة $number كمشاهدة'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 320,
          backgroundColor: K.bgCard,
        ),
      );
  }

  /// Manual "watched" toggle per episode — lets the user mark progress even
  /// when the episode itself is watched on an external platform (Crunchyroll
  /// etc), so the tracking data stays genuinely useful.
  void _toggleEpisodeWatched(DetailLoaded state, int number, bool isWatched) {
    final bloc = context.read<KokuroBloc>();
    final anime = state.anime;
    if (!state.isInWatchlist) {
      bloc.add(SetWatchStatus(anime, WatchStatus.watching));
    }
    final target = isWatched ? number - 1 : number;
    bloc.add(SetWatchProgress(anime, target.clamp(0, anime.episodes)));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isWatched
                ? 'تمت إزالة علامة المشاهدة عن الحلقة $number'
                : 'تم تحديد الحلقة $number كمشاهدة',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 340,
          backgroundColor: K.bgCard,
        ),
      );
  }

  // ── App Bar ──────────────────────────────────────────────

  Widget _buildSliverAppBar({
    required Anime anime,
    required DetailLoaded? state,
  }) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: K.bg.withValues(alpha: 0.96),
      title: Text(
        AppStrings.appName,
        style: K.labelUppercase.copyWith(
          color: K.accent,
          letterSpacing: 3,
          fontSize: 13,
        ),
      ),
      centerTitle: true,
      automaticallyImplyLeading: false,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded, color: K.textSecondary),
          color: K.bgCard,
          onSelected: (value) => _handleMenuAction(value, state),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'watch',
              child: _menuItem(
                Icons.play_circle_outline_rounded,
                AppStrings.watchNow,
              ),
            ),
            if (state != null) ...[
              PopupMenuItem(
                value: 'list',
                child: _menuItem(
                  state.isInWatchlist
                      ? Icons.check_circle_outline_rounded
                      : Icons.add_circle_outline_rounded,
                  state.isInWatchlist
                      ? AppStrings.removeFromMyList
                      : AppStrings.addToMyList,
                ),
              ),
              PopupMenuItem(
                value: 'rate',
                child: _menuItem(
                  Icons.star_outline_rounded,
                  AppStrings.rateThisAnime,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'review',
                child: _menuItem(Icons.edit_outlined, AppStrings.writeReview),
              ),
            ],
            PopupMenuItem(
              value: 'refresh',
              child: _menuItem(Icons.refresh_rounded, AppStrings.refresh),
            ),
          ],
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: K.textSecondary),
        const SizedBox(width: K.s12),
        Text(label, style: K.bodyMedium),
      ],
    );
  }

  void _handleMenuAction(String value, DetailLoaded? state) {
    switch (value) {
      case 'watch':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.streamingComingSoon)),
        );
      case 'list':
        if (state != null) {
          context.read<KokuroBloc>().add(ToggleWatchlistItem(state.anime));
        }
      case 'rate':
        if (state != null) _showRateSheet(state);
      case 'review':
        if (state != null) _showWriteReviewSheet(state);
      case 'refresh':
        _refreshDetail();
    }
  }

  // ── Header ───────────────────────────────────────────────

  Widget _buildCinematicHeader(Anime anime, DetailLoaded state) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    return Container(
      margin: const EdgeInsets.fromLTRB(K.s24, K.s8, K.s24, 0),
      child: isWide
          ? _buildDesktopHeader(anime, state)
          : _buildMobileHeader(anime, state),
    );
  }

  Widget _buildMobileHeader(Anime anime, DetailLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Hero(
            tag: 'poster-${anime.malId}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(K.r16),
              child: KuroImg(anime.imageUrl, width: 160, height: 230),
            ),
          ),
        ),
        const SizedBox(height: K.s20),
        _buildAnimeInfo(anime, state),
      ],
    );
  }

  Widget _buildDesktopHeader(Anime anime, DetailLoaded state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: 'poster-${anime.malId}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(K.r16),
            child: KuroImg(anime.imageUrl, width: 200, height: 300),
          ),
        ),
        const SizedBox(width: K.s24),
        Expanded(child: _buildAnimeInfo(anime, state)),
      ],
    );
  }

  Widget _buildAnimeInfo(Anime anime, DetailLoaded state) {
    final members = anime.members ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(anime.title, style: K.headlineLarge),
        const SizedBox(height: K.s12),
        Wrap(
          spacing: K.s6,
          runSpacing: K.s6,
          children: anime.genres.map((g) {
            return PersonalityTag(label: g, color: K.accentSoft);
          }).toList(),
        ),
        const SizedBox(height: K.s16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, color: K.gold, size: 20),
            const SizedBox(width: K.s4),
            Text(
              anime.score > 0 ? anime.score.toStringAsFixed(1) : '—',
              style: K.titleMedium.copyWith(
                color: K.gold,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            if (members > 0) ...[
              const SizedBox(width: K.s12),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: K.textTertiary,
                ),
              ),
              const SizedBox(width: K.s12),
              Text(
                '${(members / 1000).toStringAsFixed(1)}K ${AppStrings.members}',
                style: K.bodySmall,
              ),
            ],
            const Spacer(),
            if (anime.status.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: K.s8,
                  vertical: K.s4,
                ),
                decoration: BoxDecoration(
                  color: K.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(K.rFull),
                  border: Border.all(color: K.accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  anime.status,
                  style: K.bodySmall.copyWith(
                    color: K.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: K.s12),
        Row(
          children: [
            if (anime.year > 0) ...[
              _metadataChip('${anime.year}'),
              const SizedBox(width: K.s8),
            ],
            if (anime.episodes > 0) ...[
              _metadataChip('${anime.episodes} ${AppStrings.episodes}'),
              const SizedBox(width: K.s8),
            ],
            if (anime.score > 0 && (anime.members ?? 0) == 0)
              _metadataChip(
                '${AppStrings.score} ${anime.score.toStringAsFixed(1)}',
              ),
          ],
        ),
        if (state.userRating != null) ...[
          const SizedBox(height: K.s12),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: K.gold, size: 15),
              const SizedBox(width: K.s4),
              Text(
                '${AppStrings.yourRating}${state.userRating!.toStringAsFixed(1)}',
                style: K.bodySmall.copyWith(color: K.gold),
              ),
            ],
          ),
        ],
        const SizedBox(height: K.s16),
        _buildActionButtons(state),
      ],
    );
  }

  Widget _metadataChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: K.s8, vertical: K.s4),
      decoration: BoxDecoration(
        color: K.bgSurface,
        borderRadius: BorderRadius.circular(K.r4),
      ),
      child: Text(text, style: K.bodySmall),
    );
  }

  Widget _buildActionButtons(DetailLoaded state) {
    return Wrap(
      spacing: K.s12,
      runSpacing: K.s12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        KokuroButton(
          label:
              state.watchedEpisodes >= state.anime.episodes &&
                  state.anime.episodes > 0
              ? AppStrings.rewatch
              : state.watchedEpisodes > 0
              ? '${AppStrings.continueWatching} ${AppStrings.episode} ${state.watchedEpisodes + 1}'
              : AppStrings.watchNow,
          icon: Icons.play_arrow_rounded,
          filled: true,
          onPressed: () {
            final next = state.watchedEpisodes + 1;
            if (state.anime.episodes > 0 && next <= state.anime.episodes) {
              _openEpisode(state, next);
            } else if (state.anime.episodes > 0) {
              _openEpisode(state, 1);
            }
          },
        ),
        MyListButton(
          inList: state.isInWatchlist,
          status: state.watchStatus,
          addLabel: AppStrings.addToMyList,
          onSelect: (value) {
            context.read<KokuroBloc>().add(SetWatchStatus(state.anime, value));
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('${AppStrings.savedToList} · ${value.label}'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  width: 320,
                  backgroundColor: K.bgCard,
                ),
              );
          },
          onRemove: () {
            context.read<KokuroBloc>().add(
              RemoveFromLibraryEvent(state.anime.malId),
            );
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text(AppStrings.removedFromList),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  width: 320,
                  backgroundColor: K.bgCard,
                ),
              );
          },
        ),
        if (state.isInWatchlist && state.anime.episodes > 0)
          _buildProgressControl(state),
      ],
    );
  }

  Widget _buildProgressControl(DetailLoaded state) {
    final total = state.anime.episodes;
    final watched = state.watchedEpisodes.clamp(0, total);
    final color = _statusColor(state.watchStatus ?? WatchStatus.planToWatch);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: K.bgCard,
        borderRadius: BorderRadius.circular(K.rFull),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _progressStep(
            Icons.remove_rounded,
            watched > 0
                ? () => context.read<KokuroBloc>().add(
                    SetWatchProgress(state.anime, watched - 1),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: K.s8),
            child: Text(
              '$watched / $total ${AppStrings.eps}',
              style: K.bodyMedium.copyWith(color: K.textPrimary, fontSize: 13),
            ),
          ),
          _progressStep(
            Icons.add_rounded,
            watched < total
                ? () => context.read<KokuroBloc>().add(
                    SetWatchProgress(state.anime, watched + 1),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _progressStep(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? K.textTertiary.withValues(alpha: 0.4)
              : K.textPrimary,
        ),
      ),
    );
  }

  Color _statusColor(WatchStatus status) {
    switch (status) {
      case WatchStatus.watching:
        return K.cyan;
      case WatchStatus.completed:
        return const Color(0xFF4CD97B);
      case WatchStatus.planToWatch:
        return K.orange;
      case WatchStatus.onHold:
        return K.gold;
      case WatchStatus.dropped:
        return K.textTertiary;
    }
  }

  // ── At a Glance Section ──────────────────────────────────

  Widget _buildAtAGlance(Anime anime, DetailLoaded state) {
    final members = anime.members ?? 0;
    final items = <(IconData, String, String)>[];

    if (anime.score > 0) {
      items.add((
        Icons.star_rounded,
        anime.score.toStringAsFixed(1),
        AppStrings.score,
      ));
    }
    if (anime.status.isNotEmpty) {
      items.add((
        Icons.play_circle_outline_rounded,
        anime.status,
        AppStrings.status,
      ));
    }
    if (anime.year > 0) {
      items.add((
        Icons.calendar_today_rounded,
        '${anime.year}',
        AppStrings.year,
      ));
    }
    if (anime.episodes > 0) {
      items.add((
        Icons.movie_outlined,
        '${anime.episodes}',
        AppStrings.episodes,
      ));
    }
    if (members > 0) {
      items.add((
        Icons.group_outlined,
        '${(members / 1000).toStringAsFixed(1)}K',
        AppStrings.members,
      ));
    }
    if (state.characters.isNotEmpty) {
      items.add((
        Icons.people_outline_rounded,
        '${state.characters.length}',
        AppStrings.characters,
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(K.s24, K.s24, K.s24, K.s8),
      padding: const EdgeInsets.symmetric(horizontal: K.s16, vertical: K.s16),
      decoration: BoxDecoration(
        color: K.bgCard,
        borderRadius: BorderRadius.circular(K.r16),
        border: Border.all(color: K.borderSubtle, width: 1),
      ),
      child: Wrap(
        spacing: K.s8,
        runSpacing: K.s12,
        children: items.map((item) {
          return SizedBox(
            width: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.$1, color: K.accent, size: 18),
                const SizedBox(height: K.s4),
                Text(
                  item.$2,
                  style: K.titleMedium.copyWith(fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: K.s2),
                Text(
                  item.$3,
                  style: K.bodySmall.copyWith(
                    color: K.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tabs ─────────────────────────────────────────────────

  Widget _buildTabContent(DetailLoaded state) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.68,
      child: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildStoryTab(state),
          _buildCharactersTab(state),
          _buildEpisodesTab(state),
          _buildReviewsTab(state),
          _buildRelatedTab(state),
        ],
      ),
    );
  }

  // ── Story Tab ────────────────────────────────────────────

  Widget _buildStoryTab(DetailLoaded state) {
    final streamLinks = state.anime.streamingLinks;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(K.s24, K.s20, K.s24, K.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.synopsis, style: K.headlineMedium),
          const SizedBox(height: K.s12),
          Text(
            state.anime.synopsis.isNotEmpty
                ? (_translatedSynopsis ?? state.anime.synopsis)
                : AppStrings.noSynopsis,
            style: K.bodyLarge.copyWith(height: 1.75),
          ),
          if (streamLinks.isNotEmpty) ...[
            const SizedBox(height: K.s24),
            Text(AppStrings.watchOn, style: K.headlineMedium),
            const SizedBox(height: K.s12),
            Wrap(
              spacing: K.s12,
              runSpacing: K.s12,
              children: [
                for (final link in streamLinks) _buildStreamingChip(link),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamingChip(StreamingLink link) {
    final (icon, color) = _siteIcon(link.site);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => html.window.open(link.url, '_blank'),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: K.s16,
            vertical: K.s12,
          ),
          decoration: BoxDecoration(
            color: K.bgCard,
            borderRadius: BorderRadius.circular(K.r12),
            border: Border.all(color: K.border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: K.s8),
              Text(link.label, style: K.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _siteIcon(String site) {
    final s = site.toLowerCase();
    if (s.contains('crunchyroll')) {
      return (Icons.play_circle_outline_rounded, K.orange);
    }
    if (s.contains('netflix')) {
      return (Icons.play_arrow_rounded, K.coral);
    }
    if (s.contains('prime')) {
      return (Icons.play_circle_outline_rounded, K.cyan);
    }
    if (s.contains('disney')) {
      return (Icons.play_circle_fill_rounded, Color(0xFF4FD1FF));
    }
    if (s.contains('hikari') || s.contains('chill') || s.contains('hidive')) {
      return (Icons.ondemand_video_rounded, K.pink);
    }
    if (s.contains('toukaiseru') || s.contains('anime') || s.contains('icl')) {
      return (Icons.tv_rounded, K.gold);
    }
    return (Icons.language_rounded, K.textSecondary);
  }

  // ── Empty State ──────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(K.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: K.bgSurface,
                border: Border.all(color: K.borderSubtle, width: 1),
              ),
              child: Icon(icon, color: K.textTertiary, size: 28),
            ),
            const SizedBox(height: K.s16),
            Text(title, style: K.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: K.s6),
              Text(
                subtitle,
                style: K.bodySmall.copyWith(color: K.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Characters Tab ───────────────────────────────────────

  Widget _buildCharactersTab(DetailLoaded state) {
    final characters = state.characters;
    if (characters.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        title: AppStrings.noCharacters,
        subtitle: AppStrings.noCharactersSubtitle,
      );
    }

    return SizedBox(
      height: 210,
      child: ListView.separated(
        padding: const EdgeInsets.all(K.s24),
        scrollDirection: Axis.horizontal,
        itemCount: characters.length,
        separatorBuilder: (_, _) => const SizedBox(width: K.s20),
        itemBuilder: (_, i) {
          final char = characters[i];
          return GestureDetector(
            onTap: () async {
              await context.push('/character/${char.malId}');
              if (mounted) _refreshDetail();
            },
            child: Column(
              children: [
                ThreadNode(
                  size: 100,
                  glowColor: K.threadPrimary,
                  child: KuroImg(char.imageUrl),
                ),
                const SizedBox(height: K.s8),
                Text(
                  char.name,
                  style: K.titleMedium.copyWith(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: K.s2),
                PersonalityTag(label: char.role, color: K.accentSoft),
                const SizedBox(height: K.s6),
                if (char.voiceActorName != null &&
                    char.voiceActorName!.isNotEmpty)
                  SizedBox(
                    width: 120,
                    child: Text(
                      char.voiceActorName!,
                      style: K.bodySmall.copyWith(fontSize: 10),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Episodes Tab ─────────────────────────────────────────

  Widget _buildEpisodesTab(DetailLoaded state) {
    // Jikan frequently returns no episode list even when the episode count is
    // known, so fall back to a numbered list built from the total.
    final count = state.anime.episodes;
    final List<AnimeEpisode> episodes;
    if (state.episodes.isNotEmpty) {
      episodes = state.episodes;
    } else if (count > 0) {
      final n = count > 100 ? 100 : count;
      episodes = List<AnimeEpisode>.generate(
        n,
        (i) => AnimeEpisode(
          number: i + 1,
          title: '${AppStrings.episode} ${i + 1}',
        ),
      );
    } else {
      episodes = const [];
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(K.s24, K.s16, K.s24, K.s12),
          child: Text(
            episodes.isEmpty
                ? AppStrings.episodes
                : '${episodes.length} ${AppStrings.episodes}',
            style: K.headlineMedium,
          ),
        ),
        Expanded(
          child: episodes.isEmpty
              ? _buildEmptyState(
                  icon: Icons.movie_outlined,
                  title: AppStrings.noEpisodes,
                  subtitle: AppStrings.noEpisodesSubtitle,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: K.s24),
                  itemCount: episodes.length,
                  itemBuilder: (_, i) {
                    final ep = episodes[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: K.s4),
                      child: _buildRealEpisodeItem(
                        state,
                        ep,
                        ep.number == _playingEpisode,
                        ep.number <= state.watchedEpisodes,
                        () => _openEpisode(state, ep.number),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRealEpisodeItem(
    DetailLoaded state,
    AnimeEpisode ep,
    bool isActive,
    bool isWatched,
    VoidCallback onPlay,
  ) {
    bool hovered = false;
    return StatefulBuilder(
      builder: (context, setInnerState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setInnerState(() => hovered = true),
          onExit: (_) => setInnerState(() => hovered = false),
          child: GestureDetector(
            onTap: onPlay,
            child: Container(
              padding: const EdgeInsets.all(K.s12),
              decoration: BoxDecoration(
                color: isActive
                    ? K.accent.withValues(alpha: 0.08)
                    : hovered
                    ? K.bgCard
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(K.r8),
                border: Border.all(
                  color: isActive
                      ? K.accent.withValues(alpha: 0.3)
                      : hovered
                      ? K.border
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(K.r4),
                    child: Container(
                      width: 80,
                      height: 45,
                      color: K.bgSurface,
                      child: Center(
                        child: isActive || hovered
                            ? const Icon(
                                Icons.play_arrow_rounded,
                                color: K.textPrimary,
                                size: 24,
                              )
                            : Text(
                                '${ep.number}',
                                style: K.titleMedium.copyWith(
                                  color: K.textTertiary,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: K.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${AppStrings.episode} ${ep.number} \u2022 ${ep.title}',
                          style: K.bodyMedium.copyWith(
                            color: isWatched ? K.textSecondary : K.textPrimary,
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: K.s2),
                        Text(
                          '${AppStrings.aired} ${ep.aired.isEmpty ? AppStrings.tba : ep.aired}',
                          style: K.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (ep.score != null && ep.score! > 0)
                    Text(
                      ep.score!.toStringAsFixed(1),
                      style: K.bodySmall.copyWith(color: K.gold),
                    ),
                  const SizedBox(width: K.s8),
                  GestureDetector(
                    onTap: () =>
                        _toggleEpisodeWatched(state, ep.number, isWatched),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(K.s4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(K.r8),
                        color: K.bgSurface,
                      ),
                      child: isWatched
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: K.accent,
                              size: 18,
                            )
                          : const Icon(
                              Icons.radio_button_unchecked_rounded,
                              color: K.textTertiary,
                              size: 18,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Reviews Tab ──────────────────────────────────────────

  Widget _buildReviewsTab(DetailLoaded state) {
    final reviews = state.reviews;
    final hasUser = reviews.any((r) => r.isUser);
    final communityCount = reviews.where((r) => !r.isUser).length;

    return ListView.builder(
      padding: const EdgeInsets.all(K.s24),
      itemCount: reviews.isEmpty ? 3 : 2 + reviews.length,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildWriteReviewCard(state, hasUser);
        }
        if (index == 1) {
          return Padding(
            padding: const EdgeInsets.only(top: K.s16),
            child: Row(
              children: [
                Text(
                  AppStrings.communityReviews.toUpperCase(),
                  style: K.labelUppercase,
                ),
                const SizedBox(width: K.s8),
                Text('($communityCount)', style: K.bodySmall),
              ],
            ),
          );
        }
        if (reviews.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: K.s16),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: K.s40),
                child: Column(
                  children: [
                    const Icon(
                      Icons.rate_review_outlined,
                      color: K.textTertiary,
                      size: 40,
                    ),
                    const SizedBox(height: K.s12),
                    Text(
                      AppStrings.noReviews,
                      style: K.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // reviews[index-2]
        return Padding(
          padding: const EdgeInsets.only(top: K.s16),
          child: _buildReviewCard(reviews[index - 2]),
        );
      },
    );
  }

  Widget _buildWriteReviewCard(DetailLoaded state, bool hasUser) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showWriteReviewSheet(state),
        child: Container(
          padding: const EdgeInsets.all(K.s12),
          decoration: BoxDecoration(
            color: K.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(K.r12),
            border: Border.all(
              color: K.accent.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: K.accent.withValues(alpha: 0.15),
                ),
                child: Icon(
                  hasUser ? Icons.edit_rounded : Icons.add_comment_outlined,
                  color: K.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: K.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasUser
                          ? AppStrings.editReview
                          : AppStrings.writeYourReview,
                      style: K.titleMedium.copyWith(color: K.accent),
                    ),
                    const SizedBox(height: K.s2),
                    Text(AppStrings.shareYourThoughts, style: K.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: K.accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWriteReviewSheet(DetailLoaded state) async {
    final controller = TextEditingController();
    double rating = state.userRating ?? 7;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(K.s24),
            decoration: const BoxDecoration(
              color: K.bgAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(K.r20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: K.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: K.s20),
                Text(AppStrings.writeReview, style: K.headlineMedium),
                const SizedBox(height: K.s8),
                Text(state.anime.title, style: K.bodyMedium),
                const SizedBox(height: K.s24),
                Row(
                  children: [
                    Text(AppStrings.yourRating, style: K.bodyLarge),
                    Text(
                      rating.toStringAsFixed(1),
                      style: K.rating.copyWith(color: K.gold),
                    ),
                  ],
                ),
                Slider(
                  value: rating,
                  min: 1,
                  max: 10,
                  divisions: 18,
                  activeColor: K.accent,
                  label: rating.toStringAsFixed(1),
                  onChanged: (v) => setSheetState(() => rating = v),
                ),
                const SizedBox(height: K.s12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  maxLength: 600,
                  style: K.bodyMedium.copyWith(color: K.textPrimary),
                  decoration: InputDecoration(
                    hintText: AppStrings.whatDidYouThink,
                    hintStyle: K.bodyMedium.copyWith(color: K.textTertiary),
                    filled: true,
                    fillColor: K.bgCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(K.r12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: K.s8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(AppStrings.cancel),
                    ),
                    const SizedBox(width: K.s8),
                    KokuroButton(
                      label: AppStrings.submitReview,
                      icon: Icons.send_rounded,
                      filled: true,
                      onPressed: () {
                        final text = controller.text.trim();
                        if (text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(AppStrings.pleaseWriteThoughts),
                            ),
                          );
                          return;
                        }
                        context.read<KokuroBloc>().add(
                          SubmitReview(
                            animeId: widget.animeId,
                            review: AnimeReview(
                              username: AppStrings.you,
                              text: text,
                              overall: rating,
                              isUser: true,
                              animeId: widget.animeId,
                            ),
                          ),
                        );
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRateSheet(DetailLoaded state) async {
    double rating = state.userRating ?? 0;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(K.s24),
          decoration: const BoxDecoration(
            color: K.bgAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(K.r20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.rateThisAnime, style: K.headlineMedium),
              const SizedBox(height: K.s16),
              Row(
                children: [
                  Expanded(
                    child: Text(AppStrings.yourRating, style: K.bodyLarge),
                  ),
                  Text(
                    rating > 0 ? rating.toStringAsFixed(1) : '—',
                    style: K.rating.copyWith(color: K.gold),
                  ),
                ],
              ),
              Slider(
                value: rating,
                min: 0,
                max: 10,
                divisions: 20,
                activeColor: K.accent,
                onChanged: (v) => setSheetState(() => rating = v),
              ),
              const SizedBox(height: K.s8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(AppStrings.cancel),
                  ),
                  const SizedBox(width: K.s8),
                  KokuroButton(
                    label: rating > 0
                        ? AppStrings.saveRating
                        : AppStrings.clearRating,
                    icon: rating > 0
                        ? Icons.check_rounded
                        : Icons.delete_outline_rounded,
                    filled: true,
                    onPressed: () {
                      if (rating > 0) {
                        context.read<KokuroBloc>().add(
                          RateAnimeEvent(
                            animeId: widget.animeId,
                            rating: rating,
                          ),
                        );
                      } else {
                        context.read<KokuroBloc>().add(
                          RemoveRatingEvent(widget.animeId),
                        );
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(AnimeReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: K.s16),
      padding: const EdgeInsets.all(K.s16),
      decoration: BoxDecoration(
        color: review.isUser ? K.accent.withValues(alpha: 0.05) : K.bgCard,
        borderRadius: BorderRadius.circular(K.r12),
        border: Border.all(
          color: review.isUser
              ? K.accent.withValues(alpha: 0.3)
              : K.borderSubtle,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: review.isUser
                    ? K.accent.withValues(alpha: 0.2)
                    : K.bgSurface,
                child: Text(
                  review.username.isEmpty ? '?' : review.username[0],
                  style: K.titleMedium.copyWith(
                    fontSize: 14,
                    color: review.isUser ? K.accent : null,
                  ),
                ),
              ),
              const SizedBox(width: K.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.username,
                      style: K.titleMedium.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: K.s2),
                    if (review.overall > 0)
                      RatingStars(rating: review.overall, size: 12),
                  ],
                ),
              ),
              if (review.isUser)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: K.s8,
                    vertical: K.s2,
                  ),
                  decoration: BoxDecoration(
                    color: K.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(K.rFull),
                  ),
                  child: Text(
                    AppStrings.you,
                    style: K.bodySmall.copyWith(color: K.accent, fontSize: 10),
                  ),
                )
              else if (review.overall > 0)
                Text(
                  '${review.overall.toStringAsFixed(1)}/10',
                  style: K.rating.copyWith(fontSize: 18),
                ),
            ],
          ),
          const SizedBox(height: K.s12),
          Text(review.text, style: K.bodyMedium),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: K.s12),
            Wrap(
              spacing: K.s8,
              runSpacing: K.s6,
              children: review.tags.map((t) {
                return PersonalityTag(label: t, color: K.accentSoft);
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ── Related Tab ──────────────────────────────────────────

  Widget _buildRelatedTab(DetailLoaded state) {
    final related = state.recommendations;
    if (related.isEmpty) {
      return _buildEmptyState(
        icon: Icons.recommend_outlined,
        title: AppStrings.noRecommendations,
        subtitle: AppStrings.noRecommendationsSubtitle,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(K.s24),
      itemCount: related.length,
      itemBuilder: (_, i) {
        final anime = related[i];
        return GestureDetector(
          onTap: () async {
            await context.push('/anime/${anime.malId}', extra: anime);
            if (mounted) _refreshDetail();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: K.s16,
              vertical: K.s12,
            ),
            margin: const EdgeInsets.only(bottom: K.s8),
            decoration: BoxDecoration(
              color: K.bgCard,
              borderRadius: BorderRadius.circular(K.r12),
              border: Border.all(color: K.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(K.r8),
                  child: KuroImg(anime.imageUrl, width: 44, height: 56),
                ),
                const SizedBox(width: K.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anime.title,
                        style: K.titleMedium.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: K.s2),
                      Text(
                        anime.genres.take(2).join(' \u2022 '),
                        style: K.bodySmall,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${i + 1}',
                  style: K.headlineMedium.copyWith(
                    color: K.textTertiary.withValues(alpha: 0.3),
                    fontSize: 28,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Trailer Teaser — lazy poster gate. The heavy YouTube platform-view
//  (iframe + JS bridge + tick timers) is only built once the user taps
//  play, so opening a detail page costs zero video runtime.
// ══════════════════════════════════════════════════════════

class _TrailerTeaser extends StatefulWidget {
  final String youtubeId;
  final String posterUrl;

  const _TrailerTeaser({required this.youtubeId, required this.posterUrl});

  @override
  State<_TrailerTeaser> createState() => _TrailerTeaserState();
}

class _TrailerTeaserState extends State<_TrailerTeaser> {
  bool _armed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (_armed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(K.s24, K.s16, K.s24, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(K.r16),
          child: _TrailerSection(
            youtubeId: widget.youtubeId,
            posterUrl: widget.posterUrl,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(K.s24, K.s16, K.s24, 0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => setState(() => _armed = true),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: K.normal,
            height: 80,
            decoration: BoxDecoration(
              color: _hovered ? K.bgCard : K.bgSurface,
              borderRadius: BorderRadius.circular(K.r16),
              border: Border.all(
                color: _hovered
                    ? K.accent.withValues(alpha: 0.4)
                    : K.borderSubtle,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    bottomLeft: Radius.circular(15),
                  ),
                  child: SizedBox(
                    width: 120,
                    height: 80,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        KuroImg(widget.posterUrl, fit: BoxFit.cover),
                        Container(color: Colors.black.withValues(alpha: 0.3)),
                        Center(
                          child: AnimatedScale(
                            scale: _hovered ? 1.15 : 1.0,
                            duration: K.normal,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: K.accent,
                                shape: BoxShape.circle,
                                boxShadow: K.glow(color: K.accent, blur: 16),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: K.s12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.watchTrailer,
                        style: K.titleMedium.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: K.s2),
                      Text(
                        AppStrings.youtube,
                        style: K.bodySmall.copyWith(color: K.textTertiary),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: K.s12),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: K.textTertiary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Trailer Section — custom in-app player. The video layer is a
//  YouTube-hosted stream inside a bare iframe with ALL of its own
//  controls disabled; every control you see (play/pause, seek,
//  time, fullscreen) is OUR chrome, themed like the rest of the app
//  and driven through the embed's JS API over postMessage.
// ══════════════════════════════════════════════════════════

class _TrailerSection extends StatefulWidget {
  final String youtubeId;
  final String posterUrl;

  const _TrailerSection({required this.youtubeId, required this.posterUrl});

  @override
  State<_TrailerSection> createState() => _TrailerSectionState();
}

class _TrailerSectionState extends State<_TrailerSection> {
  static final Set<String> _registeredViewTypes = {};
  late final html.EventListener _messageListener;

  html.DivElement? _root;
  Timer? _tapTimer;
  bool _playing = false;
  bool _ended = false;
  bool _muted = false;
  bool _pendingPlay = false;
  Timer? _kickTimer;
  int _kickTries = 0;
  bool _gaveUp = false;
  bool _unmuteSent = false;
  Timer? _tickTimer;
  bool _playbackActive = false;
  double? _queuedSeek;
  int _queuedAtMs = 0;

  // Bridge health: the timer/slider only advance once the JS bridge has
  // actually delivered player data, so a missing/failed bridge can never
  // display a fake self-incrementing clock.
  bool _bridgeReady = false;
  bool _bridgeSeen = false;
  bool _playerFailed = false;
  int? _playerErrorCode;
  Timer? _watchdog;

  String _playerState = 'unstarted'; // unstarted|playing|paused|buffering|ended
  double _current = 0;
  double _duration = 0;
  double? _drag;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  double _volume = 1;
  double _rate = 1.0;

  late final html.EventListener _keyListener;

  static const _playSvg =
      '<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>';
  static const _pauseSvg =
      '<svg viewBox="0 0 24 24"><path d="M6 5h4v14H6zM14 5h4v14h-4z"/></svg>';
  static const _replaySvg =
      '<svg viewBox="0 0 24 24"><path d="M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"/></svg>';
  static const _volUpSvg =
      '<svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>';
  static const _volOffSvg =
      '<svg viewBox="0 0 24 24"><path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/></svg>';
  static const _fsSvg =
      '<svg viewBox="0 0 24 24"><path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z"/></svg>';

  String get _viewType => 'kuro-trailer-${widget.youtubeId}';

  @override
  void initState() {
    super.initState();
    _messageListener = _onWindowMessage;
    html.window.addEventListener('message', _messageListener);
    _keyListener = _onKeyDown;
    html.window.addEventListener('keydown', _keyListener);
    // Ask the JS bridge to identify itself so we can tell "bridge missing"
    // (stale page) apart from "player failed" before showing an error.
    html.window.postMessage(
      jsonEncode({'channel': 'kuro', 'viewType': '*', 'event': 'ping'}),
      '*',
    );
    try {
      final saved = html.window.localStorage['kuro_volume'];
      final parsed = double.tryParse(saved ?? '');
      if (parsed != null && parsed >= 0 && parsed <= 1) _volume = parsed;
    } catch (_) {}
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _tapTimer?.cancel();
    _kickTimer?.cancel();
    _tickTimer?.cancel();
    _watchdog?.cancel();
    html.window.removeEventListener('message', _messageListener);
    html.window.removeEventListener('keydown', _keyListener);
    html.window.postMessage(
      jsonEncode({
        'channel': 'kuro',
        'viewType': _viewType,
        'event': 'dispose',
      }),
      '*',
    );
    super.dispose();
  }

  // ── Bridge to the video layer ────────────────────────────

  void _registerPlayer() {
    if (_registeredViewTypes.contains(widget.youtubeId)) return;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final root = html.DivElement()
        ..className = 'krvp'
        ..style.width = '100%'
        ..style.height = '100%';
      // IMPORTANT: use the trusted sanitizer — Dart's default innerHtml
      // sanitizer strips the iframe's `src`/`allow` plus every button's
      // `data-act` and the SVG icons, leaving a dead player that spins
      // forever on a black screen.
      root.setInnerHtml(
        _chromeHtml(),
        treeSanitizer: html.NodeTreeSanitizer.trusted,
      );
      _root = root;

      // The player chrome CSS and the YouTube IFrame API JS bridge live in
      // web/index.html and are loaded with the page, so nothing needs to be
      // injected into <head> at runtime.
      html.window.postMessage(
        jsonEncode({
          'channel': 'kuro',
          'viewType': _viewType,
          'event': 'attach',
        }),
        '*',
      );

      // Every control is REAL DOM (the iframe has pointer-events:none,
      // so clicks can never leak into YouTube). Delegated click handler.
      root.addEventListener('click', (html.Event e) {
        final target = e.target;
        if (target is! html.Element) return;
        final btn = target.closest('[data-act]');
        if (btn != null) _runAction(btn.getAttribute('data-act') ?? '');
      }, true);

      final seek =
          root.querySelector('input.krv-seek') as html.RangeInputElement?;
      seek?.onInput.listen((_) {
        final v = double.tryParse(seek.value ?? '') ?? 0;
        setState(() => _drag = v);
        _syncChrome();
        _showControls();
      });
      seek?.onChange.listen((_) {
        final v = double.tryParse(seek.value ?? '') ?? 0;
        _sendCommand('seekTo', [v, true]);
        _queuedSeek = v;
        _queuedAtMs = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _current = v;
          _drag = null;
        });
        _syncChrome();
        _showControls();
      });

      final vol = root.querySelector('#krv-vol') as html.RangeInputElement?;
      vol?.onInput.listen((_) {
        _setVolume((double.tryParse(vol.value ?? '') ?? 0) / 100);
      });

      final rate = root.querySelector('select.krv-rate') as html.SelectElement?;
      rate?.onChange.listen((_) {
        _setRate(double.tryParse(rate.value ?? '') ?? 1.0);
      });

      final tap = root.querySelector('.krv-tap') as html.DivElement?;
      tap?.onClick.listen((_) => _tapSingle());
      tap?.onDoubleClick.listen((_) => _tapDouble());

      root.onMouseMove.listen((_) {
        if (_playing) _showControls();
      });

      _syncChrome();

      // Volume/playback-rate apply only once the API is up.
      Timer(const Duration(seconds: 2), () {
        if (_root == root && _playing) {
          _sendCommand('setVolume', [(_volume * 100).roundToDouble()]);
          _sendCommand('setPlaybackRate', [_rate]);
        }
      });

      return root;
    });
    _registeredViewTypes.add(widget.youtubeId);
  }

  String _chromeHtml() {
    final rates = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final rateOpts = rates
        .map(
          (r) =>
              '<option value="${r.toStringAsFixed(2)}"'
              '${(r - _rate).abs() < 0.001 ? ' selected' : ''}>'
              '${r.toStringAsFixed(2)}x</option>',
        )
        .join();

    return '''
    <div id="kuro-player-${widget.youtubeId}" class="krv-frame"></div>
    <div class="krv-tap"></div>
    <div class="krv-center">
      <div class="krv-spin"></div>
      <button class="krv-bigbtn" data-act="toggle">$_playSvg</button>
      <div class="krv-seektip"></div>
    </div>
    <div class="krv-chrome">
      <input class="krv-seek" type="range" min="0" max="1" step="0.1" value="0">
      <div class="krv-row">
        <button class="krv-b krv-playbtn" data-act="toggle">$_playSvg</button>
        <button class="krv-b krv-skip" data-act="back" title="Back 10s"><svg viewBox="0 0 24 24"><path d="M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"/></svg><span>10</span></button>
        <span class="krv-time krv-now">0:00</span>
        <span class="krv-time krv-total">0:00</span>
        <select class="krv-rate">$rateOpts</select>
        <button class="krv-b krv-skip" data-act="fwd" title="Forward 10s"><svg viewBox="0 0 24 24" style="transform:scaleX(-1)"><path d="M12 5V1L7 6l5 5V7c3.31 0 6 2.69 6 6s-2.69 6-6 6-6-2.69-6-6H4c0 4.42 3.58 8 8 8s8-3.58 8-8-3.58-8-8-8z"/></svg><span>10</span></button>
        <div class="krv-volbox">
          <input class="krv-vol" id="krv-vol" type="range" min="0" max="100" value="${(_volume * 100).round()}">
          <button class="krv-b" id="krv-mute" data-act="mute" title="Mute">$_volUpSvg</button>
        </div>
        <button class="krv-b" data-act="fs" title="Fullscreen">$_fsSvg</button>
      </div>
    </div>
    ''';
  }

  void _sendCommand(String func, [List<Object?> args = const []]) {
    final payload = jsonEncode({
      'channel': 'kuro',
      'viewType': _viewType,
      'event': 'command',
      'func': func,
      'args': args,
    });
    html.window.postMessage(payload, '*');
  }

  /// Keeps nudging the freshly-created embed to actually start playing.
  /// The iframe loads asynchronously and Chrome blocks unmuted `autoplay=1`
  /// inside a cross-origin iframe, so the only reliable start is an explicit
  /// IFrame-API `playVideo` command — which is only honored once the player
  /// is ready. Retry every 600ms until the player confirms a real state.
  void _startKickstart() {
    if (_pendingPlay) return;
    _pendingPlay = true;
    _gaveUp = false;
    _kickTries = 0;
    _kickTimer?.cancel();
    _kickstart();
  }

  /// The JS bridge pushes fresh `currentTime`/`duration`/`playerState` every
  /// ~250ms, so the timer/slider/state follow the real player. This tick
  /// keeps a self-driving clock as a safety net so the UI never freezes, and
  /// re-issues any pending seek until the player confirms it landed.
  void _startTick() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || !_playing) return;
      // Only keep time flowing once the bridge is actually feeding us data;
      // otherwise the clock would tick on its own with nothing playing.
      if (_bridgeSeen && _playbackActive && !_ended && _drag == null) {
        _current += 0.25;
        _syncChrome();
      }
      if (_queuedSeek != null) {
        if (DateTime.now().millisecondsSinceEpoch - _queuedAtMs > 10000) {
          _queuedSeek = null;
        } else {
          _sendCommand('seekTo', [_queuedSeek!, true]);
        }
      }
    });
  }

  void _kickstart() {
    if (!mounted || !_playing || !_pendingPlay || _ended) return;
    _sendCommand('setVolume', [(_volume * 100).roundToDouble()]);
    _sendCommand('setPlaybackRate', [_rate]);
    _sendCommand('playVideo');
    if (_playerState == 'playing') {
      _stopKickstart();
      return;
    }
    _kickTries++;
    if (_kickTries >= 20) {
      // Give up gently: show the big play button so a fresh tap (a new
      // user gesture, which autoplay policy needs) can retry the start.
      _pendingPlay = false;
      _kickTimer = null;
      _gaveUp = true;
      if (mounted) setState(() => _playerState = 'cued');
      _syncChrome();
      return;
    }
    _kickTimer = Timer(const Duration(milliseconds: 600), _kickstart);
  }

  void _stopKickstart() {
    _pendingPlay = false;
    _kickTries = 0;
    _kickTimer?.cancel();
    _kickTimer = null;
  }

  void _onWindowMessage(html.Event event) {
    if (!mounted) return;
    final message = event as html.MessageEvent;
    final raw = message.data;
    if (raw is! String) return;

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final ev = payload['event'];
    if (ev == 'bridgeReady') {
      _bridgeReady = true;
      return;
    }
    if (ev == 'playerError') {
      _playerErrorCode = (payload['code'] as num?)?.toInt();
      _playerFailed = true;
      _watchdog?.cancel();
      if (mounted) setState(() => _playbackActive = false);
      _syncChrome();
      return;
    }
    if (!_playing || ev != 'infoDelivery') return;
    // Our bridge tags every message with a viewType; ignore other players'.
    final vt = payload['viewType'];
    if (vt is String && vt != _viewType) return;
    _bridgeSeen = true;
    _playerFailed = false;
    _watchdog?.cancel();

    // `info` can be a real object or a JSON-encoded string, depending on
    // the message the YouTube embed sends — parse both.
    final Map<String, dynamic> info;
    final rawInfo = payload['info'];
    if (rawInfo is String) {
      try {
        info = (jsonDecode(rawInfo) as Map<String, dynamic>?) ?? {};
      } catch (_) {
        return;
      }
    } else if (rawInfo is Map<String, dynamic>) {
      info = rawInfo;
    } else {
      return;
    }

    final videoData = info['videoData'] as Map<String, dynamic>?;
    final reportedId = videoData?['video_id'] as String?;
    if (reportedId != null && reportedId.isNotEmpty) {
      if (reportedId != widget.youtubeId) return;
    }

    final time = (info['currentTime'] as num?)?.toDouble();
    final duration = (info['duration'] as num?)?.toDouble();

    // playerState arrives as a string ("playing") on newer embeds and as a
    // number (0-5) on older ones — accept both.
    final rawState = info['playerState'];
    String? state;
    if (rawState is String) {
      state = rawState;
    } else if (rawState is num) {
      const ytStates = [
        'unstarted',
        'ended',
        'playing',
        'paused',
        'buffering',
        'cued',
      ];
      final idx = rawState.toInt();
      if (idx >= 0 && idx < ytStates.length) state = ytStates[idx];
    }

    if (time != null) {
      _current = time;
      if (_queuedSeek != null && (time - _queuedSeek!).abs() < 0.5) {
        _queuedSeek = null;
      }
    }
    if (duration != null && duration > 0) _duration = duration;
    if (state != null) {
      _ended = state == 'ended';
      if (state == 'playing' || state == 'buffering') {
        _playbackActive = true;
      } else if (state == 'paused' || state == 'ended') {
        _playbackActive = false;
      }
      // While "gave up", keep the retry button on screen; only a real
      // playing/paused/ended signal clears it.
      if (_gaveUp && (state == 'unstarted' || state == 'cued')) {
        _gaveUp = false;
        _playerState = _ended ? 'ended' : 'cued';
      } else {
        _playerState = state;
      }
      // The player has answered our play request — stop pecking at it.
      if (state == 'playing' || state == 'paused' || state == 'ended') {
        _gaveUp = false;
        _stopKickstart();
      }
      // The embed auto-starts MUTED (Chrome allows muted autoplay). Once it
      // is genuinely playing, lift the sound so the trailer plays normally.
      if (state == 'playing' && !_unmuteSent) {
        _unmuteSent = true;
        _sendCommand('unMute');
        if (mounted) setState(() => _muted = false);
      }
    }
    if (mounted) setState(() {});
    _syncChrome();
  }

  // ── Playback controls ────────────────────────────────────

  void _startPlayback() {
    _registerPlayer();
    setState(() {
      _playing = true;
      _ended = false;
      _current = 0;
      _drag = null;
      _playerState = 'buffering';
      _playbackActive = true;
      _queuedSeek = null;
      _controlsVisible = true;
      // The embed starts muted (only form of autoplay every browser allows);
      // sound is lifted automatically once the video is actually playing.
      _muted = true;
      _unmuteSent = false;
      _playerFailed = false;
      _playerErrorCode = null;
    });
    _startKickstart();
    _startTick();
    _startWatchdog();
    _showControls(const Duration(milliseconds: 4000));
  }

  /// If the bridge never delivers any player data, stop pretending and show
  /// the real reason with recovery buttons instead of a dead fake clock.
  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      // Bridge handshake may exist but no player data arrived — surface it.
      if (_bridgeSeen) return;
      setState(() {
        _playerFailed = true;
        _playbackActive = false;
      });
      _syncChrome();
    });
  }

  void _togglePlayPause() {
    if (!mounted) return;
    _showControls();
    if (_ended) {
      _sendCommand('seekTo', [0, true]);
      _queuedSeek = 0;
      _queuedAtMs = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _ended = false;
        _playerState = 'playing';
        _playbackActive = true;
      });
      _startKickstart();
    } else if (_playerState == 'playing') {
      _sendCommand('pauseVideo');
      _stopKickstart();
      setState(() {
        _playerState = 'paused';
        _playbackActive = false;
      });
    } else {
      setState(() {
        _playerState = 'playing';
        _playbackActive = true;
      });
      _startKickstart();
    }
    _syncChrome();
  }

  void _skip(double delta) {
    if (!mounted) return;
    if (_ended) _ended = false;
    final upper = _duration > 0 ? _duration : _current + delta;
    final target = (_current + delta).clamp(0.0, upper).toDouble();
    _sendCommand('seekTo', [target, true]);
    _queuedSeek = target;
    _queuedAtMs = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _current = target;
      _drag = null;
    });
    _syncChrome();
    _showControls();
  }

  /// While playing, controls fade out after a short idle period and come
  /// back on any mouse activity — like a real desktop player.
  void _showControls([Duration? forMs]) {
    if (!mounted) return;
    _hideTimer?.cancel();
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
      _syncChrome();
    }
    if (!_playing || _ended) return;
    _hideTimer = Timer(forMs ?? const Duration(milliseconds: 2600), () {
      if (mounted && _playerState == 'playing' && !_ended) {
        setState(() => _controlsVisible = false);
        _syncChrome();
      }
    });
  }

  void _toggleMute() {
    if (!mounted) return;
    _showControls();
    _sendCommand(_muted ? 'unMute' : 'mute');
    setState(() => _muted = !_muted);
    _syncChrome();
  }

  void _toggleFullscreen() {
    if (!mounted) return;
    _showControls();
    if (html.document.fullscreenElement != null) {
      html.document.exitFullscreen();
    } else {
      _root?.requestFullscreen();
    }
  }

  /// One click (with a debounce) toggles play/pause; a fast second click
  /// cancels it and enters fullscreen instead.
  void _tapSingle() {
    if (!mounted) return;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 260), _togglePlayPause);
  }

  void _tapDouble() {
    if (!mounted) return;
    _tapTimer?.cancel();
    _toggleFullscreen();
  }

  void _runAction(String act) {
    if (!mounted) return;
    switch (act) {
      case 'toggle':
        _togglePlayPause();
        break;
      case 'back':
        _skip(-10);
        break;
      case 'fwd':
        _skip(10);
        break;
      case 'mute':
        _toggleMute();
        break;
      case 'fs':
        _toggleFullscreen();
        break;
    }
    _showControls();
  }

  /// Mirror the Dart-side state (time, play state, volume, rate, …) onto
  /// the live HTML chrome after every change.
  void _syncChrome() {
    final root = _root;
    if (root == null) return;

    root.classes.toggle('playing', _playerState == 'playing');
    root.classes.toggle('buff', _playerState == 'buffering');
    root.classes.toggle('end', _ended);
    root.classes.toggle('hide', !_controlsVisible);
    final stopped =
        _ended ||
        (_playing &&
            _playerState != 'playing' &&
            _playerState != 'buffering' &&
            _playerState != 'unstarted');
    root.classes.toggle('stopped', stopped);

    _root?.querySelector('.krv-now')?.text = _fmt(_drag ?? _current);
    _root?.querySelector('.krv-total')?.text = _fmt(_duration);

    final seek =
        _root?.querySelector('input.krv-seek') as html.RangeInputElement?;
    if (seek != null) {
      final max = _duration > 0 ? _duration : 1.0;
      seek.max = max.toStringAsFixed(1);
      seek.value = (_drag ?? _current).clamp(0.0, max).toStringAsFixed(1);
    }
    final pct = _duration > 0
        ? ((_drag ?? _current) / _duration * 100).clamp(0.0, 100.0)
        : 0.0;
    root.style.setProperty('--p', '${pct.toStringAsFixed(1)}%');

    final vol = _root?.querySelector('#krv-vol') as html.RangeInputElement?;
    if (vol != null) {
      vol.value = (_volume * 100).round().toString();
      vol.classes.toggle('source', _volume != 1);
    }
    root.style.setProperty('--v', '${(_volume * 100).round().clamp(0, 100)}%');

    final rate = _root?.querySelector('select.krv-rate') as html.SelectElement?;
    if (rate != null) rate.value = _rate.toStringAsFixed(2);

    final playBtn = _root?.querySelector('.krv-playbtn');
    if (playBtn != null) {
      playBtn.setInnerHtml(
        _ended
            ? _replaySvg
            : (_playerState == 'playing' ? _pauseSvg : _playSvg),
        treeSanitizer: html.NodeTreeSanitizer.trusted,
      );
    }
    final big = _root?.querySelector('.krv-bigbtn');
    if (big != null) {
      big.setInnerHtml(
        _ended ? _replaySvg : _playSvg,
        treeSanitizer: html.NodeTreeSanitizer.trusted,
      );
    }
    final muteBtn = _root?.querySelector('#krv-mute');
    if (muteBtn != null) {
      muteBtn.setInnerHtml(
        (_muted || _volume == 0) ? _volOffSvg : _volUpSvg,
        treeSanitizer: html.NodeTreeSanitizer.trusted,
      );
    }
    final tip = _root?.querySelector('.krv-seektip');
    if (tip != null) {
      if (_drag != null) {
        tip.text = '${_fmt(_drag!)} / ${_fmt(_duration)}';
        tip.classes.add('show');
      } else {
        tip.text = '';
        tip.classes.remove('show');
      }
    }
  }

  void _openInYouTube() {
    if (!mounted) return;
    _sendCommand('pauseVideo');
    _stopKickstart();
    html.window.open(
      'https://www.youtube.com/watch?v=${widget.youtubeId}',
      '_blank',
    );
  }

  void _changeVolume(double delta) {
    if (!mounted) return;
    _setVolume((_volume + delta).clamp(0.0, 1.0));
  }

  void _setVolume(double v) {
    if (!mounted) return;
    setState(() => _volume = v);
    try {
      html.window.localStorage['kuro_volume'] = v.toStringAsFixed(2);
    } catch (_) {}
    _sendCommand('setVolume', [(v * 100).roundToDouble()]);
    if (v > 0 && _muted) {
      setState(() => _muted = false);
    }
    _syncChrome();
    _showControls();
  }

  void _setRate(double r) {
    if (!mounted) return;
    _sendCommand('setPlaybackRate', [r]);
    setState(() => _rate = r);
    _syncChrome();
    _showControls();
  }

  /// Desktop shortcuts while the player is active:
  ///  Space = play/pause · ←/→ = ±10s · ↑/↓ = volume · F/V = fullscreen
  ///  M = mute · [ ] or - / = playback speed
  void _onKeyDown(html.Event event) {
    if (!mounted || !_playing) return;
    final ke = event as html.KeyboardEvent;
    switch (ke.key) {
      case ' ':
      case 'Spacebar':
        ke.preventDefault();
        _togglePlayPause();
        break;
      case 'ArrowLeft':
        ke.preventDefault();
        _skip(-10);
        break;
      case 'ArrowRight':
        ke.preventDefault();
        _skip(10);
        break;
      case 'ArrowUp':
        ke.preventDefault();
        _changeVolume(0.05);
        break;
      case 'ArrowDown':
        ke.preventDefault();
        _changeVolume(-0.05);
        break;
      case 'f':
      case 'F':
        _toggleFullscreen();
        break;
      case 'm':
      case 'M':
        _toggleMute();
        break;
      case '[':
        _setRate((_rate - 0.25).clamp(0.5, 2.0));
        break;
      case ']':
        _setRate((_rate + 0.25).clamp(0.5, 2.0));
        break;
      case '-':
        _setVolume((_volume - 0.1).clamp(0.0, 1.0));
        break;
      case '=':
        _setVolume((_volume + 0.1).clamp(0.0, 1.0));
        break;
    }
  }

  String _fmt(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) return '0:00';
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$s';
  }

  // ── Layout ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(K.s24, K.s24, K.s24, K.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                AppStrings.officialTrailer.toUpperCase(),
                style: K.labelUppercase,
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openInYouTube,
                child: Row(
                  children: [
                    const Icon(
                      Icons.open_in_new_rounded,
                      color: K.textTertiary,
                      size: 14,
                    ),
                    const SizedBox(width: K.s4),
                    Text(
                      AppStrings.openOnYouTube,
                      style: K.bodySmall.copyWith(color: K.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: K.s12),
          LayoutBuilder(
            builder: (context, constraints) {
              // If the natural 16:9 would be taller than 300 the player
              // gets capped — the video letterboxes instead of forcing the
              // user to scroll to see all of it on a laptop screen.
              final ideal = constraints.maxWidth * 9 / 16;
              final height = ideal > 300 ? 300.0 : ideal;
              return SizedBox(
                width: double.infinity,
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(K.r16),
                  child: _playing ? _buildPlayerArea() : _buildThumbnail(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        if (_playerFailed) _buildPlayerError(),
      ],
    );
  }

  Widget _buildPlayerError() {
    final code = _playerErrorCode;
    final message = !_bridgeReady
        ? AppStrings.playerDidNotLoad
        : code == null
        ? AppStrings.trailerCouldNotStart
        : switch (code) {
            2 => AppStrings.trailerUnavailable,
            5 => AppStrings.trailerCannotPlay,
            100 => AppStrings.trailerRemoved,
            101 || 150 => AppStrings.trailerNotAllowed,
            _ => AppStrings.trailerErrorCode.replaceAll(
              '\$code',
              code.toString(),
            ),
          };
    return Container(
      color: K.bg.withValues(alpha: 0.94),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(K.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_rounded, color: K.coral, size: 40),
          const SizedBox(height: K.s12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: K.bodyMedium.copyWith(color: K.textPrimary),
          ),
          const SizedBox(height: K.s16),
          Wrap(
            spacing: K.s12,
            runSpacing: K.s8,
            alignment: WrapAlignment.center,
            children: [
              KokuroButton(
                label: AppStrings.openOnYouTube,
                icon: Icons.open_in_new_rounded,
                filled: true,
                onPressed: _openInYouTube,
              ),
              KokuroButton(
                label: AppStrings.reloadPage,
                icon: Icons.refresh_rounded,
                filled: false,
                onPressed: () => html.window.location.reload(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _startPlayback,
        child: Stack(
          fit: StackFit.expand,
          children: [
            KuroImg(widget.posterUrl, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    K.bg.withValues(alpha: 0.15),
                    K.bg.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: K.accent.withValues(alpha: 0.9),
                  boxShadow: K.glow(color: K.accent, blur: 28),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            Positioned(
              bottom: K.s16,
              left: 0,
              right: 0,
              child: Text(
                AppStrings.tapToWatchTrailer,
                textAlign: TextAlign.center,
                style: K.bodySmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Sticky Tab Bar Delegate
// ══════════════════════════════════════════════════════════

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabCtrl;
  final List<String> tabs;

  _TabBarDelegate({required this.tabCtrl, required this.tabs});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: K.bg,
        border: const Border(bottom: BorderSide(color: K.border, width: 1)),
      ),
      child: AnimatedBuilder(
        animation: tabCtrl,
        builder: (context, _) => Row(
          children: List.generate(tabs.length, (i) {
            final isActive = tabCtrl.index == i;
            return GestureDetector(
              onTap: () => tabCtrl.animateTo(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: K.s20,
                  vertical: K.s16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? K.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tabs[i],
                  style: K.titleMedium.copyWith(
                    color: isActive ? K.accent : K.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      tabCtrl != oldDelegate.tabCtrl || tabs != oldDelegate.tabs;
}
