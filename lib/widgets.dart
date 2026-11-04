import 'package:flutter/material.dart';

import 'theme.dart';

/// Full-screen gradient background used on every page.
class GradientScaffold extends StatelessWidget {
  final Widget child;
  final bool safeArea;
  final bool scrollable;

  const GradientScaffold({
    super.key,
    required this.child,
    this.safeArea = true,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = safeArea ? SafeArea(child: child) : child;
    if (scrollable) {
      content = SingleChildScrollView(child: content);
    }
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: content,
    );
  }
}

/// Pill-shaped primary button with gradient.
class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final Color? color;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final baseColor = color ?? AppColors.primary;

    return SizedBox(
      height: 56,
      child: outlined
          ? OutlinedButton(
              onPressed: disabled ? null : onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: baseColor,
                side: BorderSide(color: baseColor.withOpacity(0.4), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: _content(),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: disabled ? null : AppGradients.primaryButton,
                color: disabled ? Colors.grey.shade300 : null,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: disabled ? null : AppShadow.soft,
              ),
              child: ElevatedButton(
                onPressed: disabled ? null : onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: _content(),
              ),
            ),
    );
  }

  Widget _content() {
    if (loading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      );
    }
    if (icon == null) {
      return Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// Small rounded chip (used for band labels like "5G", "2_4G").
class BandChip extends StatelessWidget {
  final String label;
  final Color color;

  const BandChip({super.key, required this.label, required this.color});

  factory BandChip.forBand(String band) {
    final c = band == '5G'
        ? AppColors.primary
        : band == '2_4G'
            ? AppColors.pink
            : AppColors.blue;
    return BandChip(label: band, color: c);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Rounded white card with soft shadow.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadow.card,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: content,
    );
  }
}

/// One tile in the stats grid.
class StatTile extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final Color accent;
  final IconData? icon;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const StatTile({
    super.key,
    required this.value,
    required this.unit,
    required this.label,
    required this.accent,
    this.icon,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      gradient: gradient,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Icon(icon, size: 20, color: accent),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: gradient != null ? Colors.white : AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: gradient != null
                      ? Colors.white.withOpacity(0.85)
                      : AppColors.textMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: gradient != null
                  ? Colors.white.withOpacity(0.85)
                  : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical spacing helper.
class Gap extends StatelessWidget {
  final double h;
  const Gap(this.h, {super.key});

  @override
  Widget build(BuildContext context) => SizedBox(height: h);
}

/// Section header with optional right-hand action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppText.h2),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                action!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated number that tweens when its value changes.
class AnimatedNumber extends StatelessWidget {
  final double value;
  final int decimals;
  final TextStyle style;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.decimals = 0,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(
        v.toStringAsFixed(decimals),
        style: style,
      ),
    );
  }
}
