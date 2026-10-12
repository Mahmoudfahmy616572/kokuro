import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/entities/anime.dart';
import '../data/datasources/jikan_remote_datasource.dart';
import 'app_strings.dart';
import 'tokens.dart';
import 'components.dart';
import 'kokuro_bloc.dart';
import 'loading_widgets.dart';

class CharacterProfileScreen extends StatefulWidget {
  final AnimeCharacter character;
  final int animeId;

  const CharacterProfileScreen({
    super.key,
    required this.character,
    required this.animeId,
  });

  @override
  State<CharacterProfileScreen> createState() => _CharacterProfileScreenState();
}

class _CharacterProfileScreenState extends State<CharacterProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KokuroBloc>().add(
        LoadCharacter(character: widget.character, animeId: widget.animeId),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      body: BlocBuilder<KokuroBloc, KokuroState>(
        builder: (context, state) {
          if (state is KokuroLoading) {
            return const Center(
              child: KokuroLoader(label: AppStrings.channelingCharacter),
            );
          }
          if (state is KokuroError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: K.coral, size: 48),
                  const SizedBox(height: K.s16),
                  Text(state.message, style: K.bodyLarge),
                ],
              ),
            );
          }
          if (state is CharacterLoaded) {
            return _buildCharacterContent(state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildCharacterContent(CharacterLoaded state) {
    final character = state.character;
    final appearances = state.appearances;

    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(character),
        SliverToBoxAdapter(child: _buildHeroSection(context, character)),
        SliverToBoxAdapter(child: _buildPersonalitySection(character)),
        SliverToBoxAdapter(child: _buildVoiceActorSection(character)),
        SliverToBoxAdapter(
          child: _buildAppearancesSection(context, appearances),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: K.s48)),
      ],
    );
  }

  // ── App Bar ──────────────────────────────────────────────

  Widget _buildSliverAppBar(AnimeCharacter character) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: K.bg.withValues(alpha: 0.95),
      leading: const SizedBox.shrink(),
      title: Text(
        character.name,
        style: K.titleMedium.copyWith(color: K.textPrimary),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded, color: K.textSecondary),
          onPressed: () {},
        ),
      ],
    );
  }

  // ── Hero Section (~40% viewport) ─────────────────────────

  Widget _buildHeroSection(BuildContext context, AnimeCharacter character) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.4,
      padding: const EdgeInsets.symmetric(horizontal: K.s24),
      child: Stack(
        children: [
          // Background atmospheric glow
          Positioned(
            top: -20,
            right: -30,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    K.threadPrimary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Character portrait (50% width)
              Expanded(
                flex: 5,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: K.threadPrimary.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    ClipOval(
                      child: KuroImg(
                        character.imageUrl,
                        width: 200,
                        height: 200,
                      ),
                    ),
                  ],
                ),
              ),

              // Character info (50% width)
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.only(left: K.s20, top: K.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        character.name,
                        style: K.headlineLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: K.s12),
                      PersonalityTag(label: character.role, color: K.coral),
                      const Spacer(),
                      KokuroButton(
                        label: AppStrings.viewAnime,
                        icon: Icons.movie_outlined,
                        filled: false,
                        onPressed: () {},
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

  // ── Personality Section ──────────────────────────────────

  Widget _buildPersonalitySection(AnimeCharacter character) {
    final personality = _derivePersonality(character.role);

    return Padding(
      padding: const EdgeInsets.fromLTRB(K.s24, K.s24, K.s24, K.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.personality.toUpperCase(), style: K.labelUppercase),
          const SizedBox(height: K.s12),
          Wrap(
            spacing: K.s8,
            runSpacing: K.s8,
            children: personality.map((p) {
              return PersonalityTag(label: p, color: K.accent);
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<String> _derivePersonality(String role) {
    switch (role.toLowerCase()) {
      case 'protagonist':
        return [
          AppStrings.traitBrave,
          AppStrings.traitDetermined,
          AppStrings.traitResilient,
        ];
      case 'antagonist':
        return [
          AppStrings.traitRuthless,
          AppStrings.traitIntelligent,
          AppStrings.traitCharismatic,
        ];
      case 'rival':
        return [
          AppStrings.traitProud,
          AppStrings.traitStrategic,
          AppStrings.traitComplex,
        ];
      case 'love interest':
        return [
          AppStrings.traitGraceful,
          AppStrings.traitPerceptive,
          AppStrings.traitKind,
        ];
      case 'supporting':
        return [
          AppStrings.traitLoyal,
          AppStrings.traitReliable,
          AppStrings.traitVersatile,
        ];
      case 'deuteragonist':
        return [
          AppStrings.traitSupportive,
          AppStrings.traitStrong,
          AppStrings.traitDependable,
        ];
      default:
        return [
          AppStrings.traitUnique,
          AppStrings.traitIntriguing,
          AppStrings.traitMysterious,
        ];
    }
  }

  // ── Voice Actor Section ──────────────────────────────────

  Widget _buildVoiceActorSection(AnimeCharacter character) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(K.s24, K.s16, K.s24, K.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.voiceActor.toUpperCase(), style: K.labelUppercase),
          const SizedBox(height: K.s12),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: K.bgSurface,
                  border: Border.all(color: K.border, width: 1),
                ),
                child:
                    character.voiceActorImageUrl != null &&
                        character.voiceActorImageUrl!.isNotEmpty
                    ? ClipOval(
                        child: KuroImg(
                          character.voiceActorImageUrl!,
                          width: 48,
                          height: 48,
                          error: const Center(
                            child: Icon(
                              Icons.mic_none_rounded,
                              color: K.textTertiary,
                              size: 22,
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.mic_none_rounded,
                          color: K.textTertiary,
                          size: 22,
                        ),
                      ),
              ),
              const SizedBox(width: K.s12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.voiceActorName != null &&
                            character.voiceActorName!.isNotEmpty
                        ? character.voiceActorName!
                        : AppStrings.unknown,
                    style: K.titleMedium.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: K.s2),
                  Text(AppStrings.japanese, style: K.bodySmall),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Appearances Section ──────────────────────────────────

  Widget _buildAppearancesSection(
    BuildContext context,
    List<Anime> appearances,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(K.s24, K.s24, K.s24, K.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.appearances.toUpperCase(), style: K.labelUppercase),
          const SizedBox(height: K.s12),
          if (appearances.isEmpty)
            Center(child: Text(AppStrings.noAppearances, style: K.bodyLarge))
          else
            ...appearances.map((anime) => _buildAppearanceItem(anime)),
        ],
      ),
    );
  }

  Widget _buildAppearanceItem(Anime anime) {
    return Container(
      margin: const EdgeInsets.only(bottom: K.s8),
      padding: const EdgeInsets.all(K.s12),
      decoration: BoxDecoration(
        color: K.bgCard,
        borderRadius: BorderRadius.circular(K.r12),
        border: Border.all(color: K.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(K.r8),
            child: KuroImg(anime.imageUrl, width: 48, height: 64),
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
                  '${anime.episodes} ${AppStrings.episodes} \u2022 ${anime.status}',
                  style: K.bodySmall,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          RatingStars(rating: anime.score, size: 12, showNumber: false),
        ],
      ),
    );
  }
}
