import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show mapEquals;
import '../domain/entities/anime.dart';
import '../data/datasources/jikan_remote_datasource.dart';
import 'tokens.dart';
import 'genre_web_layout.dart';
import 'components.dart';
import 'kokuro_bloc.dart';
import 'loading_widgets.dart';
import 'active_branch_scope.dart';
import 'app_strings.dart';
import 'anime_animations.dart';
import 'search_history.dart';

class ExploreScreen extends StatefulWidget {
  final int branchIndex;

  /// Query params arriving via `/explore?genre=..&type=..&season=..` etc.
  /// so a "See all" from a home section lands on the matching feed.
  final Map<String, String> initialParams;

  const ExploreScreen({
    super.key,
    this.branchIndex = 1,
    this.initialParams = const {},
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final Set<String> _selectedGenres = {};
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<String> _recentSearches = const [];
  bool _searchFocused = false;

  // Active filters (defaults = no filter).
  String _season = AppStrings.all;
  String _year = AppStrings.all;
  String _studio = AppStrings.all;
  String _type = AppStrings.all;
  String _rating = AppStrings.all;
  String _sort = AppStrings.popular;

  static const _seasons = [
    AppStrings.all,
    AppStrings.winter,
    AppStrings.spring,
    AppStrings.summer,
    AppStrings.fall,
    AppStrings.upcoming,
  ];
  static const _studios = [
    AppStrings.all,
    'MAPPA',
    'Ufotable',
    'Bones',
    'Wit Studio',
    'Studio Ghibli',
    'Kyoto Animation',
    'Madhouse',
    'A-1 Pictures',
    'Production I.G',
    'Toei Animation',
    'Trigger',
    'David Production',
    'Shaft',
  ];
  static const _types = [
    AppStrings.all,
    'TV',
    'Movie',
    'OVA',
    'ONA',
    'Special',
    'Music',
  ];
  static const _ratings = [
    AppStrings.all,
    'G',
    'PG',
    'PG-13',
    'R-17',
    'R+',
    'Rx',
  ];
  static const _sorts = [
    AppStrings.popular,
    'Score',
    'Favorites',
    'Newest',
    'Oldest',
  ];

  List<String> get _years =>
      List.generate(12, (i) => '${DateTime.now().year - i}')
        ..insert(0, AppStrings.all);

  // Captures the last populated grid (ExploreLoaded / SearchLoaded) so the
  // grid doesn't empty out while other screens push routes / change bloc state.
  ExploreLoaded? _cachedExplore;
  SearchLoaded? _cachedSearch;

  static const _genres = [
    AppStrings.all,
    AppStrings.genreAction,
    AppStrings.genreAdventure,
    AppStrings.genreComedy,
    AppStrings.genreDrama,
    AppStrings.genreFantasy,
    AppStrings.genreHorror,
    AppStrings.genreMystery,
    AppStrings.genreRomance,
    AppStrings.genreSciFi,
    AppStrings.genreSliceOfLife,
    AppStrings.genreSports,
    AppStrings.genreSupernatural,
    AppStrings.genreThriller,
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _applyInitialParams();
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fireFromParams();
    });
  }

  Future<void> _loadRecentSearches() async {
    final history = await SearchHistory.load();
    if (!mounted) return;
    setState(() => _recentSearches = history);
  }

  /// The explore branch lives inside a [StatefulNavigationShell], so when a
  /// home "See all" navigates to a NEW `/explore?...` location the router
  /// reuses the existing [ExploreScreen] element (same runtimeType at the top
  /// of the branch stack) instead of recreating it. That means [initState] —
  /// and with it [_applyInitialParams] — won't run again. here we detect the
  /// changed query params, reset the old section's filters and refire the
  /// feed so each "See all" lands on ITS OWN section instead of the previous
  /// one's leftovers.
  @override
  void didUpdateWidget(covariant ExploreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialParams == oldWidget.initialParams) return;
    if (mapEquals(oldWidget.initialParams, widget.initialParams)) return;
    setState(() {
      _resetFilters();
      _applyInitialParams();
    });
    _fireFromParams();
  }

  /// Restores every filter to the bare default before a fresh set of query
  /// params is layered on top (otherwise a "Romance" selection from the
  /// previous section would linger and union with the new genre).
  void _resetFilters() {
    _selectedGenres.clear();
    _searchController.clear();
    _season = AppStrings.all;
    _year = AppStrings.all;
    _studio = AppStrings.all;
    _type = AppStrings.all;
    _rating = AppStrings.all;
    _sort = AppStrings.popular;
    _cachedExplore = null;
    _cachedSearch = null;
  }

  /// Applies `/explore?...` query params (from a home "See all" link) to the
  /// local filter state so the chips/dropdowns reflect where we landed and the
  /// grid loads that specific feed instead of the default top list.
  void _applyInitialParams() {
    final qp = widget.initialParams;
    void seasonFrom(String? v) {
      if (v != null && _seasons.contains(v)) _season = v;
    }

    final presetQuery = qp['q'];
    if (presetQuery != null && presetQuery.isNotEmpty) {
      _searchController.text = presetQuery;
    }

    final presetGenre = qp['genre'];
    if (presetGenre != null && presetGenre.isNotEmpty) {
      for (final g in presetGenre.split(',')) {
        if (_genres.contains(g)) _selectedGenres.add(g);
      }
    }
    seasonFrom(qp['season']);
    if (qp.containsKey('upcoming')) _season = AppStrings.upcoming;
    final presetType = qp['type'];
    if (presetType != null && _types.contains(presetType)) _type = presetType;
    final presetYear = qp['year'];
    if (presetYear != null && _years.contains(presetYear)) _year = presetYear;
    final presetSort = qp['sort'];
    if (presetSort != null && _sorts.contains(presetSort)) _sort = presetSort;
  }

  /// Fires the right bloc event after params are applied: live search when
  /// `?q=` is present (top-bar submit), otherwise the explore filters feed.
  void _fireFromParams() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      SearchHistory.add(query);
      _loadRecentSearches();
      context.read<KokuroBloc>().add(SearchAnime(query));
    } else {
      _applyFilters();
    }
  }

  /// Infinite scroll: when the grid approaches its bottom, lazily fetch the
  /// next page of whichever feed is active (explore or live search).
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - 480) return;

    final bloc = context.read<KokuroBloc>();
    final state = bloc.state;
    if (state is ExploreLoaded) {
      if (state.hasMore && !state.isLoadingMore) {
        bloc.add(
          LoadMoreExplore(
            genre: _currentGenreParam,
            season: _seasonParam,
            year: _year == AppStrings.all || _season == AppStrings.upcoming
                ? null
                : _year,
            studio: _studio == AppStrings.all ? null : _studio,
            type: _type == AppStrings.all ? null : _type,
            rating: _rating == AppStrings.all ? null : _rating,
            sort: _sort == AppStrings.popular ? null : _sort,
            upcoming: _season == AppStrings.upcoming,
          ),
        );
      }
    } else if (state is SearchLoaded) {
      final q = _searchController.text.trim();
      if (q == state.query && state.hasMore && !state.isLoadingMore) {
        bloc.add(LoadMoreSearch(q));
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onGenreSelected(String? genre) {
    setState(() {
      _selectedGenres.clear();
      if (genre != null) _selectedGenres.add(genre);
    });
    _applyFilters();
  }

  /// Toggles one chip in/out of the multi-genre selection.
  void _toggleGenre(String genreName) {
    setState(() {
      if (genreName == AppStrings.all) {
        _selectedGenres.clear();
      } else if (!_selectedGenres.remove(genreName)) {
        _selectedGenres.add(genreName);
      }
    });
    _applyFilters();
  }

  String? get _currentGenreParam {
    if (_selectedGenres.isEmpty) return null;
    return _selectedGenres.map(AppStrings.genreKey).join(',');
  }

  void _applyFilters() {
    context.read<KokuroBloc>().add(
      LoadExplore(
        genre: _currentGenreParam,
        season: _seasonParam,
        year: _year == AppStrings.all || _season == AppStrings.upcoming
            ? null
            : _year,
        studio: _studio == AppStrings.all ? null : _studio,
        type: _type == AppStrings.all ? null : _type,
        rating: _rating == AppStrings.all ? null : _rating,
        sort: _sort == AppStrings.popular ? null : _sort,
        upcoming: _season == AppStrings.upcoming,
      ),
    );
  }

  /// "Upcoming" is a synthesized option: it maps to the dedicated upcoming
  /// feed instead of a seasonal calendar slot.
  String? get _seasonParam =>
      _season == AppStrings.all || _season == AppStrings.upcoming
      ? null
      : _season;

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    setState(() => _searchFocused = true);
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final q = query.trim();
      if (q.isNotEmpty) {
        SearchHistory.add(q);
        _loadRecentSearches();
      }
      if (!mounted) return;
      context.read<KokuroBloc>().add(SearchAnime(query));
    });
  }

  void _applyRecentSearch(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
  }

  /// Pull-to-refresh: refires the active query (live search or explore
  /// filters) so the whole feed reloads from the network.
  Future<void> _refresh() {
    final bloc = context.read<KokuroBloc>();
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      bloc.add(SearchAnime(q));
    } else {
      _applyFilters();
    }
    return Future<void>.delayed(const Duration(seconds: 1));
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
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              final isTablet =
                  constraints.maxWidth >= 800 && constraints.maxWidth < 1100;

              final Widget content = isNarrow
                  ? _buildNarrowLayout()
                  : _buildMainContent(
                      isNarrow: false,
                      isTablet: isTablet,
                      maxColumns: isTablet ? 2 : 3,
                    );

              return RefreshIndicator(
                onRefresh: _refresh,
                color: K.accent,
                backgroundColor: K.bgCard,
                child: content,
              );
            },
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Narrow Layout (mobile)
  // ══════════════════════════════════════════════════════════

  Widget _buildNarrowLayout() {
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: K.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: K.s16),
                _buildHeader(),
                const SizedBox(height: K.s16),
                _buildSearchField(isNarrow: true),
                const SizedBox(height: K.s20),
                _buildGenreChips(isNarrow: true),
                const SizedBox(height: K.s16),
                _buildFilterRow(isNarrow: true),
                const SizedBox(height: K.s32),
                _buildGenreNodesGrid(maxColumns: 2),
                const SizedBox(height: K.s32),
                _buildExploreByMoodButton(),
                const SizedBox(height: K.s40),
              ],
            ),
          ),
        ),
        ..._buildFeedSlivers(isNarrow: true, horizontalPadding: K.s20),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Main Content
  // ══════════════════════════════════════════════════════════

  Widget _buildMainContent({
    required bool isNarrow,
    required bool isTablet,
    required int maxColumns,
  }) {
    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: K.s32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: K.s32),
                _buildHeader(),
                const SizedBox(height: K.s24),
                _buildSearchField(isNarrow: false),
                const SizedBox(height: K.s24),
                _buildGenreChips(isNarrow: false),
                const SizedBox(height: K.s20),
                _buildFilterRow(isNarrow: false),
                const SizedBox(height: K.s40),
                _buildGenreNodesGrid(maxColumns: maxColumns),
                const SizedBox(height: K.s32),
                _buildExploreByMoodButton(),
                const SizedBox(height: K.s48),
              ],
            ),
          ),
        ),
        ..._buildFeedSlivers(isNarrow: isNarrow, horizontalPadding: K.s32),
        const SliverToBoxAdapter(child: SizedBox(height: K.s80)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Header
  // ══════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Text(
      AppStrings.discoverMood,
      style: K.bodyLarge.copyWith(
        fontSize: 18,
        color: K.textSecondary,
        height: 1.4,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Search Field
  // ══════════════════════════════════════════════════════════

  Widget _buildSearchField({required bool isNarrow}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: K.bgCard,
            borderRadius: BorderRadius.circular(K.r12),
            border: Border.all(color: K.border.withValues(alpha: 0.4)),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onTap: () => setState(() => _searchFocused = true),
            onSubmitted: (_) => setState(() => _searchFocused = false),
            style: K.bodyMedium.copyWith(color: K.textPrimary),
            decoration: InputDecoration(
              hintText: AppStrings.searchAnime,
              hintStyle: K.bodyMedium.copyWith(color: K.textTertiary),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: K.textTertiary,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: K.textTertiary,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: K.s16,
                vertical: K.s12,
              ),
            ),
          ),
        ),
        if (_searchFocused &&
            _searchController.text.trim().isEmpty &&
            _recentSearches.isNotEmpty)
          _buildRecentSearches(),
      ],
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: const EdgeInsets.only(top: K.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(AppStrings.recentSearches, style: K.labelUppercase),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await SearchHistory.clear();
                  if (mounted) setState(() => _recentSearches = const []);
                },
                child: Text(
                  AppStrings.clearSearches,
                  style: K.bodySmall.copyWith(color: K.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: K.s8),
          Wrap(
            spacing: K.s8,
            runSpacing: K.s8,
            children: [
              for (final q in _recentSearches)
                GestureDetector(
                  onTap: () => _applyRecentSearch(q),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: K.s12,
                      vertical: K.s6,
                    ),
                    decoration: BoxDecoration(
                      color: K.bgCard,
                      borderRadius: BorderRadius.circular(K.rFull),
                      border: Border.all(color: K.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 14,
                          color: K.textTertiary,
                        ),
                        const SizedBox(width: K.s6),
                        Text(q, style: K.bodySmall),
                        const SizedBox(width: K.s6),
                        GestureDetector(
                          onTap: () async {
                            await SearchHistory.remove(q);
                            if (mounted) _loadRecentSearches();
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: K.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Genre Chips
  // ══════════════════════════════════════════════════════════

  Widget _buildGenreChips({required bool isNarrow}) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _genres.length,
        separatorBuilder: (_, _) => const SizedBox(width: K.s8),
        itemBuilder: (context, index) {
          final genreName = _genres[index];
          final selected = genreName == AppStrings.all
              ? _selectedGenres.isEmpty
              : _selectedGenres.contains(genreName);

          return GestureDetector(
            onTap: () => _toggleGenre(genreName),
            child: AnimatedContainer(
              duration: K.fast,
              padding: const EdgeInsets.symmetric(
                horizontal: K.s16,
                vertical: K.s8,
              ),
              decoration: BoxDecoration(
                color: selected ? K.accent : K.bgCard,
                borderRadius: BorderRadius.circular(K.rFull),
                border: Border.all(
                  color: selected ? K.accent : K.border.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _genres[index],
                style: K.titleMedium.copyWith(
                  fontSize: 13,
                  color: selected ? K.textPrimary : K.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Filter Row — every chip opens a menu and refetches the feed.
  // ══════════════════════════════════════════════════════════

  List<
    ({
      String label,
      String value,
      List<String> options,
      ValueChanged<String> onChanged,
    })
  >
  get _filters => [
    (
      label: AppStrings.season,
      value: _season,
      options: _seasons,
      onChanged: (v) => _setFilter(() => _season = v),
    ),
    (
      label: AppStrings.year,
      value: _year,
      options: _years,
      onChanged: (v) => _setFilter(() => _year = v),
    ),
    (
      label: AppStrings.studio,
      value: _studio,
      options: _studios,
      onChanged: (v) => _setFilter(() => _studio = v),
    ),
    (
      label: AppStrings.type,
      value: _type,
      options: _types,
      onChanged: (v) => _setFilter(() => _type = v),
    ),
    (
      label: AppStrings.rating,
      value: _rating,
      options: _ratings,
      onChanged: (v) => _setFilter(() => _rating = v),
    ),
    (
      label: AppStrings.sort,
      value: _sort,
      options: _sorts,
      onChanged: (v) => _setFilter(() => _sort = v),
    ),
  ];

  void _setFilter(VoidCallback assign) {
    setState(assign);
    _applyFilters();
  }

  Widget _buildFilterRow({required bool isNarrow}) {
    final filters = _filters;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: K.s8),
        itemBuilder: (context, index) {
          final f = filters[index];
          final active =
              f.value != AppStrings.all &&
              !(f.label == AppStrings.sort && f.value == AppStrings.popular);
          return _FilterMenuChip(
            key: ValueKey('${f.label}-${f.value}'),
            label: f.label,
            value: f.value,
            options: f.options,
            active: active,
            onChanged: f.onChanged,
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Genre Nodes Web — a scattered constellation connected by
  //  glowing threads, behaving like a living network instead of a grid.
  // ══════════════════════════════════════════════════════════

  Widget _buildGenreNodesGrid({required int maxColumns}) {
    final nodes = genreWebNodes;
    final blocState = context.watch<KokuroBloc>().state;
    final counts = blocState is ExploreLoaded
        ? blocState.genreCounts
        : const <String, int>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.genreMap.toUpperCase(), style: K.labelUppercase),
        const SizedBox(height: K.s20),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: LayoutBuilder(
              builder: (context, c) {
                final gridWidth = c.maxWidth.clamp(300.0, 980.0);
                final gridHeight = gridWidth * 0.52;
                final nodeSize = (gridWidth * 0.115).clamp(94.0, 118.0);

                final positions = <Offset>[];
                for (final n in nodes) {
                  positions.add(Offset(n.x * gridWidth, n.y * gridHeight));
                }

                final links = _buildWebLinks(positions);

                return SizedBox(
                  width: gridWidth,
                  height: gridHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(K.r20),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: _GenreWeb(points: positions, links: links),
                        ),
                        for (int i = 0; i < nodes.length; i++)
                          Positioned(
                            left: positions[i].dx - nodeSize / 2,
                            top: positions[i].dy - nodeSize / 2,
                            child: GenreNode(
                              name: nodes[i].name,
                              count: counts[nodes[i].name],
                              size: nodeSize,
                              onTap: () => _onGenreSelected(nodes[i].name),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Connects every node to its 2 nearest neighbors, producing one
  /// mesh-like constellation (never a straight-lined grid).
  List<({int i, int j})> _buildWebLinks(List<Offset> pts) {
    final pairs = <({int i, int j})>[];
    final seen = <(int, int)>{};
    for (int i = 0; i < pts.length; i++) {
      final nearest = List<int>.generate(pts.length, (k) => k)
        ..remove(i)
        ..sort(
          (a, b) =>
              (pts[i] - pts[a]).distance.compareTo((pts[i] - pts[b]).distance),
        );
      for (final j in nearest.take(2)) {
        final key = i < j ? (i, j) : (j, i);
        if (seen.add(key)) pairs.add((i: key.$1, j: key.$2));
      }
    }
    return pairs;
  }

  // ══════════════════════════════════════════════════════════
  //  Explore by Mood Button
  // ══════════════════════════════════════════════════════════

  Widget _buildExploreByMoodButton() {
    return Center(
      child: KokuroButton(
        label: AppStrings.exploreByMood,
        icon: Icons.psychology_rounded,
        filled: false,
        accentColor: K.threadSecondary,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Loading Grid Placeholder
  // ══════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════
  //  Explore Feed — a set of slivers: section header, the lazy anime
  //  grid (SliverGrid builds only the visible cells) and the bottom
  //  "View All" section.
  // ══════════════════════════════════════════════════════════

  List<Widget> _buildFeedSlivers({
    required bool isNarrow,
    required double horizontalPadding,
  }) {
    return [
      BlocBuilder<KokuroBloc, KokuroState>(
        builder: (context, state) {
          final feed = _feedDataFor(state);
          final isLoading = state is KokuroLoading;
          final isEmpty = feed.list.isEmpty && !isLoading;

          return SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(label: feed.label),
                  if (isEmpty) ...[
                    const SizedBox(height: K.s40),
                    Center(
                      child: Text(
                        state is SearchLoaded
                            ? AppStrings.noResults
                            : AppStrings.noAnimeFound,
                        style: K.bodyLarge.copyWith(color: K.textTertiary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      BlocBuilder<KokuroBloc, KokuroState>(
        builder: (context, state) {
          if (state is SearchLoaded && state.characters.isNotEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: K.s16),
                child: _buildCharacterStrip(
                  characters: state.characters,
                  horizontalPadding: horizontalPadding,
                ),
              ),
            );
          }
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        },
      ),
      BlocBuilder<KokuroBloc, KokuroState>(
        builder: (context, state) {
          if (state is KokuroLoading) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: K.s8,
                ),
                child: FeedSkeleton(isNarrow: isNarrow),
              ),
            );
          }

          final feed = _feedDataFor(state);
          if (feed.list.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          return SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            sliver: SliverGrid(
              gridDelegate: _feedGridDelegate(isNarrow: isNarrow),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ApiAnimeCard(
                  anime: feed.list[i],
                  onTap: () => _openDetail(feed.list[i]),
                ),
                childCount: feed.list.length,
              ),
            ),
          );
        },
      ),
      BlocBuilder<KokuroBloc, KokuroState>(
        builder: (context, state) {
          if (state is ExploreLoaded) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _buildViewAllSection(state),
              ),
            );
          }
          if (state is SearchLoaded && state.isLoadingMore) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: K.s32),
                child: Center(child: KokuroLoader(compact: true, size: 22)),
              ),
            );
          }
          if (state is SearchLoaded &&
              !state.hasMore &&
              state.results.isNotEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: K.s32),
                child: Center(
                  child: Text(
                    AppStrings.noMoreResults,
                    style: K.bodySmall.copyWith(color: K.textTertiary),
                  ),
                ),
              ),
            );
          }
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        },
      ),
      const SliverToBoxAdapter(child: SizedBox(height: K.s80)),
    ];
  }

  /// Resolves which label + anime list the feed should show, falling back to
  /// the last populated grid while other screens take over the bloc state.
  ({String label, List<Anime> list}) _feedDataFor(KokuroState state) {
    if (state is ExploreLoaded) {
      return (
        label: state.selectedGenre != null
            ? '${AppStrings.popularIn} ${_prettyGenres(state.selectedGenre!)}'
            : AppStrings.popular,
        list: state.anime,
      );
    }
    if (state is SearchLoaded) {
      return (
        label: '${AppStrings.resultsFor} "${state.query}"',
        list: state.results,
      );
    }
    if (_cachedExplore != null) {
      return (
        label: _cachedExplore!.selectedGenre != null
            ? '${AppStrings.popularIn} ${_prettyGenres(_cachedExplore!.selectedGenre!)}'
            : AppStrings.popular,
        list: _cachedExplore!.anime,
      );
    }
    if (_cachedSearch != null) {
      return (
        label: '${AppStrings.resultsFor} "${_cachedSearch!.query}"',
        list: _cachedSearch!.results,
      );
    }
    return (
      label: '${AppStrings.popularIn} ${AppStrings.genreAction}',
      list: const [],
    );
  }

  SliverGridDelegate _feedGridDelegate({required bool isNarrow}) {
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: isNarrow ? 175 : 210,
      mainAxisSpacing: K.s24,
      crossAxisSpacing: K.s16,
      childAspectRatio: 200 / 280,
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Bottom "View All" — loads the remaining pages of the whole
  //  category and appends every title, then shows a spinner while
  //  the bloc keeps fetching until the category is complete.
  // ══════════════════════════════════════════════════════════

  Widget _buildViewAllSection(ExploreLoaded state) {
    if (!state.hasMore && !state.isLoadingMore) return const SizedBox.shrink();

    final total = _totalTitlesFor(state);

    return Column(
      children: [
        const SizedBox(height: K.s40),
        if (state.isLoadingMore)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const KokuroLoader(compact: true, size: 22),
              const SizedBox(width: K.s12),
              Text(
                AppStrings.loadingCategory,
                style: K.bodyMedium.copyWith(color: K.textSecondary),
              ),
            ],
          )
        else
          Center(
            child: KokuroButton(
              label: total != null && state.selectedGenre != null
                  ? '${AppStrings.viewAll} $total ${AppStrings.titles}'
                  : AppStrings.viewAll,
              icon: Icons.unfold_more_rounded,
              filled: false,
              accentColor: K.accent,
              onPressed: () => context.read<KokuroBloc>().add(
                LoadMoreExplore(
                  genre: _currentGenreParam,
                  season: _season == AppStrings.all ? null : _season,
                  year: _year == AppStrings.all ? null : _year,
                  studio: _studio == AppStrings.all ? null : _studio,
                  type: _type == AppStrings.all ? null : _type,
                  rating: _rating == AppStrings.all ? null : _rating,
                  sort: _sort == AppStrings.popular ? null : _sort,
                ),
              ),
            ),
          ),
      ],
    );
  }

  int? _totalTitlesFor(ExploreLoaded state) {
    final genre = state.selectedGenre;
    if (genre == null) return null;
    return state.genreCounts[genre];
  }

  static String _prettyGenres(String commaJoined) =>
      commaJoined.split(',').map((g) => g.trim()).join(' · ');

  /// Horizontal strip of character results above the anime grid when a search
  /// matches characters too — so people find actors, not just titles.
  Widget _buildCharacterStrip({
    required List<AnimeCharacter> characters,
    required double horizontalPadding,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Text(
            AppStrings.characters.toUpperCase(),
            style: K.labelUppercase,
          ),
        ),
        const SizedBox(height: K.s12),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: characters.length,
            separatorBuilder: (_, _) => const SizedBox(width: K.s12),
            itemBuilder: (context, index) {
              final character = characters[index];
              return _CharacterResultCard(
                character: character,
                onTap: () async {
                  await context.push(
                    '/character/${character.malId}',
                    extra: character,
                  );
                  if (mounted) _refresh();
                },
              );
            },
          ),
        ),
        const SizedBox(height: K.s24),
      ],
    );
  }

  void _openDetail(Anime anime) async {
    await context.push('/anime/${anime.malId}', extra: anime);
    if (mounted) _refresh();
  }
}

// ══════════════════════════════════════════════════════════
//  Filter Menu Chip — boxed label + selected value that opens a
//  dropdown of options and reports the chosen one back.
// ══════════════════════════════════════════════════════════

class _FilterMenuChip extends StatelessWidget {
  final String label;
  final String value;
  final List<String> options;
  final bool active;
  final ValueChanged<String> onChanged;

  const _FilterMenuChip({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.active,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: K.bgCard,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(K.r8),
        side: BorderSide(color: K.border.withValues(alpha: 0.3)),
      ),
      itemBuilder: (context) => [
        for (final option in options)
          PopupMenuItem<String>(
            value: option,
            height: 36,
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: option == value
                      ? Icon(Icons.check_rounded, color: K.accent, size: 16)
                      : null,
                ),
                const SizedBox(width: K.s8),
                Text(
                  option,
                  style: K.bodyMedium.copyWith(
                    color: option == value ? K.accent : K.textPrimary,
                    fontWeight: option == value
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: K.s12),
        decoration: BoxDecoration(
          color: K.bgCard,
          borderRadius: BorderRadius.circular(K.r8),
          border: Border.all(
            color: active
                ? K.accent.withValues(alpha: 0.7)
                : K.border.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: K.bodySmall.copyWith(color: K.textTertiary)),
            const SizedBox(width: K.s6),
            Text(
              value,
              style: K.bodySmall.copyWith(
                color: active ? K.accent : K.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: K.s2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: K.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Anime Card (uses real Anime entity)
// ══════════════════════════════════════════════════════════

class _ApiAnimeCard extends StatefulWidget {
  final Anime anime;
  final VoidCallback? onTap;

  const _ApiAnimeCard({required this.anime, this.onTap});

  @override
  State<_ApiAnimeCard> createState() => _ApiAnimeCardState();
}

class _ApiAnimeCardState extends State<_ApiAnimeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: CharacterHover(
            glowColor: K.accent,
            liftAmount: -6,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: K.normal,
              curve: K.easeOut,
              width: w,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(K.r12),
                boxShadow: _hovered
                    ? K.glow(color: K.accent, blur: 20)
                    : K.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: h - 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(K.r12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AnimatedScale(
                            scale: _hovered ? 1.08 : 1.0,
                            duration: const Duration(milliseconds: 350),
                            curve: K.easeOut,
                            child: Hero(
                              tag: 'poster-${widget.anime.malId}',
                              child: KuroImg(
                                widget.anime.imageUrl,
                                fit: BoxFit.cover,
                              ),
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
                                    K.bg.withValues(alpha: 0.6),
                                    K.bg.withValues(alpha: 0.95),
                                  ],
                                  stops: const [0.3, 0.65, 1.0],
                                ),
                              ),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 280),
                            curve: K.easeOut,
                            bottom: _hovered ? K.s8 : -40,
                            left: K.s8,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.play_circle_outline,
                                  color: K.textPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: K.s4),
                                Text(
                                  AppStrings.watch,
                                  style: K.bodySmall.copyWith(
                                    color: K.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: K.s8,
                            right: K.s8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: K.s6,
                                vertical: K.s2,
                              ),
                              decoration: BoxDecoration(
                                color: K.bg.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(K.r4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: K.gold,
                                    size: 14,
                                  ),
                                  const SizedBox(width: K.s2),
                                  Text(
                                    widget.anime.score.toStringAsFixed(1),
                                    style: K.bodySmall.copyWith(
                                      color: K.gold,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
                    widget.anime.genres.take(2).join(' \u2022 '),
                    style: K.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Character Result Card — a compact portrait + name tile for the
//  character-results strip shown above search grids.
// ══════════════════════════════════════════════════════════

class _CharacterResultCard extends StatefulWidget {
  final AnimeCharacter character;
  final VoidCallback? onTap;

  const _CharacterResultCard({required this.character, this.onTap});

  @override
  State<_CharacterResultCard> createState() => _CharacterResultCardState();
}

class _CharacterResultCardState extends State<_CharacterResultCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: K.normal,
          curve: K.easeOut,
          width: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(K.r12),
            boxShadow: _hovered
                ? K.glow(color: K.threadPrimary, blur: 16)
                : K.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(K.r12),
                  border: Border.all(
                    color: _hovered
                        ? K.threadPrimary.withValues(alpha: 0.6)
                        : K.borderSubtle,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(K.r12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      KuroImg(
                        widget.character.imageUrl,
                        fit: BoxFit.cover,
                        error: const Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: K.textTertiary,
                            size: 32,
                          ),
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: K.s6),
              Text(
                widget.character.name,
                style: K.titleMedium.copyWith(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Genre Web — animated constellation background for the genre
//  map. Draws a nebula base, twinkling star specks, glowing
//  connecting threads, and a soft pulsing halo behind each node.
// ══════════════════════════════════════════════════════════

class _GenreWeb extends StatefulWidget {
  final List<Offset> points;
  final List<({int i, int j})> links;

  const _GenreWeb({required this.points, required this.links});

  @override
  State<_GenreWeb> createState() => _GenreWebState();
}

class _GenreWebState extends State<_GenreWeb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _GenreWebPainter(
          points: widget.points,
          links: widget.links,
          t: _controller.value,
        ),
      ),
    );
  }
}

class _GenreWebPainter extends CustomPainter {
  final List<Offset> points;
  final List<({int i, int j})> links;
  final double t;

  _GenreWebPainter({
    required this.points,
    required this.links,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseRect = Offset.zero & size;

    // Faint nebula base so the map reads as a living cosmos panel.
    canvas.drawRect(
      baseRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            K.bgCard.withValues(alpha: 0.45),
            K.bg.withValues(alpha: 0.0),
          ],
          radius: 1.1,
        ).createShader(baseRect),
    );

    final wave = t * 2 * math.pi;

    // Twinkling star specks (deterministic layout).
    final rand = math.Random(7);
    for (int s = 0; s < 70; s++) {
      final sx = rand.nextDouble() * size.width;
      final sy = rand.nextDouble() * size.height;
      final tw = 0.5 + 0.5 * math.sin(wave + (s % 7) * 1.7);
      final alpha = 0.2 + 0.5 * tw * (0.3 + 0.7 * rand.nextDouble());
      final r = 0.6 + rand.nextDouble() * 1.7;
      canvas.drawCircle(
        Offset(sx, sy),
        r,
        Paint()..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0)),
      );
    }

    // Glowing threads between connected nodes, gently breathing.
    final shift = 0.5 + 0.5 * math.sin(wave + 0.4);
    final lineAlpha = (0.14 + 0.22 * shift).clamp(0.0, 1.0);

    for (final link in links) {
      final p0 = points[link.i];
      final p1 = points[link.j];

      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = K.threadPrimary.withValues(alpha: lineAlpha * 0.65)
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = K.accent.withValues(alpha: lineAlpha)
          ..strokeWidth = 1
          ..strokeCap = StrokeCap.round,
      );
    }

    // Soft pulsing halo behind each node.
    for (final p in points) {
      final pulse = 0.5 + 0.5 * math.sin(wave * 1.3 + p.dx * 0.01);
      canvas.drawCircle(
        p,
        42 + 7 * pulse,
        Paint()
          ..color = K.accent.withValues(alpha: 0.05 + 0.05 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GenreWebPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.points != points ||
        oldDelegate.links != links;
  }
}
