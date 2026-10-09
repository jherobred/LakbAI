import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ai/ai_service.dart';
import '../core/app_state.dart';
import '../knowledge/topics.dart';
import '../theme.dart';

Future<T?> openPage<T>(BuildContext context, Widget page) {
  // Drop the keyboard first so the page does not resize mid-transition.
  FocusManager.instance.primaryFocus?.unfocus();
  return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page));
}

Future<void> callNumber(BuildContext context, String number) async {
  HapticFeedback.selectionClick();
  final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
  final ok = await launchUrl(uri);
  if (!ok && context.mounted) {
    await Clipboard.setData(ClipboardData(text: number));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(context, 'Number copied: $number', 'Nakopya ang numero: $number'))));
    }
  }
}

/// The Kontrata mark: a shield holding a contract with a check.
class KLogo extends StatefulWidget {
  const KLogo({super.key, this.size = 56, this.animate = false});
  final double size;
  final bool animate;

  @override
  State<KLogo> createState() => _KLogoState();
}

class _KLogoState extends State<KLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _LogoPainter(Curves.easeOutCubic.transform(_c.value), Theme.of(context).brightness == Brightness.dark),
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.t, this.dark);
  final double t;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shield = Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..cubicTo(w * 0.68, h * 0.13, w * 0.82, h * 0.15, w * 0.92, h * 0.16)
      ..cubicTo(w * 0.94, h * 0.55, w * 0.80, h * 0.82, w * 0.5, h * 0.97)
      ..cubicTo(w * 0.20, h * 0.82, w * 0.06, h * 0.55, w * 0.08, h * 0.16)
      ..cubicTo(w * 0.18, h * 0.15, w * 0.32, h * 0.13, w * 0.5, h * 0.04)
      ..close();
    final rect = Offset.zero & size;
    canvas.drawPath(
      shield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1A56DB), Color(0xFF0E7490)],
        ).createShader(rect),
    );
    // Paper
    final paper = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.30, h * 0.24, w * 0.40, h * 0.46), Radius.circular(w * 0.05));
    canvas.drawRRect(paper, Paint()..color = Colors.white.withValues(alpha: 0.96));
    final line = Paint()
      ..color = const Color(0xFF93C5FD)
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final y = h * (0.33 + i * 0.08);
      canvas.drawLine(Offset(w * 0.37, y), Offset(w * (i == 2 ? 0.52 : 0.63), y), line);
    }
    // Check mark draws itself in.
    final check = Path()
      ..moveTo(w * 0.40, h * 0.62)
      ..lineTo(w * 0.49, h * 0.71)
      ..lineTo(w * 0.70, h * 0.50);
    final metric = check.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * t);
    canvas.drawPath(
      partial,
      Paint()
        ..color = const Color(0xFF22C55E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.t != t || old.dark != dark;
}

/// Shrinks slightly under the finger, like a physical button.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class KCard extends StatelessWidget {
  const KCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color, this.gradient, this.onTap, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Flat tonal surface without an outline, as in Google's Material 3 apps.
    final decoration = BoxDecoration(
      color: gradient == null ? (color ?? cs.surfaceContainer) : null,
      gradient: gradient,
      borderRadius: BorderRadius.circular(24),
      border: borderColor != null ? Border.all(color: borderColor!) : null,
    );
    if (onTap == null) return Container(padding: padding, decoration: decoration, child: child);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap!();
          },
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Shows whether the on-device AI is ready, loading, downloading or off.
class AiStatusPill extends StatelessWidget {
  const AiStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    final t = KTokens.of(context);
    return ListenableBuilder(
      listenable: AiService.instance,
      builder: (context, _) {
        final ai = AiService.instance;
        final (Color c, String label) = switch (ai.status) {
          AiStatus.ready => (t.success, tr(context, 'Offline AI ready', 'Handa ang offline AI')),
          AiStatus.loading => (t.warning, tr(context, 'Loading AI…', 'Nilo-load ang AI…')),
          AiStatus.downloading => (t.warning, tr(context, 'Downloading ${ai.progress}%', 'Dina-download ${ai.progress}%')),
          AiStatus.error => (t.danger, tr(context, 'Basic mode', 'Basic mode')),
          AiStatus.notInstalled => (t.inkSoft, tr(context, 'Basic mode', 'Basic mode')),
        };
        return AnimatedContainer(
          duration: Motion.d(context, 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _PulseDot(color: c, active: ai.status == AiStatus.ready || ai.status == AiStatus.loading),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
          ]),
        );
      },
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color, required this.active});
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final dot = Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
    if (!active || Motion.reduced(context)) return dot;
    return dot
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 0.8, end: 1.25, duration: 900.ms, curve: Curves.easeInOut)
        .fade(begin: 0.6, end: 1);
  }
}

class TopicChip extends StatelessWidget {
  const TopicChip({super.key, required this.topic, this.active = true, this.onTap, this.onClose, this.dense = false});
  final Topic topic;
  final bool active;
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final fil = AppScope.of(context).isFil;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = topic.color;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.d(context, 220),
        padding: EdgeInsets.symmetric(horizontal: dense ? 9 : 12, vertical: dense ? 4 : 7),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: dark ? 0.26 : 0.13) : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.withValues(alpha: active ? 0.55 : 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(topic.icon, size: dense ? 13 : 16, color: c),
          const SizedBox(width: 5),
          Text(topic.label(fil), style: TextStyle(fontSize: dense ? 11.5 : 13.5, fontWeight: FontWeight.w700, color: dark ? Colors.white : c.withValues(alpha: 1))),
          if (onClose != null) ...[
            const SizedBox(width: 4),
            GestureDetector(onTap: onClose, child: Icon(Icons.close_rounded, size: 15, color: c)),
          ],
        ]),
      ),
    );
  }
}

/// Circular progress used for downloads.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 120, this.child});
  final double value;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => CustomPaint(
          painter: _RingPainter(v, cs.primary, cs.outlineVariant),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track);
  final double v;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final stroke = size.width * 0.075;
    final rect = r.deflate(stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false, Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * v, false, Paint()
      ..shader = SweepGradient(colors: [color, KColors.cyan, color], transform: const GradientRotation(-math.pi / 2)).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v;
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
        child: Text(text.toUpperCase(), style: TextStyle(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: KTokens.of(context).inkSoft)),
      );
}

/// Large icon tile for quick actions on the home screen.
class ActionTile extends StatelessWidget {
  const ActionTile({super.key, required this.icon, required this.title, required this.subtitle, required this.color, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const Spacer(),
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.15, fontSize: 15)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

/// Safety banner with direct-call buttons for 1343 and 1348.
class EmergencyBanner extends StatelessWidget {
  const EmergencyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final t = KTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.danger.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.health_and_safety_rounded, color: t.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr(context, 'If you are in danger, call now', 'Kung nasa panganib ka, tumawag ngayon'),
                style: TextStyle(fontWeight: FontWeight.w800, color: t.danger)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: t.danger, minimumSize: const Size(0, 46)),
              onPressed: () => callNumber(context, '+6321343'),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text('1343'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), foregroundColor: t.danger, side: BorderSide(color: t.danger)),
              onPressed: () => callNumber(context, '+6321348'),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text('1348'),
            ),
          ),
        ]),
      ]),
    ).animate().fadeIn(duration: Motion.d(context, 300)).slideY(begin: -0.15, curve: Curves.easeOutCubic);
  }
}
