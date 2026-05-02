import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:valley_super_app/valley_brand_theme.dart';

class ValleyPanel extends StatelessWidget {
  const ValleyPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = 26,
    this.glowColor,
    this.background,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glowColor;
  final Gradient? background;

  @override
  Widget build(BuildContext context) {
    final ValleySurfacePalette palette = Theme.of(
      context,
    ).extension<ValleySurfacePalette>()!;
    final Color shadow = glowColor ?? palette.glow;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient:
            background ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[palette.panel, palette.panelStrong],
            ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shadow.withValues(alpha: 0.10),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.kicker,
    required this.title,
    required this.caption,
    this.trailing,
  });

  final String kicker;
  final String title;
  final String caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                kicker.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: ValleyBrandColors.cyan,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                caption,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

class SignalChip extends StatelessWidget {
  const SignalChip({
    super.key,
    required this.label,
    this.color = ValleyBrandColors.cyan,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final Color foreground = outlined ? color : ValleyBrandColors.snow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    this.accent = ValleyBrandColors.violet,
  });

  final String label;
  final String value;
  final String caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ValleyPanel(
      padding: const EdgeInsets.all(18),
      glowColor: accent,
      background: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accent.withValues(alpha: 0.12),
          Theme.of(context)
              .extension<ValleySurfacePalette>()!
              .panelStrong
              .withValues(alpha: 0.92),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            caption,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedReadinessBar extends StatelessWidget {
  const AnimatedReadinessBar({
    super.key,
    required this.value,
    this.color = ValleyBrandColors.cyan,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final double normalized = value.clamp(0, 100) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Stack(
            children: <Widget>[
              Container(height: height, color: color.withValues(alpha: 0.16)),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: normalized),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, animatedValue, child) {
                  return Container(
                    height: height,
                    width: constraints.maxWidth * animatedValue,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          color,
                          Color.lerp(color, ValleyBrandColors.lilac, 0.42)!,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class HoverModuleTile extends StatefulWidget {
  const HoverModuleTile({
    super.key,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.caption,
    this.onTap,
  });

  final String code;
  final String title;
  final String subtitle;
  final String caption;
  final VoidCallback? onTap;

  @override
  State<HoverModuleTile> createState() => _HoverModuleTileState();
}

class _HoverModuleTileState extends State<HoverModuleTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ValleySurfacePalette palette = Theme.of(
      context,
    ).extension<ValleySurfacePalette>()!;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.01 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _hovered
                  ? palette.panelStrong.withValues(alpha: 0.96)
                  : palette.panel.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _hovered
                    ? ValleyBrandColors.cyan.withValues(alpha: 0.48)
                    : palette.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SignalChip(
                      label: widget.code,
                      color: _hovered
                          ? ValleyBrandColors.cyan
                          : ValleyBrandColors.violet,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.north_east_rounded,
                      color: _hovered
                          ? ValleyBrandColors.cyan
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.offset = const Offset(0, 20),
  });

  final Widget child;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? child) {
        final double t = Curves.easeOutCubic.transform(value);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(offset.dx * (1 - t), offset.dy * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class ValleyBackdrop extends StatelessWidget {
  const ValleyBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final bool light = Theme.of(context).brightness == Brightness.light;
    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: light
                      ? const <Color>[
                          Color(0x40FFFFFF),
                          Color(0x1A6F2CFF),
                          Color(0x1420C8F3),
                        ]
                      : const <Color>[
                          Color(0x00000000),
                          Color(0x00000000),
                        ],
                ),
              ),
              child: CustomPaint(
                painter: _MountainPulsePainter(light: light),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MountainPulsePainter extends CustomPainter {
  const _MountainPulsePainter({required this.light});

  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = light ? const Color(0x186F2CFF) : const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final Path path = Path()..moveTo(0, size.height * 0.82);
    for (double x = 0; x <= size.width + 18; x += 18) {
      final double wave = math.sin(x / 70) * 14;
      final double ridge = math.sin(x / 180 + 1.4) * 26;
      path.lineTo(x, size.height * 0.82 - wave - ridge);
    }

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
