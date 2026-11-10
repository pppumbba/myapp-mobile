import 'package:flutter/material.dart';

import 'tones.dart';

/// Grey boxes in the shape of what is loading, with a soft light sweeping across them. Every content
/// load shows one of the shapes below; the ring stays only inside buttons and for a pull to refresh.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Held still when animations are off.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A pale band: it lifts the grey boxes and vanishes on the card behind them.
    final light = Colors.white.withValues(alpha: scheme.isDark ? 0.06 : 0.55);
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _sweep,
          child: widget.child,
          builder: (context, child) => ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (r) {
              // A band a third of the width wide, travelling from off the left edge to off the right.
              final x = -1.0 + 3.0 * _sweep.value;
              return LinearGradient(
                begin: Alignment(x - 0.6, -0.2),
                end: Alignment(x + 0.6, 0.2),
                colors: [light.withValues(alpha: 0), light, light.withValues(alpha: 0)],
              ).createShader(r);
            },
            child: child,
          ),
        ),
      ),
    );
  }
}

/// One grey box.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: scheme.isDark ? 0.10 : 0.08),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    // A set width holds even in a stretched column.
    return width == null ? box : Align(alignment: Alignment.centerLeft, widthFactor: 1, heightFactor: 1, child: box);
  }
}

/// Widths that vary from row to row, so the boxes don't read as one stamped block.
double _w(int i, List<double> fractions, double max) => fractions[i % fractions.length] * max;

/// A record card's shape: title with a chip at its right, a subtitle, a row of values.
class SkeletonCard extends StatelessWidget {
  final int seed;
  final EdgeInsetsGeometry margin;
  const SkeletonCard({super.key, this.seed = 0, this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4)});

  @override
  Widget build(BuildContext context) => Card(
        margin: margin,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: LayoutBuilder(
            builder: (_, box) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SkeletonBox(width: _w(seed, const [0.55, 0.42, 0.62, 0.48], box.maxWidth), height: 14),
                const Spacer(),
                const SkeletonBox(width: 54, height: 16, radius: 12),
              ]),
              const SizedBox(height: 8),
              SkeletonBox(width: _w(seed, const [0.35, 0.5, 0.3, 0.44], box.maxWidth), height: 10),
              const SizedBox(height: 10),
              Row(children: [
                SkeletonBox(width: _w(seed, const [0.22, 0.18, 0.26, 0.2], box.maxWidth), height: 10),
                const SizedBox(width: 12),
                SkeletonBox(width: _w(seed + 1, const [0.22, 0.18, 0.26, 0.2], box.maxWidth), height: 10),
              ]),
            ]),
          ),
        ),
      );
}

/// A list of record cards (grids, lookups, a screen still loading its definition).
class CardListSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  const CardListSkeleton({super.key, this.count = 6, this.padding = const EdgeInsets.only(top: 4)});

  @override
  Widget build(BuildContext context) => Shimmer(
        child: _Still(
          padding: padding,
          children: [for (var i = 0; i < count; i++) SkeletonCard(seed: i, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3))],
        ),
      );
}

/// The account page's rounded block of rows (notifications, languages).
class RowGroupSkeleton extends StatelessWidget {
  final int rows;
  /// Rows without the icon square (pick lists).
  final bool icons;
  const RowGroupSkeleton({super.key, this.rows = 5, this.icons = true});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: scheme.softFill, borderRadius: BorderRadius.circular(16)),
      child: LayoutBuilder(
        builder: (_, box) => Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < rows; i++)
            SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  if (icons) ...[const SkeletonBox(width: 32, height: 32, radius: 9), const SizedBox(width: 14)],
                  SkeletonBox(width: _w(i, const [0.45, 0.32, 0.52, 0.38, 0.28], box.maxWidth), height: 13),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// A form's shape: label over an outlined field, a few times.
class FormSkeleton extends StatelessWidget {
  final int fields;
  const FormSkeleton({super.key, this.fields = 6});

  @override
  Widget build(BuildContext context) => Shimmer(
        child: _Still(
          padding: const EdgeInsets.all(16),
          children: [
            for (var i = 0; i < fields; i++) ...[
              LayoutBuilder(builder: (_, box) => Align(
                    alignment: Alignment.centerLeft,
                    child: SkeletonBox(width: _w(i, const [0.3, 0.22, 0.36, 0.26], box.maxWidth), height: 11),
                  )),
              const SizedBox(height: 8),
              const SkeletonBox(height: 52, radius: 12),
              const SizedBox(height: 18),
            ],
          ],
        ),
      );
}

/// One dashboard card's body while its own data loads.
class ChartSkeleton extends StatelessWidget {
  final double height;
  const ChartSkeleton({super.key, this.height = 36});

  @override
  Widget build(BuildContext context) => Shimmer(child: SkeletonBox(height: height, radius: 10));
}

/// A workspace's shape: header card, a row of section tabs, then cards.
class WorkspaceSkeleton extends StatelessWidget {
  const WorkspaceSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Shimmer(
        child: _Still(
          padding: const EdgeInsets.only(top: 8),
          children: [
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: SkeletonBox(height: 96, radius: 16)),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: const [
                SkeletonBox(width: 84, height: 30, radius: 15),
                SizedBox(width: 8),
                SkeletonBox(width: 70, height: 30, radius: 15),
                SizedBox(width: 8),
                SkeletonBox(width: 92, height: 30, radius: 15),
              ]),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < 4; i++) SkeletonCard(seed: i, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3)),
          ],
        ),
      );
}

/// Boxes stacked top-down that never scroll; cut off at the bottom of a short space, sized to
/// their content inside a scroll view.
class _Still extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final List<Widget> children;
  const _Still({required this.padding, required this.children});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}
