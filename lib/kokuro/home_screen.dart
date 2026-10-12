import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../domain/entities/anime.dart';
import '../domain/entities/library_entry.dart';
import '../domain/entities/watch_status.dart';
import 'tokens.dart';
import 'components.dart';
import 'translation_service.dart';
import 'kokuro_bloc.dart';
import 'loading_widgets.dart';
import 'active_branch_scope.dart';
import 'app_strings.dart';
import 'anime_animations.dart';

class HomeScreen extends StatefulWidget {
  final int branchIndex;

  const HomeScreen({super.key, this.branchIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeLoaded? _cached;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KokuroBloc>().add(const LoadHome());
    });
  }

  void _setList(BuildContext context, Anime anime, WatchStatus? status) {
    final bloc = context.read<KokuroBloc>();
    if (status == null) {
      bloc.add(RemoveFromLibraryEvent(anime.malId));
      _snack(context, AppStrings.removedFromList);
    } else {
      bloc.add(SetWatchStatus(anime, status));
      _snack(context, '${AppStrings.savedToList} · ${status.label}');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: 320,
          backgroundColor: K.bgCard,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isActive =
        ActiveBranchScope.maybeOf(context)?.isActive(widget.branchIndex) ??
        true;
    return TickerMode(
      enabled: isActive,
      child: Scaffold(
        backgroundColor: K.bg,
        body: BlocBuilder<KokuroBloc, KokuroState>(
          builder: (context, state) {
            if (state is HomeLoaded) {
              _cached = state;
              return _buildHome(context, state);
            }
            // Keep showing the last loaded home content while the bloc is busy
            // with other views (e.g. a pushed AnimeDetailScreen) so home never
            // renders blank on back-navigation.
            if (_cached != null) {
              return _buildHome(context, _cached!);
            }
            if (state is KokuroError) {
              return _buildError(state.message);
            }
            return _buildLoadingSkeleton();
          },
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context, HomeLoaded state) {
    final hasJourney =
        state.continueWatching.isNotEmpty || state.journey.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: K.accent,
      backgroundColor: K.bgCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Section ──────────────────────────────
            if (state.featured.isNotEmpty)
              _HeroSection(
                animeList: state.featured,
                watchlistIds: state.watchlistIds,
                onWatch: (anime) => _openDetail(context, anime),
                onSetList: (anime, status) => _setList(context, anime, status),
              )
            else
              const SizedBox(height: K.s24),

            const SizedBox(height: K.s32),

            // ── Continue Your Journey + Trending (side by side) ──
            if (hasJourney || state.trending.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: K.s32),
                child: _JourneyTrendingArea(
                  state: state,
                  onOpen: (anime) => _openDetail(context, anime),
                  onExplore: () => context.go('/explore'),
                ),
              ),

            // ── Daily Pick ──────────────────────────────
            if (state.dailyPick != null) ...[
              const SizedBox(height: K.s32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: K.s32),
                child: _DailyPickSection(
                  anime: state.dailyPick!,
                  inList: state.watchlistIds.contains(state.dailyPick!.malId),
                  onWatch: () => _openDetail(context, state.dailyPick!),
                  onTap: () => _openDetail(context, state.dailyPick!),
                  onSetList: (status) =>
                      _setList(context, state.dailyPick!, status),
                ),
              ),
            ],

            const SizedBox(height: K.s48),

            // ── Top-10 Ranking Chart ──────────────────────────────
            ..._topChartSection(context, items: state.topRated),

            // ── This Season ──────────────────────────────
            ..._rowSection(
              items: state.seasonAnime,
              label: AppStrings.thisSeason,
              title: AppStrings.freshStories,
              trailing: _seeAllButton(context, query: _seasonQuery()),
            ),

            // ── Movie Night ──────────────────────────────
            ..._rowSection(
              items: state.movies,
              label: AppStrings.movieNight,
              title: AppStrings.cinemaPicks,
              trailing: _seeAllButton(context, query: {'type': 'Movie'}),
            ),

            // ── Browse by Genre ──────────────────────────────
            ..._genreBrowseSection(context),

            // ── Genre Spotlight ──────────────────────────────
            ..._rowSection(
              items: state.spotlightTitles,
              label:
                  (state.spotlightGenre ?? AppStrings.spotlight.toUpperCase()),
              title: AppStrings.handPicked,
              trailing: state.spotlightGenre == null
                  ? null
                  : _seeAllButton(
                      context,
                      query: {
                        'genre': AppStrings.genreLabel(state.spotlightGenre!),
                      },
                    ),
            ),

            // ── Coming Soon ──────────────────────────────
            ..._rowSection(
              items: state.upcoming,
              label: AppStrings.comingSoon,
              title: AppStrings.markYourCalendar,
              trailing: _seeAllButton(context, query: {'upcoming': '1'}),
            ),

            // ── Because You Watched ──────────────────────────────
            ..._rowSection(
              items: state.recommendedForYou,
              label: AppStrings.becauseYouWatched,
              title:
                  state.recommendedSeedTitle ?? AppStrings.moreLikeWhatYouLove,
            ),

            const SizedBox(height: K.s48),
          ],
        ),
      ),
    );
  }

  /// A titled horizontal rail of anime cards; renders nothing when [items] is
  /// empty so empty sections never show a dangling header.
  List<Widget> _rowSection({
    required List<Anime> items,
    required String label,
    required String title,
    Widget? trailing,
  }) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: K.s32),
        child: SectionHeader(label: label, title: title, trailing: trailing),
      ),
      const SizedBox(height: K.s16),
      SizedBox(
        height: 280,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: K.s32),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: K.s16),
          itemBuilder: (context, i) {
            return _ApiAnimeCard(
              anime: items[i],
              onTap: () => _openDetail(context, items[i]),
              onSetList: (status) => _setList(context, items[i], status),
            );
          },
        ),
      ),
      const SizedBox(height: K.s48),
    ];
  }

  /// Horizontal Top-10 chart with oversized rank numbers — a different
  /// visual rhythm from the plain poster rails around it.
  List<Widget> _topChartSection(
    BuildContext context, {
    required List<Anime> items,
  }) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: K.s32),
        child: SectionHeader(
          label: AppStrings.topRated,
          title: AppStrings.topTenNow,
          trailing: _seeAllButton(context, query: {'sort': 'Score'}),
        ),
      ),
      const SizedBox(height: K.s16),
      SizedBox(
        height: 280,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: K.s32),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: K.s16),
          itemBuilder: (context, i) {
            return _RankedAnimeCard(
              anime: items[i],
              rank: i + 1,
              onTap: () => _openDetail(context, items[i]),
            );
          },
        ),
      ),
      const SizedBox(height: K.s48),
    ];
  }

  /// Constellation genre nodes that deep-link into the explore feed —
  /// no extra fetch, pure navigation variety between the poster rails.
  static const _homeGenres = [
    'Action',
    'Romance',
    'Comedy',
    'Fantasy',
    'Drama',
    'Sci-Fi',
    'Sports',
    'Slice of Life',
    'Horror',
    'Adventure',
  ];

  List<Widget> _genreBrowseSection(BuildContext context) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: K.s32),
        child: SectionHeader(
          label: AppStrings.browseByGenre,
          title: AppStrings.pickAMood,
          trailing: _seeAllButton(context),
        ),
      ),
      const SizedBox(height: K.s16),
      SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: K.s32),
          itemCount: _homeGenres.length,
          separatorBuilder: (_, _) => const SizedBox(width: K.s16),
          itemBuilder: (context, i) {
            final genre = _homeGenres[i];
            return GenreNode(
              name: genre,
              size: 100,
              onTap: () => context.goNamed(
                'explore',
                queryParameters: {'genre': AppStrings.genreLabel(genre)},
              ),
            );
          },
        ),
      ),
      const SizedBox(height: K.s48),
    ];
  }

  Widget _seeAllButton(BuildContext context, {Map<String, String>? query}) {
    return TextButton(
      onPressed: () =>
          context.goNamed('explore', queryParameters: query ?? const {}),
      style: TextButton.styleFrom(
        foregroundColor: K.accent,
        padding: const EdgeInsets.symmetric(horizontal: K.s8),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        AppStrings.seeAll,
        style: K.bodySmall.copyWith(color: K.accent),
      ),
    );
  }

  /// The current calendar season + year, used to deep-link "This Season" into
  /// the explore feed so it loads exactly that seasonal slot.
  Map<String, String> _seasonQuery() {
    final now = DateTime.now();
    final month = now.month;
    final season = switch (month) {
      <= 2 => AppStrings.winter,
      <= 5 => AppStrings.spring,
      <= 8 => AppStrings.summer,
      _ => AppStrings.fall,
    };
    return {'season': season, 'year': '${now.year}'};
  }

  /// Pull-to-refresh: refetches home data from the network.
  Future<void> _refresh() {
    context.read<KokuroBloc>().add(const LoadHome());
    return Future<void>.delayed(const Duration(seconds: 1));
  }

  void _openDetail(BuildContext context, Anime anime) async {
    // No re-fetch on the way back — home keeps its cached data, so
    // back-navigation is instant instead of re-running the fetch chain.
    await context.push('/anime/${anime.malId}', extra: anime);
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: K.s8),
          // Hero block shimmer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: K.s32),
            child: const KShimmer(
              width: double.infinity,
              height: 340,
              radius: 20,
            ),
          ),
          const SizedBox(height: K.s48),
          // Journey row shimmer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: K.s32),
            child: const SizedBox(
              height: 120,
              child: Row(
                children: [
                  KShimmer(width: 90, height: 120, radius: 16),
                  SizedBox(width: K.s16),
                  KShimmer(width: 90, height: 120, radius: 16),
                  SizedBox(width: K.s16),
                  KShimmer(width: 90, height: 120, radius: 16),
                  SizedBox(width: K.s16),
                  KShimmer(width: 90, height: 120, radius: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: K.s48),
          // Season grid shimmer
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: K.s32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: KShimmer(width: 180, height: 14, radius: 4),
            ),
          ),
          const SizedBox(height: K.s24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: K.s32),
            child: FeedSkeleton(isNarrow: false),
          ),
          const SizedBox(height: K.s80),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: K.coral, size: 48),
          const SizedBox(height: K.s16),
          Text(message, style: K.bodyLarge),
          const SizedBox(height: K.s24),
          KokuroButton(
            label: AppStrings.retry,
            icon: Icons.refresh_rounded,
            onPressed: () => context.read<KokuroBloc>().add(const LoadHome()),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Hero Section — cinematic, full-width, deep atmosphere
// ══════════════════════════════════════════════════════════

class _HeroSection extends StatefulWidget {
  final List<Anime> animeList;
  final Set<int> watchlistIds;
  final void Function(Anime anime)? onWatch;
  final void Function(Anime anime, WatchStatus? status)? onSetList;
  const _HeroSection({
    required this.animeList,
    this.watchlistIds = const {},
    this.onWatch,
    this.onSetList,
  });

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with TickerProviderStateMixin {
  final ValueNotifier<Offset> _parallax = ValueNotifier(Offset.zero);
  int _current = 0;
  bool _isActive = true;
  late final PageController _pageController;
  Timer? _timer;
  final _translatedSynopsisCache = <int, String>{};

  // Entrance stagger
  late final AnimationController _entranceCtrl;
  late final Animation<double> _featuredAnim;
  late final Animation<double> _titleAnim;
  late final Animation<double> _descAnim;
  late final Animation<double> _genresAnim;
  late final Animation<double> _metaAnim;
  late final Animation<double> _buttonsAnim;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _restartTimer();
    // Translate synopsis for the first featured anime.
    if (widget.animeList.isNotEmpty) {
      _translateSynopsis(widget.animeList[0]);
    }

    // Entrance stagger animations
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _featuredAnim = _stagger(0, 0.15);
    _titleAnim = _stagger(0.1, 0.35);
    _descAnim = _stagger(0.2, 0.5);
    _genresAnim = _stagger(0.3, 0.6);
    _metaAnim = _stagger(0.4, 0.65);
    _buttonsAnim = _stagger(0.5, 0.75);
    _entranceCtrl.forward();
  }

  Animation<double> _stagger(double begin, double end) {
    return Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _entranceCtrl,
        curve: Interval(begin, end.clamp(begin, 1.0), curve: K.easeOut),
      ),
    );
  }

  void _translateSynopsis(Anime anime) {
    if (anime.synopsis.isEmpty) return;
    if (_translatedSynopsisCache.containsKey(anime.malId)) return;
    final id = anime.malId;
    final synopsis = anime.synopsis;
    TranslationService.toArabic(synopsis).then((t) {
      if (mounted) setState(() => _translatedSynopsisCache[id] = t);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isActive = ActiveBranchScope.maybeOf(context)?.isActive(0) ?? true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _entranceCtrl.dispose();
    _parallax.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.animeList.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      // Don't auto-rotate while the Home tab is hidden — the scroll ticker
      // is muted by TickerMode anyway and a stale rotation would fire late.
      if (!mounted || !_isActive) return;
      final next = (_current + 1) % widget.animeList.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _goTo(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final heroHeight = (size.height * 0.82).clamp(520.0, 840.0);
    final heroTextWidth = (size.width * 0.28)
        .clamp(300.0, 620.0)
        .clamp(0.0, size.width - K.s48 * 2);
    final anime = widget.animeList.isEmpty ? null : widget.animeList[_current];

    return MouseRegion(
      onEnter: (_) => _timer?.cancel(),
      onExit: (_) => _restartTimer(),
      onHover: (e) {
        _parallax.value = Offset(
          (e.localPosition.dx / size.width - 0.5) * 2,
          (e.localPosition.dy / heroHeight - 0.5) * 2,
        );
      },
      child: SizedBox(
        height: heroHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Pages of anime artwork — natural, no darkening filters
            RepaintBoundary(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) {
                  setState(() => _current = i);
                  _restartTimer();
                  _translateSynopsis(widget.animeList[i]);
                },
                itemCount: widget.animeList.length,
                itemBuilder: (context, i) {
                  final item = widget.animeList[i];
                  return ValueListenableBuilder<Offset>(
                    valueListenable: _parallax,
                    child: KuroImg(
                      item.largeImageUrl.isNotEmpty
                          ? item.largeImageUrl
                          : item.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: heroHeight,
                    ),
                    builder: (context, offset, child) => Transform.translate(
                      offset: Offset(offset.dx * -8, offset.dy * -5),
                      child: child,
                    ),
                  );
                },
              ),
            ),

            // Layer 2: Story Thread decoration (faint brand lines, not a filter)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _HeroThreadPainter()),
              ),
            ),

            // Layer 2b: Floating anime particles
            Positioned.fill(
              child: IgnorePointer(
                child: FloatingParticles(
                  count: 15,
                  colors: [
                    K.accent.withValues(alpha: 0.6),
                    K.cyan.withValues(alpha: 0.5),
                    K.pink.withValues(alpha: 0.4),
                  ],
                  maxSize: 3,
                  speed: 0.15,
                  shape: ParticleShape.star,
                ),
              ),
            ),

            // Layer 8: Content — dark scrim behind the text zone ONLY (~28%), so
            // the text stays readable no matter the artwork colors, while the
            // rest of the image stays natural
            if (anime != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: heroTextWidth + K.s48 * 2,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                K.bg.withValues(alpha: 0.92),
                                K.bg.withValues(alpha: 0.72),
                                K.bg.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: K.s48,
                      bottom: K.s64,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: heroTextWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Featured label
                            AnimatedBuilder(
                              animation: _featuredAnim,
                              builder: (c, w) => Opacity(
                                opacity: _featuredAnim.value,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    16 * (1 - _featuredAnim.value),
                                  ),
                                  child: w,
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: K.s12,
                                  vertical: K.s4,
                                ),
                                decoration: BoxDecoration(
                                  color: K.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(K.r4),
                                  border: Border.all(
                                    color: K.accent.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  AppStrings.featured.toUpperCase(),
                                  style: K.labelUppercase.copyWith(
                                    color: K.accent,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: K.s16),

                            // Title — kinetic typography
                            AnimatedBuilder(
                              animation: _titleAnim,
                              builder: (c, w) => Opacity(
                                opacity: _titleAnim.value,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    20 * (1 - _titleAnim.value),
                                  ),
                                  child: w,
                                ),
                              ),
                              child: KineticText(
                                text: anime.title,
                                mode: KineticMode.word,
                                duration: const Duration(milliseconds: 900),
                                stagger: const Duration(milliseconds: 100),
                                style: K.displayLarge.copyWith(
                                  fontSize: 48,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: K.s12),

                            // Synopsis
                            AnimatedBuilder(
                              animation: _descAnim,
                              builder: (c, w) => Opacity(
                                opacity: _descAnim.value,
                                child: Transform.translate(
                                  offset: Offset(0, 14 * (1 - _descAnim.value)),
                                  child: w,
                                ),
                              ),
                              child: Text(
                                anime.synopsis.isNotEmpty
                                    ? (_translatedSynopsisCache[anime.malId] ??
                                          anime.synopsis)
                                    : AppStrings.journeyAwaits,
                                style: K.bodyLarge.copyWith(
                                  height: 1.6,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            const SizedBox(height: K.s16),

                            // Genres
                            AnimatedBuilder(
                              animation: _genresAnim,
                              builder: (c, w) => Opacity(
                                opacity: _genresAnim.value,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    10 * (1 - _genresAnim.value),
                                  ),
                                  child: w,
                                ),
                              ),
                              child: Wrap(
                                spacing: K.s8,
                                runSpacing: K.s8,
                                children: anime.genres.take(4).map((g) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: K.s12,
                                      vertical: K.s4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: K.bgCard,
                                      borderRadius: BorderRadius.circular(K.r4),
                                      border: Border.all(
                                        color: K.border.withValues(alpha: 0.4),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      g,
                                      style: K.bodySmall.copyWith(
                                        color: K.textSecondary,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                            const SizedBox(height: K.s16),

                            // Rating + metadata
                            AnimatedBuilder(
                              animation: _metaAnim,
                              builder: (c, w) => Opacity(
                                opacity: _metaAnim.value,
                                child: Transform.translate(
                                  offset: Offset(0, 10 * (1 - _metaAnim.value)),
                                  child: w,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (anime.score > 0) ...[
                                    const Icon(
                                      Icons.star_rounded,
                                      color: K.gold,
                                      size: 20,
                                    ),
                                    const SizedBox(width: K.s4),
                                    Text(
                                      anime.score.toStringAsFixed(1),
                                      style: K.titleMedium.copyWith(
                                        color: K.gold,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: K.s16),
                                  ],
                                  if (anime.episodes > 0) ...[
                                    Text(
                                      '${anime.episodes} ${AppStrings.episodes}',
                                      style: K.bodyMedium.copyWith(
                                        color: K.textSecondary,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: K.s16),
                                  ],
                                  if (anime.members != null &&
                                      anime.members! > 0)
                                    Text(
                                      '${(anime.members! / 1000).toStringAsFixed(0)}K ${AppStrings.members}',
                                      style: K.bodyMedium.copyWith(
                                        color: K.textSecondary,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: K.s24),

                            // Buttons
                            AnimatedBuilder(
                              animation: _buttonsAnim,
                              builder: (c, w) => Opacity(
                                opacity: _buttonsAnim.value,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    12 * (1 - _buttonsAnim.value),
                                  ),
                                  child: w,
                                ),
                              ),
                              child: Row(
                                children: [
                                  KokuroButton(
                                    label: AppStrings.watchNow,
                                    icon: Icons.play_arrow_rounded,
                                    onPressed: () =>
                                        widget.onWatch?.call(anime),
                                  ),
                                  const SizedBox(width: K.s12),
                                  MyListButton(
                                    inList: widget.watchlistIds.contains(
                                      anime.malId,
                                    ),
                                    onSelect: (s) =>
                                        widget.onSetList?.call(anime, s),
                                    onRemove: () =>
                                        widget.onSetList?.call(anime, null),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Dots indicator — at the start (left) of the text zone, clickable
                    if (widget.animeList.length > 1)
                      Positioned(
                        left: K.s48,
                        bottom: K.s24,
                        width: heroTextWidth,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Row(
                            children: List.generate(widget.animeList.length, (
                              i,
                            ) {
                              final active = i == _current;
                              return GestureDetector(
                                onTap: () => _goTo(i),
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                  child: AnimatedContainer(
                                    duration: K.normal,
                                    width: active ? 40 : 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? K.accent
                                          : K.textTertiary.withValues(
                                              alpha: 0.6,
                                            ),
                                      borderRadius: BorderRadius.circular(
                                        K.rFull,
                                      ),
                                      boxShadow: active
                                          ? [
                                              BoxShadow(
                                                color: K.accent.withValues(
                                                  alpha: 0.45,
                                                ),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            // Layer 9: "Story Threads" label top-right
            Positioned(
              top: K.s24,
              right: K.s32,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    AppStrings.storyThreads,
                    style: K.headlineMedium.copyWith(
                      color: K.textPrimary.withValues(alpha: 0.7),
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: K.s4),
                  Text(
                    AppStrings.storyThreadsSubtitle,
                    style: K.bodySmall.copyWith(
                      color: K.textTertiary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Hero Thread Painter — decorative curved threads
// ══════════════════════════════════════════════════════════

class _HeroThreadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // Thread 1: top-left to center
    final path1 = Path()
      ..moveTo(0, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.1,
        size.width * 0.5,
        size.height * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.7,
        size.width,
        size.height * 0.5,
      );

    paint.shader = ui.Gradient.linear(
      Offset(0, 0),
      Offset(size.width, 0),
      [
        K.threadPrimary.withValues(alpha: 0.0),
        K.threadPrimary.withValues(alpha: 0.15),
        K.threadPrimary.withValues(alpha: 0.25),
        K.threadPrimary.withValues(alpha: 0.15),
        K.threadPrimary.withValues(alpha: 0.0),
      ],
      [0.0, 0.25, 0.5, 0.75, 1.0],
    );
    canvas.drawPath(path1, paint);

    // Thread 2: bottom-left to top-right
    final path2 = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.5,
        size.width * 0.6,
        size.height * 0.3,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.2,
        size.width,
        size.height * 0.15,
      );

    paint.shader = ui.Gradient.linear(
      Offset(0, 0),
      Offset(size.width, 0),
      [
        K.threadSecondary.withValues(alpha: 0.0),
        K.threadSecondary.withValues(alpha: 0.1),
        K.threadSecondary.withValues(alpha: 0.2),
        K.threadSecondary.withValues(alpha: 0.1),
        K.threadSecondary.withValues(alpha: 0.0),
      ],
      [0.0, 0.25, 0.5, 0.75, 1.0],
    );
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════
//  Continue Your Journey — circular nodes with thread connections
// ══════════════════════════════════════════════════════════

class _DailyPickSection extends StatelessWidget {
  final Anime anime;
  final bool inList;
  final VoidCallback? onWatch;
  final VoidCallback? onTap;
  final ValueChanged<WatchStatus?>? onSetList;
  const _DailyPickSection({
    required this.anime,
    this.inList = false,
    this.onWatch,
    this.onTap,
    this.onSetList,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 720;

    final Widget poster = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(K.r16),
        border: Border.all(color: K.borderSubtle, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: KuroImg(anime.imageUrl),
    );

    final Widget headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: K.s12,
                vertical: K.s6,
              ),
              decoration: BoxDecoration(
                color: K.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(K.rFull),
                border: Border.all(
                  color: K.accent.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 14, color: K.accent),
                  const SizedBox(width: K.s6),
                  Text(
                    AppStrings.dailyPick.toUpperCase(),
                    style: K.labelUppercase.copyWith(
                      color: K.accent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (anime.score > 0) ...[
              const SizedBox(width: K.s12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Color(0xFFFFB020),
                  ),
                  const SizedBox(width: K.s4),
                  Text(
                    anime.score.toStringAsFixed(1),
                    style: K.titleMedium.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: K.s12),
        Text(
          anime.title,
          style: K.headlineMedium.copyWith(fontSize: isCompact ? 22 : 30),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: K.s8),
        Wrap(
          spacing: K.s8,
          runSpacing: K.s6,
          children: anime.genres.take(3).map((g) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: K.s8,
                vertical: K.s4,
              ),
              decoration: BoxDecoration(
                color: K.bgSurface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(K.rFull),
                border: Border.all(color: K.borderSubtle, width: 1),
              ),
              child: Text(g, style: K.bodySmall),
            );
          }).toList(),
        ),
      ],
    );

    final Widget actions = Row(
      children: [
        KokuroButton(
          label: AppStrings.watch,
          icon: Icons.play_arrow_rounded,
          onPressed: onWatch,
        ),
        const SizedBox(width: K.s12),
        MyListButton(
          inList: inList,
          onSelect: (s) => onSetList?.call(s),
          onRemove: () => onSetList?.call(null),
        ),
      ],
    );

    final Widget body = isCompact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 100, height: 150, child: poster),
                  const SizedBox(width: K.s16),
                  Expanded(child: headline),
                ],
              ),
              const SizedBox(height: K.s16),
              Text(
                anime.synopsis,
                style: K.bodyMedium.copyWith(color: K.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: K.s16),
              actions,
            ],
          )
        : Row(
            children: [
              SizedBox(width: 170, height: 232, child: poster),
              const SizedBox(width: K.s32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    headline,
                    const SizedBox(height: K.s16),
                    Text(
                      anime.synopsis,
                      style: K.bodyMedium.copyWith(color: K.textSecondary),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: K.s20),
                    actions,
                  ],
                ),
              ),
            ],
          );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: isCompact ? null : 280,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(K.r24),
            border: Border.all(color: K.borderSubtle, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [K.bgCard, K.bgCard.withValues(alpha: 0.55)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? K.s20 : K.s24),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Lays out Continue Journey + Trending side by side on wide screens and
/// stacked on narrow ones; each section only renders when it has data.
class _JourneyTrendingArea extends StatelessWidget {
  final HomeLoaded state;
  final void Function(Anime anime) onOpen;
  final VoidCallback onExplore;
  const _JourneyTrendingArea({
    required this.state,
    required this.onOpen,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final hasJourney =
        state.continueWatching.isNotEmpty || state.journey.isNotEmpty;
    final showTrending = state.trending.isNotEmpty;

    final journeyWidget = _ContinueJourneySection(
      items: state.journey,
      entries: state.continueWatching,
      onOpen: onOpen,
      onExplore: onExplore,
    );
    final trendingWidget = showTrending
        ? _TrendingThreadsSection(
            items: state.trending,
            onOpen: onOpen,
            onSeeAll: onExplore,
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        if (isWide) {
          if (hasJourney && showTrending) {
            return SizedBox(
              height: 400,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: journeyWidget),
                  const SizedBox(width: K.s32),
                  Expanded(flex: 2, child: trendingWidget!),
                ],
              ),
            );
          }
          return SizedBox(
            height: 400,
            child: hasJourney ? journeyWidget : trendingWidget,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasJourney) SizedBox(height: 400, child: journeyWidget),
            if (hasJourney && showTrending) const SizedBox(height: K.s32),
            if (showTrending) trendingWidget!,
          ],
        );
      },
    );
  }
}

class _ContinueJourneySection extends StatelessWidget {
  final List<Anime> items;
  final List<LibraryEntry> entries;
  final void Function(Anime anime) onOpen;
  final VoidCallback? onExplore;
  const _ContinueJourneySection({
    required this.items,
    this.entries = const [],
    required this.onOpen,
    this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    // Real in-progress tracking beats the generic list fallback.
    final useProgress = entries.isNotEmpty;
    final nodeCount = useProgress ? entries.length : items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          label: AppStrings.continueJourney,
          title: AppStrings.keepMomentum,
        ),
        const SizedBox(height: K.s24),
        SizedBox(
          height: 180,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 38,
                left: 50,
                right: 50,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        K.threadPrimary.withValues(alpha: 0.0),
                        K.threadPrimary.withValues(alpha: 0.4),
                        K.threadPrimary.withValues(alpha: 0.4),
                        K.threadPrimary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: nodeCount,
                separatorBuilder: (_, _) =>
                    SizedBox(width: nodeCount > 3 ? K.s8 : K.s32),
                itemBuilder: (context, i) {
                  if (useProgress) {
                    final entry = entries[i];
                    return _JourneyNode(
                      anime: entry.anime,
                      progress: entry.progress,
                      metaLabel:
                          'E${entry.watchedEpisodes} • ${(entry.progress * 100).round()}%',
                      onTap: () => onOpen(entry.anime),
                    );
                  }
                  return _JourneyNode(
                    anime: items[i],
                    onTap: () => onOpen(items[i]),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(
          height: K.s12,
        ), // fixed heights fill the rest with a library summary card
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(K.s16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [K.bgCard, K.bgCard.withValues(alpha: 0.6)],
              ),
              borderRadius: BorderRadius.circular(K.r12),
              border: Border.all(color: K.borderSubtle, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.collections_bookmark_outlined,
                      size: 18,
                      color: K.accent.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: K.s8),
                    Text(
                      AppStrings.yourLibrary,
                      style: K.titleMedium.copyWith(fontSize: 14),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: K.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: K.s12),
                if (nodeCount > 0) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(K.rFull),
                    child: LinearProgressIndicator(
                      value: (nodeCount / 20).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: K.bgSurface,
                      valueColor: AlwaysStoppedAnimation(K.accent),
                    ),
                  ),
                  const SizedBox(height: K.s12),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        nodeCount == 0
                            ? AppStrings.nothingYet
                            : '$nodeCount ${nodeCount == 1 ? AppStrings.title : AppStrings.titles} ${AppStrings.titlesSaved}',
                        style: K.bodyMedium.copyWith(color: K.textSecondary),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: K.s4),
                      Text(
                        nodeCount == 0
                            ? AppStrings.addAnimeToList
                            : AppStrings.tapTitleAbove,
                        style: K.bodySmall.copyWith(
                          color: K.textTertiary,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (nodeCount == 0 && onExplore != null) ...[
                        const SizedBox(height: K.s12),
                        OutlinedButton(
                          onPressed: onExplore,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: K.accent,
                            side: BorderSide(
                              color: K.accent.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: K.s20,
                              vertical: K.s8,
                            ),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(AppStrings.exploreTitles),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _JourneyNode extends StatefulWidget {
  final Anime anime;
  final double? progress;
  final String? metaLabel;
  final VoidCallback? onTap;
  const _JourneyNode({
    required this.anime,
    this.progress,
    this.metaLabel,
    this.onTap,
  });

  @override
  State<_JourneyNode> createState() => _JourneyNodeState();
}

class _JourneyNodeState extends State<_JourneyNode> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular artwork
            AnimatedContainer(
              duration: K.normal,
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _hovered
                      ? K.accent.withValues(alpha: 0.6)
                      : K.border.withValues(alpha: 0.4),
                  width: _hovered ? 2 : 1,
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: K.accent.withValues(alpha: 0.2),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(child: KuroImg(widget.anime.imageUrl)),
                  if (widget.progress != null)
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: widget.progress,
                        strokeWidth: 2.5,
                        backgroundColor: K.textTertiary.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(K.accent),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: K.s8),
            // Title
            SizedBox(
              width: 100,
              child: Text(
                widget.anime.title,
                style: K.bodySmall.copyWith(
                  color: K.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: K.s2),
            // Metadata
            Text(
              widget.metaLabel ??
                  'S1 \u2022 ${widget.anime.episodes} ${AppStrings.eps}',
              style: K.bodySmall.copyWith(fontSize: 10, color: K.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Trending Threads — ranked list
// ══════════════════════════════════════════════════════════

class _TrendingThreadsSection extends StatelessWidget {
  final List<Anime> items;
  final void Function(Anime anime) onOpen;
  final VoidCallback? onSeeAll;
  const _TrendingThreadsSection({
    required this.items,
    required this.onOpen,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          label: AppStrings.trendingThreads,
          title: AppStrings.whatFansBinging,
          trailing: onSeeAll == null
              ? null
              : TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: K.accent,
                    padding: const EdgeInsets.symmetric(horizontal: K.s8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    AppStrings.seeAll,
                    style: K.bodySmall.copyWith(color: K.accent),
                  ),
                ),
        ),
        const SizedBox(height: K.s12),
        ...items.take(4).toList().asMap().entries.map((entry) {
          final i = entry.key;
          final anime = entry.value;
          return _TrendingThreadItem(
            anime: anime,
            rank: i + 1,
            onTap: () => onOpen(anime),
          );
        }),
      ],
    );
  }
}

class _TrendingThreadItem extends StatefulWidget {
  final Anime anime;
  final int rank;
  final VoidCallback? onTap;
  const _TrendingThreadItem({required this.anime, this.rank = 1, this.onTap});

  @override
  State<_TrendingThreadItem> createState() => _TrendingThreadItemState();
}

class _TrendingThreadItemState extends State<_TrendingThreadItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: K.s4),
          padding: const EdgeInsets.symmetric(horizontal: K.s8, vertical: K.s8),
          decoration: BoxDecoration(
            color: _hovered ? K.bgCard : Colors.transparent,
            borderRadius: BorderRadius.circular(K.r12),
            border: Border.all(
              color: _hovered ? K.border : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Rank number
              SizedBox(
                width: 28,
                child: Text(
                  '${widget.rank}',
                  style: K.headlineMedium.copyWith(
                    color: K.textTertiary.withValues(alpha: 0.4),
                    fontSize: 20,
                  ),
                ),
              ),
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(K.r8),
                child: KuroImg(widget.anime.imageUrl, width: 44, height: 56),
              ),
              const SizedBox(width: K.s12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.anime.title,
                      style: K.titleMedium.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: K.s2),
                    Text(
                      widget.anime.genres.take(2).join(' \u2022 '),
                      style: K.bodySmall,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              // Score
              if (widget.anime.score > 0)
                Text(
                  widget.anime.score.toStringAsFixed(1),
                  style: K.bodyMedium.copyWith(color: K.gold),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  API Anime Card — for horizontal lists
// ══════════════════════════════════════════════════════════

class _ApiAnimeCard extends StatefulWidget {
  final Anime anime;
  final VoidCallback? onTap;
  final ValueChanged<WatchStatus?>? onSetList;
  const _ApiAnimeCard({required this.anime, this.onTap, this.onSetList});

  @override
  State<_ApiAnimeCard> createState() => _ApiAnimeCardState();
}

class _ApiAnimeCardState extends State<_ApiAnimeCard> {
  bool _hovered = false;
  String? _translatedSynopsis;
  bool _translationStarted = false;

  void _startTranslation() {
    if (_translationStarted) return;
    _translationStarted = true;
    final synopsis = widget.anime.synopsis;
    if (synopsis.isEmpty) return;
    TranslationService.toArabic(synopsis).then((t) {
      if (mounted) setState(() => _translatedSynopsis = t);
    });
  }

  @override
  Widget build(BuildContext context) {
    final anime = widget.anime;
    final members = anime.members ?? 0;

    return MouseRegion(
      onEnter: (_) {
        _startTranslation();
        setState(() => _hovered = true);
      },
      onExit: (_) => setState(() => _hovered = false),
      child: CharacterHover(
        glowColor: K.accent,
        liftAmount: -10,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: K.normal,
          width: _hovered ? 300 : 160,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(K.r12),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: K.accent.withValues(alpha: 0.15),
                      blurRadius: 16,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Hero(
                      tag: 'poster-${anime.malId}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(K.r12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [KuroImg(anime.imageUrl, width: 160)],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: K.s8),
                  Text(
                    anime.title,
                    style: K.titleMedium.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: K.s2),
                  Text(
                    anime.genres.take(2).join(' • '),
                    style: K.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Story panel — appears on hover over the whole card
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !_hovered,
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1.0 : 0.0,
                    duration: K.normal,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(K.r12),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            K.bg.withValues(alpha: 0.94),
                            K.bgCard.withValues(alpha: 0.97),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(K.s12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anime.title,
                              style: K.titleMedium.copyWith(fontSize: 13),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: K.s6),
                            Row(
                              children: [
                                if (members > 0) ...[
                                  Text(
                                    '${(members / 1000).toStringAsFixed(1)}K',
                                    style: K.bodySmall.copyWith(
                                      color: K.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(width: K.s6),
                                ],
                                if (anime.score > 0) ...[
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 14,
                                    color: K.gold,
                                  ),
                                  const SizedBox(width: K.s2),
                                  Text(
                                    anime.score.toStringAsFixed(1),
                                    style: K.bodySmall.copyWith(color: K.gold),
                                  ),
                                ],
                              ],
                            ),
                            if (anime.episodes > 0) ...[
                              const SizedBox(height: K.s4),
                              Text(
                                '${anime.episodes} ${AppStrings.episodes}',
                                style: K.bodySmall.copyWith(
                                  color: K.textTertiary,
                                ),
                              ),
                            ],
                            const SizedBox(height: K.s8),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: Text(
                                  anime.synopsis.isEmpty
                                      ? AppStrings.noSynopsis
                                      : (_translatedSynopsis ?? anime.synopsis),
                                  style: K.bodySmall.copyWith(
                                    color: K.textSecondary,
                                    height: 1.5,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: K.s8),
                            Row(
                              children: [
                                if (widget.onSetList != null)
                                  PopupMenuButton<WatchStatus>(
                                    padding: EdgeInsets.zero,
                                    tooltip: AppStrings.myList,
                                    onSelected: (s) =>
                                        widget.onSetList?.call(s),
                                    itemBuilder: (context) => WatchStatus.values
                                        .map(
                                          (s) => PopupMenuItem<WatchStatus>(
                                            value: s,
                                            child: Text(s.label),
                                          ),
                                        )
                                        .toList(),
                                    child: Container(
                                      padding: const EdgeInsets.all(K.s6),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: K.accent.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          K.r8,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 18,
                                        color: K.accent,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: widget.onTap,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: K.s12,
                                      vertical: K.s6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: K.accent,
                                      borderRadius: BorderRadius.circular(K.r8),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 18,
                                      color: K.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Ranked Anime Card — Top-10 chart with oversized rank number
// ══════════════════════════════════════════════════════════

class _RankedAnimeCard extends StatefulWidget {
  final Anime anime;
  final int rank;
  final VoidCallback? onTap;
  const _RankedAnimeCard({required this.anime, required this.rank, this.onTap});

  @override
  State<_RankedAnimeCard> createState() => _RankedAnimeCardState();
}

class _RankedAnimeCardState extends State<_RankedAnimeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isPodium = widget.rank <= 3;
    final rankColor = isPodium
        ? K.gold.withValues(alpha: 0.7)
        : K.accent.withValues(alpha: 0.28);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: CharacterHover(
        glowColor: isPodium ? K.gold : K.accent,
        liftAmount: -10,
        onTap: widget.onTap,
        child: SizedBox(
          width: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Oversized rank number at the start of the card
              SizedBox(
                width: 52,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${widget.rank}',
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -4,
                      color: rankColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: K.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(K.r12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            KuroImg(widget.anime.imageUrl, width: 140),
                            if (isPodium)
                              PositionedDirectional(
                                top: K.s8,
                                start: K.s8,
                                child: Icon(
                                  Icons.emoji_events_rounded,
                                  size: 18,
                                  color: K.gold.withValues(alpha: 0.9),
                                ),
                              ),
                            AnimatedOpacity(
                              opacity: _hovered ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 250),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      K.bg.withValues(alpha: 0.8),
                                    ],
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.all(K.s8),
                                    child: Text(
                                      AppStrings.watchNow,
                                      style: K.bodySmall.copyWith(
                                        color: K.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: K.s8),
                    Text(
                      widget.anime.title,
                      style: K.titleMedium.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: K.s2),
                    Text(
                      widget.anime.score > 0
                          ? '★ ${widget.anime.score.toStringAsFixed(1)}'
                          : widget.anime.genres.take(2).join(' • '),
                      style: K.bodySmall.copyWith(
                        color: widget.anime.score > 0 ? K.gold : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
