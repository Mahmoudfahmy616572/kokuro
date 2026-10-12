import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';
import 'tokens.dart';

/// Lightweight local profile — name, bio, avatar icon/color, favorite genre.
/// Stored only on-device via [SharedPreferences]; no backend.
class UserProfile {
  final String name;
  final String bio;
  final int avatarIndex;
  final int colorIndex;
  final String favoriteGenre;

  const UserProfile({
    this.name = '',
    this.bio = '',
    this.avatarIndex = 0,
    this.colorIndex = 0,
    this.favoriteGenre = '',
  });

  String get displayName =>
      name.trim().isEmpty ? AppStrings.guestUser : name.trim();

  IconData get avatarIcon =>
      avatarIcons[avatarIndex.clamp(0, avatarIcons.length - 1)];

  Color get avatarColor =>
      avatarColors[colorIndex.clamp(0, avatarColors.length - 1)];

  UserProfile copyWith({
    String? name,
    String? bio,
    int? avatarIndex,
    int? colorIndex,
    String? favoriteGenre,
  }) {
    return UserProfile(
      name: name ?? this.name,
      bio: bio ?? this.bio,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      colorIndex: colorIndex ?? this.colorIndex,
      favoriteGenre: favoriteGenre ?? this.favoriteGenre,
    );
  }

  static const avatarIcons = <IconData>[
    Icons.person_rounded,
    Icons.face_rounded,
    Icons.auto_awesome_rounded,
    Icons.local_fire_department_rounded,
    Icons.headphones_rounded,
    Icons.videogame_asset_rounded,
    Icons.movie_rounded,
    Icons.menu_book_rounded,
    Icons.bolt_rounded,
    Icons.favorite_rounded,
    Icons.dark_mode_rounded,
    Icons.rocket_launch_rounded,
    Icons.pets_rounded,
    Icons.music_note_rounded,
    Icons.psychology_rounded,
    Icons.workspace_premium_rounded,
  ];

  static List<Color> get avatarColors => [
    K.accent,
    K.cyan,
    K.coral,
    K.orange,
    K.pink,
    K.gold,
    K.accentSoft,
    K.threadSecondary,
  ];

  static const _nameKey = 'profile_name';
  static const _bioKey = 'profile_bio';
  static const _avatarKey = 'profile_avatar_index';
  static const _colorKey = 'profile_color_index';
  static const _genreKey = 'profile_favorite_genre';

  static Future<UserProfile> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return UserProfile(
        name: prefs.getString(_nameKey) ?? '',
        bio: prefs.getString(_bioKey) ?? '',
        avatarIndex: prefs.getInt(_avatarKey) ?? 0,
        colorIndex: prefs.getInt(_colorKey) ?? 0,
        favoriteGenre: prefs.getString(_genreKey) ?? '',
      );
    } catch (_) {
      return const UserProfile();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
    await prefs.setString(_bioKey, bio);
    await prefs.setInt(_avatarKey, avatarIndex);
    await prefs.setInt(_colorKey, colorIndex);
    await prefs.setString(_genreKey, favoriteGenre);
  }
}
