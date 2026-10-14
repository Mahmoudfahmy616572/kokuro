import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../domain/entities/watch_status.dart';
import 'app_strings.dart';
import 'tokens.dart';
import 'loading_widgets.dart';
import 'image_diag.dart';

// ══════════════════════════════════════════════════════════
//  KuroImg — cached network image with a themed placeholder and
//  error fallback. All anime art goes through this so posters are
//  cached (memory + browser) instead of refetched on every rebuild.
// ══════════════════════════════════════════════════════════

class KuroImg extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final BoxDecoration? decoration;
  final Widget? placeholder;
  final Widget? error;

  const KuroImg(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.decoration,
    this.placeholder,
    this.error,
  });

  Widget _fallback(IconData icon, {double? iconSize}) {
    return DecoratedBox(
      decoration: decoration ?? const BoxDecoration(color: K.bgCard),
      child: Center(
        child: Icon(icon, color: K.textTertiary, size: iconSize ?? 32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _fallback(Icons.movie_outlined);
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decode at ~display size × DPR: a 160-wide card decodes ~320px-wide
        // instead of the full source (up to 1900+), which is exactly the
        // pixel density the screen can show — zero visual loss, ~5-10× less
        // RAM. Bounded so full-bleed backdrops never exceed the viewport.
        final double? targetW = (width != null && width!.isFinite)
            ? width! * dpr
            : constraints.hasBoundedWidth
            ? constraints.maxWidth * dpr
            : null;
        final double? targetH = (height != null && height!.isFinite)
            ? height! * dpr
            : constraints.hasBoundedHeight
            ? constraints.maxHeight * dpr
            : null;
        final int? memCacheWidth = targetW != null && targetW > 1
            ? targetW.ceil().clamp(1, 1920).toInt()
            : null;
        final int? memCacheHeight = targetH != null && targetH > 1
            ? targetH.ceil().clamp(1, 2880).toInt()
            : null;

        return CachedNetworkImage(
          imageUrl: url,
          fit: fit,
          width: width,
          height: height,
          alignment: alignment,
          memCacheWidth: memCacheWidth,
          memCacheHeight: memCacheHeight,
          // Keep the stored/offline copy bounded too (web keeps raw bytes in
          // memory — a 1280px ceiling cuts that working set without touching
          // display quality).
          maxWidthDiskCache: 1280,
          maxHeightDiskCache: 1920,
          fadeInDuration: const Duration(milliseconds: 250),
          placeholder: (_, _) =>
              placeholder ??
              KShimmer(
                width: width ?? double.infinity,
                height: height ?? double.infinity,
              ),
          errorWidget: (_, url, err) {
            recordImageFailure(url, err);
            return error ?? _fallback(Icons.image_not_supported_outlined);
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Section Header
// ══════════════════════════════════════════════════════════

class SectionHeader extends StatelessWidget {
  final String label;
  final String? title;
  final Widget? trailing;
  final EdgeInsets padding;

  const SectionHeader({
    super.key,
    required this.label,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: K.s32),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: K.labelUppercase),
                if (title != null) ...[
                  const SizedBox(height: K.s4),
                  Text(title!, style: K.headlineMedium),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Genre Node — circular genre visualization
// ══════════════════════════════════════════════════════════

class GenreNode extends StatefulWidget {
  final String name;
  final int? count;
  final double size;
  final VoidCallback? onTap;

  const GenreNode({
    super.key,
    required this.name,
    this.count,
    this.size = 100,
    this.onTap,
  });

  @override
  State<GenreNode> createState() => _GenreNodeState();
}

class _GenreNodeState extends State<GenreNode> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = _genreColors(widget.name);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: K.normal,
          curve: K.easeOut,
          width: widget.size,
          height: widget.size,
          transform: Matrix4.diagonal3Values(
            _hovered ? 1.08 : 1.0,
            _hovered ? 1.08 : 1.0,
            1.0,
          ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _hovered
                  ? colors.$1.withValues(alpha: 0.6)
                  : K.border.withValues(alpha: 0.3),
              width: _hovered ? 2 : 1,
            ),
            boxShadow: _hovered ? K.glow(color: colors.$1, blur: 24) : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.$1.withValues(alpha: 0.15),
                      colors.$2.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.genreLabel(widget.name),
                    style: K.titleMedium.copyWith(
                      fontSize: 13,
                      color: _hovered ? colors.$1 : K.textPrimary,
                    ),
                  ),
                  const SizedBox(height: K.s2),
                  if (widget.count != null)
                    Text(
                      '${widget.count} ${AppStrings.titles}',
                      style: K.bodySmall.copyWith(
                        color: _hovered
                            ? colors.$1.withValues(alpha: 0.8)
                            : K.textTertiary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (Color, Color) _genreColors(String name) {
    switch (name) {
      case 'Action':
        return (K.coral, K.orange);
      case 'Fantasy':
        return (K.accent, K.accentSoft);
      case 'Drama':
        return (K.pink, K.threadWarm);
      case 'Romance':
        return (K.pink, const Color(0xFFF5A0C0));
      case 'Sci-Fi':
        return (K.cyan, const Color(0xFF80D8F0));
      case 'Mystery':
        return (const Color(0xFF9B72CF), K.accent);
      default:
        return (K.accent, K.cyan);
    }
  }
}

// ══════════════════════════════════════════════════════════
//  DNA Bar — horizontal stat visualization
// ══════════════════════════════════════════════════════════

class DnaBar extends StatelessWidget {
  final String label;
  final double value;
  final Color? color;

  const DnaBar({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? K.accent;
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: K.bodySmall.copyWith(color: K.textSecondary),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: K.bgSurface,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [c.withValues(alpha: 0.4), c],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: K.s8),
        SizedBox(
          width: 32,
          child: Text(
            '${(value * 100).round()}%',
            style: K.bodySmall.copyWith(color: c, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Rating Stars
// ══════════════════════════════════════════════════════════

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final bool showNumber;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 14,
    this.showNumber = true,
  });

  @override
  Widget build(BuildContext context) {
    final stars = (rating / 2).round().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          return Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < stars ? K.gold : K.textTertiary,
          );
        }),
        if (showNumber) ...[
          const SizedBox(width: K.s4),
          Text(
            rating.toStringAsFixed(1),
            style: K.bodySmall.copyWith(color: K.gold),
          ),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════
//  KOKURO Button
// ══════════════════════════════════════════════════════════

class KokuroButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final Color? accentColor;

  const KokuroButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.filled = true,
    this.accentColor,
  });

  @override
  State<KokuroButton> createState() => _KokuroButtonState();
}

class _KokuroButtonState extends State<KokuroButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.accentColor ?? K.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: K.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: K.s20,
            vertical: K.s12,
          ),
          decoration: BoxDecoration(
            color: widget.filled
                ? (_hovered ? color.withValues(alpha: 0.9) : color)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(K.r8),
            border: widget.filled
                ? null
                : Border.all(color: color.withValues(alpha: 0.4), width: 1),
            boxShadow: _hovered && widget.filled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: K.textPrimary),
                const SizedBox(width: K.s6),
              ],
              Text(
                widget.label,
                style: K.titleMedium.copyWith(
                  fontSize: 14,
                  color: K.textPrimary,
                  fontWeight: FontWeight.w500,
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
//  My List button — add/change watch status (or remove)
// ══════════════════════════════════════════════════════════

class MyListButton extends StatelessWidget {
  final bool inList;
  final WatchStatus? status;
  final ValueChanged<WatchStatus> onSelect;
  final VoidCallback? onRemove;
  final String addLabel;

  const MyListButton({
    super.key,
    required this.inList,
    this.status,
    required this.onSelect,
    this.onRemove,
    this.addLabel = AppStrings.addToMyList,
  });

  @override
  Widget build(BuildContext context) {
    final current = status ?? WatchStatus.planToWatch;
    final label = inList ? (status?.label ?? AppStrings.inMyList) : addLabel;
    return PopupMenuButton<Object>(
      color: K.bgCard,
      tooltip: AppStrings.myList,
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(K.r12),
        side: const BorderSide(color: K.border),
      ),
      onSelected: (value) {
        if (value is WatchStatus) {
          onSelect(value);
        } else {
          onRemove?.call();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<Object>(
          enabled: false,
          height: 30,
          child: Text(AppStrings.myList.toUpperCase(), style: K.labelUppercase),
        ),
        ...WatchStatus.values.map(
          (s) => PopupMenuItem<Object>(
            value: s,
            child: Row(
              children: [
                Icon(
                  inList && s == current
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: inList && s == current ? K.accent : K.textTertiary,
                ),
                const SizedBox(width: K.s8),
                Text(s.label, style: K.bodyMedium),
              ],
            ),
          ),
        ),
        if (inList) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<Object>(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 16, color: K.coral),
                SizedBox(width: K.s8),
                Text(AppStrings.removeFromMyList),
              ],
            ),
          ),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: K.s20, vertical: K.s12),
        decoration: BoxDecoration(
          color: inList ? K.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(K.r8),
          border: Border.all(
            color: inList
                ? K.accent.withValues(alpha: 0.7)
                : K.accent.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              inList ? Icons.check_rounded : Icons.add_rounded,
              size: 18,
              color: K.textPrimary,
            ),
            const SizedBox(width: K.s6),
            Text(
              label,
              style: K.titleMedium.copyWith(
                fontSize: 14,
                color: K.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: K.s4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: K.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Personality Tag
// ══════════════════════════════════════════════════════════

class PersonalityTag extends StatelessWidget {
  final String label;
  final Color? color;

  const PersonalityTag({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? K.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: K.s12, vertical: K.s6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(K.rFull),
        border: Border.all(color: c.withValues(alpha: 0.2), width: 1),
      ),
      child: Text(
        label,
        style: K.bodySmall.copyWith(
          color: c.withValues(alpha: 0.9),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
