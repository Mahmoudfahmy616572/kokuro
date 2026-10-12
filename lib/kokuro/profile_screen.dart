import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';
import 'components.dart';
import 'tokens.dart';
import 'user_profile.dart';

/// Local-first profile editor: name, bio, avatar icon/color, favorite genre.
/// No backend — everything lives in SharedPreferences on this device.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  late int _avatarIndex;
  late int _colorIndex;
  late int _accentIndex;
  late String _favoriteGenre;
  bool _loading = true;
  bool _saving = false;

  static const _genreOptions = <String>[
    '',
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
    _avatarIndex = 0;
    _colorIndex = 0;
    _accentIndex = 0;
    _favoriteGenre = '';
    _load();
  }

  Future<void> _load() async {
    final profile = await UserProfile.load();
    final prefs = await SharedPreferences.getInstance();
    final accentIndex = prefs.getInt('app_accent_index') ?? 0;
    if (!mounted) return;
    setState(() {
      _nameController.text = profile.name;
      _bioController.text = profile.bio;
      _avatarIndex = profile.avatarIndex;
      _colorIndex = profile.colorIndex;
      _accentIndex = accentIndex;
      _favoriteGenre = profile.favoriteGenre;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: K.bgCard,
          content: Text(
            AppStrings.nameRequired,
            style: K.bodyMedium.copyWith(color: K.textPrimary),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final profile = UserProfile(
      name: name,
      bio: _bioController.text.trim(),
      avatarIndex: _avatarIndex,
      colorIndex: _colorIndex,
      favoriteGenre: _favoriteGenre,
    );
    await profile.save();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: K.bgCard,
        content: Text(
          AppStrings.profileSaved,
          style: K.bodyMedium.copyWith(color: K.textPrimary),
        ),
      ),
    );
    _back();
  }

  /// The profile route is reached via `go` (which replaces the whole page
  /// stack), so there may be nothing to pop — fall back to home in that case.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: K.accent))
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(child: _buildForm()),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(K.s24, K.s16, K.s24, 0),
      child: Row(
        children: [
          KokuroButton(
            label: AppStrings.goBack,
            icon: Icons.arrow_back_rounded,
            filled: false,
            accentColor: K.accent,
            onPressed: _back,
          ),
          const SizedBox(width: K.s16),
          Text(AppStrings.myProfile, style: K.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final previewColor =
        UserProfile.avatarColors[_colorIndex.clamp(
          0,
          UserProfile.avatarColors.length - 1,
        )];
    final previewIcon = UserProfile
        .avatarIcons[_avatarIndex.clamp(0, UserProfile.avatarIcons.length - 1)];

    return Padding(
      padding: const EdgeInsets.fromLTRB(K.s24, K.s32, K.s24, K.s64),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: previewColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: K.glow(color: previewColor, blur: 24),
                  ),
                  child: ClipOval(
                    child: Container(
                      color: K.bgCard,
                      child: Icon(previewIcon, size: 48, color: previewColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: K.s32),
              _buildLabel(AppStrings.pickAvatar),
              const SizedBox(height: K.s12),
              _buildIconPicker(),
              const SizedBox(height: K.s8),
              _buildColorPicker(),
              const SizedBox(height: K.s24),
              _buildLabel(AppStrings.accentTheme),
              const SizedBox(height: K.s12),
              _buildAccentPicker(),
              const SizedBox(height: K.s24),
              _buildLabel(AppStrings.displayName),
              const SizedBox(height: K.s8),
              _buildTextField(
                controller: _nameController,
                hint: AppStrings.displayNameHint,
                icon: Icons.badge_rounded,
              ),
              const SizedBox(height: K.s20),
              _buildLabel(AppStrings.bio),
              const SizedBox(height: K.s8),
              _buildTextField(
                controller: _bioController,
                hint: AppStrings.bioHint,
                icon: Icons.edit_note_rounded,
                maxLines: 3,
              ),
              const SizedBox(height: K.s20),
              _buildLabel(AppStrings.favoriteGenre),
              const SizedBox(height: K.s8),
              _buildGenreDropdown(),
              const SizedBox(height: K.s32),
              Center(
                child: KokuroButton(
                  label: _saving ? '…' : AppStrings.save,
                  icon: Icons.save_rounded,
                  accentColor: previewColor,
                  onPressed: _saving ? null : _save,
                ),
              ),
              const SizedBox(height: K.s16),
              Center(
                child: Text(
                  AppStrings.localOnlyNote,
                  textAlign: TextAlign.center,
                  style: K.bodySmall.copyWith(color: K.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: K.labelUppercase);
  }

  Widget _buildIconPicker() {
    return Wrap(
      spacing: K.s8,
      runSpacing: K.s8,
      children: [
        for (var i = 0; i < UserProfile.avatarIcons.length; i++)
          _pickChip(
            selected: _avatarIndex == i,
            onTap: () => setState(() => _avatarIndex = i),
            child: Icon(
              UserProfile.avatarIcons[i],
              size: 20,
              color: _avatarIndex == i ? K.textPrimary : K.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildAccentPicker() {
    return Wrap(
      spacing: K.s8,
      runSpacing: K.s8,
      children: [
        for (var i = 0; i < K.accentPresets.length; i++)
          GestureDetector(
            onTap: () {
              setState(() => _accentIndex = i);
              K.applyAccentIndex(i);
            },
            child: AnimatedContainer(
              duration: K.fast,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: K.accentPresets[i].$1,
                border: Border.all(
                  color: _accentIndex == i ? K.textPrimary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: _accentIndex == i
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.black,
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Wrap(
      spacing: K.s8,
      runSpacing: K.s8,
      children: [
        for (var i = 0; i < UserProfile.avatarColors.length; i++)
          GestureDetector(
            onTap: () => setState(() => _colorIndex = i),
            child: AnimatedContainer(
              duration: K.fast,
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: UserProfile.avatarColors[i],
                border: Border.all(
                  color: _colorIndex == i ? K.textPrimary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _pickChip({
    required bool selected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: K.fast,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: selected ? K.bgSurface : K.bgCard,
            borderRadius: BorderRadius.circular(K.r8),
            border: Border.all(
              color: selected
                  ? K.accent.withValues(alpha: 0.6)
                  : K.borderSubtle,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: K.bgCard,
        borderRadius: BorderRadius.circular(K.r8),
        border: Border.all(color: K.borderSubtle),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: K.bodyMedium.copyWith(color: K.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: K.bodyMedium.copyWith(color: K.textTertiary),
          prefixIcon: Icon(icon, color: K.textTertiary, size: 18),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: K.s12,
            vertical: K.s12,
          ),
        ),
      ),
    );
  }

  Widget _buildGenreDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: K.s12),
      decoration: BoxDecoration(
        color: K.bgCard,
        borderRadius: BorderRadius.circular(K.r8),
        border: Border.all(color: K.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _genreOptions.contains(_favoriteGenre) ? _favoriteGenre : '',
          isExpanded: true,
          dropdownColor: K.bgCard,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: K.textTertiary,
          ),
          style: K.bodyMedium.copyWith(color: K.textPrimary),
          items: [
            for (final g in _genreOptions)
              DropdownMenuItem(
                value: g,
                child: Text(
                  g.isEmpty ? AppStrings.none : g,
                  style: K.bodyMedium.copyWith(
                    color: g.isEmpty ? K.textTertiary : K.textPrimary,
                  ),
                ),
              ),
          ],
          onChanged: (v) => setState(() => _favoriteGenre = v ?? ''),
        ),
      ),
    );
  }
}
